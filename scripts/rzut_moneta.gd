extends Node3D

@onready var moneta: RigidBody3D = $moneta
@onready var ray_cast_3d: RayCast3D = $moneta/RayCast3D
const range = 12
const tolerancja = 0.1
var tick = 0.5
var wyrzucona = 0
var wynik = null
var start = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$camera_pivot/AnimationPlayer.play("obrot")
	$muzyka.play()

func _process(delta: float) -> void:
	if start == true:
		if abs(moneta.linear_velocity[0]) < tolerancja and abs(moneta.linear_velocity[1]) < tolerancja and abs(moneta.linear_velocity[2]) < tolerancja:
			wyrzucona += 1
		if wyrzucona == 1:
			if ray_cast_3d.is_colliding():
				$tekst.wyswietl("reszka")
				wynik = 'reszka'
			else:
				$tekst.wyswietl("orzel")
				wynik = 'orzel'
			await get_tree().create_timer(5).timeout
			$"../../..".wynik.emit(wynik)
			$"../../..".queue_free()
	else:
		if Input.is_action_just_pressed("space"):
			moneta.linear_velocity = Vector3(0,150,0)
			moneta.angular_velocity = Vector3(-range+randi()%range*2, -range+randi()%range*2, -range+randi()%range*2)
			start = true
	Engine.time_scale = 2
	Engine.physics_ticks_per_second = 120
