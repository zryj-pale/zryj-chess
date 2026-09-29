extends SceneTree

# GPU regression check: run with --script res://tests/render_piece_pixels.gd.
# Captures are saved under .godot/ for visual inspection; no profile is changed.
const PIECE = preload("res://scenes/figura.tscn")
var failures := 0

func _init() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func frames() -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw

func run() -> void:
	var board := SubViewport.new()
	board.size = Vector2i(800, 600)
	board.own_world_3d = true
	board.transparent_bg = true
	board.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(board)
	var camera := Camera3D.new()
	board.add_child(camera)
	camera.position = Vector3(0, 4, 3)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	var pieces: Array = []
	for color in ["b", "c"]:
		var piece = PIECE.instantiate()
		piece.typ = "S"
		piece.kolor = color
		board.add_child(piece)
		piece.position = Vector3(-0.7 if color == "b" else 0.7, 0.5, 0)
		check_base_center(piece)
		pieces.append(piece)
	await frames()
	for piece in pieces:
		var sprite = piece._model_sprite
		var image: Image = sprite.texture.get_image()
		check(image.get_size() == Vector2i(80, 80), "Capture must be exactly 80x80")
		var occupied := image.get_used_rect()
		check(occupied.has_area(), "Model capture must not be transparent/empty")
		check(occupied.position.x > 0 and occupied.position.y > 0 and occupied.end.x < 80 and occupied.end.y < 80, "Model must fit inside the capture")
		image.save_png("res://.godot/sprite_80_%s.png" % piece.kolor)
		var original := image.get_data()
		await frames()
		check(sprite.texture.get_image().get_data() == original, "A stationary model must have stable pixels")
		# Even forced rerendering under a bright coloured light must not change
		# baked face shading. This catches accidentally restoring live lighting.
		var probe_light := DirectionalLight3D.new()
		probe_light.light_energy = 16.0
		probe_light.light_color = Color(1, 0, 0)
		probe_light.rotation_degrees = Vector3(20, 140, 0)
		sprite.capture.add_child(probe_light)
		sprite.capture.render_target_update_mode = SubViewport.UPDATE_ONCE
		await frames()
		check(sprite.texture.get_image().get_data() == original, "Face shading must ignore live light direction, colour and intensity")
		probe_light.queue_free()
		piece.position += Vector3(0.8, 0, 0.8)
		piece.ustaw_lewitacje(Vector3(0.009, 0.022, -0.009))
		await frames()
		check(sprite.texture.get_image().get_data() != original, "Moving to another tile must update the perspective")
		original = sprite.texture.get_image().get_data()
		board.size = Vector2i(1200, 700)
		await frames()
		check(sprite.texture.get_image().get_data() == original, "Window resize must preserve every texel")
		piece.modulate = Color(0.55, 0.55, 0.55, 0.7)
		check(sprite.modulate == piece.modulate, "Creator preview tint and alpha must reach the sprite")
		piece.modulate = Color.WHITE
		var tilt := Basis.from_euler(Vector3(0.06, 0.02, -0.04))
		var drift := Vector3(0.009, 0.022, -0.009)
		piece.ustaw_lewitacje(drift, tilt)
		await frames()
		var contents: Node3D = piece.get_node("Zawartosc")
		check(contents.basis.is_equal_approx(tilt), "Model orientation must follow the tile")
		check((contents.transform * Vector3(0, -0.5, 0)).is_equal_approx(drift + Vector3(0, -0.5, 0)), "Foot must remain on the tilted tile")
		for corner in sprite._corners:
			var uv: Vector2 = sprite.capture_camera.unproject_position(corner)
			var plane_point: Vector3 = Vector3(uv.x - 40.0, 40.0 - uv.y, 0) * sprite.pixel_size
			var actual := camera.unproject_position(sprite.to_global(plane_point))
			var expected := camera.unproject_position(contents.to_global(corner))
			check(actual.distance_to(expected) < 0.02, "Pixel image must match real 3D projection, including the foot")
	board.get_texture().get_image().save_png("res://.godot/sprite_80_board.png")
	# Black online view photographs the opposite side, still into 80x80.
	camera.position = Vector3(0, 4, -3)
	camera.look_at(Vector3.ZERO)
	await frames()
	for piece in pieces:
		var image: Image = piece._model_sprite.texture.get_image()
		check(image.get_used_rect().has_area(), "Flipped online camera must show the model")
		image.save_png("res://.godot/sprite_80_flipped_%s.png" % piece.kolor)
		piece.promocja("H")
		check(piece._model_sprite == null, "Changing to a 2D piece must remove the model sprite")
		check(piece.get_node("Zawartosc/tekstura").visible, "Legacy atlas pieces must remain visible")
		piece.promocja("S")
	await frames()
	for piece in pieces:
		check(piece._model_sprite.texture.get_image().get_used_rect().has_area(), "Promotion to knight must create a visible capture")
	board.queue_free()
	await process_frame
	for scene_path in ["res://scenes/ustawianie.tscn", "res://scenes/main.tscn"]:
		var scene: Node = load(scene_path).instantiate()
		root.add_child(scene)
		# Ensure both real scenes render the new sprites, even with an empty profile.
		var scene_board: SubViewport = scene.get_node("BoardViewportContainer/BoardViewport")
		for color in ["b", "c"]:
			var piece = PIECE.instantiate()
			piece.typ = "S"
			piece.kolor = color
			scene.get_node("BoardViewportContainer/BoardViewport/BoardRoot").add_child(piece)
			piece.position = Vector3(3 if color == "b" else 4, 0.5, 4)
		await frames()
		scene_board.get_texture().get_image().save_png("res://.godot/sprite_80_%s.png" % scene_path.get_file().get_basename())
		scene.queue_free()
		await process_frame
	print("Sprite 80 GPU checks: %d failures" % failures)
	quit(1 if failures else 0)

func check_base_center(piece: Node3D) -> void:
	# Check the complete plinth, including its higher opposite edge. Checking
	# only the very lowest vertices missed a 0.28-tile horizontal offset.
	var model: Node3D = piece.model_dla("S", piece.kolor)
	var points: Array[Vector3] = []
	var low := INF
	var high := -INF
	for mesh in piece._siatki(model):
		var relative: Transform3D = piece.global_transform.affine_inverse() * mesh.global_transform
		for surface in mesh.mesh.get_surface_count():
			for vertex in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				var point: Vector3 = relative * vertex
				points.append(point)
				low = minf(low, point.y)
				high = maxf(high, point.y)
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for point in points:
		if point.y < low + (high - low) * 0.1:
			minimum = minimum.min(Vector2(point.x, point.z))
			maximum = maximum.max(Vector2(point.x, point.z))
	check(((minimum + maximum) * 0.5).length() < 0.002, "Whole base must be centered on the tile, not its lowest edge")
	check(absf(low + 0.5) < 0.0001, "Base must touch tile after centering and scaling")
