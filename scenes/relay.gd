extends Node

signal peer_connected
signal peer_disconnected
signal message_received(text: String)

var socket := WebSocketPeer.new()
var server_url: String = "ws://31.70.109.158:607"
var room_name: String = ""
var is_connected_to_server: bool = false
var is_paired: bool = false


func connect_to_server(url: String = "") -> void:
	if url != "":
		server_url = url
	var err = socket.connect_to_url(server_url)
	if err != OK:
		push_error("Could not connect to server: %s" % err)
		return
	set_process(true)


func join_room(room: String) -> void:
	room_name = room
	# If already connected, join immediately. Otherwise it will be
	# sent automatically once the socket finishes opening.
	if is_connected_to_server:
		_send_json({"type": "join", "room": room_name})


func send_message(text: String) -> void:
	if not is_paired:
		push_warning("Not paired with a peer yet.")
		return
	_send_json({"type": "message", "content": text})


func _send_json(data: Dictionary) -> void:
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		socket.send_text(JSON.stringify(data))


func _process(_delta: float) -> void:
	socket.poll()
	var state = socket.get_ready_state()

	if state == WebSocketPeer.STATE_OPEN:
		if not is_connected_to_server:
			is_connected_to_server = true
			if room_name != "":
				_send_json({"type": "join", "room": room_name})

		while socket.get_available_packet_count() > 0:
			var packet = socket.get_packet().get_string_from_utf8()
			_handle_packet(packet)

	elif state == WebSocketPeer.STATE_CLOSED:
		if is_connected_to_server:
			is_connected_to_server = false
			if is_paired:
				is_paired = false
				peer_disconnected.emit()
		set_process(false)


func _handle_packet(packet: String) -> void:
	var json := JSON.new()
	var err = json.parse(packet)
	if err != OK:
		push_warning("Failed to parse message from server.")
		return

	var data = json.get_data()
	if typeof(data) != TYPE_DICTIONARY:
		return

	match data.get("type", ""):
		"connected":
			is_paired = true
			peer_connected.emit()
		"disconnected":
			is_paired = false
			peer_disconnected.emit()
		"message":
			message_received.emit(data.get("content", ""))
		"error":
			push_warning("Server error: %s" % data.get("message", ""))
