// Cheap soft contact shadow (rounded rectangle) for cars and props.
// Mobile friendly replacement for real-time shadow maps.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform float opacity : hint_range(0.0, 1.0) = 0.62;
// Half extents of the solid core in UV units (0..0.5).
uniform vec2 core = vec2(0.30, 0.38);
uniform float softness : hint_range(0.001, 0.5) = 0.12;
uniform float corner : hint_range(0.0, 0.5) = 0.12;
uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.02, 1.0);

void fragment() {
	vec2 p = abs(UV - 0.5);
	vec2 q = p - core + corner;
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - corner;
	float a = 1.0 - smoothstep(-softness * 0.35, softness, d);
	ALBEDO = shadow_color.rgb;
	ALPHA = a * a * opacity;
}
