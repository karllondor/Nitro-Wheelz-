// Nitro Wheelz Car Factory glass: tinted, see-through (the interior and the
// roll cage stay visible like on a 1:18 die-cast), with the same studio
// reflection streaks as the paint. Double-sided so side windows read from
// any camera.
shader_type spatial;
render_mode blend_mix, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 tint : source_color = vec4(0.05, 0.06, 0.075, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.52;
uniform float gloss : hint_range(0.0, 3.0) = 1.1;
uniform vec4 studio : source_color = vec4(0.97, 0.97, 1.0, 1.0);

void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 v = normalize(VIEW);
	float ndv = clamp(abs(dot(n, v)), 0.0, 1.0);
	vec3 r = reflect(-v, n);
	float key = smoothstep(0.90, 0.985, dot(r, normalize(vec3(-0.55, 0.62, 0.56))));
	float strip = smoothstep(0.075, 0.0, abs(r.y - 0.80 - r.x * 0.18)) * 0.55;
	float dome = smoothstep(-0.35, 0.95, r.y);
	float fres = 0.05 + 0.95 * pow(1.0 - ndv, 4.0);
	vec3 env = studio.rgb * (key * 1.25 + strip + dome * 0.30);
	ALBEDO = tint.rgb;
	ROUGHNESS = 0.05;
	METALLIC = 0.0;
	SPECULAR = 0.6;
	EMISSION = env * gloss * mix(fres, 1.0, 0.15);
	ALPHA = clamp(opacity + fres * 0.40 + key * 0.3, 0.0, 0.95);
}
