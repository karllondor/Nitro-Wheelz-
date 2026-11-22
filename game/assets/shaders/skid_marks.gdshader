// Tyre marks left on the asphalt (v0.1.36). Owner feedback 2026-11-22: the old
// marks were very dark with hard edges. Now: thin, soft across the width
// (full only in the middle of the rubber line, fading out to the sides) and
// lower opacity, with the oldest marks a little lighter. Vertex colour alpha =
// per-segment intensity; UV.x runs across the mark (0..1).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.035, 0.032, 0.045, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.40;
uniform float core : hint_range(0.0, 0.9) = 0.25;

void fragment() {
	float edge = abs(UV.x * 2.0 - 1.0);              // 0 in the middle .. 1 at the side
	float a = 1.0 - smoothstep(core, 1.0, edge);
	a *= a;                                           // gentler shoulder
	ALBEDO = tint.rgb;
	ALPHA = a * strength * COLOR.a;
}
