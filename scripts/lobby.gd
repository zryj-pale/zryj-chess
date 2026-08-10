extends Control

@onready var room_code: LineEdit = $VBoxContainer/RoomCode
@onready var host_button: Button = $VBoxContainer/HostButton
@onready var join_button: Button = $VBoxContainer/JoinButton
@onready var status_label: Label = $StatusLabel

func _ready() -> void:
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	$BackButton.pressed.connect(_on_back_pressed)
	NetworkManager.peer_found.connect(_on_peer_found)
	NetworkManager.transport_ready.connect(_on_transport_ready)
	NetworkManager.remote_ready.connect(_on_remote_ready)
	NetworkManager.game_started.connect(_on_game_started)
	NetworkManager.connection_error.connect(_on_connection_error)
	NetworkManager.player_disconnected.connect(_on_player_disconnected)

func _on_host_pressed() -> void:
	_begin(true)

func _on_join_pressed() -> void:
	_begin(false)

func _begin(host: bool) -> void:
	var code := room_code.text.strip_edges()
	if code.length() < 4:
		status_label.text = "Wpisz kod pokoju o długości co najmniej 4 znaków."
		return
	host_button.disabled = true
	join_button.disabled = true
	room_code.editable = false
	status_label.text = "Łączenie z pokojem…"
	if host:
		NetworkManager.create_room(code)
	else:
		NetworkManager.join_room(code)

func _on_peer_found() -> void:
	status_label.text = "Gracz znaleziony — próba połączenia bezpośredniego…"

func _on_transport_ready(mode: String) -> void:
	status_label.text = "Połączenie: " + ("bezpośrednie P2P." if mode == "direct" else "przez VPS (relay).") + "\nSynchronizowanie ustawień…"
	NetworkManager.send_ready(_own_pieces(), PozycjaOsobista.wybrana_karta)

func _on_remote_ready(pieces: Array, card: String) -> void:
	if NetworkManager.is_host:
		NetworkManager.start_game(_own_pieces(), pieces, PozycjaOsobista.wybrana_karta, card)

func _on_game_started(_white_pieces: Array, _black_pieces: Array, _coin: String, _turn: String, _white_card: String, _black_card: String) -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _own_pieces() -> Array:
	var result: Array = []
	for piece in PozycjaOsobista.ustawienie:
		var y: int = int(piece[1].y) if NetworkManager.is_host else 7 - int(piece[1].y)
		result.append([piece[0], piece[1].x, y])
	return result

func _on_connection_error(reason: String) -> void:
	status_label.text = "Błąd połączenia: " + reason
	host_button.disabled = false
	join_button.disabled = false
	room_code.editable = true

func _on_player_disconnected(reason: String) -> void:
	status_label.text = reason

func _on_back_pressed() -> void:
	NetworkManager.reset()
	get_tree().change_scene_to_file("res://scenes/menu glowne.tscn")
