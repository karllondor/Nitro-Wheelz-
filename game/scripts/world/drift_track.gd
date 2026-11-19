extends Node3D
class_name NitroDriftTrack
## Nitro Track DNA v1: visual surfaces, solid barrier meshes and analytic
## vehicle contacts all derive from the SAME validated sampled corridor.
## The planar arcade car intentionally uses deterministic analytic contacts;
## the identical triangles are also exposed to the Godot physics engine.

const TRACK_DATA: String = "res://tracks/shin_kawa_v2.json"
var track_data_path: String = TRACK_DATA
var display_name: String = "Shin-Kawa Drift Park"
const DNA = preload("res://scripts/world/track_dna.gd")
const ASPHALT = preload("res://assets/surfaces/asphalt.webp")
const GRASS = preload("res://assets/surfaces/grass_night.webp")
const DIRT = preload("res://assets/surfaces/dirt_verge.webp")
const FLOWERS = preload("res://assets/surfaces/flower_cluster.png")
const SHADOW_SHADER = preload("res://assets/shaders/soft_shadow.gdshader")
# Night drift-park palette (approved gameplay reference: dark asphalt,
# blue/white kerbs, earth verge, olive grass, cherry blossom).
const ASPHALT_TINT := Color(0.80,0.80,0.86)
const LINE_COLOUR := Color(0.88,0.88,0.86)
const KERB_BLUE := Color(0.10,0.33,0.80)
const KERB_WHITE := Color(0.86,0.87,0.90)
const KERB_BEVEL := Color(0.09,0.09,0.11)
const BARRIER_FACE_A := Color(0.30,0.31,0.36)
const BARRIER_FACE_B := Color(0.26,0.27,0.32)
const BARRIER_TOP_A := Color(0.58,0.59,0.64)
const BARRIER_TOP_B := Color(0.52,0.53,0.58)
const KERB_INSET: float = 0.42       # outer gap between kerb and barrier
const KERB_WIDTH: float = 1.25
const KERB_BLOCK_M: float = 3.0
const LINE_INSET: float = 1.97       # kerb + safety gap
const LINE_WIDTH: float = 0.20
const VERGE_WIDTH: float = 3.6
const PROP_SEED: int = 7741
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
## Visual options used by the 3D track builder preview: open chains are
## drawn without wrap-around, start line, ground or lights.
var closed_loop: bool = true
var with_environment: bool = true

func _ready() -> void:
    if centerline.is_empty():
        build()

func build() -> void:
    var compiled: Dictionary = DNA.read_track(track_data_path)
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
    display_name = str(compiled["track_name"])
    closed_loop = true
    _build_visuals()

## Builder preview: draw the same road/kerb/verge/scenery for an arbitrary
## sampled centreline (open chain or closed loop). Not used for racing.
func build_from_samples(samples: Array[Vector2], halfwidth: float, closed: bool,
        id: String = "builder_preview", environment: bool = false) -> void:
    for child in get_children():
        remove_child(child)
        child.queue_free()
    closed_loop = closed
    with_environment = environment
    centerline = samples.duplicate()
    left_edge.clear()
    right_edge.clear()
    halfwidths = PackedFloat32Array()
    arc_lengths = PackedFloat32Array()
    var n: int = centerline.size()
    if n < 2:
        track_valid = false
        return
    var total: float = 0.0
    for i in range(n):
        var prev: Vector2 = centerline[(i-1+n)%n] if (closed or i > 0) else centerline[i]
        var next: Vector2 = centerline[(i+1)%n] if (closed or i < n-1) else centerline[i]
        var tangent: Vector2 = (next-prev).normalized()
        var normal := Vector2(-tangent.y,tangent.x)
        left_edge.append(centerline[i]-normal*halfwidth)
        right_edge.append(centerline[i]+normal*halfwidth)
        halfwidths.append(halfwidth)
        arc_lengths.append(total)
        if closed or i < n-1:
            total += centerline[i].distance_to(centerline[(i+1)%n])
    length_metres = total
    track_id = id
    track_valid = true
    _build_visuals()

func _segment_count() -> int:
    return centerline.size() if closed_loop else centerline.size()-1

func _build_visuals() -> void:
    _build_clearance_grid()
    if with_environment:
        _build_environment()
    # Layering outward from the racing surface (brief: surface -> painted
    # line -> safety gap -> kerb -> outer gap -> barrier -> verge).
    _add_corridor("Compacted shoulder",_shift_edge(left_edge,-VERGE_WIDTH),
        _shift_edge(right_edge,VERGE_WIDTH),0.018,Color.WHITE,DIRT,6.0)
    _add_corridor("Single continuous driving surface",left_edge,right_edge,
        0.05,ASPHALT_TINT,ASPHALT,7.0)
    _build_kerbs()
    _add_corridor("White edge left",_shift_edge(left_edge,LINE_INSET),
        _shift_edge(left_edge,LINE_INSET+LINE_WIDTH),0.066,LINE_COLOUR)
    _add_corridor("White edge right",_shift_edge(right_edge,-LINE_INSET-LINE_WIDTH),
        _shift_edge(right_edge,-LINE_INSET),0.066,LINE_COLOUR)
    if closed_loop:
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
        height: float,tint: Color,texture: Texture2D = null,tile_m: float = 7.0) -> void:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for i in range(_segment_count()):
        var next_i: int = (i+1)%centerline.size()
        var p: Vector3 = Vector3(a[i].x,height,a[i].y)
        var q: Vector3 = Vector3(b[i].x,height,b[i].y)
        var r: Vector3 = Vector3(a[next_i].x,height,a[next_i].y)
        var u: Vector3 = Vector3(b[next_i].x,height,b[next_i].y)
        _add_tri(st,p,r,q,tint,tile_m)
        _add_tri(st,q,r,u,tint,tile_m)
    var arr: ArrayMesh = st.commit()
    var mat := StandardMaterial3D.new()
    mat.vertex_color_use_as_albedo = true
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    if texture != null:
        mat.albedo_texture = texture
        mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    arr.surface_set_material(0,mat)
    var mesh := MeshInstance3D.new()
    mesh.name = label
    mesh.mesh = arr
    add_child(mesh)

func _add_tri(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,
        tint: Color,tile_m: float = 7.0) -> void:
    for p in [a,b,c]:
        st.set_color(tint)
        st.set_normal(Vector3.UP)
        # World-space UVs make adjacent procedural segments seamlessly tile.
        st.set_uv(Vector2(p.x,p.z)/tile_m)
        st.add_vertex(p)

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
    for i in range(_segment_count()):
        var next_i: int = (i+1)%count
        # Concrete barrier: darker inner face, lit top, subtle 3-sample
        # panel rhythm as a speed reference. Geometry is unchanged.
        var panel: bool = int(i/3)%2==0
        var colour: Color = BARRIER_FACE_A if panel else BARRIER_FACE_B
        var top_colour: Color = BARRIER_TOP_A if panel else BARRIER_TOP_B
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
            _wall_tri(st,triangles,top_a,top_b,outside_a,top_colour)
            _wall_tri(st,triangles,outside_a,top_b,outside_b,top_colour)
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


# ------------------------------------------------------------ road clearance

var _clearance_grid: Dictionary = {}
## Scenery placement records (headless-testable; MultiMesh data is not
## readable from the dummy renderer).
var tree_positions: Array[Vector2] = []
var flower_positions: Array[Vector2] = []
const CLEARANCE_CELL_M: float = 24.0

func _build_clearance_grid() -> void:
    # Spatial hash of centreline segments: fast "how far from ANY road
    # branch is this point" queries for scenery placement.
    _clearance_grid.clear()
    var n: int = centerline.size()
    for i in range(_segment_count()):
        var a: Vector2 = centerline[i]
        var b: Vector2 = centerline[(i+1)%n]
        var lo := Vector2i(int(floor(minf(a.x,b.x)/CLEARANCE_CELL_M)),int(floor(minf(a.y,b.y)/CLEARANCE_CELL_M)))
        var hi := Vector2i(int(floor(maxf(a.x,b.x)/CLEARANCE_CELL_M)),int(floor(maxf(a.y,b.y)/CLEARANCE_CELL_M)))
        for cx in range(lo.x,hi.x+1):
            for cy in range(lo.y,hi.y+1):
                var key := Vector2i(cx,cy)
                if not _clearance_grid.has(key):
                    _clearance_grid[key] = PackedInt32Array()
                var list: PackedInt32Array = _clearance_grid[key]
                list.append(i)
                _clearance_grid[key] = list

func road_clearance(pos: Vector2, search_m: float = 60.0) -> float:
    ## Distance from pos to the nearest road edge in metres (negative when
    ## the point lies on the road). INF when no road is within search_m.
    var best: float = INF
    var n: int = centerline.size()
    var reach: int = int(ceil(search_m/CLEARANCE_CELL_M))
    var cell := Vector2i(int(floor(pos.x/CLEARANCE_CELL_M)),int(floor(pos.y/CLEARANCE_CELL_M)))
    for dx in range(-reach,reach+1):
        for dy in range(-reach,reach+1):
            var key := cell+Vector2i(dx,dy)
            if not _clearance_grid.has(key):
                continue
            for i in _clearance_grid[key]:
                var a: Vector2 = centerline[i]
                var b: Vector2 = centerline[(i+1)%n]
                var ab: Vector2 = b-a
                var t: float = clampf((pos-a).dot(ab)/maxf(ab.length_squared(),0.000001),0.0,1.0)
                var d: float = pos.distance_to(a+ab*t)-lerpf(halfwidths[i],halfwidths[(i+1)%n],t)
                best = minf(best,d)
    return best

# ------------------------------------------------------------------- kerbs

func _build_kerbs() -> void:
    # Flat raised blue/white rumble strips inside both edges. Block length is
    # adjusted so an EVEN number of blocks spans the loop: the colour
    # sequence stays continuous across every segment join and the start/end.
    var n: int = centerline.size()
    var blocks: int = maxi(2,int(round(length_metres/(KERB_BLOCK_M*2.0)))*2)
    var block_len: float = length_metres/float(blocks)
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var top_y: float = 0.074
    var low_y: float = 0.054
    for side in [-1.0,1.0]:
        var edge: Array[Vector2] = left_edge if side < 0.0 else right_edge
        var inward: float = 1.0 if side < 0.0 else -1.0
        var outer: Array[Vector2] = _shift_edge(edge,inward*KERB_INSET)
        var inner: Array[Vector2] = _shift_edge(edge,inward*(KERB_INSET+KERB_WIDTH))
        var lip: Array[Vector2] = _shift_edge(edge,inward*(KERB_INSET+KERB_WIDTH+0.16))
        var back: Array[Vector2] = _shift_edge(edge,inward*(KERB_INSET-0.10))
        for i in range(_segment_count()):
            var j: int = (i+1)%n
            var s0: float = arc_lengths[i]
            var s1: float = arc_lengths[j] if j != 0 else length_metres
            var cuts: Array[float] = [0.0]
            var k: int = int(floor(s0/block_len))+1
            while float(k)*block_len < s1-0.0001:
                cuts.append((float(k)*block_len-s0)/maxf(s1-s0,0.0001))
                k += 1
            cuts.append(1.0)
            for c in range(cuts.size()-1):
                var t0: float = cuts[c]
                var t1: float = cuts[c+1]
                var mid_s: float = s0+(s1-s0)*(t0+t1)*0.5
                var colour: Color = KERB_BLUE if int(floor(mid_s/block_len))%2 == 0 else KERB_WHITE
                var o0: Vector2 = outer[i].lerp(outer[j],t0)
                var o1: Vector2 = outer[i].lerp(outer[j],t1)
                var i0: Vector2 = inner[i].lerp(inner[j],t0)
                var i1: Vector2 = inner[i].lerp(inner[j],t1)
                _flat_quad(st,o0,o1,i0,i1,top_y,top_y,colour)
                var l0: Vector2 = lip[i].lerp(lip[j],t0)
                var l1: Vector2 = lip[i].lerp(lip[j],t1)
                _flat_quad(st,i0,i1,l0,l1,top_y,low_y,colour.darkened(0.45))
                var b0: Vector2 = back[i].lerp(back[j],t0)
                var b1: Vector2 = back[i].lerp(back[j],t1)
                _flat_quad(st,b0,b1,o0,o1,low_y,top_y,KERB_BEVEL)
    var mesh: ArrayMesh = st.commit()
    var mat := StandardMaterial3D.new()
    mat.vertex_color_use_as_albedo = true
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    mesh.surface_set_material(0,mat)
    var node := MeshInstance3D.new()
    node.name = "Blue white kerbs"
    node.mesh = mesh
    add_child(node)

func _flat_quad(st: SurfaceTool,a0: Vector2,a1: Vector2,b0: Vector2,b1: Vector2,
        ya: float,yb: float,colour: Color) -> void:
    var p0 := Vector3(a0.x,ya,a0.y)
    var p1 := Vector3(a1.x,ya,a1.y)
    var q0 := Vector3(b0.x,yb,b0.y)
    var q1 := Vector3(b1.x,yb,b1.y)
    for p in [p0,p1,q0,q0,p1,q1]:
        st.set_color(colour)
        st.set_normal(Vector3.UP)
        st.add_vertex(p)

# ------------------------------------------------------------- environment

func _build_environment() -> void:
    var plane := MeshInstance3D.new()
    plane.name = "Ground outside track"
    var ground := PlaneMesh.new()
    ground.size = Vector2(900,900)
    plane.mesh = ground
    plane.position.y = -0.08
    var m := StandardMaterial3D.new()
    m.albedo_color = Color(0.92,0.95,0.92)
    m.albedo_texture = GRASS
    m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    m.uv1_scale = Vector3(900.0/18.0,900.0/18.0,1.0)
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    plane.material_override = m
    add_child(plane)
    # Cool moonlight key from the upper left + violet night ambient.
    var moon := DirectionalLight3D.new()
    moon.name = "Moonlight"
    moon.rotation_degrees = Vector3(-62,-38,0)
    moon.light_color = Color(0.86,0.87,1.0)
    moon.light_energy = 1.05
    moon.shadow_enabled = false
    add_child(moon)
    var env := WorldEnvironment.new()
    var res := Environment.new()
    res.background_mode = Environment.BG_COLOR
    res.background_color = Color(0.025,0.03,0.055)
    res.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    res.ambient_light_color = Color(0.52,0.48,0.66)
    res.ambient_light_energy = 0.85
    res.fog_enabled = false
    env.environment = res
    add_child(env)

# ----------------------------------------------------------------- scenery

func _build_track_props() -> void:
    # Deterministic per-track scenery: voxel cherry-blossom trees, dark
    # pines, soft tree shadows and pink flower clusters on the verge.
    # Every prop is rejected if it approaches ANY branch of road.
    var rng := RandomNumberGenerator.new()
    rng.seed = absi(hash(track_id))+PROP_SEED
    var n: int = centerline.size()
    var trees: Array[Dictionary] = []
    var next_s: float = 0.0
    for i in range(n):
        if arc_lengths[i] < next_s:
            continue
        next_s = arc_lengths[i]+rng.randf_range(7.0,13.0)
        var ahead: Vector2 = centerline[mini(i+1,n-1)] if not closed_loop else centerline[(i+1)%n]
        var behind: Vector2 = centerline[maxi(i-1,0)] if not closed_loop else centerline[(i-1+n)%n]
        var tangent: Vector2 = (ahead-behind).normalized()
        var normal := Vector2(-tangent.y,tangent.x)
        for side in [-1.0,1.0]:
            for ring in range(2):
                if rng.randf() < (0.30 if ring == 0 else 0.55):
                    continue
                var gap: float = rng.randf_range(5.5,13.0) if ring == 0 else rng.randf_range(16.0,34.0)
                var pos: Vector2 = centerline[i]+normal*side*(halfwidths[i]+VERGE_WIDTH+gap)+tangent*rng.randf_range(-4.0,4.0)
                var zone: float = sin(arc_lengths[i]*0.011+side*1.7)+rng.randf_range(-0.45,0.45)
                var cherry: bool = zone > 0.05
                var radius: float = rng.randf_range(2.3,3.3) if cherry else rng.randf_range(1.9,2.6)
                if road_clearance(pos) < radius+3.2:
                    continue
                var crowded: bool = false
                for other in trees:
                    if Vector2(other["pos"]).distance_to(pos) < (float(other["radius"])+radius)*0.95:
                        crowded = true
                        break
                if crowded:
                    continue
                trees.append({"pos":pos,"cherry":cherry,"radius":radius,
                    "height":rng.randf_range(0.9,1.2),"seed":rng.randi()})
    tree_positions.clear()
    for tree in trees:
        tree_positions.append(Vector2(tree["pos"]))
    _build_trees(trees)
    _build_verge_flowers(rng)

func _multimesh(label: String,mesh: Mesh,material: Material,transforms: Array[Transform3D],
        colours: Array[Color] = []) -> void:
    if transforms.is_empty():
        return
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.use_colors = not colours.is_empty()
    mm.mesh = mesh
    mm.instance_count = transforms.size()
    for k in range(transforms.size()):
        mm.set_instance_transform(k,transforms[k])
        if mm.use_colors:
            mm.set_instance_color(k,colours[k])
    var node := MultiMeshInstance3D.new()
    node.name = label
    node.multimesh = mm
    node.material_override = material
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(node)

func _build_trees(trees: Array[Dictionary]) -> void:
    var voxel_xf: Array[Transform3D] = []
    var voxel_col: Array[Color] = []
    var cone_xf: Array[Transform3D] = []
    var cone_col: Array[Color] = []
    var trunk_xf: Array[Transform3D] = []
    var shadow_xf: Array[Transform3D] = []
    var shadow_dir := Vector2(0.55,0.75)
    for tree in trees:
        var pos: Vector2 = tree["pos"]
        var radius: float = tree["radius"]
        var h: float = tree["height"]
        var local := RandomNumberGenerator.new()
        local.seed = int(tree["seed"])
        var shadow_len: float = 2.6*h
        var shadow_basis := Basis.from_scale(Vector3(radius*2.5,1.0,radius*2.9))
        shadow_basis = Basis(Vector3.UP,local.randf_range(0.0,TAU))*shadow_basis
        shadow_xf.append(Transform3D(shadow_basis,
            Vector3(pos.x+shadow_dir.x*shadow_len,0.088,pos.y+shadow_dir.y*shadow_len)))
        if bool(tree["cherry"]):
            var trunk_h: float = 2.6*h
            trunk_xf.append(Transform3D(Basis.from_scale(Vector3(0.42,trunk_h,0.42)),
                Vector3(pos.x,trunk_h*0.5,pos.y)))
            # Pixel/voxel blossom canopy (approved reference: pink "pixel"
            # cherry trees). Voxels are snapped to a 0.62 m lattice.
            var vs: float = 0.62
            var centre := Vector3(pos.x,trunk_h+radius*0.55,pos.y)
            var used: Dictionary = {}
            for k in range(int(radius*22.0)):
                var dir := Vector3(local.randf_range(-1,1),local.randf_range(-0.55,1),local.randf_range(-1,1))
                if dir.length() > 1.0:
                    continue
                var p: Vector3 = centre+Vector3(dir.x*radius,dir.y*radius*0.72,dir.z*radius)
                var snapped := Vector3i(int(round(p.x/vs)),int(round(p.y/vs)),int(round(p.z/vs)))
                if used.has(snapped):
                    continue
                used[snapped] = true
                var size: float = vs*local.randf_range(0.92,1.18)
                voxel_xf.append(Transform3D(Basis.from_scale(Vector3.ONE*size),Vector3(snapped)*vs))
                var height_t: float = clampf((p.y-centre.y)/radius*0.8+0.5,0.0,1.0)
                var pink := Color(0.80,0.24,0.50).lerp(Color(1.0,0.60,0.82),height_t)
                pink = pink.lerp(Color(1.0,0.86,0.93),local.randf()*0.22)
                voxel_col.append(pink)
        else:
            var base_h: float = 0.6
            for tier in range(3):
                var s: float = (1.0-float(tier)*0.24)*radius
                cone_xf.append(Transform3D(Basis.from_scale(Vector3(s,h*1.25,s)),
                    Vector3(pos.x,base_h+1.7*h+float(tier)*1.55*h,pos.y)))
                cone_col.append(Color(0.06,0.15,0.11).lerp(Color(0.12,0.24,0.16),float(tier)/2.0))
            trunk_xf.append(Transform3D(Basis.from_scale(Vector3(0.38,base_h+1.2,0.38)),
                Vector3(pos.x,(base_h+1.2)*0.5,pos.y)))
    var foliage := StandardMaterial3D.new()
    foliage.vertex_color_use_as_albedo = true
    foliage.roughness = 0.9
    var voxel := BoxMesh.new()
    voxel.size = Vector3.ONE
    _multimesh("Cherry blossom voxels",voxel,foliage,voxel_xf,voxel_col)
    var cone := CylinderMesh.new()
    cone.top_radius = 0.04
    cone.bottom_radius = 1.0
    cone.height = 2.6
    cone.radial_segments = 7
    cone.rings = 1
    _multimesh("Night pines",cone,foliage,cone_xf,cone_col)
    var bark := StandardMaterial3D.new()
    bark.albedo_color = Color(0.20,0.13,0.11)
    var trunk := BoxMesh.new()
    trunk.size = Vector3.ONE
    _multimesh("Tree trunks",trunk,bark,trunk_xf)
    var shade := ShaderMaterial.new()
    shade.shader = SHADOW_SHADER
    shade.set_shader_parameter("core",Vector2(0.16,0.16))
    shade.set_shader_parameter("softness",0.30)
    shade.set_shader_parameter("corner",0.16)
    shade.set_shader_parameter("opacity",0.50)
    var quad := PlaneMesh.new()
    quad.size = Vector2.ONE
    _multimesh("Soft tree shadows",quad,shade,shadow_xf)

func _build_verge_flowers(rng: RandomNumberGenerator) -> void:
    var n: int = centerline.size()
    var xf: Array[Transform3D] = []
    var cols: Array[Color] = []
    flower_positions.clear()
    for side in [-1.0,1.0]:
        var edge: Array[Vector2] = left_edge if side < 0.0 else right_edge
        var next_s: float = 0.0
        for i in range(_segment_count()):
            if arc_lengths[i] < next_s:
                continue
            next_s = arc_lengths[i]+rng.randf_range(0.8,2.2)
            if rng.randf() < 0.25:
                continue
            var j: int = (i+1)%n
            var t: float = rng.randf()
            var e: Vector2 = edge[i].lerp(edge[j],t)
            var inward: Vector2 = (right_edge[i]-left_edge[i]).normalized()
            var out_dir: Vector2 = -inward if side < 0.0 else inward
            var dist: float = rng.randf_range(VERGE_WIDTH*0.55,VERGE_WIDTH+3.0)
            var pos: Vector2 = e+out_dir*dist
            if road_clearance(pos) < 1.2:
                continue
            var size: float = rng.randf_range(0.9,1.9)
            var basis := Basis(Vector3.UP,rng.randf_range(0.0,TAU))*Basis.from_scale(Vector3(size,1.0,size))
            xf.append(Transform3D(basis,Vector3(pos.x,0.03,pos.y)))
            flower_positions.append(pos)
            cols.append(Color(1,1,1).lerp(Color(1.0,0.75,0.9),rng.randf()))
    var mat := StandardMaterial3D.new()
    mat.albedo_texture = FLOWERS
    mat.vertex_color_use_as_albedo = true
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
    mat.alpha_scissor_threshold = 0.45
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    var quad := PlaneMesh.new()
    quad.size = Vector2.ONE
    _multimesh("Verge blossom clusters",quad,mat,xf,cols)
