shader_type canvas_item;
render_mode unshaded;

// First half of a separable alpha dilation.  Keeping this as a short
// horizontal pass makes a solid outline much cheaper than sampling a whole
// square around every pixel in one shader.
uniform sampler2D source_texture : source_color, filter_nearest;
uniform int radius : hint_range(1, 8) = 5;

void fragment() {
	float mask = 0.0;
	for (int x = -8; x <= 8; x++) {
		if (abs(x) <= radius) {
			mask = max(mask, textureLod(source_texture, UV + vec2(float(x), 0.0) * TEXTURE_PIXEL_SIZE, 0.0).a);
		}
	}
	COLOR = vec4(0.0, 0.0, 0.0, mask);
}
