extends Node2D

@onready var warstwa_1: Sprite2D = $"warstwa 1"
@onready var warstwa_2: Sprite2D = $"warstwa 2"
@onready var warstwa_3: Sprite2D = $"warstwa 3"
var przez = 100
var target_tint := Color.WHITE

func _ready() -> void:
	$AnimationPlayer.play("jigglowanie")

func _process(delta: float) -> void:
	modulate = modulate.lerp(target_tint, minf(delta * 3.0, 1.0))
	przez += 2*delta
	warstwa_1.modulate = Color(przez,przez,przez,0.8+(sin(przez)/5))
	if przez > 100:
		przez = 0

func set_match_tint(tint: Color) -> void:
	target_tint = tint
