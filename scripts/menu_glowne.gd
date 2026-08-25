extends Control

const TLO_EKRANU_GLOWNEGO = preload("uid://tvwbs626pujp")

@onready var nickname_input: LineEdit = $NicknameInput
@onready var nickname_status: Label = $NicknameStatus

func _ready() -> void:
	var tlo = TLO_EKRANU_GLOWNEGO.instantiate()
	add_child(tlo)
	nickname_input.text = PozycjaOsobista.nickname
	nickname_input.text_changed.connect(_on_nickname_changed)
	nickname_input.text_submitted.connect(func(_text: String): _save_nickname())
	$muzyka.play()

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
		return true
	nickname_status.text = "Wpisz nick, aby rozpocząć grę."
	nickname_input.grab_focus()
	return false
