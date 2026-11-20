// Nitro Wheelz terrain vegetation (MultiMesh, one mesh per species).
// COLOR = baked vertex shading x per-instance species colour (MultiMesh
// colours). UV.x marks foliage (1) vs trunk / branches (0): trunks use a
// fixed bark colour. Foliage sways a little with height.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform float sway = 1.0;
uniform vec4 bark : source_color = vec4(0.30, 0.22, 0.16, 1.0);
varying float foliage;

void vertex() {
	foliage = UV.x;
	vec3 root = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float h = max(VERTEX.y - 0.25, 0.0) * UV.x;
	float ph = TIME * 1.1 + root.x * 0.045 + root.z * 0.061;
	VERTEX.x += sin(ph) * sway * h * 0.025;
	VERTEX.z += cos(ph * 0.83) * sway * h * 0.02;
}

void fragment() {
	ALBEDO = mix(bark.rgb, COLOR.rgb, foliage);
	ROUGHNESS = 0.9;
	SPECULAR = 0.2;
}
