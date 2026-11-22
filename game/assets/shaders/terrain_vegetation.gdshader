// Nitro Wheelz terrain vegetation (MultiMesh, one mesh per species).
// COLOR = baked vertex shading x per-instance species colour (MultiMesh
// colours). UV.x marks foliage (1) vs trunk / branches (0): trunks use a
// fixed bark colour. Foliage sways a little with height.
//
// Two ways to feed the sway (issue #20):
//  * MultiMesh species (trees): unit-size mesh scaled by the instance, so the
//    lever is the mesh height (VERTEX.y) and the phase comes from the
//    instance's world position (MODEL_MATRIX);
//  * merged meshes (roadside planting, baked = 1): many plants share ONE mesh
//    whose vertices are in chunk-local METRES - VERTEX.y is then the absolute
//    terrain height (the chunk centre is at y = 0), not the height above the
//    plant's own root, and MODEL_MATRIX is the chunk centre. v0.1.33 used the
//    MultiMesh formula there: a bush on 20 m terrain slid 0.5 m, on 100 m
//    terrain 2.5 m, as a whole. The merge now bakes the lever in metres (the
//    plant's own height above its root, UV2.x) and the phase (UV2.y).
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform float sway = 1.0;
uniform float baked = 0.0;
uniform vec4 bark : source_color = vec4(0.30, 0.22, 0.16, 1.0);
varying float foliage;

void vertex() {
	foliage = UV.x;
	float h;
	float ph;
	if (baked > 0.5) {
		h = UV2.x;
		ph = TIME * 1.1 + UV2.y;
	} else {
		vec3 root = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
		h = max(VERTEX.y - 0.25, 0.0) * UV.x;
		ph = TIME * 1.1 + root.x * 0.045 + root.z * 0.061;
	}
	VERTEX.x += sin(ph) * sway * h * 0.025;
	VERTEX.z += cos(ph * 0.83) * sway * h * 0.02;
}

void fragment() {
	ALBEDO = mix(bark.rgb, COLOR.rgb, foliage);
	ROUGHNESS = 0.9;
	SPECULAR = 0.2;
}
