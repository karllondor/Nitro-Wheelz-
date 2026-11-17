extends Node3D
class_name NitroDriftTrack
## Original fictional Japanese circuit, built from spline samples. No real circuit map.

const HALF_ROAD_WIDTH: float = 8.2
const SAMPLE_SUBDIVISIONS: int = 12
const CONTROL_POINTS: Array[Vector2] = [
    Vector2(-65, -50), Vector2(-35, -78), Vector2(12, -84),
    Vector2(63, -67), Vector2(85, -30), Vector2(79, 12),
    Vector2(48, 32), Vector2(11, 26), Vector2(-10, 45),
    Vector2(-13, 76), Vector2(-54, 78), Vector2(-83, 36),
    Vector2(-90, -10)
]

var centerline: Array[Vector2] = []
var arc_lengths: PackedFloat32Array = PackedFloat32Array()
var length_metres: float = 0.0

func _ready() -> void:
    if centerline.is_empty():
        build()

func build() -> void:
    centerline.clear()
    var count: int = CONTROL_POINTS.size()
    for i in range(count):
        var p0: Vector2 = CONTROL_POINTS[(i - 1 + count) % count]
        var p1: Vector2 = CONTROL_POINTS[i]
        var p2: Vector2 = CONTROL_POINTS[(i + 1) % count]
        var p3: Vector2 = CONTROL_POINTS[(i + 2) % count]
        for segment in range(SAMPLE_SUBDIVISIONS):
            var t: float = float(segment) / float(SAMPLE_SUBDIVISIONS)
            var point: Vector2 = 0.5 * (
                2.0 * p1 + (-p0 + p2) * t +
                (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t +
                (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t
            )
            centerline.append(point)
    arc_lengths = PackedFloat32Array()
    length_metres = 0.0
    for i in range(centerline.size()):
        arc_lengths.append(length_metres)
        length_metres += centerline[i].distance_to(centerline[(i + 1) % centerline.size()])
    _build_environment()
    _add_ribbon("Tarmac", 0.0, HALF_ROAD_WIDTH, 0.04, Color(0.17,0.18,0.21))
    _add_ribbon("Kerbs", 0.0, HALF_ROAD_WIDTH + 1.6, 0.012, Color(0.43,0.37,0.31))
    # Re-add tarmac above kerbs so only the coloured outside shoulder remains.
    _add_ribbon("Driving Surface", 0.0, HALF_ROAD_WIDTH, 0.05, Color(0.19,0.19,0.215))
    _add_ribbon("White edge left", -HALF_ROAD_WIDTH + 0.55, 0.10, 0.065, Color(0.84,0.85,0.83))
    _add_ribbon("White edge right", HALF_ROAD_WIDTH - 0.55, 0.10, 0.065, Color(0.84,0.85,0.83))
    _build_start_line()
    _build_barriers()
    _build_track_props()

func start_position() -> Vector2:
    return centerline[0]

func start_heading() -> float:
    var tangent: Vector2 = (centerline[5] - centerline[0]).normalized()
    return atan2(tangent.x, -tangent.y)

func sample_info(pos: Vector2) -> Dictionary:
    var best_sq: float = INF
    var closest: Vector2 = Vector2.ZERO
    var closest_index: int = 0
    var segment_t: float = 0.0
    for i in range(centerline.size()):
        var start: Vector2 = centerline[i]
        var end: Vector2 = centerline[(i + 1) % centerline.size()]
        var direction: Vector2 = end - start
        var denom: float = maxf(direction.length_squared(), 0.00001)
        var t: float = clampf((pos - start).dot(direction) / denom, 0.0, 1.0)
        var p: Vector2 = start + direction * t
        var squared_distance: float = pos.distance_squared_to(p)
        if squared_distance < best_sq:
            best_sq = squared_distance
            closest = p
            closest_index = i
            segment_t = t
    var next_index: int = (closest_index + 1) % centerline.size()
    var portion: float = (arc_lengths[closest_index] +
        centerline[closest_index].distance_to(centerline[next_index]) * segment_t
    ) / maxf(length_metres, 1.0)
    return {"distance": sqrt(best_sq), "point": closest, "index": closest_index,
        "progress": portion, "tangent": (
            centerline[next_index] - centerline[closest_index]).normalized()}

func _tangent(i: int) -> Vector2:
    var count: int = centerline.size()
    return (centerline[(i + 1) % count] - centerline[(i - 1 + count) % count]).normalized()

func _add_ribbon(name: String, offset: float, half_width: float, height: float, tint: Color) -> void:
    var mesh := SurfaceTool.new()
    mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
    for i in range(centerline.size()):
        var next_index: int = (i + 1) % centerline.size()
        var n0: Vector2 = Vector2(-_tangent(i).y, _tangent(i).x)
        var n1: Vector2 = Vector2(-_tangent(next_index).y, _tangent(next_index).x)
        var a: Vector2 = centerline[i] + n0 * (offset - half_width)
        var b: Vector2 = centerline[i] + n0 * (offset + half_width)
        var c: Vector2 = centerline[next_index] + n1 * (offset - half_width)
        var d: Vector2 = centerline[next_index] + n1 * (offset + half_width)
        for p in [a,c,b,b,c,d]:
            mesh.set_normal(Vector3.UP)
            mesh.set_color(tint)
            mesh.add_vertex(Vector3(p.x,height,p.y))
    var result: ArrayMesh = mesh.commit()
    var material := StandardMaterial3D.new()
    material.vertex_color_use_as_albedo = true
    material.roughness = 0.98
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    result.surface_set_material(0, material)
    var instance := MeshInstance3D.new()
    instance.name = name
    instance.mesh = result
    add_child(instance)

func _build_environment() -> void:
    var plane := MeshInstance3D.new()
    plane.name = "Japanese drift park earth"
    var ground := PlaneMesh.new()
    ground.size = Vector2(360, 360)
    plane.mesh = ground
    plane.position.y = -0.08
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.31,0.27,0.22)
    mat.roughness = 1.0
    plane.material_override = mat
    add_child(plane)

    var sun := DirectionalLight3D.new()
    sun.name = "Late dusk sky"
    sun.rotation_degrees = Vector3(-58, -33, -12)
    sun.light_color = Color(1.0,0.75,0.59)
    sun.light_energy = 0.95
    sun.shadow_enabled = false
    add_child(sun)

    var env := WorldEnvironment.new()
    var resource := Environment.new()
    resource.background_mode = Environment.BG_COLOR
    resource.background_color = Color(0.11,0.14,0.22)
    resource.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    resource.ambient_light_color = Color(0.62,0.7,0.78)
    resource.ambient_light_energy = 0.7
    env.environment = resource
    add_child(env)

func _build_start_line() -> void:
    var p: Vector2 = centerline[0]
    var tangent: Vector2 = _tangent(0)
    var lateral: Vector2 = Vector2(-tangent.y,tangent.x)
    var size: float = 1.2
    for tile in range(14):
        for stripe in range(2):
            var board := MeshInstance3D.new()
            var tile_mesh := BoxMesh.new()
            tile_mesh.size = Vector3(size,0.025,size)
            board.mesh = tile_mesh
            var offset: float = -7.5 + (float(tile) + 0.5) * (15.0/14.0)
            var delta: float = (float(stripe)-0.5)*size
            var world_point: Vector2 = p + lateral*offset + tangent*delta
            board.position = Vector3(world_point.x, 0.092, world_point.y)
            board.rotation.y = atan2(tangent.x,-tangent.y)
            var material := StandardMaterial3D.new()
            material.albedo_color = Color.WHITE if (tile+stripe)%2==0 else Color(0.055,0.055,0.06)
            material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
            board.material_override = material
            add_child(board)

func _build_barriers() -> void:
    for i in range(0, centerline.size(), 4):
        var tangent: Vector2 = _tangent(i)
        var lateral: Vector2 = Vector2(-tangent.y,tangent.x)
        for side in [-1.0,1.0]:
            var p: Vector2 = centerline[i] + lateral*(HALF_ROAD_WIDTH+1.4)*side
            var item := MeshInstance3D.new()
            var cube := BoxMesh.new()
            cube.size = Vector3(3.5,0.55,0.45)
            item.mesh = cube
            item.position = Vector3(p.x,0.31,p.y)
            item.rotation.y = atan2(tangent.x,-tangent.y) + PI/2.0
            var mat := StandardMaterial3D.new()
            mat.albedo_color = Color(0.95,0.75,0.3) if (i/4)%2 == 0 else Color(0.17,0.18,0.2)
            item.material_override = mat
            add_child(item)

func _build_track_props() -> void:
    # Sparse low-poly scenery; no branded venues or real-world circuit layouts.
    for i in range(0, centerline.size(), 13):
        var tangent: Vector2 = _tangent(i)
        var lateral: Vector2 = Vector2(-tangent.y,tangent.x)
        var offset: float = 25.0 if (i/13)%2 == 0 else -23.0
        var p: Vector2 = centerline[i] + lateral*offset
        var trunk := MeshInstance3D.new()
        var stem := CylinderMesh.new()
        stem.top_radius = 0.35
        stem.bottom_radius = 0.45
        stem.height = 3.8
        trunk.mesh = stem
        trunk.position = Vector3(p.x,1.9,p.y)
        var bark := StandardMaterial3D.new()
        bark.albedo_color = Color(0.20,0.16,0.15)
        trunk.material_override = bark
        add_child(trunk)
        for tier in range(3):
            var tree := MeshInstance3D.new()
            var cone := CylinderMesh.new()
            cone.top_radius = 0.05
            cone.bottom_radius = 2.7 - tier*0.45
            cone.height = 3.7
            tree.mesh = cone
            tree.position = Vector3(p.x,3.5+tier*1.8,p.y)
            var needles := StandardMaterial3D.new()
            needles.albedo_color = Color(0.13,0.27,0.23) if tier%2 == 0 else Color(0.12,0.21,0.19)
            tree.material_override = needles
            add_child(tree)

