extends Node3D

@onready var moneta: RigidBody3D = $moneta
@onready var ray_cast_3d: RayCast3D = $moneta/RayCast3D

signal wyrzucona(strona)
signal throw_started

var forced_result := ""
var can_launch := true
var resolved := false
var previous_time_scale := 1.0
var previous_physics_ticks := 60

func _ready() -> void:
	$camera_pivot/AnimationPlayer.play("obrot")
	$muzyka.play()
	previous_time_scale = Engine.time_scale
	previous_physics_ticks = Engine.physics_ticks_per_second
	Engine.time_scale = 2
	Engine.physics_ticks_per_second = 120

func _exit_tree() -> void:
	Engine.time_scale = previous_time_scale
	Engine.physics_ticks_per_second = previous_physics_ticks

func configure(result: String, allow_launch: bool) -> void:
	forced_result = result
	can_launch = allow_launch

func _process(_delta: float) -> void:
	if moneta.rzucona == true:
		if nieruchomy(moneta, 0.1):
			set_process(false)
			if resolved:
				return
			resolved = true
			if not forced_result.is_empty():
				# Lock the visual landing face so remote physics cannot change the agreed result.
				moneta.freeze = true
				moneta.rotation = Vector3.ZERO if forced_result == "orzel" else Vector3(PI, 0, 0)
				wyrzucona.emit(forced_result)
			elif ray_cast_3d.is_colliding():
				wyrzucona.emit("reszka")
			else:
				wyrzucona.emit("orzel")

func _input(_event: InputEvent) -> void:
	if can_launch and Input.is_action_just_pressed("space"):
		launch()

func launch() -> void:
	if moneta.rzucona:
		return
	rzut(moneta, 150, 12)
	throw_started.emit()

func nieruchomy(obiekt, tolerancja):
	if abs(obiekt.linear_velocity[0]) < tolerancja and abs(obiekt.linear_velocity[1]) < tolerancja and abs(obiekt.linear_velocity[2]) < tolerancja:
		return true
	return false

func rzut(obiekt, sila_wyrzutu, zakres_obrotu):
	moneta.rzucona = true
	obiekt.linear_velocity.y = sila_wyrzutu
	obiekt.angular_velocity = Vector3(randf_range(-zakres_obrotu,zakres_obrotu), randf_range(-zakres_obrotu,zakres_obrotu), randf_range(-zakres_obrotu,zakres_obrotu))
