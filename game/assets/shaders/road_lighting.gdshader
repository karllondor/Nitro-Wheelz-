// The production pavement texture and vertex tint, with a low-beam response
// calibrated for visibility at grazing angles in both driving cameras.
shader_type spatial;
render_mode cull_disabled, specular_disabled;

uniform sampler2D pavement : source_color, filter_linear_mipmap_anisotropic, repeat_enable;

void fragment() {
    ALBEDO = texture(pavement, UV).rgb * COLOR.rgb;
    ROUGHNESS = 0.96;
}

void light() {
    float incidence = max(dot(NORMAL, LIGHT), 0.0);
    float spread = 0.153 + 0.18 * incidence;
    // Local headlights hit almost horizontally. Keep the near field bounded
    // and let the reflector's measured distance and cone falloff do the work.
    spread *= 1.0 - 0.76 * smoothstep(0.12, 0.42, incidence);
    float response = LIGHT_IS_DIRECTIONAL ? incidence : spread * step(0.002, incidence);
    DIFFUSE_LIGHT += LIGHT_COLOR * (response * ATTENUATION / PI);
}
