extends Node3D
class_name NitroDriftTrack
## Nitro Track DNA v1: visual surfaces, solid barrier meshes and analytic
## vehicle contacts all derive from the SAME validated sampled corridor.
## The planar arcade car intentionally uses deterministic analytic contacts;
## the identical triangles are also exposed to the Godot physics engine.

const TRACK_DATA: String = "res://tracks/shin_kawa_v2.json"
const DNA = preload("res://scripts/world/track_dna.gd")
const HALF_ROAD_WIDTH: float = 12.0  # legacy test compatibility, local widths vary
const CAR_WALL_CLEARANCE: float = 1.18
const WALL_HEIGHT: float = 1.30
const WALL_THICKNESS: float = 0.40

var centerline: Array[Vector2] = []
var left_edge: Array[Vector2] = []
var right_edge: Array[Vector2] = []
var halfwidths: PackedFloat32Array = PackedFloat32Array()
var arc_lengths: PackedFloat32Array = PackedFloat32Array()
var length_metres: float = 0.0
var validation_errors: PackedStringArray = PackedStringArray()
var track_valid: bool = false
var track_id: String = ""

func _ready() -> void:
    if centerline.is_empty():
        build()

func build() -> void:
    var compiled: Dictionary = DNA.read_track(TRACK_DATA)
    _apply_compiled(compiled)

func rebuild_from_data(data: Dictionary) -> bool:
    # Future editor entrypoint: reject invalid data without replacing the
    # currently playable track. No accidental broken geometry is generated.
    var compiled: Dictionary = DNA.compile(data)
    if not bool(compiled.get("ok",false)):
        validation_errors = compiled["errors"]
        return false
    _apply_compiled(compiled)
    return true

func _apply_compiled(compiled: Dictionary) -> void:
    track_valid = bool(compiled.get("ok",false))
    validation_errors = compiled.get("errors",PackedStringArray())
    if not track_valid:
        push_error("Nitro Track DNA rejected circuit: "+str(validation_errors))
        return
    for child in get_children():
        remove_child(child)
        child.queue_free()
    centerline = compiled["centerline"]
    left_edge = compiled["left_edge"]
    right_edge = compiled["right_edge"]
    halfwidths = compiled["halfwidths"]
    arc_lengths = compiled["arc_lengths"]
    length_metres = float(compiled["length_metres"])
    track_id = str(compiled["track_id"])
    _build_environment()
    _add_corridor("Compacted shoulder",_shift_edge(left_edge,-1.8),
        _shift_edge(right_edge,1.8),0.018,Color(0.43,0.37,0.31))
    _add_corridor("Single continuous driving surface",left_edge,right_edge,
        0.05,Color(0.19,0.19,0.215))
    _add_corridor("White edge left",_shift_edge(left_edge,0.49),
        _shift_edge(left_edge,0.61),0.066,Color(0.87,0.87,0.85))
    _add_corridor("White edge right",_shift_edge(right_edge,-0.61),
        _shift_edge(right_edge,-0.49),0.066,Color(0.87,0.87,0.85))
    _build_start_line()
    _build_barriers()
    _build_track_props()

func _shift_edge(edge: Array[Vector2], metres: float) -> Array[Vector2]:
    var shifted: Array[Vector2] = []
    for i in range(edge.size()):
        var inward: Vector2 = (right_edge[i]-left_edge[i]).normalized()
        shifted.append(edge[i]+inward*metres)
    return shifted

func start_position() -> Vector2:
    return centerline[0]

func start_heading() -> float:
    var tangent: Vector2 = (centerline[1]-centerline[centerline.size()-1]).normalized()
    return atan2(tangent.x,-tangent.y)

func sample_info(pos: Vector2) -> Dictionary:
    var best_sq: float = INF
    var index: int = 0
    var nearest: Vector2 = Vector2.ZERO
    var segment_t: float = 0.0
    var n: int = centerline.size()
    for i in range(n):
        var a: Vector2 = centerline[i]
        var b: Vector2 = centerline[(i+1)%n]
        var delta: Vector2 = b-a
        var t: float = clampf((pos-a).dot(delta)/maxf(delta.length_squared(),0.000001),0.0,1.0)
        var p: Vector2 = a+delta*t
        var dsq: float = pos.distance_squared_to(p)
        if dsq < best_sq:
            best_sq=dsq
            index=i
            nearest=p
            segment_t=t
    var next_i: int = (index+1)%n
    var segment: Vector2 = centerline[next_i]-centerline[index]
    var width: float = lerpf(halfwidths[index],halfwidths[next_i],segment_t)
    var progress: float = (arc_lengths[index]+segment.length()*segment_t)/maxf(length_metres,1.0)
    return {"distance":sqrt(best_sq),"point":nearest,"index":index,
        "t":segment_t,"width":width,"progress":progress,
        "tangent":segment.normalized()}

func resolve_wall(pos: Vector2, travel_velocity: Vector2) -> Dictionary:
    # Derive analytic contact from the *same sampled edge segments*
    # used for the blue/white wall mesh. Not a distance-to-centre fudge.
    var info: Dictionary = sample_info(pos)
    var i: int = int(info["index"])
    var next_i: int = (i+1)%centerline.size()
    var t: float = float(info["t"])
    var normal: Vector2 = (right_edge[i].lerp(right_edge[next_i],t) -
        left_edge[i].lerp(left_edge[next_i],t)).normalized()
    var side: float = -1.0 if (pos-Vector2(info["point"])).dot(normal)<0.0 else 1.0
    var boundary: Vector2 = left_edge[i].lerp(left_edge[next_i],t) if side<0 else right_edge[i].lerp(right_edge[next_i],t)
    var outward: Vector2 = normal*side
    var safe_centre: Vector2 = boundary-outward*(CAR_WALL_CLEARANCE+0.10)
    var penetration: float = (pos-safe_centre).dot(outward)
    if penetration <= 0.0:
        return {"hit":false,"position":pos,"velocity":travel_velocity,
            "impact_speed":0.0,"normal":Vector2.ZERO}
    var outward_speed: float = maxf(travel_velocity.dot(outward),0.0)
    var reflected: Vector2 = (travel_velocity-outward*(1.18*outward_speed))*0.80
    var corrected: Vector2 = pos-outward*(penetration+0.005)
    return {"hit":true,"position":corrected,"velocity":reflected,
        "impact_speed":outward_speed,"normal":outward}

func _add_corridor(label: String,a: Array[Vector2],b: Array[Vector2],
        height: float,tint: Color) -> void:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for i in range(centerline.size()):
        var next_i: int = (i+1)%centerline.size()
        var p: Vector3 = Vector3(a[i].x,height,a[i].y)
        var q: Vector3 = Vector3(b[i].x,height,b[i].y)
        var r: Vector3 = Vector3(a[next_i].x,height,a[next_i].y)
        var u: Vector3 = Vector3(b[next_i].x,height,b[next_i].y)
        _add_tri(st,p,r,q,tint)
        _add_tri(st,q,r,u,tint)
    var arr: ArrayMesh = st.commit()
    var mat := StandardMaterial3D.new()
    mat.vertex_color_use_as_albedo = true
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    arr.surface_set_material(0,mat)
    var mesh := MeshInstance3D.new()
    mesh.name = label
    mesh.mesh = arr
    add_child(mesh)

func _add_tri(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,
        tint: Color,vertices: PackedVector3Array = PackedVector3Array()) -> void:
    for p in [a,b,c]:
        st.set_color(tint)
        st.set_normal(Vector3.UP)
        st.add_vertex(p)
        # Optional collision vertices are returned by explicit wall helper.

func _wall_tri(st: SurfaceTool,vertices: PackedVector3Array,
        a: Vector3,b: Vector3,c: Vector3,tint: Color) -> void:
    for p in [a,b,c]:
        st.set_color(tint)
        st.set_normal(Vector3.UP)
        st.add_vertex(p)
        vertices.append(p)

func _build_barriers() -> void:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var triangles := PackedVector3Array()
    var count: int = centerline.size()
    for i in range(count):
        var next_i: int = (i+1)%count
        var colour: Color = Color(0.90,0.92,0.91) if int(i/3)%2==0 else Color(0.14,0.42,0.69)
        var n0: Vector2 = (right_edge[i]-left_edge[i]).normalized()
        var n1: Vector2 = (right_edge[next_i]-left_edge[next_i]).normalized()
        for side in [-1.0,1.0]:
            var p: Vector2 = left_edge[i] if side<0 else right_edge[i]
            var q: Vector2 = left_edge[next_i] if side<0 else right_edge[next_i]
            p += n0*side*0.10
            q += n1*side*0.10
            var bottom_a := Vector3(p.x,0.055,p.y)
            var bottom_b := Vector3(q.x,0.055,q.y)
            var top_a := Vector3(p.x,WALL_HEIGHT,p.y)
            var top_b := Vector3(q.x,WALL_HEIGHT,q.y)
            var outer_p: Vector2 = p+n0*side*WALL_THICKNESS
            var outer_q: Vector2 = q+n1*side*WALL_THICKNESS
            var outside_a := Vector3(outer_p.x,WALL_HEIGHT,outer_p.y)
            var outside_b := Vector3(outer_q.x,WALL_HEIGHT,outer_q.y)
            _wall_tri(st,triangles,bottom_a,bottom_b,top_a,colour)
            _wall_tri(st,triangles,top_a,bottom_b,top_b,colour)
            _wall_tri(st,triangles,top_a,top_b,outside_a,colour)
            _wall_tri(st,triangles,outside_a,top_b,outside_b,colour)
    var mesh: ArrayMesh = st.commit()
    var mat := StandardMaterial3D.new()
    mat.vertex_color_use_as_albedo = true
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mesh.surface_set_material(0,mat)
    var visual := MeshInstance3D.new()
    visual.name = "Walls from Track DNA edges"
    visual.mesh = mesh
    add_child(visual)
    var body := StaticBody3D.new()
    body.name = "Exactly matched wall triangle collision mesh"
    var collider := CollisionShape3D.new()
    var shape := ConcavePolygonShape3D.new()
    shape.data = triangles
    collider.shape = shape
    body.add_child(collider)
    add_child(body)

func _build_start_line() -> void:
    var p: Vector2 = start_position()
    var t: Vector2 = (centerline[1]-centerline[centerline.size()-1]).normalized()
    var across: Vector2 = (right_edge[0]-left_edge[0]).normalized()
    var road_width: float = halfwidths[0]*2.0
    var tiles: int = 20
    for tile in range(tiles):
        for stripe in range(2):
            var board := MeshInstance3D.new()
            var box := BoxMesh.new()
            box.size = Vector3(road_width/float(tiles),0.025,0.58)
            board.mesh = box
            var lateral: float = -halfwidths[0]+(float(tile)+0.5)*road_width/float(tiles)
            var longitudinal: float = (float(stripe)-0.5)*0.58
            var pt: Vector2 = p+across*lateral+t*longitudinal
            board.position = Vector3(pt.x,0.094,pt.y)
            board.rotation.y = -start_heading()
            var material := StandardMaterial3D.new()
            material.albedo_color = Color.WHITE if (tile+stripe)%2==0 else Color(0.055,0.055,0.06)
            material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
            board.material_override = material
            add_child(board)

func _build_environment() -> void:
    var plane := MeshInstance3D.new()
    plane.name = "Ground outside track"
    var ground := PlaneMesh.new()
    ground.size = Vector2(650,650)
    plane.mesh = ground
    plane.position.y = -0.08
    var m := StandardMaterial3D.new()
    m.albedo_color = Color(0.31,0.27,0.22)
    plane.material_override = m
    add_child(plane)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-58,-33,-12)
    sun.light_color = Color(1.0,0.75,0.59)
    sun.light_energy = 0.95
    sun.shadow_enabled = false
    add_child(sun)
    var env := WorldEnvironment.new()
    var res := Environment.new()
    res.background_mode = Environment.BG_COLOR
    res.background_color = Color(0.11,0.14,0.22)
    res.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    res.ambient_light_color = Color(0.62,0.7,0.78)
    res.ambient_light_energy = 0.7
    env.environment = res
    add_child(env)

func _build_track_props() -> void:
    # Every prop is rejected if it would approach any other branch of road.
    # The global query matters on U-turns and hairpins.
    for i in range(0,centerline.size(),13):
        var t: Vector2 = (centerline[(i+1)%centerline.size()]-
            centerline[(i-1+centerline.size())%centerline.size()]).normalized()
        var n: Vector2 = Vector2(-t.y,t.x)
        var offset: float = halfwidths[i]+19.0
        var pos: Vector2 = centerline[i]+n*offset*(1.0 if (i/13)%2==0 else -1.0)
        var check: Dictionary = sample_info(pos)
        if float(check["distance"]) < float(check["width"])+6.0:
            continue
        var trunk := MeshInstance3D.new()
        var stem := CylinderMesh.new()
        stem.top_radius = 0.35
        stem.bottom_radius = 0.45
        stem.height = 3.8
        trunk.mesh = stem
        trunk.position = Vector3(pos.x,1.9,pos.y)
        var bark := StandardMaterial3D.new()
        bark.albedo_color = Color(0.20,0.16,0.15)
        trunk.material_override = bark
        add_child(trunk)
        for tier in range(3):
            var tree := MeshInstance3D.new()
            var cone := CylinderMesh.new()
            cone.top_radius = 0.05
            cone.bottom_radius = 2.7-float(tier)*0.45
            cone.height = 3.7
            tree.mesh = cone
            tree.position = Vector3(pos.x,3.5+float(tier)*1.8,pos.y)
            var needles := StandardMaterial3D.new()
            needles.albedo_color = Color(0.13,0.27,0.23) if tier%2==0 else Color(0.12,0.21,0.19)
            tree.material_override = needles
            add_child(tree)
