shader_type canvas_item;
render_mode unshaded;

// Finish the vertical half of the dilation, then put the untouched model over
// the black mask.  The result is a continuous, attached outline regardless of
// mesh normals, triangle seams or the viewing angle.
uniform sampler2D source_texture : source_color, filter_nearest;
uniform sampler2D horizontal_mask : filter_nearest;
uniform sampler2D geometry_texture : filter_nearest;
uniform sampler2D triangle_texture : filter_nearest;
uniform bool triangle_edges_enabled = false;
uniform float triangle_opacity : hint_range(0.0, 1.0) = 0.28;
uniform int radius : hint_range(1, 8) = 5;
uniform float normal_threshold : hint_range(0.01, 1.0) = 0.12;
// Fraction of this piece's depth range, not camera distance.
uniform float depth_threshold : hint_range(0.001, 0.2) = 0.015;

vec3 decode_normal(vec2 encoded) {
	vec2 f = encoded * 2.0 - 1.0;
	vec3 normal = vec3(f, 1.0 - abs(f.x) - abs(f.y));
	float fold = clamp(-normal.z, 0.0, 1.0);
	normal.xy += vec2(normal.x >= 0.0 ? -fold : fold, normal.y >= 0.0 ? -fold : fold);
	return normalize(normal);
}

void fragment() {
	float mask = 0.0;
	for (int y = -8; y <= 8; y++) {
		if (abs(y) <= radius) {
			mask = max(mask, textureLod(horizontal_mask, UV + vec2(0.0, float(y)) * TEXTURE_PIXEL_SIZE, 0.0).a);
		}
	}
	vec4 model = textureLod(source_texture, UV, 0.0);
	vec4 outline = vec4(0.0, 0.0, 0.0, mask);
	vec4 geometry = textureLod(geometry_texture, UV, 0.0);
	float internal_edge = 0.0;
	if (model.a > 0.5 && geometry.a > 0.5) {
		vec3 center_normal = decode_normal(geometry.rg);
		for (int x = -1; x <= 1; x++) {
			for (int y = -1; y <= 1; y++) {
				if (x != 0 || y != 0) {
					vec4 neighbour = textureLod(geometry_texture, UV + vec2(float(x), float(y)) * TEXTURE_PIXEL_SIZE, 0.0);
					if (neighbour.a > 0.5) {
						vec3 neighbour_normal = decode_normal(neighbour.rg);
						float normal_change = 1.0 - dot(center_normal, neighbour_normal);
						vec4 opposite = textureLod(geometry_texture, UV - vec2(float(x), float(y)) * TEXTURE_PIXEL_SIZE, 0.0);
						// Subtract the continuing slope: a steep flat face is not an edge.
						float depth_change = opposite.a > 0.5 ? abs(neighbour.b + opposite.b - 2.0 * geometry.b) : 0.0;
						// Ink only one side of a crease, instead of both adjacent faces.
						// A lexicographic tie-break keeps equally facing normals distinct.
						bool normal_side = center_normal.z > neighbour_normal.z || (center_normal.z == neighbour_normal.z && (center_normal.y > neighbour_normal.y || (center_normal.y == neighbour_normal.y && center_normal.x > neighbour_normal.x)));
						if (normal_side) {
							internal_edge = max(internal_edge, step(normal_threshold, normal_change));
						}
						if (geometry.b < neighbour.b) {
							internal_edge = max(internal_edge, step(depth_threshold, depth_change));
						}
					}
				}
			}
		}
	}
	if (triangle_edges_enabled) {
		// Resolve the thin stroke over its final 2x2 footprint before the
		// reduction, so faint diagonals do not turn into dotted lines.
		vec2 size = vec2(textureSize(triangle_texture, 0));
		vec2 origin = floor(UV * size / 2.0) * 2.0;
		float fine_edge = 0.0;
		for (int y = 0; y < 2; y++) {
			for (int x = 0; x < 2; x++) {
				fine_edge = max(fine_edge, textureLod(triangle_texture, (origin + vec2(float(x), float(y)) + 0.5) / size, 0.0).r);
			}
		}
		model.rgb *= 1.0 - fine_edge * triangle_opacity;
	}
	model.rgb = mix(model.rgb, vec3(0.0), internal_edge);
	COLOR = model + outline * (1.0 - model.a);
}
