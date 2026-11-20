// Nitro Wheelz terrain (v0.1.27): vertex-coloured ground (grass / forest
// floor / rock / snow / seasonal tint baked per vertex by the generator)
// plus, in the shader and without extra geometry:
//  * large-scale colour variation (no flat colour fields);
//  * rock strata on steep faces (horizontal bands broken by noise), strength
//    per region (limestone / granite / basalt), so cliffs read as rock;
//  * slope darkening and a softer, less glaring snow;
//  * world-space detail at two scales so close ground is not plastic.
//  * Japan City (city = 1): the street grid is PAINTED here (asphalt,
//    sidewalks with kerbs, centre / lane lines, zebra crossings), aligned
//    with the scenery's block grid, so streets cost no geometry and never
//    z-fight; vertex alpha masks them out near the race road, on the shore
//    and on the hills.
// GL Compatibility friendly (one texture).
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D detail : filter_linear_mipmap, repeat_enable;
uniform float detail_strength : hint_range(0.0, 1.0) = 0.36;
uniform float macro_strength : hint_range(0.0, 1.0) = 0.22;
uniform float strata : hint_range(0.0, 1.0) = 0.5;
uniform float strata_scale : hint_range(0.2, 4.0) = 1.0;
uniform float slope_dark : hint_range(0.0, 1.0) = 0.22;
uniform float snow_soften : hint_range(0.0, 0.5) = 0.12;
uniform float city = 0.0;
uniform vec2 city_u = vec2(1.0, 0.0);
uniform vec2 city_pitch = vec2(72.0, 72.0);
uniform vec2 city_off = vec2(0.0, 0.0);
uniform float city_every = 3.0;
uniform vec2 city_phase = vec2(0.0, 0.0);
uniform float city_side_w = 12.0;
uniform float city_ave_w = 21.0;
uniform float city_walk = 2.8;
// Builder: buildability markers painted ON the ground (they used to be flat
// quads that sank into slopes). One texel per tile: rgb = colour, a = on.
uniform float tiles = 0.0;
uniform sampler2D tile_tex : filter_nearest, repeat_disable;
uniform vec2 tile_origin = vec2(-336.0, -448.0);
uniform vec2 tile_count = vec2(12.0, 16.0);
uniform float tile_size = 56.0;
varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

// Nearest street line on one grid axis: (offset from its centre, width, avenue).
vec3 street(float c, float pitch, float off, float phase) {
	float i = floor((c - off) / pitch + 0.5);
	float d = c - (off + i * pitch);
	float ave = mod(i - phase, city_every) < 0.5 ? 1.0 : 0.0;
	return vec3(d, mix(city_side_w, city_ave_w, ave), ave);
}

float band(float x, float half_w, float aa) {
	return 1.0 - smoothstep(half_w - aa, half_w + aa, abs(x));
}

vec3 city_ground(vec3 base_col, vec2 l) {
	vec3 sx = street(l.x, city_pitch.x, city_off.x, city_phase.x);   // street running along V
	vec3 sz = street(l.y, city_pitch.y, city_off.y, city_phase.y);   // street running along U
	float fx = max(fwidth(l.x), 0.02);
	float fz = max(fwidth(l.y), 0.02);
	float hx = sx.y * 0.5;
	float hz = sz.y * 0.5;
	float in_x = band(sx.x, hx, fx);
	float in_z = band(sz.x, hz, fz);
	float road_x = band(sx.x, hx - city_walk, fx);
	float road_z = band(sz.x, hz - city_walk, fz);
	float street_m = max(in_x, in_z);
	float asphalt = max(road_x, road_z);
	// Plaza / lot ground (lighter concrete) inside the blocks.
	vec3 col = mix(base_col, base_col * 1.12 + vec3(0.03), 0.6);
	vec2 tile = abs(fract(l * 0.5) - 0.5);
	float joint = smoothstep(0.47, 0.5, max(tile.x, tile.y)) * (1.0 - smoothstep(0.08, 0.2, max(fx, fz)));
	vec3 walk = vec3(0.60, 0.58, 0.55) * (1.0 - 0.10 * joint);
	col = mix(col, walk, street_m);
	// Kerb stones along the sidewalk edge.
	float kerb = max(band(abs(sx.x) - (hx - city_walk), 0.18, fx) * in_x * (1.0 - road_z),
		band(abs(sz.x) - (hz - city_walk), 0.18, fz) * in_z * (1.0 - road_x));
	col = mix(col, vec3(0.74, 0.73, 0.70), kerb);
	vec3 asph = vec3(0.21, 0.215, 0.23);
	col = mix(col, asph, asphalt);
	// Markings fade out before they alias.
	float lx = 1.0 - smoothstep(0.10, 0.30, fx);
	float lz = 1.0 - smoothstep(0.10, 0.30, fz);
	vec3 paint = vec3(0.90, 0.90, 0.86);
	float outside_z = 1.0 - band(sz.x, hz, fz);   // not inside the crossing street
	float outside_x = 1.0 - band(sx.x, hx, fx);
	// Centre lines: solid on avenues, dashed on side streets.
	float dash_x = mix(step(0.5, fract(l.y / 6.0)), 1.0, sx.z);
	float dash_z = mix(step(0.5, fract(l.x / 6.0)), 1.0, sz.z);
	float mk = band(sx.x, 0.09, fx) * dash_x * road_x * outside_z * lx;
	mk = max(mk, band(sz.x, 0.09, fz) * dash_z * road_z * outside_x * lz);
	// Avenue lane lines (dashed).
	float lane = hx - city_walk;
	mk = max(mk, band(abs(sx.x) - lane * 0.5, 0.07, fx) * sx.z * step(0.6, fract(l.y / 9.0)) * outside_z * lx);
	lane = hz - city_walk;
	mk = max(mk, band(abs(sz.x) - lane * 0.5, 0.07, fz) * sz.z * step(0.6, fract(l.x / 9.0)) * outside_x * lz);
	// Zebra crossings just before each crossing street.
	float zb_x = road_x * step(hz + 0.8, abs(sz.x)) * step(abs(sz.x), hz + 4.6) * step(0.5, fract(sx.x / 1.0)) * lx;
	float zb_z = road_z * step(hx + 0.8, abs(sx.x)) * step(abs(sx.x), hx + 4.6) * step(0.5, fract(sz.x / 1.0)) * lz;
	mk = max(mk, max(zb_x, zb_z));
	// Stop lines.
	mk = max(mk, road_x * band(abs(sz.x) - (hz + 5.4), 0.22, fz) * step(0.0, sx.x) * lx);
	mk = max(mk, road_z * band(abs(sx.x) - (hx + 5.4), 0.22, fx) * step(sz.x, 0.0) * lz);
	return mix(col, paint, clamp(mk, 0.0, 1.0) * 0.9);
}

void fragment() {
	vec3 n = normalize(wnrm);
	float slope = 1.0 - clamp(n.y, 0.0, 1.0);
	float a = texture(detail, wpos.xz / 41.0).r;
	float b = texture(detail, wpos.xz / 9.0).r;
	float m = texture(detail, wpos.xz / 330.0 + vec2(0.37, 0.11)).r;
	vec3 col = COLOR.rgb;
	// Large-scale variation (meadows, patches).
	col *= 1.0 - macro_strength * 0.5 + macro_strength * m;
	// Rock strata on steep faces: bands along height, broken by noise.
	float rocky = smoothstep(0.30, 0.68, slope);
	float side = texture(detail, vec2(wpos.x + wpos.z, wpos.y * 1.7) / 29.0).r;
	float band = 0.5 + 0.5 * sin((wpos.y * 0.85 + side * 6.0) * strata_scale);
	col *= mix(1.0, 0.74 + 0.36 * band, rocky * strata);
	col *= 1.0 - slope_dark * smoothstep(0.15, 0.85, slope);
	// Snow: slightly greyed so peaks do not glare.
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, col * (1.0 - snow_soften), smoothstep(0.70, 0.88, lum));
	if (city > 0.5) {
		vec2 v = vec2(-city_u.y, city_u.x);
		vec2 l = vec2(dot(wpos.xz, city_u), dot(wpos.xz, v));
		col = mix(col, city_ground(col, l), smoothstep(0.4, 0.9, COLOR.a));
	}
	if (tiles > 0.5) {
		vec2 cell = (wpos.xz - tile_origin) / tile_size;
		if (cell.x >= 0.0 && cell.y >= 0.0 && cell.x < tile_count.x && cell.y < tile_count.y) {
			vec4 tc = texture(tile_tex, (floor(cell) + 0.5) / tile_count);
			vec2 q = abs(fract(cell) - 0.5);
			float aa = max(fwidth(cell.x), 0.002) * 1.5;
			// Rounded square (30 % of the tile) with a light rim.
			float dq = length(max(q - vec2(0.11), 0.0)) - 0.04;
			float inside = 1.0 - smoothstep(-aa, aa, dq);
			float rim = (1.0 - smoothstep(-aa, aa, abs(dq + 0.012) - 0.010)) * inside;
			col = mix(col, tc.rgb, inside * 0.72 * tc.a);
			col = mix(col, vec3(1.0), rim * 0.35 * tc.a);
		}
	}
	float d = a * 0.6 + b * 0.4;
	ALBEDO = col * (1.0 - detail_strength * 0.5 + detail_strength * d);
	ROUGHNESS = mix(0.94, 0.82, rocky);
	SPECULAR = 0.18;
}
