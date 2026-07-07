extends Control

const TLO_EKRANU_GLOWNEGO = preload("uid://tvwbs626pujp")


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var tlo = TLO_EKRANU_GLOWNEGO.instantiate()
	add_child(tlo)
	$muzyka.play()

func _on_robcza_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")
<<<<<<< HEAD


func _on_video_stream_player_finished() -> void:
	await get_tree().create_timer(1).timeout
	$VideoStreamPlayer.visible = false


func _on_ustawianie_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ustawianie.tscn")


func _on_online_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")
=======
>>>>>>> parent of 01d08f7 (dodano różne rzeczy)
