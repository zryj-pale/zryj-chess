extends Node

signal mm_match_found(peer_ip: String, peer_port: int)
signal mm_match_cancelled
signal mm_match_timeout
signal mm_match_waiting
signal mm_match_full

var socket = PacketPeerUDP.new()
var server_address = ""
var server_port = 5000
var peer_address = ""
var peer_port = 0
var is_searching = false
var ping_timer = null
var timeout_timer = null

func connect_to_server(address: String, port: int = 5000):
	server_address = address
	server_port = port
	socket.connect_to_host(address, port)

func join_room(room_name: String):
	if server_address == "":
		return
	is_searching = true
	var msg = "ROOM " + room_name
	socket.put_packet(msg.to_utf8_buffer())
	_start_listening()

func leave_room(room_name: String):
	is_searching = false
	_stop_timers()
	if server_address != "":
		var msg = "LEAVE " + room_name
		socket.put_packet(msg.to_utf8_buffer())

func cancel():
	is_searching = false
	_stop_timers()

func _start_listening():
	if ping_timer == null:
		ping_timer = Timer.new()
		ping_timer.wait_time = 0.05
		ping_timer.one_shot = false
		ping_timer.timeout.connect(_on_ping_timer)
		add_child(ping_timer)

	if timeout_timer == null:
		timeout_timer = Timer.new()
		timeout_timer.wait_time = 30.0
		timeout_timer.one_shot = true
		timeout_timer.timeout.connect(_on_timeout)
		add_child(timeout_timer)

	ping_timer.start()
	timeout_timer.start()

func _stop_timers():
	if ping_timer:
		ping_timer.stop()
	if timeout_timer:
		timeout_timer.stop()

func _on_ping_timer():
	if not is_searching:
		return
	if socket.get_available_packet_count() > 0:
		_process_packets()
	else:
		if server_address != "":
			socket.put_packet("PING".to_utf8_buffer())

func _on_timeout():
	if is_searching:
		is_searching = false
		_stop_timers()
		mm_match_timeout.emit()

func _process_packets():
	while socket.get_available_packet_count() > 0:
		var packet = socket.get_packet()
		var message = packet.get_string_from_utf8().strip_edges()
		_handle_message(message)

func _handle_message(message: String):
	if message.begins_with("PEER "):
		var parts = message.split(" ")
		if parts.size() >= 3:
			peer_address = parts[1]
			peer_port = int(parts[2])
			is_searching = false
			_stop_timers()
			mm_match_found.emit(peer_address, peer_port)

	elif message == "CANCEL":
		is_searching = false
		_stop_timers()
		mm_match_cancelled.emit()

	elif message == "TIMEOUT":
		is_searching = false
		_stop_timers()
		mm_match_timeout.emit()

	elif message == "WAITING":
		mm_match_waiting.emit()

	elif message == "FULL":
		is_searching = false
		_stop_timers()
		mm_match_full.emit()

	elif message == "ALREADY_IN":
		pass

	elif message == "PING":
		pass

func _exit_tree():
	cancel()
	if socket:
		socket.close()
