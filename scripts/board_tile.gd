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

# Entrance animation: a tile placed mid-match rises up out of the void
# instead of popping into existence. Measured from the moment it starts;
# negative means "not currently rising" (the common case).
const RISE_DURATION := 0.45
const RISE_DROP := 1.1 # how far below its resting height the plate starts, in cell units

# Collapse animation: played instead of a plain queue_free() when a hole is
# punched through the square. Unlike the rise-in above this needs no ongoing
# _process on the tile itself: the plate is immediately replaced by a handful
# of irregular shard meshes that sit assembled with a hairline gap between
# them (the "it cracks first" beat) before they let go and tumble away on
# their own tweens. No single break point - the footprint is recursively
# split by random straight cuts (a small BSP fracture, see _crumble_split()),
# the way a block of masonry crumbles into a handful of unevenly sized
# chunks, rather than how a pane of glass shatters from one impact point.
# See _shatter().
const CRACK_DURATION := 0.14 # how long the cracks are visible before pieces let go
const SHARD_THICKNESS_RATIO := 0.1 # shard thickness, as a fraction of the plate size
const SHARD_GAP := 0.05 # crack width, as a fraction of each shard's own size
const SPLIT_ROUNDS := 3
const SPLIT_CHANCE := 0.8 # a piece's odds of splitting again each round
const FALL_DURATION := 0.6
const FALL_DISTANCE := 1.6 # how far a chunk drops while falling, in cell units
const OUTWARD := 0.35 # chunks mostly just drop, rather than fly outward
const SPIN := 2.2 # average tumble rate, radians/sec

# The exposed break surface (the shard's side walls) is given its own flat,
# duller material instead of reusing the plate's photo texture there - a
# freshly broken edge reads as raw stone/mortar, not as more of the same
# weathered top finish.
const BROKEN_EDGE_COLOR := Color(0.56, 0.5, 0.45)

# A small burst of dust motes at the crack, puffing up and fading as the
# chunks let go - sells "crumbling masonry" alongside the sound effect.
const DUST_COUNT := 14
const DUST_LIFETIME := 0.55
const DUST_COLOR := Color(0.62, 0.56, 0.5, 0.55)

static var _broken_material: StandardMaterial3D = null
static var _dust_mesh: QuadMesh = null

var pole := Vector2i.ZERO
var base_position := Vector3.ZERO
var _phases := PackedFloat32Array()
var _plate_size := 1.0
var _plate_material: StandardMaterial3D = null

var _rise_elapsed := -1.0
var _collapsed := false

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
	tile._plate_material = plate.material_override
	var size := tile_size * TILE_FILL
	tile._plate_size = size
	plate.scale = _unit_scale * size
	if _unit_flip:
		plate.rotation = Vector3(PI, 0.0, 0.0)
	plate.position = Vector3(-_unit_center.x, -_unit_top, -_unit_center.z) * size
	tile.add_child(plate)
	if not LEVITATION:
		tile.set_process(false)
	return tile

# Called right after create() for a tile appearing mid-match (a newly placed
# square) rather than at board setup, so it visibly climbs up out of the void
# instead of just appearing.
func play_rise_in() -> void:
	_rise_elapsed = 0.0

# Called instead of queue_free() when a hole is punched through this square.
# Spawns the shatter effect and frees the tile right away - the shards are
# independent nodes that go on animating themselves, so the tile itself has
# nothing left to do. The caller just forgets about it (and should drop it
# from any lookup table immediately, since the square is already gone from
# play).
func play_collapse() -> void:
	if _collapsed:
		return
	_collapsed = true
	_shatter()
	queue_free()

# How far this plate currently sits from its resting spot. Pieces standing on
# it borrow this so they drift with their square instead of hovering over a
# plate that has floated out from under them.
func levitation_offset() -> Vector3:
	return position - base_position

func _process(delta: float) -> void:
	# Driven off the shared engine clock rather than an accumulated per-node
	# delta, so every plate agrees on the phase of the motion - including
	# across the two clients of an online match, where both players are
	# supposed to be looking at the same board.
	var t := float(Time.get_ticks_msec()) / 1000.0 * LEV_SPEED
	var rise_y := 0.0
	if _rise_elapsed >= 0.0:
		_rise_elapsed += delta
		var p := clampf(_rise_elapsed / RISE_DURATION, 0.0, 1.0)
		rise_y = (_ease_out_back(p) - 1.0) * RISE_DROP
		if p >= 1.0:
			_rise_elapsed = -1.0
	position = base_position + Vector3(
		sin(t * RATE_DRIFT_X + _phases[1]) * LEV_DRIFT,
		sin(t * RATE_RISE + _phases[0]) * LEV_RISE + rise_y,
		sin(t * RATE_DRIFT_Z + _phases[2]) * LEV_DRIFT)
	rotation = Vector3(
		sin(t * RATE_TILT_X + _phases[3]) * LEV_TILT,
		0.0,
		sin(t * RATE_TILT_Z + _phases[4]) * LEV_TILT)

# No single break point. The footprint is recursively cut by random straight
# lines (a small BSP fracture - see _crumble_split()) into a handful of
# unevenly sized chunks, the way a block of masonry crumbles rather than how
# a pane of glass shatters. Each chunk drifts gently outward from the tile's
# own centre as it falls, instead of blowing out from one impact point.
func _shatter() -> void:
	var parent := get_parent()
	if parent == null or _plate_material == null or _plate_size <= 0.0:
		return
	var half := _plate_size * 0.5
	var square := PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)])
	var tile_origin := global_position
	for poly in _crumble_split(square, SPLIT_ROUNDS):
		_spawn_shard(parent, tile_origin, poly, half)
	_spawn_dust(parent, tile_origin)

# Recursively cuts `poly` into smaller convex pieces: each round, every piece
# has a SPLIT_CHANCE of being sliced in two by a random straight line through
# roughly its own centre, and is otherwise left whole - which is what keeps
# the final pieces unevenly sized instead of a uniform grid.
static func _crumble_split(poly: PackedVector2Array, rounds: int) -> Array[PackedVector2Array]:
	var polys: Array[PackedVector2Array] = [poly]
	for _round in rounds:
		var next: Array[PackedVector2Array] = []
		for p in polys:
			if p.size() >= 3 and randf() < SPLIT_CHANCE:
				next.append_array(_split_polygon(p))
			else:
				next.append(p)
		polys = next
	return polys

# Cuts a convex polygon in two with a single random line (Sutherland-Hodgman
# clip against both half-planes of that line). The cut point is jittered off
# the centroid so the two resulting pieces are unevenly sized rather than
# always splitting a piece exactly down the middle.
static func _split_polygon(poly: PackedVector2Array) -> Array[PackedVector2Array]:
	var centroid := Vector2.ZERO
	for p in poly:
		centroid += p
	centroid /= poly.size()
	var radius := 0.0
	for p in poly:
		radius = maxf(radius, (p - centroid).length())
	var dir := Vector2.from_angle(randf_range(0.0, PI))
	var cut := centroid + Vector2(randf_range(-0.2, 0.2), randf_range(-0.2, 0.2)) * radius
	var a := _clip_polygon(poly, cut, dir)
	var b := _clip_polygon(poly, cut, -dir)
	var result: Array[PackedVector2Array] = []
	if a.size() >= 3:
		result.append(a)
	if b.size() >= 3:
		result.append(b)
	if result.is_empty():
		result.append(poly)
	return result

# Keeps the part of `poly` on the side of the line through `p` (direction
# `dir`) where cross(dir, vertex - p) >= 0, inserting a new vertex at each
# edge that crosses the line.
static func _clip_polygon(poly: PackedVector2Array, p: Vector2, dir: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	var n := poly.size()
	for i in n:
		var a := poly[i]
		var b := poly[(i + 1) % n]
		var side_a := dir.cross(a - p)
		var side_b := dir.cross(b - p)
		if side_a >= 0.0:
			result.append(a)
		if (side_a >= 0.0) != (side_b >= 0.0):
			result.append(a.lerp(b, side_a / (side_a - side_b)))
	return result

# Builds and launches one chunk. `poly` is in tile-footprint-local space (XZ,
# centred on the tile). The chunk is a small wrapper Node3D holding two
# meshes - a textured "cap" (top+bottom, the plate's own worn finish) and an
# untextured "edge" (the side walls, in BROKEN_EDGE_COLOR) - so the freshly
# exposed break reads as raw stone rather than more of the painted top.
func _spawn_shard(parent: Node, tile_origin: Vector3, poly: PackedVector2Array, half: float) -> void:
	var centroid := Vector2.ZERO
	for p in poly:
		centroid += p
	centroid /= poly.size()
	var inset := PackedVector2Array()
	for p in poly:
		inset.append(centroid + (p - centroid) * (1.0 - SHARD_GAP))
	var local_poly := PackedVector2Array()
	for p in inset:
		local_poly.append(p - centroid)
	var thickness := _plate_size * SHARD_THICKNESS_RATIO

	var chunk := Node3D.new()
	chunk.position = tile_origin + Vector3(centroid.x, 0.0, centroid.y)
	parent.add_child(chunk)

	var cap := MeshInstance3D.new()
	cap.mesh = _build_cap_mesh(local_poly, inset, thickness, half)
	cap.material_override = _plate_material
	chunk.add_child(cap)

	var edge := MeshInstance3D.new()
	edge.mesh = _build_edge_mesh(local_poly, thickness)
	edge.material_override = _get_broken_material()
	chunk.add_child(edge)

	_animate_shard(chunk, centroid)

# First holds the chunk in its cracked-but-assembled spot for CRACK_DURATION,
# then lets it tumble away from the tile's own centre (so pieces nearer the
# middle travel less, outer ones more) while it falls and shrinks away, and
# finally frees itself.
func _animate_shard(chunk: Node3D, centroid: Vector2) -> void:
	var outward2 := centroid.normalized() if centroid.length() > 0.001 else Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
	var drift := Vector3(outward2.x, 0.0, outward2.y) * OUTWARD * randf_range(0.7, 1.3)
	drift.x += randf_range(-0.12, 0.12)
	drift.z += randf_range(-0.12, 0.12)
	drift.y = -FALL_DISTANCE * randf_range(0.8, 1.3)
	var spin := Vector3(
		randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized() \
		* SPIN * randf_range(0.6, 1.3)
	var start_pos := chunk.position
	var start_rot := chunk.rotation
	var tween := chunk.create_tween().set_parallel(true)
	tween.tween_property(chunk, "position", start_pos + drift, FALL_DURATION)\
		.set_delay(CRACK_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(chunk, "rotation", start_rot + spin, FALL_DURATION)\
		.set_delay(CRACK_DURATION)
	tween.tween_property(chunk, "scale", Vector3.ZERO, FALL_DURATION * 0.4)\
		.set_delay(CRACK_DURATION + FALL_DURATION * 0.6)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(chunk.queue_free)

# The textured top+bottom faces of one chunk, in shard-local space (centred
# on the chunk's own centroid, for clean rotation); `uv_src` carries the
# matching points in tile-footprint space so the chunk samples the right
# patch of the plate's own texture. Normals are written explicitly rather
# than via generate_normals(), since cull_mode is disabled on the shared
# material and so winding direction can't be relied on to say which way a
# face is meant to point.
static func _build_cap_mesh(poly: PackedVector2Array, uv_src: PackedVector2Array, thickness: float, half: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := poly.size()
	# Fan-triangulated from vertex 0, which is only valid for a convex
	# polygon - true of every chunk here, since cutting a convex polygon with
	# a straight line always leaves two convex pieces.
	for i in range(1, n - 1):
		for j in [0, i, i + 1]:
			st.set_normal(Vector3.UP)
			st.set_uv(_uv(uv_src[j], half))
			st.add_vertex(Vector3(poly[j].x, 0.0, poly[j].y))
		for j in [0, i + 1, i]:
			st.set_normal(Vector3.DOWN)
			st.set_uv(_uv(uv_src[j], half))
			st.add_vertex(Vector3(poly[j].x, -thickness, poly[j].y))
	return st.commit()

# The untextured side walls of one chunk - the exposed break surface, drawn
# with BROKEN_EDGE_COLOR instead of the plate's texture.
static func _build_edge_mesh(poly: PackedVector2Array, thickness: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := poly.size()
	for i in n:
		_add_wall_quad(st, poly[i], poly[(i + 1) % n], thickness)
	return st.commit()

static func _add_wall_quad(st: SurfaceTool, a: Vector2, b: Vector2, thickness: float) -> void:
	# The wall's outward normal, found from its midpoint relative to the
	# chunk's own centroid (the mesh's local origin) rather than from vertex
	# winding, for the same reason _build_cap_mesh() sets normals by hand.
	var mid := (a + b) * 0.5
	var n2 := mid.normalized() if mid.length() > 0.001 else Vector2.RIGHT
	var normal := Vector3(n2.x, 0.0, n2.y)
	var a_top := Vector3(a.x, 0.0, a.y)
	var b_top := Vector3(b.x, 0.0, b.y)
	var a_bot := Vector3(a.x, -thickness, a.y)
	var b_bot := Vector3(b.x, -thickness, b.y)
	for v in [a_top, b_top, a_bot, b_top, b_bot, a_bot]:
		st.set_normal(normal)
		st.add_vertex(v)

# Maps a tile-footprint-space point (+/-half on each axis) onto the plate
# texture's 0..1 UV range, assuming it is stretched flat across the footprint
# - true of the simple stone photos this project uses.
static func _uv(p: Vector2, half: float) -> Vector2:
	return Vector2(p.x / (half * 2.0) + 0.5, p.y / (half * 2.0) + 0.5)

static func _get_broken_material() -> StandardMaterial3D:
	if _broken_material != null:
		return _broken_material
	var material := StandardMaterial3D.new()
	material.albedo_color = BROKEN_EDGE_COLOR
	material.roughness = 1.0
	material.metallic = 0.0
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_broken_material = material
	return material

# A small burst of dust motes puffing up from the crack and fading out, to
# sell "crumbling masonry" alongside the crack sound effect.
func _spawn_dust(parent: Node, tile_origin: Vector3) -> void:
	if _dust_mesh == null:
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE * 0.09
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		material.albedo_color = DUST_COLOR
		quad.material = material
		_dust_mesh = quad
	var particles := GPUParticles3D.new()
	particles.amount = DUST_COUNT
	particles.lifetime = DUST_LIFETIME
	particles.one_shot = true
	particles.explosiveness = 0.85
	particles.draw_pass_1 = _dust_mesh
	var process_material := ParticleProcessMaterial.new()
	process_material.direction = Vector3.UP
	process_material.spread = 60.0
	process_material.initial_velocity_min = _plate_size * 0.3
	process_material.initial_velocity_max = _plate_size * 0.9
	process_material.gravity = Vector3(0.0, -1.2, 0.0)
	process_material.scale_min = 0.5
	process_material.scale_max = 1.4
	particles.process_material = process_material
	particles.position = tile_origin
	parent.add_child(particles)
	particles.emitting = true
	particles.get_tree().create_timer(DUST_LIFETIME + CRACK_DURATION + 0.1).timeout.connect(particles.queue_free)

static func _ease_out_back(x: float) -> float:
	const C1 := 1.70158
	const C3 := C1 + 1.0
	var y := x - 1.0
	return 1.0 + C3 * y * y * y + C1 * y * y

# A stable pseudo-random offset per square, so the board looks irregular while
# every plate keeps the same character for the whole match (and looks the same
# to both players online) instead of being reshuffled whenever it respawns.
static func _phase(square: Vector2i, salt: float) -> float:
	return fposmod(sin(square.x * 12.9898 + square.y * 78.233 + salt) * 43758.5453, TAU)

# One-time setup of the viewport the board renders into. Call from _ready().
static func setup_board(viewport: SubViewport, board_root: Node3D) -> void:
	Viewport3D.setup(viewport)
	_add_lighting(board_root)

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
	# The key light is the board's only shadow caster. Plates are coplanar, so
	# they cannot shadow each other in any way that shows; what does show is a
	# piece standing a tile tall, whose shadow now falls across its square.
	key.shadow_enabled = true
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key.shadow_bias = 0.04
	key.shadow_normal_bias = 1.0
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
	# The key light's shadow window has to cover the whole board including the
	# camera's slant across it, or pieces on the far edge would lose their
	# shadow; it scales with the board so a 10x10 still fits.
	var key := board_root.get_node_or_null(KEY_LIGHT) as DirectionalLight3D
	if key != null:
		key.directional_shadow_max_distance = maxf(half_span, 1.0) * 6.0

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
