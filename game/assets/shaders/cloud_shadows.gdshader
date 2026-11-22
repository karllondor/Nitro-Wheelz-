// Soft cloud shadows drifting across the circuit (world-space projection of
// the sky's cloud texture). A single transparent plane above the ground,
// road and kerbs but below the car: cheap on mobile, no shadow maps.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D clouds : repeat_enable, filter_linear_mipmap;
uniform vec2 wind = vec2(1.8, 0.7);       // metres per second
uniform float scale_m = 64.0;             // metres per texture tile (v0.1.36: was 150 = huge patches)
uniform float coverage : hint_range(0.0, 1.0) = 0.56;   // v0.1.36: was 0.46 = fewer, smaller patches
uniform float strength : hint_range(0.0, 1.0) = 0.26;   // v0.1.36: was 0.55 = the track went suddenly dark
uniform vec4 shade : source_color = vec4(0.04, 0.03, 0.10, 1.0);

varying vec2 world_xz;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 uv = (world_xz + TIME * wind) / scale_m;
	// Blurred mip levels: broad soft cloud shapes, not smoky detail.
	float c = textureLod(clouds, uv, 3.2).r * 0.8 + textureLod(clouds, uv * 1.7 + 0.31, 3.6).r * 0.2;
	float a = smoothstep(coverage, coverage + 0.22, c) * strength;
	ALBEDO = shade.rgb;
	ALPHA = a;
}
