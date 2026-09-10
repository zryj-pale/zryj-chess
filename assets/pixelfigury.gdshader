shader_type spatial;
render_mode blend_mix, cull_back, diffuse_toon, specular_disabled, shadows_disabled, ambient_light_disabled;

uniform vec4 albedo_color : source_color = vec4(0.8, 0.1, 0.1, 1.0);
uniform int shade_bands : hint_range(2, 5) = 2;
uniform vec4 shadow_tint : source_color = vec4(0.45, 0.45, 0.55, 1.0);

void fragment() {
    ALBEDO = albedo_color.rgb;
}

void light() {
    float ndotl = dot(NORMAL, LIGHT);
    float banded = floor(clamp(ndotl, 0.0, 1.0) * float(shade_bands)) / float(shade_bands - 1);
    banded = clamp(banded, 0.0, 1.0);
    vec3 shaded = mix(shadow_tint.rgb, vec3(1.0), banded);
    DIFFUSE_LIGHT += albedo_color.rgb * shaded * ATTENUATION;
}
