class_name BoardTile
extends Node3D

# One board square, built from the artist's beveled plate model instead of the
# flat PlaneMesh the board used to be made of.
#
# The node itself stays UNSCALED and is placed so the plate's top face sits at
# its local y = 0. That keeps every assumption the rest of the board math
# already makes about the old plane intact: mouse picking still ray-casts
# against the y = 0 ground plane, pieces still stand at PIECE_Y, and move
# hints still hover HINT_Y above the square. The scaled mesh lives on a child
# node, so anything parented to a tile (the hints) rides along with the
# levitation below without inheriting the plate's scale.

const MODEL := preload("res://assets/POLA/pole.glb")
const TEXTURE_LIGHT := preload("res://assets/POLA/pole_biale.jpg")
const TEXTURE_DARK := preload("res://assets/POLA/pole_czarne.jpg")

# Tiles no longer meet edge to edge: they are separate floating plates, so
# each one is inset inside its cell. The gap doubles as the headroom the
# sideways drift needs - without it neighbouring plates would intersect, so
# raising this means lowering LEV_DRIFT. At 0.97 the gap is 0.03 of a cell
# and two neighbours drifting toward each other close at most 0.018 of it.
const TILE_FILL := 0.97

# Levitation: every plate drifts along its own slow, endless loop, as if the
# board were floating on water. Amplitudes are in cell units and deliberately
# tiny - which square a plate belongs to has to stay unambiguous at a glance,
# and picking still happens against the fixed grid, so a plate must never
# wander far enough from its cell for the two to visibly disagree.
const LEVITATION := true
const LEV_SPEED := 0.42 # global rate; one full bob takes about 15s at 0.42
const LEV_RISE := 0.022 # +/- vertical travel
const LEV_DRIFT := 0.009 # +/- sideways travel
const LEV_TILT := 0.018 # +/- rocking, in radians (~1 degree)
# Per-axis rates, kept mutually irrational-ish so a plate's motion never
# settles into a short repeating loop and neighbours never sync up.
const RATE_RISE := 1.0
const RATE_DRIFT_X := 0.73
const RATE_DRIFT_Z := 0.61
const RATE_TILT_X := 0.83
const RATE_TILT_Z := 0.67

# Board lighting. Two directionals give the plates their shape (without them
# the bevel and the sides read exactly as bright as the top); the lamp is a
# point light hung over the middle of the board, and it is what makes one
# plate brighter than another instead of the whole board being evenly washed.
# Plates riding high on their levitation come nearer to it and pick up a
# little more light, which is free and reads nicely.
const KEY_LIGHT := "BoardKeyLight"
const FILL_LIGHT := "BoardFillLight"
const LAMP := "BoardLamp"
const KEY_ENERGY := 0.16
const FILL_ENERGY := 0.12
const LAMP_ENERGY := 1.0
const LAMP_HEIGHT := 0.65 # how high the lamp hangs, in board half-spans
const LAMP_REACH := 2.7 # lamp range, in multiples of that height
# How far each light is dragged from white toward the two players' mixed
# colour. Nickname colours are strongly saturated, so lighting the board with
# them neat would drown the plates' own texture - the lamp carries most of the
# tint because that is where the light actually pools.
const LAMP_TINT := 0.55
const KEY_TINT := 0.22

static var _mesh: Mesh = null
# The model normalized to a 1.0-wide cell: the scale that gets it there, plus
# where its top face and centre land once scaled. Derived from the mesh's own
# AABB rather than hard-coded, so re-exporting pole.glb at a different size or
# thickness keeps working.
static var _unit_scale := Vector3.ONE
static var _unit_top := 0.0
static var _unit_center := Vector3.ZERO
static var _unit_flip := false # see _load_model()
static var _materials := {} # bool (is_light) -> StandardMaterial3D

var pole := Vector2i.ZERO
var base_position := Vector3.ZERO
var _phases := PackedFloat32Array()

# `light` picks which of the two textures the plate wears; `tile_size` is the
# full cell size, inside which the plate is then inset (see TILE_FILL).
static func create(square: Vector2i, world_position: Vector3, tile_size: float, light: bool) -> BoardTile:
	_load_model()
	var tile := BoardTile.new()
	tile.pole = square
	tile.base_position = world_position
	tile.position = world_position
	tile._phases = PackedFloat32Array([
		_phase(square, 0.0), _phase(square, 11.3), _phase(square, 27.1),
		_phase(square, 43.7), _phase(square, 61.9)])
	var plate := MeshInstance3D.new()
	plate.name = "Plate"
	plate.mesh = _mesh
	plate.material_override = _material(light)
	var size := tile_size * TILE_FILL
	plate.scale = _unit_scale * size
	if _unit_flip:
		plate.rotation = Vector3(PI, 0.0, 0.0)
	plate.position = Vector3(-_unit_center.x, -_unit_top, -_unit_center.z) * size
	tile.add_child(plate)
	if not LEVITATION:
		tile.set_process(false)
	return tile

# How far this plate currently sits from its resting spot. Pieces standing on
# it borrow this so they drift with their square instead of hovering over a
# plate that has floated out from under them.
func levitation_offset() -> Vector3:
	return position - base_position

func _process(_delta: float) -> void:
	# Driven off the shared engine clock rather than an accumulated per-node
	# delta, so every plate agrees on the phase of the motion - including
	# across the two clients of an online match, where both players are
	# supposed to be looking at the same board.
	var t := float(Time.get_ticks_msec()) / 1000.0 * LEV_SPEED
	position = base_position + Vector3(
		sin(t * RATE_DRIFT_X + _phases[1]) * LEV_DRIFT,
		sin(t * RATE_RISE + _phases[0]) * LEV_RISE,
		sin(t * RATE_DRIFT_Z + _phases[2]) * LEV_DRIFT)
	rotation = Vector3(
		sin(t * RATE_TILT_X + _phases[3]) * LEV_TILT,
		0.0,
		sin(t * RATE_TILT_Z + _phases[4]) * LEV_TILT)

# A stable pseudo-random offset per square, so the board looks irregular while
# every plate keeps the same character for the whole match (and looks the same
# to both players online) instead of being reshuffled whenever it respawns.
static func _phase(square: Vector2i, salt: float) -> float:
	return fposmod(sin(square.x * 12.9898 + square.y * 78.233 + salt) * 43758.5453, TAU)

# One-time setup of the viewport the board renders into. Call from _ready().
static func setup_board(viewport: SubViewport, board_root: Node3D) -> void:
	# The plates are hard-edged and permanently, slowly moving, so aliasing on
	# them crawls. Nothing else in this viewport is geometry, so this is paid
	# for the board alone.
	viewport.msaa_3d = Viewport.MSAA_4X
	_add_lighting(board_root)

# The 2D world is authored against a fixed 512-unit base and scaled up to the
# window (window/stretch/mode = canvas_items). Text and controls come through
# that sharp because they are re-rasterized at the real resolution. A
# SubViewport does not: it is a texture, so sizing it in base units renders
# the board at a fraction of the window's real resolution and leaves the
# container to blow the result back up - which is why the plates looked like
# you could count their pixels. The container is therefore sized in REAL
# pixels and scaled back down by the same factor: same area of screen, one
# board pixel per screen pixel.
#
# `canvas_rect` is where the board should sit, in the 2D units the rest of the
# scene is laid out in. Mouse math has to divide by the container's scale to
# get back into the viewport's pixels - see _mouse_ground_point().
static func fit_to_pixels(container: SubViewportContainer, canvas_rect: Rect2) -> void:
	var canvas := container.get_viewport_rect().size
	var pixels := Vector2(container.get_window().size)
	var factor := 1.0
	# aspect = expand keeps the scale uniform, so one axis is enough.
	if canvas.x > 0.0 and pixels.x > 0.0:
		factor = pixels.x / canvas.x
	container.position = canvas_rect.position
	container.scale = Vector2.ONE / factor
	container.size = canvas_rect.size * factor

# The board's SubViewport renders its own world and starts out with no lights
# at all, which is why every other 3D thing in it (piece billboards, hints,
# the duck) is unshaded. Flat-lit plates would waste the model, so the lights
# the tiles need are added here. Nothing else in the viewport is shaded, so
# they affect the tiles and only the tiles.
#
# There is deliberately no WorldEnvironment: the board viewport is transparent
# so the animated 2D background shows through behind it, and an environment
# would paint over that. The ambient term that keeps the plates' shaded sides
# off pure black comes from the material's own emission instead.
static func _add_lighting(board_root: Node3D) -> void:
	if board_root.has_node(KEY_LIGHT):
		return
	var key := DirectionalLight3D.new()
	key.name = KEY_LIGHT
	key.rotation_degrees = Vector3(-52.0, -34.0, 0.0)
	key.light_energy = KEY_ENERGY
	key.shadow_enabled = false
	board_root.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.name = FILL_LIGHT
	fill.rotation_degrees = Vector3(-18.0, 146.0, 0.0)
	fill.light_energy = FILL_ENERGY
	fill.light_color = Color(0.84, 0.88, 1.0)
	fill.shadow_enabled = false
	board_root.add_child(fill)
	var lamp := OmniLight3D.new()
	lamp.name = LAMP
	lamp.light_energy = LAMP_ENERGY
	lamp.shadow_enabled = false
	# Attenuation 0 turns off the physical 1/d^2 term and leaves only the
	# range window, which is what makes the falloff across the board something
	# that can be aimed by hand rather than something that collapses into a
	# hotspot over the middle four squares.
	lamp.omni_attenuation = 0.0
	board_root.add_child(lamp)

# Hangs the lamp over the middle of the board. `half_span` is the board's
# half-width in world units, so the pool of light keeps the same shape
# relative to the board whether it is 8x8 or grown to 10x10 by a card.
static func focus_lighting(board_root: Node3D, center: Vector3, half_span: float) -> void:
	var lamp := board_root.get_node_or_null(LAMP) as OmniLight3D
	if lamp == null:
		return
	var height := maxf(half_span, 1.0) * LAMP_HEIGHT
	lamp.position = center + Vector3(0.0, height, 0.0)
	lamp.omni_range = height * LAMP_REACH

# Colours the board with the two players' mixed colour - the same mix the
# animated background behind it is tinted with, so board and background read
# as one scene. The mix arrives at whatever brightness the nickname hash
# produced; only its hue and saturation are wanted here, since how BRIGHT the
# board is has already been decided by the light energies above.
static func tint_lighting(board_root: Node3D, tint: Color) -> void:
	var hue := Color.from_hsv(tint.h, tint.s, 1.0)
	var key := board_root.get_node_or_null(KEY_LIGHT) as DirectionalLight3D
	if key != null:
		key.light_color = Color.WHITE.lerp(hue, KEY_TINT)
	var lamp := board_root.get_node_or_null(LAMP) as OmniLight3D
	if lamp != null:
		lamp.light_color = Color.WHITE.lerp(hue, LAMP_TINT)

static func _material(light: bool) -> StandardMaterial3D:
	if _materials.has(light):
		return _materials[light]
	var material := StandardMaterial3D.new()
	material.albedo_texture = TEXTURE_LIGHT if light else TEXTURE_DARK
	material.roughness = 1.0
	material.metallic = 0.0
	# A closed, opaque, convex plate: with depth testing on, drawing its back
	# faces too is invisible in the result and costs 12 extra triangles per
	# tile, but it makes the board immune to a re-export coming back with its
	# winding the other way round - which is exactly the failure this model
	# already shipped with once.
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	# The plates are matte plastic and there is no environment to reflect, so
	# a specular lobe would only ever show up as a hotspot sliding across them
	# as they rock.
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	# Stands in for ambient light - see add_lighting(). MULTIPLY, not the
	# default ADD: ADD would add the emission colour to the texture rather
	# than scaling it, i.e. glow every plate by the same flat amount, which
	# lifts the dark squares far more than the light ones and all but erases
	# the checkerboard.
	material.emission_enabled = true
	material.emission = Color.WHITE
	material.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	material.emission_energy_multiplier = 0.08
	material.emission_texture = material.albedo_texture
	_materials[light] = material
	return material

static func _load_model() -> void:
	if _mesh != null:
		return
	var scene: Node = MODEL.instantiate()
	var source := _find_mesh_instance(scene)
	if source == null:
		push_error("pole.glb contains no MeshInstance3D")
		scene.free()
		return
	_mesh = source.mesh
	# Blender exported this plate upside down, as a NEGATIVE scale on its node
	# - a MIRRORED transform, not a rotation. A mirror reverses triangle
	# winding, and the renderer culls on winding, so used as-is the plate
	# loses its side walls: only its inside-out back faces survive and it
	# reads as a flat quad. The plate is a square frustum, symmetric about its
	# own vertical axis, so the mirror can be replaced by an honest 180-degree
	# rotation: same orientation the artist intended (the wider face up),
	# winding left alone.
	var model_transform := _relative_transform(scene, source)
	var model_scale := model_transform.basis.get_scale().abs()
	_unit_flip = model_transform.basis.determinant() < 0.0
	var aabb := _mesh.get_aabb()
	var width := maxf(aabb.size.x * model_scale.x, aabb.size.z * model_scale.z)
	_unit_scale = model_scale / width if width > 0.0 else model_scale
	# Where the plate's top face and its horizontal centre end up once scaled
	# (and flipped, which turns the model's bottom into its top).
	var low := aabb.position * _unit_scale
	var high := (aabb.position + aabb.size) * _unit_scale
	_unit_top = -low.y if _unit_flip else high.y
	_unit_center = Vector3((low.x + high.x) * 0.5, 0.0, (low.z + high.z) * 0.5)
	if _unit_flip:
		_unit_center.z = -_unit_center.z
	scene.free()

static func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		return node
	for child in node.get_children():
		var found := _find_mesh_instance(child)
		if found != null:
			return found
	return null

# global_transform is meaningless for a scene that was instantiated but never
# added to the tree, so the chain up to the root is walked by hand instead.
static func _relative_transform(root: Node, node: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var current: Node = node
	while current is Node3D:
		result = (current as Node3D).transform * result
		if current == root:
			break
		current = current.get_parent()
	return result
