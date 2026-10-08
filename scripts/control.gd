extends Control
@export var wyrzucona = null
signal koniec_rzutu
signal snapshot_ready(snapshot: Dictionary)
signal result_ready(result: String)

var online := false
var can_launch := true

func _ready() -> void:
	z_index = 4
	_set_viewport_size()
	call_deferred("_set_viewport_size")
	get_viewport().size_changed.connect(_set_viewport_size)
	$SubViewportContainer/SubViewport/Node3D.configure(can_launch, online)
	$SubViewportContainer/SubViewport/Node3D.snapshot_ready.connect(func(snapshot: Dictionary): snapshot_ready.emit(snapshot))

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

func configure(allow_launch: bool, is_online: bool) -> void:
	can_launch = allow_launch
	online = is_online
	if is_node_ready():
		$SubViewportContainer/SubViewport/Node3D.configure(can_launch, online)

func receive_snapshot(snapshot: Dictionary) -> void:
	$SubViewportContainer/SubViewport/Node3D.receive_snapshot(snapshot)

func _on_wyrzucona(strona: Variant) -> void:
	wyrzucona = strona
	result_ready.emit(str(strona))
	await get_tree().create_timer(5).timeout
	koniec_rzutu.emit()
	queue_free()
