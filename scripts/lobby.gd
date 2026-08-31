extends Control

@onready var room_code: LineEdit = $VBoxContainer/RoomCode
@onready var play_button: Button = $VBoxContainer/PlayButton
@onready var status_label: Label = $StatusLabel

var role_known := false
var transport_mode := ""

func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	$BackButton.pressed.connect(_on_back_pressed)
	NetworkManager.peer_found.connect(_on_peer_found)
	NetworkManager.role_assigned.connect(_on_role_assigned)
	NetworkManager.transport_ready.connect(_on_transport_ready)
	NetworkManager.remote_ready.connect(_on_remote_ready)
	NetworkManager.game_started.connect(_on_game_started)
	NetworkManager.connection_error.connect(_on_connection_error)
	NetworkManager.player_disconnected.connect(_on_player_disconnected)

func _on_play_pressed() -> void:
	if not PozycjaOsobista.has_nickname():
		status_label.text = "Wróć do menu głównego i wpisz nick."
		return
	if not PozycjaOsobista.loadout_has_king(0):
		status_label.text = "Ustaw najpierw armię z królem w Loadout 1 (online zawsze go używa)."
		return
	var code := room_code.text.strip_edges()
	if code.length() < 4:
		status_label.text = "Wpisz kod pokoju o długości co najmniej 4 znaków."
		return
	play_button.disabled = true
	room_code.editable = false
	role_known = false
	transport_mode = ""
	status_label.text = "Łączenie z pokojem…"
	NetworkManager.connect_to_room(code)

func _on_peer_found() -> void:
	status_label.text = "Gracz znaleziony — próba połączenia bezpośredniego…"

# Whoever joins a room code first becomes the host (białe); the next player
# to join the same code becomes the guest (czarne) - the server decides,
# not a button choice.
func _on_role_assigned(is_host: bool) -> void:
	role_known = true
	status_label.text = "Jesteś hostem (białe)." if is_host else "Dołączasz jako czarne."
	_maybe_send_ready()

func _on_transport_ready(mode: String) -> void:
	transport_mode = mode
	_maybe_send_ready()

func _maybe_send_ready() -> void:
	if not role_known or transport_mode.is_empty():
		return
	status_label.text = "Połączenie: " + ("bezpośrednie P2P." if transport_mode == "direct" else "przez VPS (relay).") + "\nSynchronizowanie ustawień…"
	NetworkManager.send_ready(_own_pieces(), _own_card(), PozycjaOsobista.nickname)

func _on_remote_ready(pieces: Array, card: String, nickname: String) -> void:
	if NetworkManager.is_host:
		if nickname.is_empty():
			status_label.text = "Drugi gracz nie podał nicku."
			return
		NetworkManager.start_game(_own_pieces(), pieces, _own_card(), card, PozycjaOsobista.nickname, nickname)

func _on_game_started(_white_pieces: Array, _black_pieces: Array, _coin: String, _turn: String, _white_card: String, _black_card: String, _white_nickname: String, _black_nickname: String) -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")

# Online always plays with the first saved loadout - there's only one of
# you connecting, so there's nothing to choose between (unlike local versus,
# where both loadouts are on the same screen and each side picks one).
func _own_pieces() -> Array:
	var result: Array = []
	for piece in PozycjaOsobista.loadouts[0]["ustawienie"]:
		var y: int = int(piece[1].y) if NetworkManager.is_host else 7 - int(piece[1].y)
		result.append([piece[0], piece[1].x, y])
	return result

func _own_card() -> String:
	return str(PozycjaOsobista.loadouts[0]["karta"])

func _on_connection_error(reason: String) -> void:
	status_label.text = "Błąd połączenia: " + reason
	play_button.disabled = false
	room_code.editable = true

func _on_player_disconnected(reason: String) -> void:
	status_label.text = reason

func _on_back_pressed() -> void:
	NetworkManager.reset()
	get_tree().change_scene_to_file("res://scenes/menu glowne.tscn")
