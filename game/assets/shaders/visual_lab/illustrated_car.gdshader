// Nitro Wheelz Visual Lab C: single-geometry, mobile GL Compatibility
// Keep Car Factory variant hiding and livery UVs. No outline passes.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_disabled;

uniform float variant_slot = 0.0;
uniform float atlas_on = 0.0;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D livery_tex : source_color, hint_default_transparent, filter_linear_mipmap, repeat_disable;
uniform float livery_on = 0.0;
uniform vec4 paint : source_color = vec4(0.85, 0.85, 0.85, 1.0);
uniform float night_lift = 0.0;

void vertex() {
    if (UV2.x > 0.5 && abs(UV2.x - variant_slot) > 0.25) {
        VERTEX = vec3(0.0);
    }
}

void fragment() {
    vec3 base = paint.rgb;
    if (atlas_on > 0.5) {
        base = texture(albedo_tex, UV).rgb;
    } else if (livery_on > 0.5) {
        vec4 ink = texture(livery_tex, UV);
        base = mix(base, ink.rgb, ink.a);
    }
    vec3 world_normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
    float elevation = smoothstep(-0.65, 0.65, world_normal.y);
    float graphic = mix(0.78, 1.0, smoothstep(0.28, 0.78, elevation));
    ALBEDO = base * (graphic + night_lift);
    ROUGHNESS = 0.94;
    METALLIC = 0.0;
    SPECULAR = 0.0;
}
