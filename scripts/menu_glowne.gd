extends Control

const TLO_EKRANU_GLOWNEGO = preload("uid://tvwbs626pujp")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var tlo = TLO_EKRANU_GLOWNEGO.instantiate()
	add_child(tlo)
	$muzyka.play()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_texture_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")
