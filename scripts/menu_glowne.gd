extends Control

const TLO_EKRANU_GLOWNEGO = preload("uid://tvwbs626pujp")

@onready var nickname_input: LineEdit = $NicknameInput
@onready var nickname_status: Label = $NicknameStatus
@onready var nickname_label: Label = $NicknameLabel

var tlo = null

func _ready() -> void:
	tlo = TLO_EKRANU_GLOWNEGO.instantiate()
	add_child(tlo)
	nickname_input.text = PozycjaOsobista.nickname
	nickname_input.text_changed.connect(_on_nickname_changed)
	nickname_input.text_submitted.connect(func(_text: String): _save_nickname())
	nickname_label.mouse_filter = Control.MOUSE_FILTER_STOP
	nickname_label.gui_input.connect(_on_nickname_label_input)
	_refresh_nickname_visibility()
	_refresh_background_tint()
	$muzyka.play()

func _refresh_background_tint() -> void:
	# Uses the live input text (not just the saved nickname) so the tint
	# updates as the player types, before they even confirm the nickname.
	tlo.set_match_tint(PozycjaOsobista.nickname_color(nickname_input.text))

# Pole nicku ma być widoczne tylko dopóki nick nie jest ustawiony; potem
# chowa się, żeby nie zasłaniać reszty menu. Kliknięcie etykiety pozwala
# wrócić do edycji.
func _refresh_nickname_visibility() -> void:
	var has_nick := PozycjaOsobista.has_nickname()
	nickname_input.visible = not has_nick
	nickname_status.visible = not has_nick
	nickname_label.text = PozycjaOsobista.nickname if has_nick else "Twój nick"

func _on_nickname_label_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		nickname_input.visible = true
		nickname_status.visible = true
		nickname_input.grab_focus()

func _on_lokalna_pressed() -> void:
	if not _save_nickname():
		return
	if not PozycjaOsobista.any_loadout_has_king():
		# No playable army yet in either slot - send them to set one up
		# instead of starting a match that can't work.
		get_tree().change_scene_to_file("res://scenes/ustawianie.tscn")
		return
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_video_stream_player_finished() -> void:
	await get_tree().create_timer(1).timeout
	$VideoStreamPlayer.visible = false
	$IntroBackdrop.visible = false


func _on_ustawianie_pressed() -> void:
	if not _save_nickname():
		return
	get_tree().change_scene_to_file("res://scenes/ustawianie.tscn")


# Music muting and the key map moved into the shared settings overlay, so
# there is one place to change them from the menu, the army creator and
# mid-match alike.
func _on_ustawienia_pressed() -> void:
	Ustawienia.open()

func _on_wyjdz_pressed() -> void:
	get_tree().quit()

func _on_online_pressed() -> void:
	if not _save_nickname():
		return
	if not PozycjaOsobista.loadout_has_king(0):
		# Online always plays with loadout 1 specifically (see lobby.gd).
		get_tree().change_scene_to_file("res://scenes/ustawianie.tscn")
		return
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")

func _on_nickname_changed(_value: String) -> void:
	nickname_status.text = ""
	_refresh_background_tint()

func _save_nickname() -> bool:
	if PozycjaOsobista.set_nickname(nickname_input.text):
		nickname_input.text = PozycjaOsobista.nickname
		_refresh_nickname_visibility()
		_refresh_background_tint()
		return true
	nickname_status.text = "Wpisz nick, aby rozpocząć grę."
	nickname_status.visible = true
	nickname_input.grab_focus()
	return false
