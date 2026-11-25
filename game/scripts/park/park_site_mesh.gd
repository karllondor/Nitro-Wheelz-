extends RefCounted
## One opaque, vertex-coloured surface per batch. The material is replaceable.
const KIT = preload("res://scripts/vehicles/mesh_kit.gd")
var surface := SurfaceTool.new()

func _init() -> void:
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)

func box(at: Vector3, size: Vector3, color: Color, basis := Basis.IDENTITY) -> void:
    surface.set_color(color)
    KIT.box(surface, Transform3D(basis, at), size)

func round_shape(at: Vector3, radii: Vector3, color: Color, exponent := 1.0) -> void:
    surface.set_color(color)
    KIT.superellipsoid(surface, Transform3D(Basis.IDENTITY, at), radii, exponent, 10, 6)

func triangle(a: Vector3, b: Vector3, c: Vector3, normal: Vector3, color: Color) -> void:
    surface.set_color(color)
    KIT.tri(surface, a, b, c, normal, normal, normal)

func quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, y: float, tint: Color) -> void:
    surface.set_color(tint)
    surface.set_normal(Vector3.UP)
    var points: Array[Vector2] = [a, b, c, c, b, d]
    if (b - a).cross(c - a) < 0.0:
        points = [a, c, b, c, d, b]
    for p in points:
        surface.set_uv(p / 7.0)
        surface.add_vertex(Vector3(p.x, y, p.y))

func rect(bounds: Rect2, y: float, color: Color) -> void:
    quad(bounds.position, Vector2(bounds.end.x, bounds.position.y),
        Vector2(bounds.position.x, bounds.end.y), bounds.end, y, color)

func strip(path: PackedVector2Array, width: float, offset: float, y: float, color: Color,
        closed := false, dash := false, gaps := PackedVector2Array()) -> void:
    var left := PackedVector2Array()
    var right := PackedVector2Array()
    var count := path.size()
    for i in range(count):
        var a := path[(i + count - 1) % count] if closed or i > 0 else path[i]
        var b := path[(i + 1) % count] if closed or i < count - 1 else path[i]
        var tangent := (b - a).normalized()
        var normal := Vector2(-tangent.y, tangent.x)
        left.append(path[i] + normal * (offset - width * 0.5))
        right.append(path[i] + normal * (offset + width * 0.5))
    var distance := 0.0
    for i in range(count if closed else count - 1):
        var j := (i + 1) % count
        var mid := (path[i] + path[j]) * 0.5
        distance += path[i].distance_to(path[j])
        if dash and fposmod(distance, 9.0) > 5.0:
            continue
        var skip := false
        for gap in gaps:
            if mid.distance_squared_to(gap) < 169.0:
                skip = true
                break
        if not skip:
            quad(left[i], right[i], left[j], right[j], y, color)

func commit(parent: Node3D, label: String, texture: Texture2D = null, shaded := true) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    var material := StandardMaterial3D.new()
    material.albedo_texture = texture
    material.vertex_color_use_as_albedo = true
    material.resource_name = label
    if not shaded:
        material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    node.name = label
    node.mesh = surface.commit()
    node.material_override = material
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(node)
    return node
