shader_type canvas_item;
render_mode unshaded;

// Ink is already drawn at 160x160. Preserve it across the entire 2x2
// footprint instead of throwing away three samples during pixelisation.
// All other colours retain nearest sampling; no blur or temporal trails.
uniform sampler2D source_texture : source_color, filter_nearest, repeat_disable;

void fragment() {
	vec2 source_size = vec2(textureSize(source_texture, 0));
	vec2 origin = floor(UV * source_size / 2.0) * 2.0;
	// Address the texel centre explicitly; the scaled UV lies on a texel
	// boundary and floating-point rounding can otherwise flip the choice.
	vec4 result = textureLod(source_texture, (origin + 1.5) / source_size, 0.0);
	float ink = 0.0;
	for (int y = 0; y < 2; y++) {
		for (int x = 0; x < 2; x++) {
			vec2 uv = (origin + vec2(float(x), float(y)) + 0.5) / source_size;
			vec4 sample_color = textureLod(source_texture, uv, 0.0);
			if (sample_color.a > 0.5 && max(sample_color.r, max(sample_color.g, sample_color.b)) < 0.001) {
				ink = 1.0;
			}
		}
	}
	COLOR = mix(result, vec4(0.0, 0.0, 0.0, 1.0), ink);
}
