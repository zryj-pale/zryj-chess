extends Node

# Relay-only networking for zryj chess.
# Replaces the old ENet-based network_manager.gd AND matchmaking_client.gd.
# All traffic (matchmaking + gameplay) goes through relay_server.py on the
# VPS. There is no direct P2P connection between players -- the server
# always forwards messages between the two players in a room.

# --- Public signals kept identical to the old NetworkManager, so main.gd
# and hud.gd need no changes. ---
signal player_connected
signal player_disconnected
signal game_started(white_pieces: Array, black_pieces: Array, host_is_white: bool)
signal move_received(from: Vector2i, to: Vector2i)
signal coinflip_received(result: String)

# --- Matchmaking-flavored signals kept identical to the old
# MatchmakingClient, so lobby.gd's existing handlers mostly still work.
# NOTE: mm_match_found no longer carries an ip/port (nothing to connect
# to -- everything goes through the relay). If lobby.gd's handler reads
# those args, drop them; player_connected fires right after this and is
# the real "we're ready to play" signal now. ---
signal mm_match_waiting
signal mm_match_found
signal mm_match_cancelled
signal mm_match_timeout
signal mm_match_full

# --- Connection / role state ---
var socket := PacketPeerUDP.new()
var server_address := ""
var server_port := 5000
var connected_to_relay := false

var room_name := ""
var is_searching := false
var is_host := false
var player_id := 0  # 1 = host/authority, 2 = joining player, matches old semantics

var my_pieces: Array = []
var opponent_pieces: Array = []
var host_is_white := true
var white_moves_first := true

# --- Reliability layer (ack + retry over the unreliable relay) ---
const RESEND_INTERVAL := 0.3
const MAX_RETRIES := 25
const SEEN_SEQ_HISTORY := 64

var _out_seq := 0
var _pending: Dictionary = {}       # seq -> {payload_str, elapsed, retries}
var _seen_in_seqs: Array = []       # recently processed incoming seqs (dedupe)

var _ping_timer: Timer = null


func _ready() -> void:
	set_process(true)


# ---------------------------------------------------------------------
# Connection lifecycle
# ---------------------------------------------------------------------

func connect_to_server(address: String, port: int = 5000) -> void:
	server_address = address
	server_port = port
	socket.connect_to_host(address, port)
	connected_to_relay = true
	_ensure_ping_timer()


func join_room(room: String) -> void:
	if not connected_to_relay:
		return
	room_name = room
	is_searching = true
	socket.put_packet(("JOIN:%s" % room).to_utf8_buffer())


func leave_room(room: String) -> void:
	is_searching = false
	if connected_to_relay:
		socket.put_packet(("LEAVE:%s" % room).to_utf8_buffer())
	_reset_room_state()


func cancel() -> void:
	is_searching = false
	if room_name != "":
		leave_room(room_name)
	_reset_room_state()


func close_connection() -> void:
	if room_name != "":
		socket.put_packet(("LEAVE:%s" % room_name).to_utf8_buffer())
	_reset_room_state()
	connected_to_relay = false
	if _ping_timer:
		_ping_timer.stop()


func _reset_room_state() -> void:
	room_name = ""
	is_host = false
	player_id = 0
	my_pieces = []
	opponent_pieces = []
	white_moves_first = true
	_pending.clear()
	_seen_in_seqs.clear()
	_out_seq = 0


# ---------------------------------------------------------------------
# Game API -- same method names/signatures as the old NetworkManager
# ---------------------------------------------------------------------

func set_my_positions(white_pieces: Array, _black_pieces: Array) -> void:
	my_pieces = white_pieces


func send_my_pieces() -> void:
	_send_reliable("set_pieces", {
		"pieces": _serialize_pieces(my_pieces),
	})


func _serialize_pieces(pieces: Array) -> Array:
	# Converts [[type, Vector2i], ...] -> [[type, [x, y]], ...] for JSON.
	var out: Array = []
	for entry in pieces:
		var pos = entry[1]
		if pos is Vector2i:
			out.append([entry[0], [pos.x, pos.y]])
		else:
			out.append([entry[0], [int(pos[0]), int(pos[1])]])
	return out


func _deserialize_pieces(pieces: Array) -> Array:
	# Converts [[type, [x, y]], ...] (JSON gives floats) -> [[type, Vector2i], ...]
	var out: Array = []
	for entry in pieces:
		var pos = entry[1]
		out.append([entry[0], Vector2i(int(pos[0]), int(pos[1]))])
	return out


func broadcast_coinflip(result: String) -> void:
	white_moves_first = (result == "orzel")
	_send_reliable("coinflip", {"result": result})


func start_game() -> void:
	_send_reliable("game_start", {
		"white": _serialize_pieces(my_pieces),
		"black": _serialize_pieces(opponent_pieces),
		"host_is_white": host_is_white,
		"white_moves_first": white_moves_first,
	})


func submit_move(from: Vector2i, to: Vector2i) -> void:
	_send_reliable("move", {
		"from": [from.x, from.y],
		"to": [to.x, to.y],
	})


# ---------------------------------------------------------------------
# Reliable-send layer
# ---------------------------------------------------------------------

func _send_reliable(type: String, data: Dictionary) -> void:
	_out_seq += 1
	var envelope = {"seq": _out_seq, "kind": "data", "type": type, "data": data}
	var payload_str = JSON.stringify(envelope)
	_pending[_out_seq] = {"payload": payload_str, "elapsed": 0.0, "retries": 0}
	_send_raw(payload_str)


func _send_ack(seq: int) -> void:
	var envelope = {"seq": seq, "kind": "ack"}
	_send_raw(JSON.stringify(envelope))


func _send_raw(payload_str: String) -> void:
	if room_name == "":
		return
	socket.put_packet(("DATA:%s:%s" % [room_name, payload_str]).to_utf8_buffer())


# ---------------------------------------------------------------------
# Per-frame: drain socket, retry unacked sends
# ---------------------------------------------------------------------

func _process(delta: float) -> void:
	if not connected_to_relay:
		return

	while socket.get_available_packet_count() > 0:
		var packet = socket.get_packet()
		_handle_message(packet.get_string_from_utf8().strip_edges())

	if _pending.is_empty():
		return
	var to_drop: Array = []
	for seq in _pending.keys():
		var entry = _pending[seq]
		entry["elapsed"] += delta
		if entry["elapsed"] >= RESEND_INTERVAL:
			entry["elapsed"] = 0.0
			entry["retries"] += 1
			if entry["retries"] > MAX_RETRIES:
				to_drop.append(seq)
			else:
				_send_raw(entry["payload"])
	for seq in to_drop:
		_pending.erase(seq)
		push_warning("zryj-net: gave up delivering message seq=%d -- connection likely lost" % seq)
		player_disconnected.emit()


# ---------------------------------------------------------------------
# Incoming message handling
# ---------------------------------------------------------------------

func _handle_message(message: String) -> void:
	if message == "WAITING":
		mm_match_waiting.emit()

	elif message.begins_with("MATCHED:"):
		var role = int(message.substr(len("MATCHED:")))
		player_id = role
		is_host = (role == 1)
		is_searching = false
		mm_match_found.emit()
		player_connected.emit()

	elif message == "FULL":
		is_searching = false
		mm_match_full.emit()

	elif message == "ALREADY_IN":
		pass

	elif message == "CANCEL":
		is_searching = false
		mm_match_cancelled.emit()
		player_disconnected.emit()

	elif message == "TIMEOUT":
		is_searching = false
		mm_match_timeout.emit()

	elif message.begins_with("DATA:"):
		_handle_data(message.substr(len("DATA:")))


func _handle_data(payload_str: String) -> void:
	var parsed = JSON.parse_string(payload_str)
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		return

	if parsed.get("kind") == "ack":
		var seq = int(parsed.get("seq", -1))
		_pending.erase(seq)
		return

	if parsed.get("kind") != "data":
		return

	var seq = int(parsed.get("seq", -1))
	_send_ack(seq)  # always ack, even duplicates, in case our earlier ack was lost

	if _seen_in_seqs.has(seq):
		return  # already processed this one, don't double-dispatch
	_seen_in_seqs.append(seq)
	if _seen_in_seqs.size() > SEEN_SEQ_HISTORY:
		_seen_in_seqs.pop_front()

	var type = parsed.get("type", "")
	var data = parsed.get("data", {})

	match type:
		"set_pieces":
			opponent_pieces = _deserialize_pieces(data.get("pieces", []))
		"coinflip":
			white_moves_first = (data.get("result") == "orzel")
			coinflip_received.emit(data.get("result"))
		"game_start":
			var white = _deserialize_pieces(data.get("white", []))
			var black = _deserialize_pieces(data.get("black", []))
			white_moves_first = data.get("white_moves_first", true)
			game_started.emit(white, black, data.get("host_is_white", true))
		"move":
			var f = data.get("from", [0, 0])
			var t = data.get("to", [0, 0])
			move_received.emit(Vector2i(int(f[0]), int(f[1])), Vector2i(int(t[0]), int(t[1])))


# ---------------------------------------------------------------------
# Keepalive so the relay (and any NAT mapping) doesn't time us out
# ---------------------------------------------------------------------

func _ensure_ping_timer() -> void:
	if _ping_timer:
		return
	_ping_timer = Timer.new()
	_ping_timer.wait_time = 5.0
	_ping_timer.one_shot = false
	_ping_timer.timeout.connect(func():
		if connected_to_relay:
			socket.put_packet("PING".to_utf8_buffer())
	)
	add_child(_ping_timer)
	_ping_timer.start()
