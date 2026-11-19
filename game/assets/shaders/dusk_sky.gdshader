// Nitro Wheelz golden-hour sky: violet zenith, warm horizon, sun glow and
// drifting procedural clouds sampled from the same tileable cloud texture
// that drives the cloud shadows on the circuit.
shader_type sky;

uniform sampler2D clouds : repeat_enable, filter_linear_mipmap;
uniform vec4 zenith : source_color = vec4(0.16, 0.20, 0.42, 1.0);
uniform vec4 horizon : source_color = vec4(0.98, 0.62, 0.52, 1.0);
uniform vec4 ground : source_color = vec4(0.10, 0.10, 0.14, 1.0);
uniform vec4 sun_colour : source_color = vec4(1.0, 0.80, 0.55, 1.0);
uniform vec3 sun_dir = vec3(-0.45, 0.22, -0.86);
uniform vec2 wind = vec2(0.006, 0.002);
uniform float coverage : hint_range(0.0, 1.0) = 0.42;

void sky() {
	vec3 d = normalize(EYEDIR);
	float up = clamp(d.y, -1.0, 1.0);
	vec3 col = mix(horizon.rgb, zenith.rgb, pow(clamp(up, 0.0, 1.0), 0.55));
	col = mix(col, ground.rgb, smoothstep(0.0, -0.08, up));
	float sun = max(dot(d, normalize(sun_dir)), 0.0);
	col += sun_colour.rgb * (pow(sun, 12.0) * 0.55 + pow(sun, 400.0) * 2.0);
	if (up > 0.0) {
		vec2 uv = d.xz / (up + 0.10) * 0.13 + TIME * wind;
		float c = texture(clouds, uv).r * 0.7 + texture(clouds, uv * 2.3 + 0.37).r * 0.3;
		float density = smoothstep(coverage, coverage + 0.22, c) * smoothstep(0.0, 0.05, up);
		vec3 cloud_lit = mix(vec3(0.95, 0.72, 0.70), vec3(1.0, 0.93, 0.86), pow(sun, 3.0));
		vec3 cloud_shade = vec3(0.42, 0.38, 0.55);
		vec3 cloud = mix(cloud_lit, cloud_shade, smoothstep(0.55, 1.0, c));
		col = mix(col, cloud, density * 0.92);
	}
	COLOR = col;
}
