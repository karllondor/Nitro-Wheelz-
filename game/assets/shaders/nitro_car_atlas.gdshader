// Nitro Wheelz Car Factory atlas material: every opaque non-paint part of a
// factory car (trim, chrome, lamps, interior, tyres, rims) in ONE material,
// so a whole car body costs paint + atlas + glass draw calls. The textures
// come from the GLB (albedo, ORM: G = roughness, B = metallic, emission).
// The same view-space studio reflection as diecast_paint.gdshader keeps the
// die-cast look consistent with the other cars in GL Compatibility.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

// Car Factory geometry variants (v0.1.30): UV2.x = 0 on parts shared by
// every variant, n on parts that exist only in variant slot n (e.g. Lada
// RED = 1 exposed engine, WHITE = 2 closed bonnet). The other slot's faces
// collapse to a point here, so variants share one GLB / mesh / draw call.
// Meshes without UV2 (E30, wheels) read 0 = always visible.
uniform float variant_slot = 0.0;
uniform bool road_lights_enabled = false;
uniform vec2 road_lamp_limits = vec2(-1.88, 1.82);
uniform vec2 road_lamp_levels = vec2(0.0);
uniform float road_reflection = 1.0;
varying vec3 part_position;

void vertex() {
	part_position = VERTEX;
	if (UV2.x > 0.5 && abs(UV2.x - variant_slot) > 0.25) {
		VERTEX = vec3(0.0);
	}
}

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
	vec3 baked = texture(emission_tex, UV).rgb;
	vec3 fixture = baked * emission_energy;
	if (road_lights_enabled && abs(part_position.x) > 0.25) {
		if (part_position.z < road_lamp_limits.x && part_position.y > 0.37 && part_position.y < 0.78) {
			float lens = smoothstep(0.019, 0.14, min(baked.r, min(baked.g, baked.b)));
			fixture = mix(fixture, vec3(1.0, 0.91, 0.74) * lens * road_lamp_levels.x, step(0.004, lens));
		}
		if (part_position.z > road_lamp_limits.y && part_position.y > 0.38 && part_position.y < 0.79) {
			float lens = smoothstep(0.004, 0.053, baked.r - max(baked.g, baked.b) * 1.65);
			vec3 lamp = vec3(0.85, 0.022, 0.032) * road_lamp_levels.y;
			lamp.gb += vec2(0.085, 0.065) * smoothstep(0.25, 1.0, road_lamp_levels.y);
			fixture = mix(fixture, lamp * lens, step(0.004, lens));
		}
	}
	EMISSION = (env * tint * shine * mix(fres, 1.0, 0.18 + metal * 0.55)
		+ studio.rgb * pow(1.0 - ndv, 3.0) * rim * 0.22 * (1.0 - rough)) * road_reflection
		+ fixture;
}
