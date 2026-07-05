extends Control

const OKNO = preload("uid://dcnl4l5bu5ucc")

const RELAY_SERVER_IP = "31.70.109.158"
const RELAY_SERVER_PORT = 5000

@onready var host_port = $VBoxContainer/HostSection/PortInput
@onready var host_button = $VBoxContainer/HostSection/HostButton
@onready var join_ip = $VBoxContainer/JoinSection/IPInput
@onready var join_port = $VBoxContainer/JoinSection/PortInput
@onready var join_button = $VBoxContainer/JoinSection/JoinButton
@onready var status_label = $StatusLabel
@onready var back_button = $BackButton
@onready var room_input = $VBoxContainer/MatchmakingSection/RoomInput
@onready var find_match_button = $VBoxContainer/MatchmakingSection/FindMatchButton

var current_room = ""

func _ready():
	# Direct host-by-port / join-by-IP relied on ENet + UPnP/manual port
	# forwarding, which we've dropped in favor of relay-only networking.
	# Left in place (disabled) rather than ripped out, in case you want to
	# revive a direct-connect path later for LAN play.
	host_button.disabled = true
	join_button.disabled = true
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)

	back_button.pressed.connect(_on_back_pressed)
	find_match_button.pressed.connect(_on_find_match_pressed)

	NetworkManager.player_connected.connect(_on_player_connected)
	NetworkManager.player_disconnected.connect(_on_player_disconnected)
	NetworkManager.coinflip_received.connect(_on_coinflip_received)
	NetworkManager.game_started.connect(_on_game_started)
	NetworkManager.mm_match_waiting.connect(_on_match_waiting)
	NetworkManager.mm_match_found.connect(_on_match_found)
	NetworkManager.mm_match_cancelled.connect(_on_match_cancelled)
	NetworkManager.mm_match_timeout.connect(_on_match_timeout)
	NetworkManager.mm_match_full.connect(_on_match_full)

	NetworkManager.connect_to_server(RELAY_SERVER_IP, RELAY_SERVER_PORT)

func _on_host_pressed():
	status_label.text = "Direct hosting isn't available in relay mode.\nUse Find Match instead."

func _on_join_pressed():
	status_label.text = "Direct join isn't available in relay mode.\nUse Find Match instead."

func _on_find_match_pressed():
	var room_name = room_input.text.strip_edges()
	if room_name == "":
		status_label.text = "Enter a room name first."
		return

	status_label.text = "Searching for match...\nRoom: " + room_name
	find_match_button.disabled = true
	current_room = room_name
	NetworkManager.join_room(room_name)

func _on_match_waiting():
	status_label.text = "Waiting for opponent...\nRoom: " + current_room

func _on_match_found():
	status_label.text = "Match found! Connecting..."

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

func _on_player_connected():
	NetworkManager.set_my_positions(PozycjaOsobista.ustawienia_bialych, PozycjaOsobista.ustawienia_czarnych)
	if NetworkManager.is_host:
		status_label.text = "Opponent connected!\nFlipping coin..."
		start_coinflip()
	else:
		status_label.text = "Connected! Waiting for coin flip..."

func _on_player_disconnected():
	status_label.text = "Connection lost."
	_reset_buttons()

func start_coinflip():
	var okno = OKNO.instantiate()
	okno.global_position = Vector2.ZERO
	okno.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(okno)
	await okno.koniec_rzutu
	NetworkManager.broadcast_coinflip(okno.wyrzucona)
	NetworkManager.start_game()
	_on_game_started(
		PozycjaOsobista.ustawienia_bialych,
		PozycjaOsobista.ustawienia_czarnych,
		NetworkManager.host_is_white
	)

func _on_coinflip_received(result: String):
	if not NetworkManager.is_host:
		status_label.text = "Coin flip: " + result + "\nStarting game..."

func _on_game_started(white_pieces: Array, black_pieces: Array, host_is_white: bool):
	PozycjaOsobista.ustawienia_bialych = white_pieces
	PozycjaOsobista.ustawienia_czarnych = black_pieces
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_back_pressed():
	if current_room != "":
		NetworkManager.leave_room(current_room)
		current_room = ""
	NetworkManager.close_connection()
	get_tree().change_scene_to_file("res://scenes/menu glowne.tscn")
