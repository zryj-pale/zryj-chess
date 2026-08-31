extends Control

@onready var message_label: Label = $VBox/MessageLabel
@onready var big_label: Label = $VBox/BigLabel
@onready var back_button: Button = $VBox/BackButton

func _ready() -> void:
	message_label.text = PozycjaOsobista.last_result_message
	var big_text := PozycjaOsobista.last_result_big_text
	big_label.visible = not big_text.is_empty()
	big_label.text = big_text
	big_label.modulate = Color(0.3, 1.0, 0.3) if big_text.begins_with("W") else Color(1.0, 0.3, 0.3)
	back_button.pressed.connect(_on_back_pressed)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu glowne.tscn")
