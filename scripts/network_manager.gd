extends Node

# Set these to the public address and UDP port of files/server.py on the VPS.
const VPS_HOST := "31.70.109.158"
const VPS_PORT := 51820
const PUNCH_TIMEOUT_MS := 4000
const HEARTBEAT_MS := 10000
const RETRY_MS := 800
const MAX_RETRIES := 8

signal peer_found
signal transport_ready(mode: String)
signal remote_ready(pieces: Array)
signal game_started(white_pieces: Array, black_pieces: Array, coin: String, turn: String)
signal action_received(action: Dictionary)
signal player_disconnected(reason: String)
signal connection_error(reason: String)

var udp := PacketPeerUDP.new()
var room_code := ""
var player_token := ""
var peer_token := ""
var peer_ip := ""
var peer_port := 0
var is_host := false
var is_online := false
var transport_mode := "" # "direct" or "relay"
var peer_found_at := 0
var last_register_at := 0
var last_ping_at := 0
var last_punch_at := 0
var next_sequence := 1
var pending := {}
var received_sequences := {}
var white_pieces: Array = []
var black_pieces: Array = []
var coin_result := "orzel"
var initial_turn := "b"

func _ready() -> void:
	randomize()

func create_room(code: String) -> void:
	_start_room(code, true)

func join_room(code: String) -> void:
	_start_room(code, false)

func _start_room(code: String, host: bool) -> void:
	reset()
	room_code = code.strip_edges()
	if room_code.length() < 4:
		connection_error.emit("Kod pokoju musi mieć co najmniej 4 znaki.")
		return
	is_host = host
	is_online = true
	player_token = "%x%x" % [Time.get_ticks_usec(), randi()]
	var err := udp.bind(0)
	if err != OK:
		connection_error.emit("Nie udało się otworzyć portu UDP.")
		reset()
		return
	_register()

func reset() -> void:
	udp.close()
	room_code = ""
	player_token = ""
	peer_token = ""
	peer_ip = ""
	peer_port = 0
	is_host = false
	is_online = false
	transport_mode = ""
	peer_found_at = 0
	last_register_at = 0
	last_ping_at = 0
	last_punch_at = 0
	next_sequence = 1
	pending.clear()
	received_sequences.clear()
	white_pieces.clear()
	black_pieces.clear()
	coin_result = "orzel"
	initial_turn = "b"

func _process(_delta: float) -> void:
	if not is_online:
		return
	_poll_packets()
	var now := Time.get_ticks_msec()
	if peer_token.is_empty() and now - last_register_at >= 1000:
		_register()
	if now - last_ping_at >= HEARTBEAT_MS:
		_send_to_server("GAME_PING:%s:%s" % [room_code, player_token])
		last_ping_at = now
	if not peer_token.is_empty() and transport_mode.is_empty() and now - peer_found_at >= PUNCH_TIMEOUT_MS:
		transport_mode = "relay"
		transport_ready.emit(transport_mode)
	if not peer_token.is_empty() and transport_mode.is_empty() and now - last_punch_at >= 250:
		_send_direct("GAME_PUNCH:%s:%s" % [room_code, player_token])
		last_punch_at = now
	_retry_pending(now)

func _register() -> void:
	_send_to_server("GAME_REGISTER:%s:%s:%s" % [room_code, player_token, "host" if is_host else "guest"])
	last_register_at = Time.get_ticks_msec()

func _poll_packets() -> void:
	while udp.get_available_packet_count() > 0:
		var packet := udp.get_packet()
		var source_ip := udp.get_packet_ip()
		var source_port := udp.get_packet_port()
		var text := packet.get_string_from_utf8()
		_handle_packet(text, source_ip, source_port)

func _handle_packet(text: String, source_ip: String, source_port: int) -> void:
	if text == "GAME_GONE":
		player_disconnected.emit("Drugi gracz rozłączył się.")
		return
	if text.begins_with("GAME_ERROR:"):
		connection_error.emit(text.trim_prefix("GAME_ERROR:"))
		return
	if text.begins_with("GAME_PEER:"):
		var peer_parts := text.split(":", false, 3)
		if peer_parts.size() == 4:
			peer_ip = peer_parts[1]
			peer_port = int(peer_parts[2])
			peer_token = peer_parts[3]
			peer_found_at = Time.get_ticks_msec()
			peer_found.emit()
		return
	if text.begins_with("GAME_FORWARD:"):
		_handle_game_packet(text.trim_prefix("GAME_FORWARD:"), true, source_ip, source_port)
		return
	_handle_game_packet(text, false, source_ip, source_port)

func _handle_game_packet(text: String, relayed: bool, source_ip: String, source_port: int) -> void:
	if peer_token.is_empty():
		return
	if not relayed and (source_ip != peer_ip or source_port != peer_port):
		return
	var parts := text.split(":", false, 4)
	if parts.size() < 3 or parts[1] != room_code or parts[2] != peer_token:
		return
	match parts[0]:
		"GAME_PUNCH":
			_send_direct("GAME_PUNCH_ACK:%s:%s" % [room_code, player_token])
			_confirm_direct()
		"GAME_PUNCH_ACK":
			_confirm_direct()
		"GAME_ACK":
			if parts.size() == 4:
				pending.erase(int(parts[3]))
		"GAME_DATA":
			if parts.size() != 5:
				return
			var sequence := int(parts[3])
			_send_ack(sequence)
			if received_sequences.has(sequence):
				return
			received_sequences[sequence] = true
			var json := JSON.new()
			if json.parse(Marshalls.base64_to_utf8(parts[4])) != OK or typeof(json.data) != TYPE_DICTIONARY:
				return
			_receive_payload(json.data)

func _confirm_direct() -> void:
	if transport_mode != "direct":
		transport_mode = "direct"
		transport_ready.emit(transport_mode)

func send_ready(pieces: Array) -> void:
	_send_reliable({"type": "ready", "pieces": pieces})

func start_game(host_white: Array, guest_black: Array) -> void:
	if not is_host:
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var resolved := GameRules.resolve_start_position(host_white, guest_black, rng)
	white_pieces = resolved["white"]
	black_pieces = resolved["black"]
	coin_result = "orzel" if rng.randf() < 0.5 else "reszka"
	initial_turn = GameRules.starting_turn(white_pieces, black_pieces, coin_result)
	_send_reliable({"type": "start", "white": white_pieces, "black": black_pieces, "coin": coin_result, "turn": initial_turn})
	game_started.emit(white_pieces, black_pieces, coin_result, initial_turn)

func submit_action(action: Dictionary) -> void:
	_send_reliable({"type": "action", "action": action})

func close_room() -> void:
	if is_online and is_host and not room_code.is_empty() and not player_token.is_empty():
		# `server.py` will validate the host token, remove the room and notify its guest.
		_send_to_server("GAME_CLOSE:%s:%s" % [room_code, player_token])
	reset()

func _receive_payload(payload: Dictionary) -> void:
	match payload.get("type", ""):
		"ready":
			if payload.get("pieces", []) is Array:
				remote_ready.emit(payload["pieces"])
		"start":
			if payload.get("white", []) is Array and payload.get("black", []) is Array:
				white_pieces = payload["white"]
				black_pieces = payload["black"]
				coin_result = str(payload.get("coin", "orzel"))
				initial_turn = str(payload.get("turn", "b"))
				game_started.emit(white_pieces, black_pieces, coin_result, initial_turn)
		"action":
			if payload.get("action", {}) is Dictionary:
				action_received.emit(payload["action"])

func _send_reliable(payload: Dictionary) -> void:
	if transport_mode.is_empty():
		return
	var sequence := next_sequence
	next_sequence += 1
	var packet := "GAME_DATA:%s:%s:%d:%s" % [room_code, player_token, sequence, Marshalls.utf8_to_base64(JSON.stringify(payload))]
	pending[sequence] = {"packet": packet, "last_sent": 0, "retries": 0}
	_send_pending(sequence)

func _send_ack(sequence: int) -> void:
	_send_transport("GAME_ACK:%s:%s:%d" % [room_code, player_token, sequence])

func _retry_pending(now: int) -> void:
	for sequence in pending.keys():
		var entry: Dictionary = pending[sequence]
		if now - int(entry["last_sent"]) < RETRY_MS:
			continue
		if int(entry["retries"]) >= MAX_RETRIES:
			pending.erase(sequence)
			player_disconnected.emit("Brak odpowiedzi drugiego gracza.")
			continue
		_send_pending(sequence)

func _send_pending(sequence: int) -> void:
	var entry: Dictionary = pending[sequence]
	_send_transport(entry["packet"])
	entry["last_sent"] = Time.get_ticks_msec()
	entry["retries"] = int(entry["retries"]) + 1
	pending[sequence] = entry

func _send_transport(packet: String) -> void:
	if transport_mode == "direct":
		_send_direct(packet)
	elif transport_mode == "relay":
		_send_to_server("GAME_RELAY:%s:%s:%s" % [room_code, player_token, packet])

func _send_direct(packet: String) -> void:
	if not peer_ip.is_empty() and peer_port > 0:
		udp.set_dest_address(peer_ip, peer_port)
		udp.put_packet(packet.to_utf8_buffer())

func _send_to_server(packet: String) -> void:
	udp.set_dest_address(VPS_HOST, VPS_PORT)
	udp.put_packet(packet.to_utf8_buffer())
