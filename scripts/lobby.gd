extends Control

const OKNO = preload("uid://dcnl4l5bu5ucc")

@onready var host_port = $VBoxContainer/HostSection/PortInput
@onready var host_button = $VBoxContainer/HostSection/HostButton
@onready var join_ip = $VBoxContainer/JoinSection/IPInput
@onready var join_port = $VBoxContainer/JoinSection/PortInput
@onready var join_button = $VBoxContainer/JoinSection/JoinButton
@onready var status_label = $StatusLabel
@onready var back_button = $BackButton
@onready var room_input = $VBoxContainer/MatchmakingSection/RoomInput
@onready var find_match_button = $VBoxContainer/MatchmakingSection/FindMatchButton

var matchmaking = null
var current_room = ""

func _ready():
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	back_button.pressed.connect(_on_back_pressed)
	find_match_button.pressed.connect(_on_find_match_pressed)
	NetworkManager.player_connected.connect(_on_player_connected)
	NetworkManager.coinflip_received.connect(_on_coinflip_received)
	NetworkManager.game_started.connect(_on_game_started)

func _on_host_pressed():
	var port = int(host_port.text) if host_port.text != "" else 7777
	var err = NetworkManager.host_game(port)
	if err == OK:
		var addresses = IP.get_local_addresses()
		var ip_text = "localhost"
		for addr in addresses:
			if addr.begins_with("192.168.") or addr.begins_with("10.") or addr.begins_with("172."):
				ip_text = addr
				break
		var upnp_status = "\nUPnP: Port forwarded" if NetworkManager.upnp else "\nUPnP: Not available (manual forwarding may be needed)"
		status_label.text = "Hosting on port " + str(port) + "\nYour IP: " + ip_text + upnp_status + "\nWaiting for opponent..."
		host_button.disabled = true
		join_button.disabled = true
		find_match_button.disabled = true
	else:
		status_label.text = "Failed to host: " + str(err)

func _on_join_pressed():
	var ip = join_ip.text if join_ip.text != "" else "127.0.0.1"
	var port = int(join_port.text) if join_port.text != "" else 7777
	var err = NetworkManager.join_game(ip, port)
	if err == OK:
		status_label.text = "Connecting to " + ip + ":" + str(port) + "..."
		host_button.disabled = true
		join_button.disabled = true
		find_match_button.disabled = true
	else:
		status_label.text = "Failed to connect: " + str(err)

func _on_find_match_pressed():
	var room_name = room_input.text.strip_edges()
	if room_name == "":
		status_label.text = "Enter a room name first."
		return

	status_label.text = "Searching for match...\nRoom: " + room_name
	find_match_button.disabled = true
	host_button.disabled = true
	join_button.disabled = true
	current_room = room_name

	matchmaking = load("res://scripts/matchmaking_client.gd").new()
	add_child(matchmaking)
	matchmaking.connect_to_server("31.70.109.158", 5000)
	matchmaking.mm_match_found.connect(_on_match_found)
	matchmaking.mm_match_cancelled.connect(_on_match_cancelled)
	matchmaking.mm_match_timeout.connect(_on_match_timeout)
	matchmaking.mm_match_waiting.connect(_on_match_waiting)
	matchmaking.mm_match_full.connect(_on_match_full)
	matchmaking.join_room(room_name)

func _on_match_waiting():
	status_label.text = "Waiting for opponent...\nRoom: " + current_room

func _on_match_found(peer_ip: String, peer_port: int):
	status_label.text = "Match found!\nConnecting to " + peer_ip + ":" + str(peer_port) + "..."
	NetworkManager.set_my_positions(PozycjaOsobista.ustawienia_bialych, PozycjaOsobista.ustawienia_czarnych)
	var err = NetworkManager.join_game(peer_ip, peer_port)
	if err != OK:
		status_label.text = "Failed to connect to peer: " + str(err)
		_reset_buttons()

func _on_match_cancelled():
	status_label.text = "Match cancelled.\nOpponent left the room."
	_reset_buttons()

func _on_match_timeout():
	status_label.text = "No match found.\nTimed out after 30 seconds."
	_reset_buttons()

func _on_match_full():
	status_label.text = "Room is full.\nTry a different room name."
	_reset_buttons()

func _reset_buttons():
	find_match_button.disabled = false
	host_button.disabled = false
	join_button.disabled = false
	if matchmaking:
		matchmaking.queue_free()
		matchmaking = null

func _on_player_connected():
	NetworkManager.set_my_positions(PozycjaOsobista.ustawienia_bialych, PozycjaOsobista.ustawienia_czarnych)
	if NetworkManager.is_host:
		status_label.text = "Opponent connected!\nFlipping coin..."
		start_coinflip()
	else:
		status_label.text = "Connected! Waiting for coin flip..."

func start_coinflip():
	var okno = OKNO.instantiate()
	okno.global_position = Vector2.ZERO
	okno.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(okno)
	await okno.koniec_rzutu
	NetworkManager.broadcast_coinflip(okno.wyrzucona)

func _on_coinflip_received(result: String):
	if not NetworkManager.is_host:
		status_label.text = "Coin flip: " + result + "\nStarting game..."
	NetworkManager.start_game()

func _on_game_started(white_pieces: Array, black_pieces: Array, host_is_white: bool):
	PozycjaOsobista.ustawienia_bialych = white_pieces
	PozycjaOsobista.ustawienia_czarnych = black_pieces
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_back_pressed():
	if matchmaking:
		matchmaking.leave_room(current_room)
		matchmaking.queue_free()
		matchmaking = null
	NetworkManager.close_connection()
	get_tree().change_scene_to_file("res://scenes/menu glowne.tscn")
