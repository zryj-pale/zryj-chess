extends Camera3D
@onready var moneta: RigidBody3D = $"../../moneta"

func _process(delta: float) -> void:
	look_at(moneta.global_position)
