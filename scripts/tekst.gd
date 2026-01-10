extends Label3D
@onready var moneta: RigidBody3D = $"../moneta"
@onready var camera: Node3D = $"../camera_pivot/Camera3D/Marker3D"
var ruszaj = false
var tik = 0

func wyswietl(tekst:String):
	visible = true
	text = tekst
	global_position = moneta.global_position
	$AnimationPlayer.play("spin")
	var tween = get_tree().create_tween()
	tween.tween_property(self, "global_position", self.global_position+Vector3(0,10,0), 2.0)
	await $AnimationPlayer.animation_finished
	ruszaj = true

func _process(delta: float) -> void:
	if ruszaj == true:
		global_position = lerp(global_position, camera.global_position, delta*10)
		look_at($"../camera_pivot/Camera3D".global_position, Vector3(0,1,0), true)
		var a = (1+sin(tik))*10
		scale = Vector3(a,a,a)
		tik += 0.001

func _on_node_3d_wyrzucona(strona: Variant) -> void:
	wyswietl(strona)
