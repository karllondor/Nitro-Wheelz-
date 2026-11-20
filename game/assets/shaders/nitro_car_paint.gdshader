// Nitro Wheelz Car Factory paint (v0.2, factory GLB cars only; the Lada and
// RYU-32 keep diecast_paint.gdshader). Premium die-cast look in GL
// Compatibility without brightening the scene:
//  * body shading from the car's own geometry: surfaces facing up keep the
//    full colour, sides and lower panels fall off into a deeper, warmer tone
//    (readable light / shadow on a flat-lit studio or race track);
//  * deeper colour at grazing angles (paint depth) instead of a milky film;
//  * clear coat: the same studio soft boxes as the other cars, but sharper,
//    and only a thin fresnel sheen on the rest of the body.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 paint : source_color = vec4(0.93, 0.70, 0.04, 1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.20;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float gloss : hint_range(0.0, 3.0) = 1.0;
uniform float rim : hint_range(0.0, 3.0) = 0.6;
uniform float glow : hint_range(0.0, 8.0) = 0.0;
uniform vec4 studio : source_color = vec4(0.97, 0.97, 1.0, 1.0);
uniform vec4 floor_tint : source_color = vec4(0.11, 0.11, 0.13, 1.0);
// 0 = flat colour; how much darker vertical / lower panels get.
uniform float body_shade : hint_range(0.0, 1.0) = 0.27;
// Warm shift of the shaded tone (keeps yellow golden, not olive).
uniform vec4 shade_tint : source_color = vec4(1.0, 0.94, 0.84, 1.0);
uniform float depth : hint_range(0.0, 1.0) = 0.24;
uniform float coat : hint_range(0.5, 3.0) = 1.4;

void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 v = normalize(VIEW);
	vec3 nw = normalize((INV_VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float ndv = clamp(dot(n, v), 0.0, 1.0);
	vec3 r = reflect(-v, n);
	// Studio soft boxes (view space, stable from the high race camera).
	float key = smoothstep(0.93, 0.99, dot(r, normalize(vec3(-0.55, 0.62, 0.56)))) * coat;
	float fill = smoothstep(0.90, 0.995, dot(r, normalize(vec3(0.70, 0.30, 0.65)))) * 0.40;
	float strip = smoothstep(0.050, 0.0, abs(r.y - 0.80 - r.x * 0.18)) * 0.60;
	float dome = smoothstep(-0.20, 0.95, r.y);
	vec3 env = studio.rgb * (key * 1.2 + fill + strip)
		+ mix(floor_tint.rgb, studio.rgb * (0.30 + metallic * 0.30), dome);
	float f0 = mix(0.04, 0.80, metallic);
	float fres = f0 + (1.0 - f0) * pow(1.0 - ndv, 5.0);
	// Body light / shadow from the panel orientation (world up = lit).
	float up = smoothstep(-0.60, 0.85, nw.y);
	float lit = mix(1.0 - body_shade, 1.0, up);
	vec3 base = paint.rgb * lit * mix(shade_tint.rgb, vec3(1.0), up);
	// Paint depth: richer, darker colour where the surface turns away.
	base *= mix(1.0, 1.0 - depth, pow(1.0 - ndv, 1.6));
	vec3 tint = mix(vec3(1.0), paint.rgb * 1.3 + 0.06, metallic);
	ALBEDO = base * (1.0 - metallic * 0.55);
	ROUGHNESS = roughness;
	METALLIC = metallic * 0.6;
	SPECULAR = 0.5;
	EMISSION = env * tint * gloss * mix(fres, 1.0, 0.04 + metallic * 0.50)
		+ studio.rgb * (key + strip) * gloss * 0.35
		+ studio.rgb * pow(1.0 - ndv, 4.0) * rim * 0.14
		+ paint.rgb * glow;
}
