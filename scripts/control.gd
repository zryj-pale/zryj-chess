extends Control
@export var wyrzucona = null
signal koniec_rzutu
signal throw_started(throw_seed: int)

var forced_result := "orzel"
var can_launch := true

func _ready() -> void:
	z_index = 4
	_set_viewport_size()
	call_deferred("_set_viewport_size")
	get_viewport().size_changed.connect(_set_viewport_size)
	$SubViewportContainer/SubViewport/Node3D.configure(forced_result, can_launch)
	$SubViewportContainer/SubViewport/Node3D.throw_started.connect(func(throw_seed: int): throw_started.emit(throw_seed))

func _set_viewport_size() -> void:
	var screen_size := get_viewport().get_visible_rect().size
	# This Control is added below Node2D, so anchors alone do not give it a size.
	position = Vector2.ZERO
	size = screen_size
	var container: SubViewportContainer = $SubViewportContainer
	container.position = Vector2.ZERO
	container.size = screen_size
	var subviewport: SubViewport = $SubViewportContainer/SubViewport
	subviewport.size = Vector2i(screen_size)

func configure(result: String, allow_launch: bool) -> void:
	forced_result = result
	can_launch = allow_launch
	if is_node_ready():
		$SubViewportContainer/SubViewport/Node3D.configure(forced_result, can_launch)

func launch(throw_seed := -1) -> void:
	$SubViewportContainer/SubViewport/Node3D.launch(throw_seed)

func _on_wyrzucona(strona: Variant) -> void:
	wyrzucona = strona
	await get_tree().create_timer(5).timeout
	koniec_rzutu.emit()
	queue_free()
