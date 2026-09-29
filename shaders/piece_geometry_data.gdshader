shader_type spatial;
render_mode unshaded, cull_back, fog_disabled;

// Auxiliary view of the piece. RG stores the view-space normal (octahedral
// encoding), B stores view depth. The image is never shown directly; the
// outline compositor uses discontinuities in it to ink internal form edges.
varying float view_depth;
uniform float depth_origin = 0.0;
uniform float depth_span = 1.0;
uniform bool triangle_edges_only = false;
uniform float triangle_width = 0.55;

vec2 encode_normal(vec3 normal) {
	normal /= abs(normal.x) + abs(normal.y) + abs(normal.z);
	vec2 encoded = normal.xy;
	if (normal.z < 0.0) {
		encoded = (1.0 - abs(encoded.yx)) * vec2(encoded.x >= 0.0 ? 1.0 : -1.0, encoded.y >= 0.0 ? 1.0 : -1.0);
	}
	return encoded * 0.5 + 0.5;
}

void vertex() {
	view_depth = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
}

void fragment() {
	ALBEDO = vec3(encode_normal(normalize(NORMAL)), clamp((view_depth - depth_origin) / depth_span, 0.0, 1.0));
	if (triangle_edges_only) {
		vec3 barycentric = vec3(UV2, 1.0 - UV2.x - UV2.y);
		vec3 gradient = max(sqrt(dFdx(barycentric) * dFdx(barycentric) + dFdy(barycentric) * dFdy(barycentric)), vec3(0.00001));
		vec3 distance_px = barycentric / gradient;
		float distance_edge = min(distance_px.x, min(distance_px.y, distance_px.z));
		float edge = 1.0 - smoothstep(max(triangle_width - 0.5, 0.0), triangle_width + 0.5, distance_edge);
		ALBEDO = vec3(edge);
	}
}
