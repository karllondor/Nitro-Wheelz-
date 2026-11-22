// The approved NITRO WHEELZ logo painted flat on the pavement of the Park
// (issue #27). Only a light wear: sparse worn specks lower the paint a little;
// outline, colours and proportions of the artwork are untouched. One quad, no
// lighting, drawn before the tyre marks (render_priority lower than 0).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D logo : filter_linear_mipmap_anisotropic, repeat_disable;   // no source_color: the Compatibility renderer would darken the paint
uniform vec2 size_m = vec2(40.0, 22.5);
uniform float wear : hint_range(0.0, 0.5) = 0.16;
uniform float paint_alpha : hint_range(0.0, 1.0) = 0.96;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec4 t = texture(logo, UV);
	vec2 world = UV * size_m;
	float n = value_noise(world * 2.3) * 0.6 + value_noise(world * 9.0) * 0.4;
	float speck = smoothstep(0.64, 0.92, n);
	ALBEDO = t.rgb * (1.0 - 0.12 * speck);
	ALPHA = t.a * paint_alpha * (1.0 - speck * wear * 1.5);
}
