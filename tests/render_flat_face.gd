extends SceneTree
var failures := 0
func _init():
    call_deferred("run")
func run():
    for size in [32, 34, 46, 62, 80, 118, 160]:
        var fill = Image.create(size, size, false, Image.FORMAT_RGBAF)
        fill.fill(Color(0.6, 0.4, 0.2, 1))
        var geometry = Image.create(size, size, false, Image.FORMAT_RGBAF)
        for y in size:
            for x in size:
                geometry.set_pixel(x, y, Color(0.5, 0.5, 0.05 + 0.9 * float(x + y) / float(2 * size), 1))
        var viewport = SubViewport.new()
        viewport.size = Vector2i(size, size)
        viewport.disable_3d = true
        viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
        root.add_child(viewport)
        var rect = TextureRect.new()
        rect.size = Vector2(size, size)
        rect.texture = ImageTexture.create_from_image(fill)
        var material = ShaderMaterial.new()
        material.shader = load("res://shaders/piece_outline_composite.gdshader")
        material.set_shader_parameter("source_texture", rect.texture)
        material.set_shader_parameter("horizontal_mask", rect.texture)
        material.set_shader_parameter("geometry_texture", ImageTexture.create_from_image(geometry))
        material.set_shader_parameter("internal_edge_opacity", 0.5)
        rect.material = material
        viewport.add_child(rect)
        for i in 4:
            await process_frame
        await RenderingServer.frame_post_draw
        var actual = viewport.get_texture().get_image()
        material.set_shader_parameter("internal_edge_opacity", 0.0)
        for i in 4:
            await process_frame
        await RenderingServer.frame_post_draw
        var expected = viewport.get_texture().get_image()
        var dark := 0
        for y in range(2, size - 2):
            for x in range(2, size - 2):
                if actual.get_pixel(x, y).r < expected.get_pixel(x, y).r - 0.01:
                    dark += 1
        print("Flat face %d: %d false shadow pixels" % [size, dark])
        if dark > 0:
            failures += 1
        # A real normal discontinuity must still produce a contour.
        for y in size:
            for x in range(size / 2, size):
                var value = geometry.get_pixel(x, y)
                value.r = 0.9
                geometry.set_pixel(x, y, value)
        material.set_shader_parameter("geometry_texture", ImageTexture.create_from_image(geometry))
        material.set_shader_parameter("internal_edge_opacity", 0.5)
        for i in 4:
            await process_frame
        await RenderingServer.frame_post_draw
        var creased = viewport.get_texture().get_image()
        var edge_pixels := 0
        for y in range(2, size - 2):
            for x in range(size / 2 - 1, size / 2 + 1):
                if creased.get_pixel(x, y).r < expected.get_pixel(x, y).r - 0.01:
                    edge_pixels += 1
        if edge_pixels == 0:
            failures += 1
            push_error("Real creases must retain their contours")
        viewport.queue_free()
        await process_frame
    print("Flat face checks: %d failures" % failures)
    quit(1 if failures else 0)
