extends Control

const TLO_EKRANU_GLOWNEGO = preload("uid://tvwbs626pujp")

@onready var nickname_input: LineEdit = $NicknameInput
@onready var nickname_status: Label = $NicknameStatus
@onready var nickname_label: Label = $NicknameLabel

func _ready() -> void:
	var tlo = TLO_EKRANU_GLOWNEGO.instantiate()
	add_child(tlo)
	nickname_input.text = PozycjaOsobista.nickname
	nickname_input.text_changed.connect(_on_nickname_changed)
	nickname_input.text_submitted.connect(func(_text: String): _save_nickname())
	nickname_label.mouse_filter = Control.MOUSE_FILTER_STOP
	nickname_label.gui_input.connect(_on_nickname_label_input)
	_refresh_nickname_visibility()
	$muzyka.play()

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

func _on_robcza_pressed() -> void:
	if not _save_nickname():
		return
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_video_stream_player_finished() -> void:
	await get_tree().create_timer(1).timeout
	$VideoStreamPlayer.visible = false


func _on_ustawianie_pressed() -> void:
	if not _save_nickname():
		return
	get_tree().change_scene_to_file("res://scenes/ustawianie.tscn")


func _on_online_pressed() -> void:
	if not _save_nickname():
		return
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")

func _on_nickname_changed(_value: String) -> void:
	nickname_status.text = ""

func _save_nickname() -> bool:
	if PozycjaOsobista.set_nickname(nickname_input.text):
		nickname_input.text = PozycjaOsobista.nickname
		_refresh_nickname_visibility()
		return true
	nickname_status.text = "Wpisz nick, aby rozpocząć grę."
	nickname_status.visible = true
	nickname_input.grab_focus()
	return false
