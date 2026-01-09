extends RichTextLabel
var pokaz = false

func _on_node_2d_kirk() -> void:
	pokaz = true

func _process(delta: float) -> void:
	if pokaz == true:
		pokaz = false
		while global_position[0] > 0:
			global_position += Vector2(-1, 0)
