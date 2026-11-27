// Nitro Wheelz FOREST LAB tree (issue #54): ONE opaque material for every species / LOD / season.
// COLOR = the baked absolute palette (vertex colours, linear) x the per-instance tint of the MultiMesh (near white,
// +-8 % so a stand of one species does not look cloned). UV.x marks foliage (1) vs wood (0): only foliage sways,
// by the same DEVELOPER > VEGETATION WIND factor as the CLASSIC trees (uniform `sway`, 1 = the build's default).
// The meshes are in METRES (a tree is ~10 units tall) and the instance scale is ~1, so the lever is the height above
// the root. No alpha, no textures, no per-fragment tricks: GL Compatibility / mobile safe.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform float sway = 1.0;

void vertex() {
	vec3 root = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float h = max(VERTEX.y - 0.6, 0.0) * UV.x;
	float ph = TIME * 1.1 + root.x * 0.045 + root.z * 0.061;
	VERTEX.x += sin(ph) * sway * h * 0.0042;
	VERTEX.z += cos(ph * 0.83) * sway * h * 0.0034;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.92;
	SPECULAR = 0.15;
}
