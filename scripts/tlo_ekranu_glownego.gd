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
const PULSE_LAYER := 1 # the middle layer keeps the old brightness ramp
const FOV := 45.0
const CAP_SEGMENTS := 40 # enough that the bulge is smooth rather than faceted
const TEXTURE_ASPECT := 16.0 / 9.0

var target_tint := Color.WHITE
var tint := Color.WHITE
var container: SubViewportContainer
var viewport: SubViewport
var sheets: Array[MeshInstance3D] = []
var materials: Array[StandardMaterial3D] = []
var przez := 100.0
var _time := 0.0

func _ready() -> void:
	_build()
	_fit_to_viewport()
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
	# The layers overlap almost completely and their bounding boxes all sit on
	# the camera's axis, so distance sorting cannot be trusted to keep them in
	# order. Fixed order instead, back to front, with depth testing out of the
	# way.
	material.no_depth_test = true
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
	przez += 2.0 * delta
	if przez > 100.0:
		przez = 0.0
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
			brightness = przez
			alpha = 0.8 + sin(przez) / 5.0
		materials[i].albedo_color = Color(tint.r * brightness, tint.g * brightness, tint.b * brightness, alpha)

func set_match_tint(value: Color) -> void:
	target_tint = value
