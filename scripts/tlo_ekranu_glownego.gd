extends Node2D

# The layers below were designed to jiggle around a 512x512 canvas. With the
# project's stretch mode set to expand the visible area on wider screens
# instead of scaling the UI, this background scales itself up to still cover
# the whole window; every other (Control-based) UI node is unaffected since
# it isn't a child of this node.
const BASE_SIZE := Vector2(512, 512)

@onready var warstwa_1: Sprite2D = $"warstwa 1"
@onready var warstwa_2: Sprite2D = $"warstwa 2"
@onready var warstwa_3: Sprite2D = $"warstwa 3"
var przez = 100
var target_tint := Color.WHITE

func _ready() -> void:
	$AnimationPlayer.play("jigglowanie")
	_fit_to_viewport()
	get_viewport().size_changed.connect(_fit_to_viewport)

func _fit_to_viewport() -> void:
	var viewport_size := get_viewport_rect().size
	var factor := maxf(1.0, maxf(viewport_size.x / BASE_SIZE.x, viewport_size.y / BASE_SIZE.y))
	scale = Vector2(factor, factor)

func _process(delta: float) -> void:
	modulate = modulate.lerp(target_tint, minf(delta * 3.0, 1.0))
	przez += 2*delta
	warstwa_1.modulate = Color(przez,przez,przez,0.8+(sin(przez)/5))
	if przez > 100:
		przez = 0

func set_match_tint(tint: Color) -> void:
	target_tint = tint
