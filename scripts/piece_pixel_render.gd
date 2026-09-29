extends Sprite3D

# Crop the real perspective view of a model to a 80x80 render target. The
# source model stays oriented to its tile, never rotated to face the camera.
const RESOLUTION := 80
const FRAME_MARGIN := 1.08
const FACE_SHADING := preload("res://scripts/piece_face_shading.gd")

var capture: SubViewport
var capture_camera: Camera3D
var _corners: Array[Vector3] = []
var _view_transform := Transform3D.IDENTITY
var _has_frame := false

func configure(model: Node3D) -> void:
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	shaded = false
	alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	capture = SubViewport.new()
	capture.name = "Capture80"
	capture.size = Vector2i(RESOLUTION, RESOLUTION)
	capture.own_world_3d = true
	capture.transparent_bg = true
	capture.handle_input_locally = false
	capture.render_target_update_mode = SubViewport.UPDATE_DISABLED
	capture.msaa_3d = Viewport.MSAA_DISABLED
	add_child(capture)
	_copy_meshes(model, model.get_parent() as Node3D)
	capture_camera = Camera3D.new()
	capture_camera.near = 0.01
	capture.add_child(capture_camera)
	capture_camera.current = true
	# Face brightness is baked into the mesh; no live lights or shadow maps.
	texture = capture.get_texture()
	refresh_view()

func _copy_meshes(node: Node, origin: Node3D) -> void:
	if node is MeshInstance3D:
		var source := node as MeshInstance3D
		if source.mesh != null:
			var copy := MeshInstance3D.new()
			copy.transform = origin.global_transform.affine_inverse() * source.global_transform
			copy.mesh = FACE_SHADING.bake(source, copy.basis)
			capture.add_child(copy)
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
	for corner in _corners:
		var point := inverse * corner
		if point.z >= -near_plane:
			visible = false
			_has_frame = false
			return
		var projected := Vector2(point.x, point.y) * near_plane / -point.z
		closest_depth = minf(closest_depth, -point.z)
		low = low.min(projected)
		high = high.max(projected)
	visible = true
	var extent := high - low
	var frame_size := maxf(maxf(extent.x, extent.y) * FRAME_MARGIN, 0.00001)
	var center := (low + high) * 0.5
	capture_camera.transform = view_transform
	capture_camera.set_frustum(frame_size, center, near_plane, board_camera.far)
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
	# but every new frame still uses exactly 80x80 pixels and nearest sampling.
	capture.render_target_update_mode = SubViewport.UPDATE_ONCE
