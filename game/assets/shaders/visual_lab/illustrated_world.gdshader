// Nitro Wheelz Visual Lab C: restrained editorial-illustration finish.
// A single opaque material pass, with original base textures/vertex colours.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_disabled;

uniform vec4 tint : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float use_texture = 0.0;
uniform float use_vertex_color = 0.0;
uniform float night_lift = 0.0;

void fragment() {
    vec3 base = tint.rgb;
    if (use_texture > 0.5) {
        base *= texture(albedo_tex, UV).rgb;
    }
    if (use_vertex_color > 0.5) {
        base *= COLOR.rgb;
    }
    vec3 nw = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
    float exposure = smoothstep(-0.25, 0.85, dot(nw, normalize(vec3(0.28, 0.91, 0.24))));
    float two_tone = mix(0.76, 1.0, smoothstep(0.25, 0.70, exposure));
    ALBEDO = base * (two_tone + night_lift);
    ROUGHNESS = 0.97;
    METALLIC = 0.0;
    SPECULAR = 0.0;
}
