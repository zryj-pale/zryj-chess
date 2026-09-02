extends Node2D

# The animated background. The three artwork layers used to be Sprite2Ds slid
# around a flat canvas by an AnimationPlayer; each one now sits on the surface
# of its own sphere - a curved sheet bulging toward the player - and drifts by
# turning about that sphere's centre. What the layers do is unchanged: they
# move independently at their own speeds. They just do it on a curve now, so
# the artwork swells slightly toward the middle of the screen and falls away
# at the edges.
#
# The camera is deliberately OUTSIDE the spheres. Sitting at the centre of one
# would show no curvature at all - every point of the surface would be exactly
# the same distance away, which projects perfectly flat. The bulge exists only
# because the near pole is closer to the camera than the rim is.
#
# Each layer is a spherical CAP rather than a whole sphere. A full sphere has
# to be textured either equirectangularly, which puts a seam down one meridian
# and pinches everything at the poles, or triplanarly, which on a sphere lays
# down three projections that meet along hard rectangular edges - both were
# tried and both were plainly visible on artwork made of big soft blobs. A cap
# takes flat UVs, so the artwork lands on it exactly as drawn.
#
# Public interface is unchanged: instantiate, add_child, set z_index, and call
# set_match_tint(). Both the menu and the match scene use it that way.

const LAYER_TEXTURES := [
	preload("res://assets/ekran poczatkowy/warstwa3.png"), # furthest back
	preload("res://assets/ekran poczatkowy/warstwa1.png"),
	preload("res://assets/ekran poczatkowy/warstwa2.png"), # nearest the player
]

# Per layer, back to front.
#
# `radius` is the sphere the sheet is cut from and `distance` how far its near
# pole sits in front of the camera. Between them they set how much curve shows:
# what matters is the RATIO - a sheet whose radius dwarfs its distance reads
# nearly flat, and bringing it closer relative to its radius bows it harder.
# `half_angle` is how much of the sphere the sheet spans, which has to stay
# comfortably wider than the roughly 16 degrees the camera can actually see of
# it, or an edge swings into frame as the layer drifts.
# `sway` is the drift amplitude in radians and `rate` how fast it runs.
#
# `apex` is where that sphere's near pole sits on screen, in -1..1 from the
# middle. Each layer gets its own spot so the three bulges peak in three
# different places instead of stacking on the camera's axis - which is what
# makes it read as three separate spheres rather than one surface. Moving a
# pole off centre costs cap: the far side of the frame is then further round
# the sphere, so `half_angle` has to grow with the offset.
const LAYERS := [
	{"radius": 60.0, "distance": 16.0, "half_angle": 27.0, "alpha": 0.56,
		"apex": Vector2(-0.42, 0.26), "sway": Vector2(0.055, 0.040), "rate": Vector2(0.041, 0.029)},
	{"radius": 26.0, "distance": 8.5, "half_angle": 38.0, "alpha": 1.0,
		"apex": Vector2(0.48, -0.40), "sway": Vector2(0.095, 0.070), "rate": Vector2(0.063, 0.047)},
	{"radius": 15.0, "distance": 4.0, "half_angle": 32.0, "alpha": 1.0,
		"apex": Vector2(-0.30, -0.52), "sway": Vector2(0.120, 0.090), "rate": Vector2(0.089, 0.071)},
]
# Board plates drifting across the frame, in front of all three sheets. Off by
# default: the match scene uses this same background behind a board made of
# these very plates, and a second set floating over it would only confuse what
# is playable. The menu switches them on.
const TILE_COUNT := 20
# Deep enough to sit AMONG the sheets rather than in front of them: the front
# sheet's pole is 4.0 away and the middle one 8.5, so plates in this range pass
# behind the first and in front of the second. That is what puts them in the
# background instead of over it - and it works because the sheets test depth
# without writing it, so a solid plate simply occludes the ones behind it.
const TILE_DEPTH := Vector2(10.0, 21.0)
const TILE_SIZE := Vector2(0.6, 0.95)
const TILE_DRIFT := Vector2(0.04, 0.18) # units per second
const TILE_SPIN := Vector2(0.02, 0.09) # radians per second, about each plate own axis
const TILE_MARGIN := 0.8 # how far past the edge a plate goes before it wraps
const TILE_OVERFLOW := 1.15 # start positions reach a little past the frame
# Placed one per cell of this grid rather than at free random. Fourteen
# independent draws clump badly - the first attempt put nearly all of them in
# one corner - and a plate that has drifted away leaves its cell empty anyway.
const TILE_GRID := Vector2i(5, 4)
# The plates borrow BoardTile's lighting rig, but that rig is tuned for a board
# a few units across sitting right under the camera. Out here the field is
# twenty units deep, so the lamp is hung to match and every light is turned up:
# left at board strength the plates fall outside the lamp entirely and go
# flat. Only the LIGHTS are touched - BoardTile caches its materials
# statically and shares them with the real board, so those are off limits.
const TILE_KEY_ENERGY := 0.85
const TILE_FILL_ENERGY := 0.30
const TILE_LAMP_ENERGY := 2.4
const TILE_LAMP_SPAN := 13.0

# The middle layer breathes: it brightens and dims again, endlessly.
#
# It used to be a SAWTOOTH - a fifty-second ramp that snapped back to zero -
# which is what made the background jump to its opening state every time
# round. A cosine covers the same range and never jumps, so there is no seam
# to see.
#
# MAX is a deliberate blow-out. Past about 1.9 a typical nickname colour has
# every channel over 1 and the peak of the breath is white; at 50 it is white
# for a good stretch either side of the peak too. That is the look that was
# wanted - the smooth rise and fall is what the cosine is for, not a limit on
# how bright it gets.
#
# MIN is the lever for how dark the background FEELS, because it is where the
# breath spends half its time. Raise it if the dim end is the problem; raising
# MAX does nothing for it.
const PULSE_LAYER := 1
const PULSE_PERIOD := 46.0 # seconds for a full brighten-and-dim
const PULSE_MIN := 0.35
const PULSE_MAX := 50.0
const PULSE_FLUTTER := 2.0 # the faster alpha breathing, radians per second
const FOV := 45.0
const CAP_SEGMENTS := 40 # enough that the bulge is smooth rather than faceted
const TEXTURE_ASPECT := 16.0 / 9.0

var target_tint := Color.WHITE
var tint := Color.WHITE
var container: SubViewportContainer
var viewport: SubViewport
var sheets: Array[MeshInstance3D] = []
var materials: Array[StandardMaterial3D] = []
var _time := 0.0
# Set between instantiate() and add_child() to get the drifting plates.
var floating_tiles := false
var _tiles: Array = [] # {holder, velocity, spin}
var _tile_root: Node3D

func _ready() -> void:
	_build()
	# BEFORE the plates are placed, not after. _visible_half() reads the
	# viewport's aspect, and until the container has been fitted the viewport
	# is still at its default square size - which laid the plates out in a
	# square field, so they covered the full height but only the middle half of
	# the width.
	_fit_to_viewport()
	if floating_tiles:
		_build_tiles()
	get_viewport().size_changed.connect(_fit_to_viewport)

func _build() -> void:
	container = SubViewportContainer.new()
	container.name = "BackgroundViewportContainer"
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)

	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.handle_input_locally = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	Viewport3D.setup(viewport)

	var camera := Camera3D.new()
	camera.fov = FOV
	camera.current = true
	camera.far = 200.0
	viewport.add_child(camera)

	for i in range(LAYERS.size()):
		var layer: Dictionary = LAYERS[i]
		var radius: float = layer["radius"]
		var node := MeshInstance3D.new()
		node.mesh = _build_cap(radius, deg_to_rad(float(layer["half_angle"])))
		var material := _build_material(i, layer)
		node.material_override = material
		materials.append(material)
		# The mesh is built around the sphere's centre, so the node's origin IS
		# that centre - which is what lets the drift below be a plain rotation
		# and still slide the sheet along the sphere's surface. Sliding the
		# centre sideways carries the near pole with it, which is how each
		# layer's bulge ends up somewhere different on screen.
		var distance: float = layer["distance"]
		var apex: Vector2 = layer["apex"]
		var tan_v := tan(deg_to_rad(FOV) * 0.5)
		node.position = Vector3(
			apex.x * distance * tan_v * TEXTURE_ASPECT,
			apex.y * distance * tan_v,
			-(radius + distance))
		viewport.add_child(node)
		sheets.append(node)

# Real BoardTiles, so the plates drifting past are the same object the board is
# made of rather than a lookalike. Each one hangs inside a holder: BoardTile
# overwrites its own rotation every frame for its levitation, so the holder is
# what carries the turn that stands the plate up to face the camera, the slow
# spin, and the drift - leaving the plate free to keep bobbing inside it.
func _build_tiles() -> void:
	_tile_root = Node3D.new()
	_tile_root.name = "FloatingTiles"
	viewport.add_child(_tile_root)
	BoardTile.setup_board(viewport, _tile_root)
	BoardTile.focus_lighting(_tile_root, Vector3(0.0, 0.0, -(TILE_DEPTH.x + TILE_DEPTH.y) * 0.5), TILE_LAMP_SPAN)
	_boost_tile_lighting()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260902 # fixed, so the scatter is the same every launch
	var cells := range(TILE_GRID.x * TILE_GRID.y)
	cells.shuffle() # so consecutive plates are not neighbours in the grid
	for i in range(TILE_COUNT):
		var cell: int = cells[i]
		var depth := rng.randf_range(TILE_DEPTH.x, TILE_DEPTH.y)
		var half := _visible_half(depth)
		# One plate per grid cell, jittered inside it. Spread is measured across
		# the SCREEN, not in world units, so plates at different depths still
		# come out evenly distributed in frame.
		# Spread slightly past the frame, so some plates start half out of it
		# rather than every one sitting neatly inside the edges.
		var u := ((float(cell % TILE_GRID.x) + rng.randf()) / float(TILE_GRID.x) * 2.0 - 1.0) * TILE_OVERFLOW
		var v := ((float(cell / TILE_GRID.x) + rng.randf()) / float(TILE_GRID.y) * 2.0 - 1.0) * TILE_OVERFLOW
		var holder := Node3D.new()
		holder.position = Vector3(u * half.x, v * half.y, -depth)
		# Fully random orientation. Standing every plate square to the camera
		# made a row of identical rectangles; tumbled, they catch the light
		# differently and some pass edge-on, which is what sells them as
		# objects rather than cards.
		holder.rotation = Vector3(rng.randf_range(0.0, TAU), rng.randf_range(0.0, TAU), rng.randf_range(0.0, TAU))
		var tile := BoardTile.create(Vector2i(i, 0), Vector3.ZERO, rng.randf_range(TILE_SIZE.x, TILE_SIZE.y), i % 2 == 0)
		holder.add_child(tile)
		_tile_root.add_child(holder)
		var speed := rng.randf_range(TILE_DRIFT.x, TILE_DRIFT.y)
		var angle := rng.randf_range(0.0, TAU)
		_tiles.append({
			"holder": holder,
			"velocity": Vector2(cos(angle), sin(angle)) * speed,
			# A fixed random axis rather than per-axis Euler rates: turning about
			# one axis stays a steady tumble instead of wandering into gimbal.
			"axis": Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)).normalized(),
			"spin": rng.randf_range(TILE_SPIN.x, TILE_SPIN.y) * (1.0 if rng.randf() < 0.5 else -1.0),
		})

# The lamp's falloff is what makes one plate brighter than another as they
# drift, so it is worth having reach out here rather than dying a few units
# from the camera.
func _boost_tile_lighting() -> void:
	var key := _tile_root.get_node_or_null(BoardTile.KEY_LIGHT) as DirectionalLight3D
	if key != null:
		key.light_energy = TILE_KEY_ENERGY
	var fill := _tile_root.get_node_or_null(BoardTile.FILL_LIGHT) as DirectionalLight3D
	if fill != null:
		fill.light_energy = TILE_FILL_ENERGY
	var lamp := _tile_root.get_node_or_null(BoardTile.LAMP) as OmniLight3D
	if lamp != null:
		lamp.light_energy = TILE_LAMP_ENERGY

# Half the world extent the camera can see at `depth` in front of it.
func _visible_half(depth: float) -> Vector2:
	var tan_v := tan(deg_to_rad(FOV) * 0.5)
	var aspect := TEXTURE_ASPECT
	if viewport != null and viewport.size.y > 0:
		aspect = float(viewport.size.x) / float(viewport.size.y)
	return Vector2(depth * tan_v * aspect, depth * tan_v)

# A rectangle of sphere: a grid of vertices pushed out to `radius`, spanning
# `half_angle` either side of the +Z pole horizontally and proportionally less
# vertically so the 16:9 artwork keeps its shape. UVs are the plain grid
# coordinates, so the texture lands undistorted at the middle and compresses
# toward the rim exactly as the curve carries it away.
func _build_cap(radius: float, half_angle: float) -> ArrayMesh:
	var half_x := half_angle
	var half_y := half_angle / TEXTURE_ASPECT
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for row in range(CAP_SEGMENTS + 1):
		var v := float(row) / float(CAP_SEGMENTS)
		var ay := lerpf(-half_y, half_y, v)
		for col in range(CAP_SEGMENTS + 1):
			var u := float(col) / float(CAP_SEGMENTS)
			var ax := lerpf(-half_x, half_x, u)
			vertices.append(Vector3(sin(ax) * cos(ay), sin(ay), cos(ax) * cos(ay)) * radius)
			uvs.append(Vector2(u, 1.0 - v))
	var stride := CAP_SEGMENTS + 1
	for row in range(CAP_SEGMENTS):
		for col in range(CAP_SEGMENTS):
			var a := row * stride + col
			var b := a + 1
			var c := a + stride
			var d := c + 1
			indices.append_array([a, c, b, b, c, d])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _build_material(index: int, layer: Dictionary) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = LAYER_TEXTURES[index]
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Single-sided sheets with no lighting, so which way the triangles wind is
	# neither here nor there - and not caring about it removes a whole class of
	# way for the background to come out invisible.
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	# The layers overlap almost completely, so distance sorting cannot be
	# trusted to keep them in order; render_priority fixes it, back to front.
	# Depth TESTING stays on, though - these are transparent and so write no
	# depth of their own, which leaves priority in charge of their mutual
	# order, while still letting solid things in front of them (the drifting
	# plates) occlude them properly.
	material.render_priority = index - 1
	material.albedo_color = Color(1.0, 1.0, 1.0, float(layer["alpha"]))
	return material

# The 2D world is authored against a fixed base size and scaled up to the
# window, so a SubViewport sized in those units renders at a fraction of the
# real resolution - see Viewport3D.fit_to_pixels().
func _fit_to_viewport() -> void:
	Viewport3D.fit_to_pixels(container, Rect2(Vector2.ZERO, get_viewport_rect().size))

func _process(delta: float) -> void:
	_time += delta
	tint = tint.lerp(target_tint, minf(delta * 3.0, 1.0))
	# The old flat layers kept this: a long, slow ramp that drives the middle
	# layer far past white before snapping back, with the alpha breathing under
	# it. Values above 1 blow out the same way they did as a 2D modulate.
	if not _tiles.is_empty():
		_drift_tiles(delta)
	for i in range(sheets.size()):
		var layer: Dictionary = LAYERS[i]
		var sway: Vector2 = layer["sway"]
		var rate: Vector2 = layer["rate"]
		# Turning the sheet about its sphere's centre slides it ALONG the
		# surface, which is the drift; the rates are mutually irrational-ish so
		# the three layers never fall into step.
		sheets[i].rotation = Vector3(
			sin(_time * rate.y) * sway.y,
			sin(_time * rate.x) * sway.x,
			0.0)
		var alpha: float = layer["alpha"]
		var brightness := 1.0
		if i == PULSE_LAYER:
			brightness = lerpf(PULSE_MIN, PULSE_MAX, 0.5 - 0.5 * cos(TAU * _time / PULSE_PERIOD))
			alpha = 0.8 + sin(_time * PULSE_FLUTTER) * 0.2
		materials[i].albedo_color = Color(tint.r * brightness, tint.g * brightness, tint.b * brightness, alpha)

# Plates leaving one side come back on the other, so the drift never runs out.
func _drift_tiles(delta: float) -> void:
	for entry in _tiles:
		var holder: Node3D = entry["holder"]
		var velocity: Vector2 = entry["velocity"]
		holder.position += Vector3(velocity.x, velocity.y, 0.0) * delta
		holder.rotate(entry["axis"], float(entry["spin"]) * delta)
		var limit := _visible_half(absf(holder.position.z)) + Vector2.ONE * TILE_MARGIN
		if absf(holder.position.x) > limit.x:
			holder.position.x = -sign(holder.position.x) * limit.x
		if absf(holder.position.y) > limit.y:
			holder.position.y = -sign(holder.position.y) * limit.y

func set_match_tint(value: Color) -> void:
	target_tint = value
	# The plates are lit rather than flat, so they take the colour through
	# their lighting the same way the board does.
	if _tile_root != null:
		BoardTile.tint_lighting(_tile_root, value)
