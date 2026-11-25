shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

void fragment() {
    vec2 offset = (UV - 0.5) * 2.0;
    ALBEDO = vec3(0.025, 0.018, 0.035);
    ALPHA = (1.0 - smoothstep(0.18, 1.0, dot(offset, offset))) * 0.62;
}
