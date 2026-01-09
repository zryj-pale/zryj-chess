extends Control

signal wynik(strona)
var wyrzucona = null


func _ready() -> void:
	z_index = 4
	$SubViewportContainer/SubViewport.size = get_viewport_rect().size*5/6


func _on_wynik(strona: Variant) -> void:
	wyrzucona = strona
