extends Control
@export var wyrzucona = null
signal koniec_rzutu
signal throw_started

var forced_result := "orzel"
var can_launch := true

func _ready() -> void:
	z_index = 4
	_set_viewport_size()
	get_viewport().size_changed.connect(_set_viewport_size)
	$SubViewportContainer/SubViewport/Node3D.configure(forced_result, can_launch)
	$SubViewportContainer/SubViewport/Node3D.throw_started.connect(func(): throw_started.emit())

func _set_viewport_size() -> void:
	$SubViewportContainer/SubViewport.size = Vector2i(get_viewport_rect().size)

func configure(result: String, allow_launch: bool) -> void:
	forced_result = result
	can_launch = allow_launch
	if is_node_ready():
		$SubViewportContainer/SubViewport/Node3D.configure(forced_result, can_launch)

func launch() -> void:
	$SubViewportContainer/SubViewport/Node3D.launch()

func _on_wyrzucona(strona: Variant) -> void:
	wyrzucona = strona
	await get_tree().create_timer(5).timeout
	koniec_rzutu.emit()
	queue_free()
