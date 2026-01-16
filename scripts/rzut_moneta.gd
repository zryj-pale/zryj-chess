extends Node3D

@onready var moneta: RigidBody3D = $moneta
@onready var ray_cast_3d: RayCast3D = $moneta/RayCast3D

signal wyrzucona(strona)

func _ready() -> void:
	$camera_pivot/AnimationPlayer.play("obrot")
	$muzyka.play()
	Engine.time_scale = 2
	Engine.physics_ticks_per_second = 120

func _process(_delta: float) -> void:
	if moneta.rzucona == true:
		if nieruchomy(moneta, 0.1):
			set_process(false)
			if ray_cast_3d.is_colliding():
				wyrzucona.emit("reszka")
			else:
				wyrzucona.emit("orzel")

func _input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("space") and moneta.rzucona == false:
		rzut(moneta, 150, 12)

func nieruchomy(obiekt, tolerancja):
	if abs(obiekt.linear_velocity[0]) < tolerancja and abs(obiekt.linear_velocity[1]) < tolerancja and abs(obiekt.linear_velocity[2]) < tolerancja:
		return true
	return false

func rzut(obiekt, sila_wyrzutu, zakres_obrotu):
	moneta.rzucona = true
	obiekt.linear_velocity.y = sila_wyrzutu
	obiekt.angular_velocity = Vector3(randf_range(-zakres_obrotu,zakres_obrotu), randf_range(-zakres_obrotu,zakres_obrotu), randf_range(-zakres_obrotu,zakres_obrotu))
