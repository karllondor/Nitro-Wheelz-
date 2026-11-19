shader_type spatial;
// Garage backdrop: neutral mid-grey radial gradient (lighter behind the car,
// darker towards the card edges) with faint drift-swirl rings, after the
// owner's poster reference. Screen-space so it is identical on every
// phone; works in GL Compatibility.
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never, fog_disabled;

uniform vec3 centre_colour : source_color = vec3(0.50, 0.50, 0.52);
uniform vec3 edge_colour : source_color = vec3(0.24, 0.24, 0.255);
uniform vec2 focus = vec2(0.5, 0.56);
uniform float aspect = 0.82;
uniform float ring_strength = 0.05;

void fragment() {
	vec2 p = SCREEN_UV - focus;
	p.x *= aspect;
	float r = length(p);
	vec3 c = mix(centre_colour, edge_colour, smoothstep(0.04, 0.78, r));
	// Soft, slightly spiralling tyre-mark rings around the car.
	float swirl = 0.5 + 0.5 * sin(r * 44.0 + atan(p.y, p.x) * 2.0);
	float rings = smoothstep(0.80, 1.0, swirl) * smoothstep(0.16, 0.30, r) * (1.0 - smoothstep(0.55, 0.85, r));
	c *= 1.0 - ring_strength * rings;
	ALBEDO = c;
}
