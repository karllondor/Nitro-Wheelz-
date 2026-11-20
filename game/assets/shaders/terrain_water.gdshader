// Nitro Wheelz sea / stream: deep colour with a fresnel sky tint and slow
// world-space ripples (detail texture scrolled in two directions).
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

uniform vec4 deep : source_color = vec4(0.06, 0.20, 0.28, 1.0);
uniform vec4 shallow : source_color = vec4(0.16, 0.38, 0.42, 1.0);
uniform vec4 sky : source_color = vec4(0.75, 0.82, 0.88, 1.0);
uniform sampler2D detail : filter_linear_mipmap, repeat_enable;
varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float r1 = texture(detail, wpos.xz / 60.0 + vec2(TIME * 0.006, TIME * 0.003)).r;
	float r2 = texture(detail, wpos.xz / 23.0 - vec2(TIME * 0.004, TIME * 0.007)).r;
	float ripple = r1 * 0.5 + r2 * 0.5;
	vec3 n = normalize(NORMAL);
	vec3 v = normalize(VIEW);
	float fres = pow(1.0 - clamp(dot(n, v), 0.0, 1.0), 3.0);
	vec3 base = mix(deep.rgb, shallow.rgb, ripple * 0.6);
	ALBEDO = base;
	EMISSION = sky.rgb * fres * 0.35 + vec3(0.9) * smoothstep(0.78, 0.92, ripple) * 0.08;
	ROUGHNESS = 0.12;
	METALLIC = 0.0;
	SPECULAR = 0.6;
}
