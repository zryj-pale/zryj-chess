extends Control

const OKNO = preload("uid://dcnl4l5bu5ucc")

@onready var host_port = $VBoxContainer/HostSection/PortInput
@onready var host_button = $VBoxContainer/HostSection/HostButton
@onready var join_ip = $VBoxContainer/JoinSection/IPInput
@onready var join_port = $VBoxContainer/JoinSection/PortInput
@onready var join_button = $VBoxContainer/JoinSection/JoinButton
@onready var status_label = $StatusLabel
@onready var back_button = $BackButton

var coinflip_done = false

func _ready():
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	back_button.pressed.connect(_on_back_pressed)
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
		status_label.text = "Hosting on port " + str(port) + "\nYour IP: " + ip_text + upnp_status + "\nWaiting for opponent...\n\nTell your friend to enter this IP and port."
		host_button.disabled = true
		join_button.disabled = true
	else:
		status_label.text = "Failed to host: " + str(err) + "\nMake sure port " + str(port) + " is not in use."

func _on_join_pressed():
	var ip = join_ip.text if join_ip.text != "" else "127.0.0.1"
	var port = int(join_port.text) if join_port.text != "" else 7777
	var err = NetworkManager.join_game(ip, port)
	if err == OK:
		status_label.text = "Connecting to " + ip + ":" + str(port) + "..."
		host_button.disabled = true
		join_button.disabled = true
	else:
		status_label.text = "Failed to connect: " + str(err) + "\n\nMake sure:\n- IP and port are correct\n- Host is running and reachable\n- No firewall is blocking the connection"

func _on_player_connected():
	NetworkManager.set_my_positions(PozycjaOsobista.ustawienia_bialych, PozycjaOsobista.ustawienia_czarnych)
	if NetworkManager.is_host:
		status_label.text = "Opponent connected!\nFlipping coin to decide who plays white..."
		start_coinflip()
	else:
		status_label.text = "Connected! Waiting for host to flip the coin..."

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
	NetworkManager.close_connection()
	get_tree().change_scene_to_file("res://scenes/menu glowne.tscn")
