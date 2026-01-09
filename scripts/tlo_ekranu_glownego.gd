extends Node2D

@onready var warstwa_1: Sprite2D = $"warstwa 1"
@onready var warstwa_2: Sprite2D = $"warstwa 2"
@onready var warstwa_3: Sprite2D = $"warstwa 3"
var przez = 100

func _ready() -> void:
	$AnimationPlayer.play("jigglowanie")

func _process(delta: float) -> void:
	przez += 2*delta
	warstwa_1.modulate = Color(przez,przez,przez,0.8+(sin(przez)/5))
	if przez > 100:
		przez = 0
