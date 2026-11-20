// Nitro Wheelz terrain: vertex-coloured ground (grass / forest floor / rock /
// snow / seasonal tint baked per vertex by the terrain generator) with a
// world-space detail texture so large flat areas do not look plastic.
// GL Compatibility friendly (one texture, no triplanar).
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D detail : filter_linear_mipmap, repeat_enable;
uniform float detail_strength : hint_range(0.0, 1.0) = 0.36;
varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float a = texture(detail, wpos.xz / 41.0).r;
	float b = texture(detail, wpos.xz / 9.0).r;
	float d = a * 0.6 + b * 0.4;
	ALBEDO = COLOR.rgb * (1.0 - detail_strength * 0.5 + detail_strength * d);
	ROUGHNESS = 0.94;
	SPECULAR = 0.18;
}
