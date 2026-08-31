extends Node3D

@onready var moneta: RigidBody3D = $moneta
@onready var ray_cast_3d: RayCast3D = $moneta/RayCast3D

signal wyrzucona(strona)
signal throw_started(throw_seed: int)

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

func launch(throw_seed := -1) -> void:
	if moneta.rzucona:
		return
	# Both clients receive the same seed from the host.  The resulting impulse
	# and spin are therefore identical instead of relying on local randf_range().
	if throw_seed < 0:
		throw_seed = randi()
	rzut(moneta, 150, 12, throw_seed)
	throw_started.emit(throw_seed)

func nieruchomy(obiekt, tolerancja):
	if abs(obiekt.linear_velocity[0]) < tolerancja and abs(obiekt.linear_velocity[1]) < tolerancja and abs(obiekt.linear_velocity[2]) < tolerancja:
		return true
	return false

func rzut(obiekt, sila_wyrzutu, zakres_obrotu, throw_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = throw_seed
	moneta.rzucona = true
	obiekt.freeze = false
	obiekt.linear_velocity = Vector3(0, sila_wyrzutu, 0)
	obiekt.angular_velocity = Vector3(
		rng.randf_range(-zakres_obrotu, zakres_obrotu),
		rng.randf_range(-zakres_obrotu, zakres_obrotu),
		rng.randf_range(-zakres_obrotu, zakres_obrotu)
	)
