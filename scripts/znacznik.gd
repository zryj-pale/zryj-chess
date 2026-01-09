extends Node2D

@export var kolor:Color
@export var typ:int

func _ready() -> void:
	$ColorRect.color = kolor * Color(1,1,1,0.6)
