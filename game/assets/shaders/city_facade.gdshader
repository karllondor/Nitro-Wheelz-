// Nitro Wheelz Japan City facades (v0.1.27). Buildings are plain boxes;
// windows, shopfronts, ribbon glazing and curtain walls are drawn here so
// the city reads as varied architecture without window geometry.
//   UV.x = the building's base height (floors count from it),
//   UV.y = facade style:
//     0 plain (roofs, signs, parapets)   1 punched windows (residential)
//     2 office ribbon glazing            3 tower curtain wall
//     4 shop: shopfront + flats above    5 mansion: sliding doors
//     6 department store: tall slits     7 convenience store: glass front
// Window cells are 1.5 / 3 m modules counted from each face's own edge
// (UV2.x); buildings are multiples of 3 m, so windows never cut corners.
// Far away the pattern fades to its average colour (no shimmering).
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;

uniform vec4 glass_dark : source_color = vec4(0.12, 0.16, 0.22, 1.0);
uniform vec4 glass_sky : source_color = vec4(0.56, 0.66, 0.80, 1.0);
uniform vec4 curtain : source_color = vec4(0.80, 0.76, 0.66, 1.0);

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float rect(vec2 f, vec2 lo, vec2 hi, vec2 aa) {
	vec2 a = smoothstep(lo - aa, lo + aa, f) * (1.0 - smoothstep(hi - aa, hi + aa, f));
	return a.x * a.y;
}

void fragment() {
	vec3 col = COLOR.rgb;
	vec3 n = normalize(wnrm);
	int style = int(UV.y + 0.5);
	float y = wpos.y - UV.x;
	float glass = 0.0;
	float wv = 0.5;
	vec2 cid = vec2(0.0);
	float tint = 0.0;
	if (abs(n.y) < 0.5) {
		// Contact shade at the foot of every wall.
		col *= mix(0.80, 1.0, smoothstep(0.0, 5.0, y));
		if (style > 0) {
			vec2 t = normalize(vec2(-n.z, n.x));
			float h = dot(wpos.xz, t) - UV2.x;
			float M = 3.0;
			float F = 3.0;
			float g0 = 0.0;
			vec2 lo = vec2(0.24, 0.30);
			vec2 hi = vec2(0.76, 0.80);
			if (style == 2) {
				M = 1.5; F = 3.6; g0 = 4.2; lo = vec2(0.05, 0.26); hi = vec2(0.95, 0.80);
				if (y < g0) { F = g0; g0 = 0.0; lo = vec2(0.05, 0.04); hi = vec2(0.95, 0.80); }
			} else if (style == 3) {
				M = 1.5; F = 3.8; g0 = 6.0; lo = vec2(0.04, 0.10); hi = vec2(0.96, 0.96); tint = 1.0;
				if (y < g0) { F = g0; g0 = 0.0; lo = vec2(0.04, 0.03); hi = vec2(0.96, 0.75); }
			} else if (style == 4) {
				g0 = 4.0;
				if (y < g0) { F = g0; g0 = 0.0; lo = vec2(0.06, 0.06); hi = vec2(0.94, 0.66); }
			} else if (style == 5) {
				lo = vec2(0.10, 0.04); hi = vec2(0.90, 0.74);
			} else if (style == 6) {
				F = 4.5; g0 = 5.0; lo = vec2(0.42, 0.12); hi = vec2(0.58, 0.88);
				if (y < g0) { F = g0; g0 = 0.0; lo = vec2(0.06, 0.04); hi = vec2(0.94, 0.70); }
			} else if (style == 7) {
				M = 1.5; F = 3.4;
				lo = vec2(0.04, 0.04); hi = vec2(0.96, 0.78);
				if (y > F) { lo = vec2(2.0); hi = vec2(2.0); }
			}
			vec2 c = vec2(h / M, (y - g0) / F);
			vec2 f = fract(c);
			cid = floor(c);
			vec2 aa = vec2(fwidth(h) / M, fwidth(y) / F) * 0.75;
			glass = rect(f, lo, hi, aa);
			wv = clamp((f.y - lo.y) / max(hi.y - lo.y, 0.01), 0.0, 1.0);
			// Coverage average once a cell is only a few pixels wide.
			float far = smoothstep(0.12, 0.40, max(aa.x, aa.y));
			float cover = clamp((hi.x - lo.x) * (hi.y - lo.y), 0.0, 1.0);
			glass = mix(glass, cover * 0.85, far);
			wv = mix(wv, 0.5, far);
			if (y < 0.0 || f.y < 0.0) {
				glass = 0.0;
			}
		}
	}
	// Glass: dark with a sky gradient, a little different per window, some
	// with drawn curtains; curtain walls a cooler blue-green.
	float r = hash(cid + vec2(floor(wpos.x * 0.01), floor(wpos.z * 0.01)));
	vec3 g = mix(glass_dark.rgb, glass_sky.rgb, clamp(0.18 + 0.55 * wv + 0.22 * r, 0.0, 1.0));
	g = mix(g, g * vec3(0.80, 0.98, 1.02), tint);
	g = mix(g, curtain.rgb, step(0.84, hash(cid + vec2(3.1, 7.7))) * 0.55 * (1.0 - tint));
	ALBEDO = mix(col, g, glass);
	ROUGHNESS = mix(0.84, 0.16, glass);
	SPECULAR = mix(0.25, 0.65, glass);
}
