class_name MenuSign3D
extends Node3D

# One main-menu entry, as a slab of extruded 3D text hanging in the air
# instead of a flat 2D button.
#
# The node's origin is the middle of the word: each model is re-centred on its
# own bounding box when it is loaded, so signs of wildly different lengths
# ("exit" against "position") still stack into a tidy centred column. Nothing
# here knows what the sign does - menu_glowne.gd owns the mapping from sign to
# action, the same way the old Buttons owned their `pressed` signals.

# The signs drift the way the board's plates do, just looser: these are hung
# in mid-air rather than floating on water, so they swing a little more and
# turn as they go.
const BOB := 0.055 # +/- vertical travel
const SWAY := 0.035 # +/- sideways travel
const TURN := 0.075 # +/- yaw, radians (~4 degrees)
const ROLL := 0.035 # +/- roll, radians (~2 degrees)
const SPEED := 0.5

# Hover: the sign steps toward the camera and brightens. HOVER_LERP is how
# fast it gets there - high enough to feel like a button, slow enough that the
# motion is visible rather than a snap.
const HOVER_LIFT := 0.28
const HOVER_SCALE := 1.14
const HOVER_LERP := 12.0
const EMISSION_IDLE := 0.18
const EMISSION_HOVER := 0.95
# A word is a row of separate letters with gaps between them, so a hit test
# against the tight bounding box makes the sign feel like it has holes in it.
# The clickable rectangle is padded out to what the eye reads as one button.
const HIT_PADDING := Vector2(14.0, 10.0)

var base_position := Vector3.ZERO
var hovered := false
# What this sign does when clicked. The menu fills it in, exactly the way the
# Buttons it replaced carried their own `pressed` connection.
var on_pressed := Callable()
var _phase := 0.0
var _blend := 0.0 # 0 = resting, 1 = fully hovered
var _material: StandardMaterial3D
var _model: Node3D
var _size := Vector3.ONE # the word's own extent, before any hover scaling

# `model_path` is the artist's .glb and `node_name` the word to take out of
# it. Naming the node matters because these exports are not all one word per
# file - settings.glb is a whole Blender scene carrying every word plus some
# leftover scenery - so taking the file wholesale would put the entire menu
# inside a single sign. When the name is not found the whole file is used,
# which is what the one-word exports need.
#
# `fallback_text` is only used when the model is missing or exported empty, in
# which case the sign is built from Godot's own extruded TextMesh so the menu
# still has every entry.
static func create(model_path: String, node_name: String, fallback_text: String, phase: float) -> MenuSign3D:
	var entry := MenuSign3D.new()
	entry._phase = phase
	entry._material = _build_material()
	var model := _load_model(model_path, node_name)
	if model == null:
		push_warning("MenuSign3D: '%s' is missing or has no mesh - falling back to TextMesh for \"%s\"" % [model_path, fallback_text])
		model = _build_fallback(fallback_text)
	entry._model = model
	entry.add_child(model)
	# Re-centre on the word itself. The models carry the artist's Blender
	# origin, which sits wherever the text happened to be typed.
	var bounds := _local_bounds(entry, model)
	entry._size = bounds.size
	model.position -= bounds.get_center()
	_apply_material(model, entry._material)
	return entry

# The rectangle on screen this sign answers clicks in. Derived from the word's
# real corners rather than a guessed box, so it tracks the drifting and the
# hover step toward the camera.
func hit_rect(camera: Camera3D) -> Rect2:
	var half := _size * 0.5
	var rect := Rect2()
	var first := true
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var corner := global_position + basis * Vector3(sx * half.x, sy * half.y, sz * half.z)
				# A corner behind the camera unprojects to nonsense; the menu
				# camera never gets that close, but a bad rect would swallow
				# clicks across the whole screen, so it is not worth risking.
				if not camera.is_position_behind(corner):
					var point := camera.unproject_position(corner)
					rect = Rect2(point, Vector2.ZERO) if first else rect.expand(point)
					first = false
	if first:
		return Rect2()
	return rect.grow_individual(HIT_PADDING.x, HIT_PADDING.y, HIT_PADDING.x, HIT_PADDING.y)

# The word's own extent, so the menu can stack and frame the signs without
# knowing anything about the models they came from.
func word_size() -> Vector3:
	return _size

func set_tint(tint: Color) -> void:
	if _material == null:
		return
	_material.albedo_color = Color.WHITE.lerp(tint, 0.35)
	_material.emission = tint

func _process(delta: float) -> void:
	var t := float(Time.get_ticks_msec()) / 1000.0 * SPEED + _phase
	_blend = move_toward(_blend, 1.0 if hovered else 0.0, delta * HOVER_LERP)
	var eased := _blend * _blend * (3.0 - 2.0 * _blend) # smoothstep, so the step in and out settles instead of stopping dead
	position = base_position + Vector3(
		sin(t * 0.71) * SWAY,
		sin(t) * BOB,
		eased * HOVER_LIFT)
	rotation = Vector3(0.0, sin(t * 0.83) * TURN, sin(t * 0.61) * ROLL)
	scale = Vector3.ONE * lerpf(1.0, HOVER_SCALE, eased)
	if _material != null:
		_material.emission_energy_multiplier = lerpf(EMISSION_IDLE, EMISSION_HOVER, eased)

static func _build_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.92, 0.92, 0.94)
	material.roughness = 0.32
	material.metallic = 0.15
	# The menu's animated background is busy and changes colour with the
	# player's nickname, so the signs carry their own glow rather than relying
	# on contrast against whatever is behind them at the time.
	material.emission_enabled = true
	material.emission = Color.WHITE
	material.emission_energy_multiplier = EMISSION_IDLE
	return material

static func _load_model(path: String, node_name: String) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	var instance := packed.instantiate()
	# `owned = false`, because nodes coming out of an imported scene belong to
	# its root and the owned search would walk straight past them.
	var wanted := instance.find_child(node_name, true, false) if not node_name.is_empty() else null
	if wanted is Node3D and _has_mesh(wanted):
		wanted.get_parent().remove_child(wanted)
		instance.free() # everything else in the file - other words, stray scenery
		return wanted
	if instance is Node3D and _has_mesh(instance):
		return instance
	instance.free()
	return null

static func _build_fallback(text: String) -> Node3D:
	var node := MeshInstance3D.new()
	var mesh := TextMesh.new()
	mesh.text = text
	# Sized and extruded to sit alongside the artist's models rather than
	# matching them - it is a stand-in, and it should be obvious which one it is.
	mesh.font_size = 72
	mesh.depth = 0.34
	node.mesh = mesh
	return node

static func _has_mesh(node: Node) -> bool:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		return true
	for child in node.get_children():
		if _has_mesh(child):
			return true
	return false

static func _apply_material(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = material
	for child in node.get_children():
		_apply_material(child, material)

# Every mesh under `node`, merged into one box expressed in `root`'s space.
static func _local_bounds(root: Node3D, node: Node3D) -> AABB:
	var bounds := AABB()
	var found := false
	for mesh_instance in _mesh_instances(node):
		var box := mesh_instance.mesh.get_aabb()
		# Measured before the sign is ever added to the tree, so
		# global_transform is meaningless here and the chain up to the sign is
		# walked by hand instead.
		box = _relative_transform(root, mesh_instance) * box
		bounds = box if not found else bounds.merge(box)
		found = true
	return bounds if found else AABB(Vector3.ZERO, Vector3.ONE)

static func _mesh_instances(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		result.append(node)
	for child in node.get_children():
		result.append_array(_mesh_instances(child))
	return result

static func _relative_transform(root: Node, node: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var current: Node = node
	while current is Node3D and current != root:
		result = (current as Node3D).transform * result
		current = current.get_parent()
	return result

# The signs' SubViewport renders its own world and starts out with no lights,
# so they would be pure emission - flat, and with no sense of the letters
# being solid. A key, a fill and a rim from behind give the extrusion an edge
# to catch, which is the whole point of them being models rather than labels.
static func add_lighting(root: Node3D) -> void:
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35.0, -40.0, 0.0)
	key.light_energy = 1.15
	key.shadow_enabled = false
	root.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-10.0, 55.0, 0.0)
	fill.light_energy = 0.45
	fill.light_color = Color(0.80, 0.86, 1.0)
	fill.shadow_enabled = false
	root.add_child(fill)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(18.0, 170.0, 0.0)
	rim.light_energy = 0.7
	rim.shadow_enabled = false
	root.add_child(rim)
