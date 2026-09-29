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
		check(sprite.capture.size == Vector2i(160, 160), "Model and outline must be rendered before pixelisation")
		check(sprite.geometry_capture != null and sprite.geometry_capture.size == Vector2i(160, 160), "Internal edges need a matching normal/depth capture")
		check(sprite.geometry_capture.use_hdr_2d, "Geometry data must stay linear and retain floating-point depth precision")
		check(sprite.outline_horizontal != null and sprite.outline_composite != null, "The capture must contain both continuous outline passes")
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
			var uv: Vector2 = sprite.capture_camera.unproject_position(corner) / float(sprite.SOURCE_SCALE)
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
	# Inspect the ears and underside from a full orbit, including shallow views.
	var orbit := Image.create(6 * 80, 4 * 80, false, Image.FORMAT_RGBA8)
	orbit.fill(Color(0.65, 0.65, 0.65))
	for elevation in 2:
		for angle in 12:
			var target: Vector3 = pieces[0].global_position
			var yaw := float(angle) * TAU / 12.0
			camera.position = target + Vector3(sin(yaw) * 4.0, 2.0 if elevation == 0 else 4.0, cos(yaw) * 4.0)
			camera.look_at(target)
			await frames()
			var sprite = pieces[0]._model_sprite
			var image: Image = sprite.texture.get_image()
			var occupied := image.get_used_rect()
			check(occupied.has_area(), "Orbit capture must show the knight")
			check(occupied.position.x > 0 and occupied.position.y > 0 and occupied.end.x < 80 and occupied.end.y < 80, "Orbit outline must fit inside the capture")
			orbit.blend_rect(image, Rect2i(0, 0, 80, 80), Vector2i((angle % 6) * 80, (elevation * 2 + angle / 6) * 80))
	orbit.resize(960, 640, Image.INTERPOLATE_NEAREST)
	orbit.save_png("res://.godot/sprite_80_orbit.png")
	# Small tile motion used to move pre-rendered ink between nearest samples.
	var motion := Image.create(6 * 80, 2 * 80, false, Image.FORMAT_RGBA8)
	motion.fill(Color(0.65, 0.65, 0.65))
	camera.position = Vector3(0, 4, 3)
	camera.look_at(Vector3.ZERO)
	for phase in 12:
		var time := float(phase) * TAU / 12.0
		for piece in pieces:
			piece.ustaw_lewitacje(Vector3(0.009 * sin(time), 0.022 * cos(time), -0.009 * sin(time)), Basis.from_euler(Vector3(0.06 * sin(time), 0.02 * cos(time), -0.04 * sin(time))))
		await frames()
		for piece in pieces:
			check_ink_survives(piece._model_sprite)
		motion.blend_rect(pieces[0]._model_sprite.texture.get_image(), Rect2i(0, 0, 80, 80), Vector2i((phase % 6) * 80, (phase / 6) * 80))
	motion.resize(960, 320, Image.INTERPOLATE_NEAREST)
	motion.save_png("res://.godot/sprite_80_motion.png")
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

func is_ink(color: Color) -> bool:
	return color.a > 0.5 and maxf(color.r, maxf(color.g, color.b)) < 0.001

func check_ink_survives(sprite: Sprite3D) -> void:
	var source: Image = sprite.outline_composite.get_texture().get_image()
	var reduced: Image = sprite.texture.get_image()
	var lost := 0
	var changed_fill := 0
	for y in 80:
		for x in 80:
			var ink := false
			for dy in 2:
				for dx in 2:
					ink = ink or is_ink(source.get_pixel(x * 2 + dx, y * 2 + dy))
			if ink and not is_ink(reduced.get_pixel(x, y)):
				lost += 1
			if not ink:
				var expected := source.get_pixel(x * 2 + 1, y * 2 + 1)
				var actual := reduced.get_pixel(x, y)
				if absf(expected.a - actual.a) > 0.005 or (expected.a > 0.5 and (absf(expected.r - actual.r) > 0.005 or absf(expected.g - actual.g) > 0.005 or absf(expected.b - actual.b) > 0.005)):
					changed_fill += 1
	check(lost == 0, "Pixel reduction dropped %d ink pixels during tile motion" % lost)
	check(changed_fill == 0, "Non-ink pixels must retain nearest colour and transparency")

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
