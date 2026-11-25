shader_type spatial;
render_mode unshaded, shadows_disabled;

uniform sampler2D grass : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 shade : source_color = vec4(0.29, 0.33, 0.24, 1.0);
uniform vec4 light : source_color = vec4(0.41, 0.46, 0.29, 1.0);
uniform vec4 time_of_day_tint : source_color = vec4(1.0);
varying vec2 ground_position;

void vertex() {
    ground_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
    vec2 p = ground_position;
    float meadow = sin(p.x * 0.039 + sin(p.y * 0.022) * 1.65) * 0.20
        + sin(p.y * 0.036 - p.x * 0.017) * 0.17
        + sin((p.x + p.y) * 0.11) * 0.07 + 0.50;
    ALBEDO = time_of_day_tint.rgb * mix(shade.rgb, light.rgb, meadow) * (0.80 + texture(grass, p / 26.0).rgb * 0.48);
}
