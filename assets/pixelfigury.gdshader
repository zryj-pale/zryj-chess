shader_type spatial;
// No `shadows_disabled` here: the piece both casts a shadow onto its plate -
// through a shadow-only copy of the mesh that stays in the board's world, see
// scenes/figura.tscn - and receives shadows from its own key light inside the
// baked preview, which is what gives the figure its form back.
render_mode blend_mix, cull_back, specular_disabled, ambient_light_disabled;

// Shading for the board figures (scenes/figura.tscn).
//
// This file deliberately does NOT try to pixelate anything. Pixelation is an
// image-space operation - the frame has to be rasterised small and then blown
// up with nearest sampling, which is what shaders/napisy_zaklocenie.gdshader
// does on the menu's SubViewportContainer. A spatial shader runs per fragment
// of a full-resolution rasterisation, so it can flatten colour but it can
// never make the silhouette blocky; an earlier version of this file tried
// (vertex snapping + ordered dither) and all it produced was a dotted surface.
//
// What is left here is the half that does belong to a per-fragment shader: the
// lighting is crushed into flat steps, the way old hardware did it because it
// could not afford a smooth gradient.
//
// The ramp alone is not enough, and that is measured, not assumed. The bundled
// model (models/Skoczek_punkt.glb) is 92 triangles with 15 distinct normal
// directions, no texture, no UVs and a COLOR_0 that is black on every vertex.
// Baked with the board's own key light, 99% of the figure's pixels came out on
// ONE tone - a solid silhouette. So two cheap, period-correct terms do the work
// the missing geometry cannot:
//
//   shade_bands    how many flat steps the N.L ramp is cut into.
//   shadow_tint    colour of the darkest step; darker means more contrast.
//   edge_darken    darkens faces turning away from the camera, which reads as
//                  an inked outline around the silhouette.
//   bottom_darken  darkens the piece toward its own base - the fake ambient
//                  occlusion every sprite of that era had painted in by hand.
//
// All of them are pure functions of geometry and light, so the bake is stable.

uniform vec4 albedo_color : source_color = vec4(0.8, 0.1, 0.1, 1.0);

// Jednolite zabarwienie calego modelu - to samo, co Sprite3D robi ze swoim
// modulate, tylko dla cieniowanej bryly. Kreator armii podaje tu szary, zeby
// neutralny podglad ustawienia byl szary takze dla skoczka.
uniform vec4 tint : source_color = vec4(1.0);

// The bundled models (models/*.glb) ship a COLOR_0 attribute that is black on
// every vertex, so multiplying by it would simply turn the figure black. It
// stays available for models that do carry real vertex colours.
uniform bool use_vertex_color = false;

uniform int shade_bands : hint_range(2, 5) = 5;
uniform vec4 shadow_tint : source_color = vec4(0.32, 0.32, 0.40, 1.0);
uniform float edge_darken : hint_range(0.0, 1.0) = 0.4;
uniform float bottom_darken : hint_range(0.0, 1.0) = 0.35;
// Bryła stoi teraz w świecie planszy (figura nie jest już pieczona w osobnym
// buforze), więc te dwie liczby to współrzędne ŚWIATA, a nie lokalne. figura.gd
// wylicza je z pozycji figury i zmierzonej bryły modelu.
uniform float height_base = 0.0;
uniform float height_top = 1.0;

// fragment() -> light(). The light stage can neither see the camera direction
// nor a per-fragment constant computed from geometry, so both terms travel as
// varyings.
varying float v_podstawa;
varying float v_krawedz;

void fragment() {
	vec3 base = albedo_color.rgb * tint.rgb;
	if (use_vertex_color) {
		base *= COLOR.rgb;
	}
	ALBEDO = base;

	// Fake occlusion toward the piece's base.
	float wysokosc = clamp((VERTEX.y - height_base) / max(height_top - height_base, 0.001), 0.0, 1.0);
	v_podstawa = mix(1.0 - bottom_darken, 1.0, wysokosc);

	// Faces turned away from the camera go dark: an outline for free on a model
	// too coarse to have edges of its own.
	float na_wprost = abs(dot(normalize(NORMAL), normalize(VIEW)));
	v_krawedz = 1.0 - edge_darken * pow(1.0 - clamp(na_wprost, 0.0, 1.0), 2.0);
}

void light() {
	float bands = float(max(shade_bands, 2));
	float ndotl = clamp(dot(normalize(NORMAL), normalize(LIGHT)), 0.0, 1.0);
	float banded = clamp(floor(ndotl * bands) / (bands - 1.0), 0.0, 1.0);
	DIFFUSE_LIGHT += ALBEDO * mix(shadow_tint.rgb, vec3(1.0), banded) * v_podstawa * v_krawedz * ATTENUATION;
}
