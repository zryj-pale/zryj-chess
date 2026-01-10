extends Control
@export var wyrzucona = null
signal koniec_rzutu

func _ready() -> void:
	z_index = 4
	$SubViewportContainer/SubViewport.size = get_viewport_rect().size*5/6

func _on_wyrzucona(strona: Variant) -> void:
	wyrzucona = strona
	await get_tree().create_timer(5).timeout
	koniec_rzutu.emit()
	queue_free()
