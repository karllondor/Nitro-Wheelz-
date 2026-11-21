// Nitro Wheelz Car Factory glass: tinted, see-through (the interior and the
// roll cage stay visible like on a 1:18 die-cast), with the same studio
// reflection streaks as the paint. Double-sided so side windows read from
// any camera.
shader_type spatial;
render_mode blend_mix, cull_disabled, diffuse_burley, specular_schlick_ggx;

// Car Factory geometry variants (v0.1.30): UV2.x = 0 on parts shared by
// every variant, n on parts that exist only in variant slot n (e.g. Lada
// RED = 1 exposed engine, WHITE = 2 closed bonnet). The other slot's faces
// collapse to a point here, so variants share one GLB / mesh / draw call.
// Meshes without UV2 (E30, wheels) read 0 = always visible.
uniform float variant_slot = 0.0;

void vertex() {
	if (UV2.x > 0.5 && abs(UV2.x - variant_slot) > 0.25) {
		VERTEX = vec3(0.0);
	}
}

// v0.2: darker, more realistic tint; the cage and seats stay subtly visible.
uniform vec4 tint : source_color = vec4(0.028, 0.034, 0.044, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.64;
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
