extends Node3D

@onready var moneta: RigidBody3D = $moneta
@onready var ray_cast_3d: RayCast3D = $moneta/RayCast3D
@onready var camera_animation: AnimationPlayer = $camera_pivot/AnimationPlayer

signal wyrzucona(strona)
signal snapshot_ready(snapshot: Dictionary)

const SAMPLE_TICKS := 4
const SETTLE_SECONDS := 0.35
var can_launch := true
var online := false
var resolved := false
var previous_time_scale := 1.0
var previous_physics_ticks := 60
var elapsed := 0.0
var settled_time := 0.0
var sample_tick := 0
var sample_index := 0
var snapshots := {}
var playback_index := 0
var playback_time := 0.0
var playback_frame: Dictionary = {}

func _ready() -> void:
	camera_animation.play("obrot")
	$muzyka.play()
	previous_time_scale = Engine.time_scale
	previous_physics_ticks = Engine.physics_ticks_per_second
	Engine.time_scale = 2
	Engine.physics_ticks_per_second = 120
	moneta.contact_monitor = true
	moneta.max_contacts_reported = 4

func _exit_tree() -> void:
	Engine.time_scale = previous_time_scale
	Engine.physics_ticks_per_second = previous_physics_ticks

func configure(allow_launch: bool, is_online: bool) -> void:
	can_launch = allow_launch
	online = is_online
	# Neither machine simulates the idle coin; only the host launches physics.
	moneta.freeze = true
	if online and not can_launch:
		camera_animation.pause()

func _physics_process(delta: float) -> void:
	if not moneta.rzucona or resolved or (online and not can_launch):
		return
	elapsed += delta
	# Low vertical speed at the apex is not a landing. Require contact and
	# quiet angular velocity for several consecutive physics frames.
	if moneta.get_contact_count() > 0 and moneta.linear_velocity.length() < 0.1 and moneta.angular_velocity.length() < 0.1:
		settled_time += delta
	else:
		settled_time = 0.0
	if settled_time >= SETTLE_SECONDS:
		moneta.freeze = true
		ray_cast_3d.force_raycast_update()
		var result := "reszka" if ray_cast_3d.is_colliding() else "orzel"
		_publish_snapshot(result)
		_resolve(result)
		return
	sample_tick += 1
	if sample_tick >= SAMPLE_TICKS:
		sample_tick = 0
		_publish_snapshot()

func _process(delta: float) -> void:
	if not online or can_launch or resolved:
		return
	if playback_frame.is_empty():
		if not snapshots.has(0):
			return
		playback_frame = snapshots[0]
		snapshots.erase(0)
		moneta.rzucona = true
		_apply_frame(playback_frame, playback_frame, 0.0)
	# Consume only consecutive samples: packet loss/reordering pauses playback
	# instead of skipping bounces or revealing the landing result too early.
	playback_time += delta
	while snapshots.has(playback_index + 1):
		var next: Dictionary = snapshots[playback_index + 1]
		var end_time := float(next["time"])
		if playback_time < end_time:
			var weight := inverse_lerp(float(playback_frame["time"]), end_time, playback_time)
			_apply_frame(playback_frame, next, clampf(weight, 0.0, 1.0))
			return
		playback_index += 1
		snapshots.erase(playback_index)
		playback_frame = next
		_apply_frame(next, next, 0.0)
		var result := str(next.get("result", ""))
		if result in ["orzel", "reszka"]:
			_resolve(result)
			return
	playback_time = float(playback_frame["time"])

func _input(_event: InputEvent) -> void:
	if can_launch and Input.is_action_just_pressed("space"):
		launch()

func launch(throw_seed := -1) -> void:
	if not can_launch or moneta.rzucona or (online and not NetworkManager.coin_peer_ready):
		return
	if throw_seed < 0:
		throw_seed = randi()
	camera_animation.play("obrot")
	camera_animation.seek(0.0, true)
	_publish_snapshot()
	var rng := RandomNumberGenerator.new()
	rng.seed = throw_seed
	moneta.rzucona = true
	moneta.freeze = false
	moneta.linear_velocity = Vector3(0, 150, 0)
	moneta.angular_velocity = Vector3(rng.randf_range(-12, 12), rng.randf_range(-12, 12), rng.randf_range(-12, 12))

func _publish_snapshot(result := "") -> void:
	if not online:
		return
	var p := moneta.position
	var q := moneta.quaternion
	snapshot_ready.emit({"index": sample_index, "time": elapsed,
		"position": [p.x, p.y, p.z], "rotation": [q.x, q.y, q.z, q.w],
		"camera": camera_animation.current_animation_position, "result": result})
	sample_index += 1

func receive_snapshot(snapshot: Dictionary) -> void:
	if not online or can_launch or resolved:
		return
	var index := int(snapshot.get("index", -1))
	if index < 0 or (not playback_frame.is_empty() and index <= playback_index):
		return
	if not snapshot.get("position") is Array or snapshot["position"].size() != 3:
		return
	if not snapshot.get("rotation") is Array or snapshot["rotation"].size() != 4:
		return
	snapshots[index] = snapshot

func _apply_frame(a: Dictionary, b: Dictionary, weight: float) -> void:
	var pa: Array = a["position"]
	var pb: Array = b["position"]
	var qa: Array = a["rotation"]
	var qb: Array = b["rotation"]
	moneta.position = Vector3(pa[0], pa[1], pa[2]).lerp(Vector3(pb[0], pb[1], pb[2]), weight)
	moneta.quaternion = Quaternion(qa[0], qa[1], qa[2], qa[3]).slerp(Quaternion(qb[0], qb[1], qb[2], qb[3]), weight)
	var camera_from := float(a["camera"])
	var camera_to := float(b["camera"])
	var camera_length := camera_animation.get_animation("obrot").length
	if camera_to < camera_from:
		camera_to += camera_length
	camera_animation.seek(fposmod(lerpf(camera_from, camera_to, weight), camera_length), true)

func _resolve(result: String) -> void:
	if resolved:
		return
	resolved = true
	camera_animation.pause()
	wyrzucona.emit(result)
