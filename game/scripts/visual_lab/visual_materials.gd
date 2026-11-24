extends RefCounted
class_name NitroVisualLabMaterials
## Non-destructive visual-only comparison. Do not touch shared GLB resources.
## The snapshot holds material refs and per-instance overrides for exact restore.

const CAR_C = preload("res://assets/shaders/visual_lab/illustrated_car.gdshader")
const WORLD_C = preload("res://assets/shaders/visual_lab/illustrated_world.gdshader")
var entries: Array[Dictionary] = []
var _vehicle_style: String = "A"
var _world_style: String = "A"

func capture(root: Node, group: String) -> void:
    for node in root.find_children("*", "MeshInstance3D", true, false):
        var mesh_node := node as MeshInstance3D
        if mesh_node.mesh == null:
            continue
        var before: Array[Material] = []
        var original: Array[Material] = []
        for surface in range(mesh_node.mesh.get_surface_count()):
            before.append(mesh_node.get_surface_override_material(surface))
            original.append(mesh_node.get_active_material(surface))
        entries.append({
            "node": mesh_node, "group": group,
            "override": mesh_node.material_override,
            "surface_overrides": before,
            "active": original
        })

func restore() -> void:
    for entry in entries:
        var node: MeshInstance3D = entry["node"]
        if not is_instance_valid(node) or node.mesh == null:
            continue
        var before: Array[Material] = entry["surface_overrides"]
        for i in range(mini(before.size(), node.mesh.get_surface_count())):
            node.set_surface_override_material(i, before[i])
        node.material_override = entry["override"]

func set_styles(vehicle: String, environment: String, night: bool = false) -> void:
    _vehicle_style = vehicle
    _world_style = environment
    for entry in entries:
        var node: MeshInstance3D = entry["node"]
        if not is_instance_valid(node) or node.mesh == null:
            continue
        var group: String = entry["group"]
        var style: String = vehicle if group == "vehicle" else environment
        var originals: Array[Material] = entry["active"]
        var before: Array[Material] = entry["surface_overrides"]
        # A custom shader over a transparent smoke/decal or contact-shadow
        # would destroy its blending; retain those materials in both styles.
        if _preserve(node.name):
            node.material_override = entry["override"]
            for i in range(mini(before.size(), node.mesh.get_surface_count())):
                node.set_surface_override_material(i, before[i])
            continue
        node.material_override = null
        for i in range(mini(originals.size(), node.mesh.get_surface_count())):
            var src: Material = originals[i]
            var m: Material = _matte(src) if style == "A" else _illustrate(src, group, node.name, night)
            node.set_surface_override_material(i, m)

static func _preserve(name: String) -> bool:
    var n: String = name.to_lower()
    for item in ["shadow", "smoke", "skid", "inscription", "logo", "decal", "cloud", "water", "glass"]:
        if n.contains(item):
            return true
    return false

static func _has_uniform(src: ShaderMaterial, key: String) -> bool:
    if src.shader == null:
        return false
    for uniform_entry in src.shader.get_shader_uniform_list():
        if str(uniform_entry.get("name", "")) == key:
            return true
    return false

static func _parameter(src: ShaderMaterial, key: String, fallback: Variant) -> Variant:
    if _has_uniform(src, key):
        var result: Variant = src.get_shader_parameter(key)
        if result != null:
            return result
    return fallback

static func _matte(src: Material) -> Material:
    if src == null:
        return null
    var m: Material = src.duplicate() as Material
    if m is StandardMaterial3D:
        var std := m as StandardMaterial3D
        if std.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
            std.roughness = maxf(std.roughness, 0.78)
            std.metallic = minf(std.metallic, 0.12)
            std.metallic_specular = 0.25
    elif m is ShaderMaterial:
        var sm := m as ShaderMaterial
        if _has_uniform(sm, "roughness"):
            sm.set_shader_parameter("roughness", 0.55)
        if _has_uniform(sm, "gloss"):
            sm.set_shader_parameter("gloss", 0.40)
        if _has_uniform(sm, "rim"):
            sm.set_shader_parameter("rim", 0.18)
        if _has_uniform(sm, "horizon"):
            sm.set_shader_parameter("horizon", 0.40)
        if _has_uniform(sm, "detail_strength"):
            sm.set_shader_parameter("detail_strength", 0.18)
    return m

static func _illustrate(src: Material, group: String, label: String, night: bool) -> Material:
    if src == null:
        return null
    if src is BaseMaterial3D and (src as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
        return src
    var mat := ShaderMaterial.new()
    mat.shader = CAR_C if group == "vehicle" else WORLD_C
    mat.set_shader_parameter("night_lift", 0.10 if night else 0.0)
    if group == "vehicle":
        if src is ShaderMaterial:
            var sm := src as ShaderMaterial
            # GLB paint, variant selection and liveries remain in the same UVs.
            mat.set_shader_parameter("variant_slot", _parameter(sm, "variant_slot", 0.0))
            mat.set_shader_parameter("paint", _parameter(sm, "paint", Color.WHITE))
            mat.set_shader_parameter("livery_on", _parameter(sm, "livery_on", 0.0))
            var livery: Variant = _parameter(sm, "livery_tex", null)
            if livery is Texture2D:
                mat.set_shader_parameter("livery_tex", livery)
            var atlas: Variant = _parameter(sm, "albedo_tex", null)
            if atlas is Texture2D:
                mat.set_shader_parameter("albedo_tex", atlas)
                mat.set_shader_parameter("atlas_on", 1.0)
            elif not _has_uniform(sm, "paint"):
                # Unsupported shaders (e.g. glass) retain their original look.
                return src
        elif src is BaseMaterial3D:
            var std := src as BaseMaterial3D
            mat.set_shader_parameter("paint", std.albedo_color)
            if std.albedo_texture != null:
                mat.set_shader_parameter("albedo_tex", std.albedo_texture)
                mat.set_shader_parameter("atlas_on", 1.0)
        else:
            return src
    else:
        if src is BaseMaterial3D:
            var b := src as BaseMaterial3D
            mat.set_shader_parameter("tint", b.albedo_color)
            if b.albedo_texture != null:
                mat.set_shader_parameter("albedo_tex", b.albedo_texture)
                mat.set_shader_parameter("use_texture", 1.0)
        elif src is ShaderMaterial:
            var sm2 := src as ShaderMaterial
            var tex: Variant = _parameter(sm2, "albedo_tex", null)
            if not (tex is Texture2D):
                tex = _parameter(sm2, "detail", null)
            if tex is Texture2D:
                mat.set_shader_parameter("albedo_tex", tex)
                mat.set_shader_parameter("use_texture", 1.0)
            mat.set_shader_parameter("use_vertex_color", 1.0)
        else:
            return src
    return mat
