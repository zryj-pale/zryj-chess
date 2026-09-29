extends Sprite3D

# Crop the real perspective view of a model to a 80x80 render target. The
# source model stays oriented to its tile, never rotated to face the camera.
const RESOLUTION := 80
const SOURCE_SCALE := 2
const SOURCE_RESOLUTION := RESOLUTION * SOURCE_SCALE
const FRAME_MARGIN := 1.08
const FACE_SHADING := preload("res://scripts/piece_face_shading.gd")
const GEOMETRY_DATA_SHADER := preload("res://shaders/piece_geometry_data.gdshader")
const OUTLINE_HORIZONTAL_SHADER := preload("res://shaders/piece_outline_horizontal.gdshader")
const OUTLINE_COMPOSITE_SHADER := preload("res://shaders/piece_outline_composite.gdshader")
const PIXEL_REDUCE_SHADER := preload("res://shaders/piece_pixel_reduce.gdshader")
const OUTLINE_RADIUS := 2 # source pixels; 1 final pixel before ink-preserving reduction
# Experiment: false restores the 9905a15 rendering path without an extra pass.
const TRIANGLE_EDGES_ENABLED := true
const TRIANGLE_EDGE_OPACITY := 0.28
const TRIANGLE_EDGE_WIDTH := 0.4675 # source pixels on each side, before 2x reduction

var capture: SubViewport
var geometry_capture: SubViewport
var triangle_capture: SubViewport
var triangle_camera: Camera3D
var _triangle_material: ShaderMaterial
var outline_horizontal: SubViewport
var outline_composite: SubViewport
var pixel_capture: SubViewport
var capture_camera: Camera3D
var geometry_camera: Camera3D
var _geometry_material: ShaderMaterial
var _corners: Array[Vector3] = []
var _view_transform := Transform3D.IDENTITY
var _has_frame := false

func configure(model: Node3D) -> void:
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	shaded = false
	alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	capture = SubViewport.new()
	capture.name = "ModelCapture160"
	capture.size = Vector2i(SOURCE_RESOLUTION, SOURCE_RESOLUTION)
	capture.own_world_3d = true
	capture.transparent_bg = true
	capture.handle_input_locally = false
	capture.render_target_update_mode = SubViewport.UPDATE_DISABLED
	capture.msaa_3d = Viewport.MSAA_DISABLED
	add_child(capture)
	geometry_capture = SubViewport.new()
	geometry_capture.name = "GeometryCapture160"
	geometry_capture.size = Vector2i(SOURCE_RESOLUTION, SOURCE_RESOLUTION)
	geometry_capture.own_world_3d = true
	geometry_capture.transparent_bg = true
	geometry_capture.handle_input_locally = false
	geometry_capture.render_target_update_mode = SubViewport.UPDATE_DISABLED
	geometry_capture.msaa_3d = Viewport.MSAA_DISABLED
	# Preserve linear floating-point data, without the LDR sRGB conversion.
	geometry_capture.use_hdr_2d = true
	add_child(geometry_capture)
	_geometry_material = ShaderMaterial.new()
	_geometry_material.shader = GEOMETRY_DATA_SHADER
	if TRIANGLE_EDGES_ENABLED:
		triangle_capture = SubViewport.new()
		triangle_capture.name = "TriangleEdges160"
		triangle_capture.size = Vector2i(SOURCE_RESOLUTION, SOURCE_RESOLUTION)
		triangle_capture.own_world_3d = true
		triangle_capture.transparent_bg = true
		triangle_capture.use_hdr_2d = true
		triangle_capture.handle_input_locally = false
		triangle_capture.render_target_update_mode = SubViewport.UPDATE_DISABLED
		add_child(triangle_capture)
		_triangle_material = ShaderMaterial.new()
		_triangle_material.shader = GEOMETRY_DATA_SHADER
		_triangle_material.set_shader_parameter("triangle_edges_only", true)
		_triangle_material.set_shader_parameter("triangle_width", TRIANGLE_EDGE_WIDTH)
		triangle_camera = Camera3D.new()
		triangle_capture.add_child(triangle_camera)
		triangle_camera.current = true
	_copy_meshes(model, model.get_parent() as Node3D)
	capture_camera = Camera3D.new()
	capture_camera.near = 0.01
	capture.add_child(capture_camera)
	capture_camera.current = true
	geometry_camera = Camera3D.new()
	geometry_camera.near = 0.01
	geometry_capture.add_child(geometry_camera)
	geometry_camera.current = true
	# Face brightness is baked into the mesh; no live lights or shadow maps.
	_create_outline_pipeline()
	texture = pixel_capture.get_texture()
	refresh_view()

func _create_outline_pipeline() -> void:
	var horizontal_material := ShaderMaterial.new()
	horizontal_material.shader = OUTLINE_HORIZONTAL_SHADER
	horizontal_material.set_shader_parameter("source_texture", capture.get_texture())
	horizontal_material.set_shader_parameter("radius", OUTLINE_RADIUS)
	outline_horizontal = _canvas_pass("OutlineHorizontal160", SOURCE_RESOLUTION, capture.get_texture(), horizontal_material)

	var composite_material := ShaderMaterial.new()
	composite_material.shader = OUTLINE_COMPOSITE_SHADER
	composite_material.set_shader_parameter("source_texture", capture.get_texture())
	composite_material.set_shader_parameter("horizontal_mask", outline_horizontal.get_texture())
	composite_material.set_shader_parameter("geometry_texture", geometry_capture.get_texture())
	composite_material.set_shader_parameter("radius", OUTLINE_RADIUS)
	composite_material.set_shader_parameter("triangle_edges_enabled", TRIANGLE_EDGES_ENABLED)
	composite_material.set_shader_parameter("triangle_opacity", TRIANGLE_EDGE_OPACITY)
	if triangle_capture != null:
		composite_material.set_shader_parameter("triangle_texture", triangle_capture.get_texture())
	outline_composite = _canvas_pass("OutlineComposite160", SOURCE_RESOLUTION, capture.get_texture(), composite_material)

	# Preserve pre-rendered ink from all four source texels. Pure nearest
	# sampling drops thin lines as the tile bobs between sample positions.
	assert(SOURCE_SCALE == 2, "Ink-preserving reduction expects a 2x2 footprint")
	var reduce_material := ShaderMaterial.new()
	reduce_material.shader = PIXEL_REDUCE_SHADER
	reduce_material.set_shader_parameter("source_texture", outline_composite.get_texture())
	pixel_capture = _canvas_pass("PixelCapture80", RESOLUTION, outline_composite.get_texture(), reduce_material)

func _canvas_pass(pass_name: String, pass_size: int, source: Texture2D, material: Material) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.name = pass_name
	viewport.size = Vector2i(pass_size, pass_size)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.handle_input_locally = false
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	var rect := TextureRect.new()
	rect.size = Vector2(pass_size, pass_size)
	rect.texture = source
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if material != null:
		rect.material = material
	viewport.add_child(rect)
	return viewport

func _copy_meshes(node: Node, origin: Node3D) -> void:
	if node is MeshInstance3D:
		var source := node as MeshInstance3D
		if source.mesh != null:
			var copy := MeshInstance3D.new()
			copy.name = "%sFill" % source.name
			copy.transform = origin.global_transform.affine_inverse() * source.global_transform
			copy.mesh = FACE_SHADING.bake(source, copy.basis)
			copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			capture.add_child(copy)
			var geometry_copy := MeshInstance3D.new()
			geometry_copy.name = "%sGeometry" % source.name
			geometry_copy.transform = copy.transform
			# The fill already has geometric face normals (including smooth imports).
			geometry_copy.mesh = copy.mesh
			geometry_copy.material_override = _geometry_material
			geometry_copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			geometry_capture.add_child(geometry_copy)
			if triangle_capture != null:
				var triangle_copy := MeshInstance3D.new()
				triangle_copy.transform = copy.transform
				triangle_copy.mesh = copy.mesh
				triangle_copy.material_override = _triangle_material
				triangle_copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				triangle_capture.add_child(triangle_copy)
			for corner in 8:
				_corners.append(copy.transform * source.get_aabb().get_endpoint(corner))
	for child in node.get_children():
		_copy_meshes(child, origin)

func _process(_delta: float) -> void:
	refresh_view()

func refresh_view() -> void:
	if capture == null or _corners.is_empty():
		return
	var board_camera := get_viewport().get_camera_3d()
	if board_camera == null:
		return
	var parent := get_parent() as Node3D
	var view_transform := parent.global_transform.affine_inverse() * board_camera.global_transform
	if _has_frame and _view_transform.is_equal_approx(view_transform):
		return
	_view_transform = view_transform
	_has_frame = true
	var inverse := view_transform.affine_inverse()
	var near_plane := 0.01
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	var closest_depth := INF
	var farthest_depth := -INF
	for corner in _corners:
		var point := inverse * corner
		if point.z >= -near_plane:
			visible = false
			_has_frame = false
			return
		var projected := Vector2(point.x, point.y) * near_plane / -point.z
		closest_depth = minf(closest_depth, -point.z)
		farthest_depth = maxf(farthest_depth, -point.z)
		low = low.min(projected)
		high = high.max(projected)
	visible = true
	var extent := high - low
	var frame_size := maxf(maxf(extent.x, extent.y) * FRAME_MARGIN, 0.00001)
	var center := (low + high) * 0.5
	capture_camera.transform = view_transform
	capture_camera.set_frustum(frame_size, center, near_plane, board_camera.far)
	geometry_camera.transform = view_transform
	geometry_camera.set_frustum(frame_size, center, near_plane, board_camera.far)
	if triangle_camera != null:
		triangle_camera.transform = view_transform
		triangle_camera.set_frustum(frame_size, center, near_plane, board_camera.far)
	_geometry_material.set_shader_parameter("depth_origin", closest_depth)
	_geometry_material.set_shader_parameter("depth_span", maxf(farthest_depth - closest_depth, 0.001))
	# Reproject the cropped image onto precisely the same screen rectangle.
	# Unlike the former orthographic photograph, its contents include the real
	# perspective and foreshortening at this tile, including the opposite side
	# when viewed from black's end. The display plane must stay in front of
	# the model's bounds: putting it at the foot's depth cuts the projected
	# base in half against the tile. Perspective reprojection preserves the
	# exact screen-space foot position regardless of this display depth.
	var distance := maxf(near_plane, closest_depth - 0.002)
	var center_at_depth := Vector3(center.x * distance / near_plane, center.y * distance / near_plane, -distance)
	transform = Transform3D(view_transform.basis, view_transform * center_at_depth)
	pixel_size = frame_size * distance / near_plane / float(RESOLUTION)
	# A stationary model/camera reuses the image. Movement changes perspective,
	# but every new frame still ends as exactly 80x80 with preserved ink.
	capture.render_target_update_mode = SubViewport.UPDATE_ONCE
	geometry_capture.render_target_update_mode = SubViewport.UPDATE_ONCE
	if triangle_capture != null:
		triangle_capture.render_target_update_mode = SubViewport.UPDATE_ONCE
	outline_horizontal.render_target_update_mode = SubViewport.UPDATE_ONCE
	outline_composite.render_target_update_mode = SubViewport.UPDATE_ONCE
	pixel_capture.render_target_update_mode = SubViewport.UPDATE_ONCE
