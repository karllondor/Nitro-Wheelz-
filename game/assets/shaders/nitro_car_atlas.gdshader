// Nitro Wheelz Car Factory atlas material: every opaque non-paint part of a
// factory car (trim, chrome, lamps, interior, tyres, rims) in ONE material,
// so a whole car body costs paint + atlas + glass draw calls. The textures
// come from the GLB (albedo, ORM: G = roughness, B = metallic, emission).
// The same view-space studio reflection as diecast_paint.gdshader keeps the
// die-cast look consistent with the other cars in GL Compatibility.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap, repeat_disable;
uniform sampler2D emission_tex : source_color, hint_default_black, filter_linear_mipmap, repeat_disable;
uniform float gloss : hint_range(0.0, 3.0) = 1.0;
uniform float rim : hint_range(0.0, 3.0) = 0.35;
uniform float emission_energy : hint_range(0.0, 8.0) = 1.6;
uniform vec4 studio : source_color = vec4(0.97, 0.97, 1.0, 1.0);
uniform vec4 floor_tint : source_color = vec4(0.11, 0.11, 0.13, 1.0);

void fragment() {
	vec3 base = texture(albedo_tex, UV).rgb;
	vec3 orm = texture(orm_tex, UV).rgb;
	float rough = orm.g;
	float metal = orm.b;
	vec3 n = normalize(NORMAL);
	vec3 v = normalize(VIEW);
	float ndv = clamp(dot(n, v), 0.0, 1.0);
	vec3 r = reflect(-v, n);
	float key = smoothstep(0.90, 0.985, dot(r, normalize(vec3(-0.55, 0.62, 0.56))));
	float fill = smoothstep(0.86, 0.99, dot(r, normalize(vec3(0.70, 0.30, 0.65)))) * 0.45;
	float strip = smoothstep(0.075, 0.0, abs(r.y - 0.80 - r.x * 0.18)) * 0.55;
	// v0.3: world-space horizon reflection whose sharpness follows the
	// roughness: polished lips / chrome show crisp bright-over-dark bands
	// (reads as mirror polish), machined faces a soft gradient, so polished
	// and satin metal finally differ.
	vec3 rw = (INV_VIEW_MATRIX * vec4(r, 0.0)).xyz;
	float w = mix(0.025, 0.75, clamp(rough * 1.6, 0.0, 1.0));
	float hz = smoothstep(-w, w, rw.y + 0.03);
	vec3 sky = studio.rgb * (0.50 + 0.30 * smoothstep(0.1, 0.9, rw.y) + metal * 0.32);
	vec3 ground = floor_tint.rgb * mix(0.35, 1.0, rough) + metal * 0.02;
	vec3 env = studio.rgb * (key * 1.25 + fill + strip) + mix(ground, sky, hz);
	float f0 = mix(0.05, 0.85, metal);
	float fres = f0 + (1.0 - f0) * pow(1.0 - ndv, 4.0);
	vec3 tint = mix(vec3(1.0), base * 1.25 + 0.06, metal);
	// Glossy swatches reflect the studio, rough ones (rubber, fabric) do not.
	float shine = gloss * pow(1.0 - rough, 1.6) * 1.35;
	ALBEDO = base * (1.0 - metal * 0.55);
	ROUGHNESS = rough;
	METALLIC = metal * 0.6;
	SPECULAR = 0.5;
	EMISSION = env * tint * shine * mix(fres, 1.0, 0.18 + metal * 0.55)
		+ studio.rgb * pow(1.0 - ndv, 3.0) * rim * 0.22 * (1.0 - rough)
		+ texture(emission_tex, UV).rgb * emission_energy;
}
