// Night drift-park mood: darkened, slightly violet screen corners that keep
// the centre (car and next corner) readable. One cheap full-screen pass.
shader_type canvas_item;

uniform vec4 tint : source_color = vec4(0.02, 0.01, 0.05, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.48;
uniform float inner : hint_range(0.0, 1.5) = 0.45;
uniform float outer : hint_range(0.0, 2.0) = 1.05;

void fragment() {
	vec2 p = (UV - vec2(0.5, 0.55)) * vec2(1.0, 1.25);
	float d = length(p * 1.6);
	float a = smoothstep(inner, outer, d) * strength;
	COLOR = vec4(tint.rgb, a);
}
