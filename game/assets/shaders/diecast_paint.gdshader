// Nitro Wheelz "diecast" paint: glossy collectible-toy finish that works in
// the GL Compatibility renderer (Android). Real lights give the base shading;
// a view-space studio environment (matcap-like soft boxes) adds the bright,
// stable highlights that make small cars read as polished die-cast models
// from a high top-down camera, independent of scene lighting.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 paint : source_color = vec4(0.78, 0.03, 0.05, 1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.24;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
// Strength of the faked studio reflection (0 = matte plastic / rubber).
uniform float gloss : hint_range(0.0, 3.0) = 1.0;
// Clear-coat style edge reflection.
uniform float rim : hint_range(0.0, 3.0) = 0.8;
// Self illumination for lamps / tinted glow.
uniform float glow : hint_range(0.0, 8.0) = 0.0;
uniform vec4 studio : source_color = vec4(1.0, 0.95, 0.98, 1.0);
uniform vec4 floor_tint : source_color = vec4(0.10, 0.07, 0.14, 1.0);

uniform vec4 road_lamp_emission : source_color = vec4(0.0);

void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 v = normalize(VIEW);
	float ndv = clamp(dot(n, v), 0.0, 1.0);
	vec3 r = reflect(-v, n);
	// Large key soft box (upper left), thin strip light, broad sky dome.
	float key = smoothstep(0.90, 0.985, dot(r, normalize(vec3(-0.55, 0.62, 0.56))));
	float fill = smoothstep(0.86, 0.99, dot(r, normalize(vec3(0.70, 0.30, 0.65)))) * 0.45;
	float strip = smoothstep(0.075, 0.0, abs(r.y - 0.80 - r.x * 0.18)) * 0.55;
	float dome = smoothstep(-0.35, 0.95, r.y);
	vec3 env = studio.rgb * (key * 1.25 + fill + strip) + mix(floor_tint.rgb + metallic * 0.12, studio.rgb * (0.38 + metallic * 0.30), dome);
	float f0 = mix(0.05, 0.85, metallic);
	float fres = f0 + (1.0 - f0) * pow(1.0 - ndv, 4.0);
	vec3 tint = mix(vec3(1.0), paint.rgb * 1.35 + 0.08, metallic);
	ALBEDO = paint.rgb * (1.0 - metallic * 0.55);
	ROUGHNESS = roughness;
	METALLIC = metallic * 0.6;
	SPECULAR = 0.55;
	EMISSION = env * tint * gloss * mix(fres, 1.0, 0.18 + metallic * 0.55)
		+ studio.rgb * pow(1.0 - ndv, 3.0) * rim * 0.22
		+ paint.rgb * glow + road_lamp_emission.rgb;
}
