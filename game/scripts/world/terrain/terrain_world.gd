extends Node3D
class_name NitroTerrainWorld
## Terrain-first world: generated landscape (built BEFORE any road), local
## road adaptation and the scenery around it. The builder and the race both
## create this node from the same descriptor + road, so they show the same
## world.
##
##  * terrain mesh in stable chunks (28 x 28 cells of 8 m = 224 m); a road
##    edit rebuilds only the chunks whose heights changed;
##  * road adaptation: inside the road core the ground sits just under the
##    asphalt; beyond it cut slopes rise / fill slopes fall back to the
##    untouched ground; deep cuts and high fills get retaining walls, big
##    drops / streams get bridges. Distant terrain is never touched;
##  * sea cliffs are true vertical faces (grid vertices snapped onto the cliff
##    line + a dedicated rock face mesh);
##  * sea plane, horizon ring, sky, sun and fog per archetype.
const CAT = preload("res://scripts/world/terrain/terrain_catalog.gd")
const FIELD = preload("res://scripts/world/terrain/terrain_field.gd")
const PROFILE = preload("res://scripts/world/terrain/road_profile.gd")
const SCENERY = preload("res://scripts/world/terrain/terrain_scenery.gd")
const GROUND_SHADER = preload("res://assets/shaders/terrain_ground.gdshader")
const WATER_SHADER = preload("res://assets/shaders/terrain_water.gdshader")
const DETAIL = preload("res://assets/surfaces/cloud_noise.png")

const CHUNK_CELLS: int = 28
const ROAD_SINK: float = 0.25
const INFLUENCE_M: float = 70.0
## Flat bench from the road edge to the cut / fill slopes (verge 3.6 m +
## ditch / run-off). Wider than the 8 m terrain grid needs so that no
## terrain triangle can rise through the shoulder.
const BENCH_M: float = 15.0
const DEFORM_STRIDE: int = 2

var desc: Dictionary = {}
var field: NitroTerrainField
var chunk_nodes: Dictionary = {}     # Vector2i -> MeshInstance3D
var chunk_hash: Dictionary = {}      # Vector2i -> int
var road: Dictionary = {}            # samples, halfwidths, heights, closed, class
var ground_mat: ShaderMaterial
var structures: Node3D
var scenery: NitroTerrainScenery
var last_stats: Dictionary = {}
var with_lighting: bool = true
var env: Environment
var _fog_base: float = 0.001

func setup(descriptor: Dictionary) -> NitroTerrainWorld:
    desc = descriptor.duplicate(true)
    var arch: String = CAT.valid(str(desc.get("archetype","jp_sakura")))
    desc["archetype"] = arch
    desc["country"] = str(CAT.info(arch)["country"])
    field = FIELD.new(arch,int(desc.get("terrain_seed",1)))
    return self

func descriptor() -> Dictionary:
    return desc.duplicate(true)

func info() -> Dictionary:
    return field.info

func height_at(x: float, z: float) -> float:
    return field.height_at(x,z)

func chunk_counts() -> Vector2i:
    return Vector2i((field.nx-1)/CHUNK_CELLS,(field.nz-1)/CHUNK_CELLS)

## Build everything (terrain first; road comes later with set_road()).
func build() -> void:
    var t0: int = Time.get_ticks_usec()
    for child in get_children():
        remove_child(child)
        child.queue_free()
    chunk_nodes.clear()
    chunk_hash.clear()
    ground_mat = ShaderMaterial.new()
    ground_mat.shader = GROUND_SHADER
    ground_mat.set_shader_parameter("detail",DETAIL)
    if with_lighting:
        _build_lighting()
    _build_far_ring()
    _build_water()
    var cc: Vector2i = chunk_counts()
    for cz in range(cc.y):
        for cx in range(cc.x):
            _build_chunk(Vector2i(cx,cz))
    if field.relief == "coast":
        _build_cliff_face()
    structures = Node3D.new()
    structures.name = "Road structures"
    add_child(structures)
    scenery = SCENERY.new()
    scenery.name = "Scenery"
    add_child(scenery)
    scenery.setup(self)
    scenery.rebuild_all()
    last_stats = {"build_ms":float(Time.get_ticks_usec()-t0)/1000.0,"bake_ms":field.bake_ms,
        "chunks":chunk_nodes.size()}

# ------------------------------------------------------------ road adapt

## Adapt the terrain to a road (or clear it with an empty sample list).
## Returns {"dirty": [chunk ids], "ms": time, "class": per-sample classes}.
func set_road(samples: Array[Vector2], halfwidths: PackedFloat32Array, heights: PackedFloat32Array,
        closed: bool) -> Dictionary:
    var t0: int = Time.get_ticks_usec()
    road = {}
    var cls := PackedInt32Array()
    if samples.size() >= 2 and heights.size() == samples.size():
        var c: Dictionary = PROFILE.classify(field,samples,halfwidths,heights,closed)
        cls = c["class"]
        road = {"samples":samples,"halfwidths":halfwidths,"heights":heights,"closed":closed,
            "class":cls,"summary":c}
    _deform()
    var dirty: Array = []
    var cc: Vector2i = chunk_counts()
    for cz in range(cc.y):
        for cx in range(cc.x):
            var id := Vector2i(cx,cz)
            if _chunk_hash(id) != int(chunk_hash.get(id,-1)):
                _build_chunk(id)
                dirty.append(id)
    _build_structures()
    if scenery != null:
        scenery.on_road_changed(dirty)
    last_stats = {"dirty":dirty.size(),"ms":float(Time.get_ticks_usec()-t0)/1000.0}
    return {"dirty":dirty,"ms":last_stats["ms"],"class":cls,"summary":road.get("summary",{})}

func _deform() -> void:
    var h: PackedFloat32Array = field.base.duplicate()
    if road.is_empty():
        field.height = h
        return
    var samples: Array[Vector2] = road["samples"]
    var hw: PackedFloat32Array = road["halfwidths"]
    var rh: PackedFloat32Array = road["heights"]
    var cls: PackedInt32Array = road["class"]
    var closed: bool = road["closed"]
    var n: int = samples.size()
    var nx: int = field.nx
    var best_d := PackedFloat32Array()
    best_d.resize(h.size())
    best_d.fill(INF)
    var best_h := PackedFloat32Array()
    best_h.resize(h.size())
    var best_w := PackedFloat32Array()
    best_w.resize(h.size())
    var best_c := PackedInt32Array()
    best_c.resize(h.size())
    var touched: Dictionary = {}
    # Decimated polyline (every DEFORM_STRIDE-th sample, ~9 m): plenty for
    # an 8 m terrain grid and half the work.
    var idxs: Array[int] = []
    for i0 in range(0,n,DEFORM_STRIDE):
        idxs.append(i0)
    if not closed and idxs[idxs.size()-1] != n-1:
        idxs.append(n-1)
    var segs: int = idxs.size() if closed else idxs.size()-1
    for s_i in range(segs):
        var i: int = idxs[s_i]
        var j: int = idxs[(s_i+1)%idxs.size()]
        var a: Vector2 = samples[i]
        var b: Vector2 = samples[j]
        var reach: float = maxf(hw[i],hw[j])+INFLUENCE_M
        var lo := Vector2(minf(a.x,b.x)-reach,minf(a.y,b.y)-reach)
        var hi := Vector2(maxf(a.x,b.x)+reach,maxf(a.y,b.y)+reach)
        var i0: int = maxi(0,int(ceil((lo.x+FIELD.HALF_X)/FIELD.STEP)))
        var i1: int = mini(nx-1,int(floor((hi.x+FIELD.HALF_X)/FIELD.STEP)))
        var j0: int = maxi(0,int(ceil((lo.y+FIELD.HALF_Z)/FIELD.STEP)))
        var j1: int = mini(field.nz-1,int(floor((hi.y+FIELD.HALF_Z)/FIELD.STEP)))
        var ab: Vector2 = b-a
        var len2: float = maxf(ab.length_squared(),0.0001)
        var reach2: float = reach*reach
        for gj in range(j0,j1+1):
            var pz: float = -FIELD.HALF_Z+float(gj)*FIELD.STEP
            for gi in range(i0,i1+1):
                var px: float = -FIELD.HALF_X+float(gi)*FIELD.STEP
                var q := Vector2(px,pz)
                var t: float = clampf((q-a).dot(ab)/len2,0.0,1.0)
                var dsq: float = q.distance_squared_to(a+ab*t)
                if dsq > reach2:
                    continue
                var k: int = gj*nx+gi
                if dsq < best_d[k]:
                    best_d[k] = dsq
                    best_h[k] = lerpf(rh[i],rh[j],t)
                    best_w[k] = lerpf(hw[i],hw[j],t)
                    best_c[k] = cls[i] if t < 0.5 else cls[j]
                    touched[k] = true
    var coast: bool = field.relief == "coast"
    var rocky: bool = str(field.info["rock_kind"]) in ["granite","limestone","basalt"]
    for k in touched.keys():
        var d2: float = sqrt(best_d[k])
        var core: float = best_w[k]+BENCH_M
        if d2 > core+INFLUENCE_M-6.0:
            continue
        if coast and field.water[k] == 1:
            continue
        var orig: float = field.base[k]
        var road_h: float = best_h[k]-ROAD_SINK
        var c: int = best_c[k]
        var tgt: float = orig
        if c == 4:
            # Bridge: the ground stays; only clear the deck.
            if d2 <= best_w[k]+3.0:
                tgt = minf(orig,road_h-2.4)
        elif d2 <= core:
            tgt = road_h
        else:
            var t2: float = d2-core
            var dz: float = orig-road_h
            if dz > 0.0:
                var wall: float = minf(dz,7.0) if c == 2 else 0.0
                var slope: float = 1.6 if rocky else 1.25
                tgt = road_h+minf(dz,wall+t2*slope)
            else:
                var wall2: float = minf(-dz,5.5) if c == 3 else 0.0
                tgt = road_h-minf(-dz,wall2+t2*0.75)
        h[k] = tgt
    field.height = h

func _chunk_hash(id: Vector2i) -> int:
    var acc: int = 7
    var i0: int = id.x*CHUNK_CELLS
    var j0: int = id.y*CHUNK_CELLS
    for j in range(j0,j0+CHUNK_CELLS+1):
        for i in range(i0,i0+CHUNK_CELLS+1):
            acc = (acc*131+int(round(field.height[j*field.nx+i]*50.0))) & 0x7fffffff
    return acc

# ---------------------------------------------------------------- meshes

func _ground_colour(k: int, i: int, j: int) -> Color:
    var g: Dictionary = field.info["ground"]
    var h: float = field.height[k]
    var b: float = field.base[k]
    var hn: float = clampf((b-0.0)/120.0,0.0,1.0)
    var col: Color = Color(g["low"]).lerp(Color(g["high"]),smoothstep(0.1,0.9,hn))
    col = col.lerp(Color(g["dirt"]).darkened(0.15),field.forest[k]*0.45)
    var tint: float = field.tint[k]
    if tint > 0.0:
        var tk: String = str(field.info["tint_mask"])
        if tk == "fields":
            var shades: Array = [Color(0.36,0.60,0.26),Color(0.44,0.64,0.30),Color(0.30,0.52,0.22),
                Color(0.56,0.62,0.30),Color(0.40,0.56,0.24)]
            col = col.lerp(shades[int(round(tint*4.0))],0.65)
        else:
            col = col.lerp(Color(g["tint"]),tint*0.5)
    col = col.lerp(Color(g["rock"]),field.rock[k])
    col = col.lerp(Color(g["snow"]),field.snow[k])
    if b < FIELD.SEA_LEVEL+0.5 and bool(field.info["sea"]):
        col = Color(g["shore"]).darkened(0.35)
    var dd: float = h-b
    if dd > 0.8:
        col = col.lerp(Color(g["low"]).lightened(0.05),0.55)       # fill slope: grassed embankment
    elif dd < -0.8:
        var cut_col: Color = Color(g["rock"]) if str(field.info["rock_kind"]) in ["granite","limestone","basalt"] else Color(g["dirt"])
        col = col.lerp(cut_col,clampf(-dd/3.0,0.0,0.85))          # exposed cutting
    return col

func _vertex(i: int, j: int) -> Vector3:
    var x: float = -FIELD.HALF_X+float(i)*FIELD.STEP
    var z: float = -FIELD.HALF_Z+float(j)*FIELD.STEP
    var y: float = field.height[j*field.nx+i]
    if field.relief == "coast":
        var d: float = field.coast_distance(x,z)
        if d >= 0.0 and d < FIELD.STEP:
            x -= d-0.3
        elif d < 0.0 and d > -FIELD.STEP:
            x += -d-0.3
    return Vector3(x,y,z)

func _normal(i: int, j: int) -> Vector3:
    var nx: int = field.nx
    var i0: int = maxi(i-1,0)
    var i1: int = mini(i+1,nx-1)
    var j0: int = maxi(j-1,0)
    var j1: int = mini(j+1,field.nz-1)
    var dx: float = (field.height[j*nx+i1]-field.height[j*nx+i0])/(float(i1-i0)*FIELD.STEP)
    var dz: float = (field.height[j1*nx+i]-field.height[j0*nx+i])/(float(j1-j0)*FIELD.STEP)
    return Vector3(-dx,1.0,-dz).normalized()

func _build_chunk(id: Vector2i) -> void:
    var i0: int = id.x*CHUNK_CELLS
    var j0: int = id.y*CHUNK_CELLS
    var m: int = CHUNK_CELLS+1
    var verts := PackedVector3Array()
    var norms := PackedVector3Array()
    var cols := PackedColorArray()
    verts.resize(m*m)
    norms.resize(m*m)
    cols.resize(m*m)
    for b in range(m):
        for a in range(m):
            var i: int = i0+a
            var j: int = j0+b
            var k: int = j*field.nx+i
            verts[b*m+a] = _vertex(i,j)
            norms[b*m+a] = _normal(i,j)
            cols[b*m+a] = _ground_colour(k,i,j)
    var idx := PackedInt32Array()
    for b in range(CHUNK_CELLS):
        for a in range(CHUNK_CELLS):
            var p: int = b*m+a
            if (a+b)%2 == 0:
                idx.append_array([p,p+1,p+m,p+1,p+m+1,p+m])
            else:
                idx.append_array([p,p+1,p+m+1,p,p+m+1,p+m])
    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = verts
    arrays[Mesh.ARRAY_NORMAL] = norms
    arrays[Mesh.ARRAY_COLOR] = cols
    arrays[Mesh.ARRAY_INDEX] = idx
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
    mesh.surface_set_material(0,ground_mat)
    var node: MeshInstance3D = chunk_nodes.get(id,null)
    if node == null:
        node = MeshInstance3D.new()
        node.name = "Terrain chunk %d_%d" % [id.x,id.y]
        node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(node)
        chunk_nodes[id] = node
    node.mesh = mesh
    chunk_hash[id] = _chunk_hash(id)

func _build_far_ring() -> void:
    var step: float = 64.0
    var ext: float = 3200.0
    var cells: int = int(ext*2.0/step)
    var inner_x: float = FIELD.HALF_X-24.0
    var inner_z: float = FIELD.HALF_Z-24.0
    var g: Dictionary = field.info["ground"]
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var hcache: Dictionary = {}
    for b in range(cells):
        for a in range(cells):
            var x0: float = -ext+float(a)*step
            var z0: float = -ext+float(b)*step
            var x1: float = x0+step
            var z1: float = z0+step
            if x0 >= -inner_x and x1 <= inner_x and z0 >= -inner_z and z1 <= inner_z:
                continue
            var quad: Array = [Vector2(x0,z0),Vector2(x1,z0),Vector2(x1,z1),Vector2(x0,z1)]
            var p3: Array = []
            for q in quad:
                var key := Vector2i(int(q.x),int(q.y))
                if not hcache.has(key):
                    var hh: float = field.raw_height(q.x,q.y)
                    if absf(q.x) < FIELD.HALF_X+8.0 and absf(q.y) < FIELD.HALF_Z+8.0:
                        hh -= 1.5
                    hcache[key] = hh
                p3.append(Vector3(q.x,hcache[key],q.y))
            for tri in [[0,1,2],[0,2,3]]:
                var va: Vector3 = p3[tri[0]]
                var vb: Vector3 = p3[tri[1]]
                var vc: Vector3 = p3[tri[2]]
                var nrm: Vector3 = (vc-va).cross(vb-va).normalized()
                if nrm.y < 0.0:
                    nrm = -nrm
                for v in [va,vb,vc]:
                    st.set_color(_far_colour(v,nrm))
                    st.set_normal(nrm)
                    st.add_vertex(v)
    var mesh: ArrayMesh = st.commit()
    mesh.surface_set_material(0,ground_mat)
    var node := MeshInstance3D.new()
    node.name = "Horizon terrain ring"
    node.mesh = mesh
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(node)

## Horizon ring colour: same palette rules as the detailed terrain (height
## blend, forest canopy shade, rock on steep faces, snow, shore) so the
## seam between the two meshes does not read as a rectangle.
func _far_colour(v: Vector3, nrm: Vector3) -> Color:
    var g: Dictionary = field.info["ground"]
    var hn: float = clampf(v.y/120.0,0.0,1.0)
    var col: Color = Color(g["low"]).lerp(Color(g["high"]),smoothstep(0.1,0.9,hn))
    var forest: float = float(field.info["forest"])*(0.55+0.45*field._n(4,v.x,v.z))
    if field.relief == "alpine":
        forest *= 1.0-smoothstep(170.0,260.0,v.y)
    col = col.lerp(Color(g["dirt"]).darkened(0.15),clampf(forest,0.0,1.0)*0.45)
    col = col.lerp(Color(0.10,0.20,0.12),clampf(forest,0.0,1.0)*0.35)     # canopy seen from afar
    var slope: float = sqrt(maxf(1.0-nrm.y*nrm.y,0.0))/maxf(nrm.y,0.05)
    col = col.lerp(Color(g["rock"]),smoothstep(0.55,1.1,slope)*(0.0 if str(field.info["rock_kind"]) == "none" else 0.9))
    if field.relief == "alpine":
        col = col.lerp(Color(g["snow"]),smoothstep(300.0,370.0,v.y))
    if v.y < 0.5 and bool(field.info["sea"]):
        col = Color(g["shore"]).darkened(0.35)
    return col

func _water_material() -> ShaderMaterial:
    var mat := ShaderMaterial.new()
    mat.shader = WATER_SHADER
    mat.set_shader_parameter("detail",DETAIL)
    var sky: Dictionary = field.info["sky"]
    mat.set_shader_parameter("sky",Color(sky["horizon"]))
    return mat

func _build_water() -> void:
    if bool(field.info["sea"]):
        var sea := MeshInstance3D.new()
        sea.name = "Sea"
        var plane := PlaneMesh.new()
        plane.size = Vector2(6400,6400)
        plane.subdivide_width = 8
        plane.subdivide_depth = 8
        sea.mesh = plane
        sea.position.y = FIELD.SEA_LEVEL
        sea.material_override = _water_material()
        sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(sea)
    if field.relief == "canyon":
        # Stream ribbon on the valley floor (water at the channel bed + 1.2 m).
        var st := SurfaceTool.new()
        st.begin(Mesh.PRIMITIVE_TRIANGLES)
        var prev_l := Vector3.ZERO
        var prev_r := Vector3.ZERO
        var first: bool = true
        var z: float = -FIELD.HALF_Z
        while z <= FIELD.HALF_Z:
            var v: float = z/FIELD.PLAY_HALF_Z
            var cx: float = (field.canyon_u(v)+0.05*sin(v*7.0+field._phase*2.0))*FIELD.PLAY_HALF_X
            var y: float = field.base_at(cx,z)+1.0
            var l := Vector3(cx-4.6,y,z)
            var r := Vector3(cx+4.6,y,z)
            if not first:
                for p in [prev_l,prev_r,l,l,prev_r,r]:
                    st.set_normal(Vector3.UP)
                    st.add_vertex(p)
            prev_l = l
            prev_r = r
            first = false
            z += 6.0
        var mesh: ArrayMesh = st.commit()
        var node := MeshInstance3D.new()
        node.name = "Stream"
        node.mesh = mesh
        node.material_override = _water_material()
        add_child(node)

func _build_cliff_face() -> void:
    # Dedicated vertical rock face along the sea cliff (not a stretched
    # heightfield): jittered columns from below the waterline to the top.
    var g: Dictionary = field.info["ground"]
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var z: float = -FIELD.HALF_Z-60.0
    var step: float = 5.0
    var prev: Array = []
    while z <= FIELD.HALF_Z+60.0:
        var x: float = field.coast_x(z)-0.45
        var top: float = field.raw_height(x+3.0,z)-0.2
        var col: Array = []
        var rows: int = 6
        for r in range(rows+1):
            var f: float = float(r)/float(rows)
            var y: float = lerpf(-8.0,top,f)
            var jitter: float = 1.4*field._n(5,z*1.7,y*1.3)+0.9*sin(z*0.9+y*0.5)
            col.append(Vector3(x-maxf(0.0,jitter)-0.2,y,z))
        if not prev.is_empty():
            for r in range(rows):
                var a: Vector3 = prev[r]
                var b: Vector3 = col[r]
                var c: Vector3 = col[r+1]
                var d: Vector3 = prev[r+1]
                var nrm := Vector3(-1.0,0.0,0.0)
                var shade: float = 0.75+0.25*(float(r)/float(rows))
                var rc: Color = Color(g["rock"]).darkened(0.25*(1.0-shade))
                if r == 0:
                    rc = rc.darkened(0.35)
                for p in [a,b,c,a,c,d]:
                    st.set_color(rc)
                    st.set_normal(nrm)
                    st.add_vertex(p)
        prev = col
        z += step
    var mesh: ArrayMesh = st.commit()
    var mat := StandardMaterial3D.new()
    mat.vertex_color_use_as_albedo = true
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    mat.roughness = 0.95
    mesh.surface_set_material(0,mat)
    var node := MeshInstance3D.new()
    node.name = "Sea cliff face"
    node.mesh = mesh
    add_child(node)

# ------------------------------------------------------------ structures

func _build_structures() -> void:
    if structures == null:
        return
    for child in structures.get_children():
        structures.remove_child(child)
        child.queue_free()
    if road.is_empty():
        return
    var samples: Array[Vector2] = road["samples"]
    var hw: PackedFloat32Array = road["halfwidths"]
    var rh: PackedFloat32Array = road["heights"]
    var cls: PackedInt32Array = road["class"]
    var closed: bool = road["closed"]
    var n: int = samples.size()
    var wall_col: Color = Color(0.62,0.62,0.60)
    match str(field.info["rock_kind"]):
        "granite":
            wall_col = Color(0.56,0.55,0.55)
        "limestone":
            wall_col = Color(0.80,0.78,0.72)
        "basalt":
            wall_col = Color(0.46,0.46,0.46)
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var count: Dictionary = {"cut_wall_m":0.0,"fill_wall_m":0.0,"bridge_m":0.0,"pier":0,"cliff_wall_m":0.0}
    var nrms: Array[Vector2] = []
    for i in range(n):
        nrms.append(PROFILE._normal(samples,i,closed))
    # Continuous strips: a run of samples of one class on one side becomes
    # one wall that follows the road (no per-segment pieces).
    for side in [-1.0,1.0]:
        var prev: Dictionary = {}
        for k in range(n+(1 if closed else 0)):
            var i: int = k%n
            var cur: Dictionary = _wall_point(samples,hw,rh,cls,nrms,i,side)
            if not cur.is_empty() and not prev.is_empty() and cur["kind"] == prev["kind"]:
                var col: Color = wall_col if cur["kind"] == "cut" else wall_col.darkened(0.12)
                if cur["kind"] == "cliff":
                    col = Color(0.50,0.50,0.48)
                _quad(st,prev["bot"],cur["bot"],cur["top"],prev["top"],col)
                # coping on top
                _quad(st,prev["top"],cur["top"],cur["top"]+Vector3(0,0.25,0),prev["top"]+Vector3(0,0.25,0),col.lightened(0.12))
                var key: String = "cut_wall_m" if cur["kind"] == "cut" else ("fill_wall_m" if cur["kind"] == "fill" else "cliff_wall_m")
                count[key] = float(count[key])+Vector3(prev["top"]).distance_to(cur["top"])
            prev = cur
    # Bridges: deck slab + girders + piers.
    var segs: int = n if closed else n-1
    var since_pier: float = 999.0
    for i2 in range(segs):
        var j2: int = (i2+1)%n
        if cls[i2] != 4 and cls[j2] != 4:
            since_pier = 999.0
            continue
        var li: Vector2 = samples[i2]-nrms[i2]*(hw[i2]+1.2)
        var ri: Vector2 = samples[i2]+nrms[i2]*(hw[i2]+1.2)
        var lj: Vector2 = samples[j2]-nrms[j2]*(hw[j2]+1.2)
        var rj: Vector2 = samples[j2]+nrms[j2]*(hw[j2]+1.2)
        var yi: float = rh[i2]-1.6
        var yj: float = rh[j2]-1.6
        _quad(st,Vector3(li.x,yi,li.y),Vector3(lj.x,yj,lj.y),Vector3(rj.x,yj,rj.y),Vector3(ri.x,yi,ri.y),Color(0.52,0.52,0.53))
        _quad(st,Vector3(li.x,yi,li.y),Vector3(lj.x,yj,lj.y),Vector3(lj.x,rh[j2]+0.05,lj.y),Vector3(li.x,rh[i2]+0.05,li.y),Color(0.66,0.66,0.67))
        _quad(st,Vector3(ri.x,yi,ri.y),Vector3(rj.x,yj,rj.y),Vector3(rj.x,rh[j2]+0.05,rj.y),Vector3(ri.x,rh[i2]+0.05,ri.y),Color(0.66,0.66,0.67))
        var seg_len: float = samples[i2].distance_to(samples[j2])
        count["bridge_m"] = float(count["bridge_m"])+seg_len
        since_pier += seg_len
        if since_pier >= 26.0:
            since_pier = 0.0
            var pp: Vector2 = samples[i2]
            var ground: float = field.base_at(pp.x,pp.y)
            if field.is_water(pp.x,pp.y):
                ground = minf(ground,-2.0)
            if ground < yi-1.0:
                _pier(st,pp,nrms[i2],hw[i2],ground-1.0,yi,Color(0.60,0.60,0.61))
                count["pier"] = int(count["pier"])+1
    var mesh: ArrayMesh = st.commit()
    if mesh.get_surface_count() == 0:
        structures.set_meta("counts",count)
        return
    var mat := StandardMaterial3D.new()
    mat.vertex_color_use_as_albedo = true
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    mat.roughness = 0.9
    mesh.surface_set_material(0,mat)
    var node := MeshInstance3D.new()
    node.name = "Retaining walls, bridges, cliff walls"
    node.mesh = mesh
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    structures.add_child(node)
    structures.set_meta("counts",count)

## One wall vertex pair for sample i on one side, or {} when that side
## needs no wall. Cut walls stand at the end of the flat bench and hold the
## cut slope; fill walls stand under the bench edge; cliff walls are low
## stone parapets on the sea side.
func _wall_point(samples: Array[Vector2], hw: PackedFloat32Array, rh: PackedFloat32Array, cls: PackedInt32Array,
        nrms: Array[Vector2], i: int, side: float) -> Dictionary:
    var c: int = cls[i]
    var core: float = hw[i]+BENCH_M
    var p: Vector2 = samples[i]+nrms[i]*side*core
    var road_y: float = rh[i]-ROAD_SINK
    if c == 2:
        var q: Vector2 = samples[i]+nrms[i]*side*(core+4.0)
        var dz: float = field.base_at(q.x,q.y)-road_y
        if dz < 1.2:
            return {}
        var top: float = road_y+minf(dz,7.0)+0.6
        return {"kind":"cut","bot":Vector3(p.x,road_y-0.8,p.y),"top":Vector3(p.x,top,p.y)}
    if c == 3:
        var q2: Vector2 = samples[i]+nrms[i]*side*(core+4.0)
        var dz2: float = road_y-field.base_at(q2.x,q2.y)
        if dz2 < 1.2:
            return {}
        var bot: float = road_y-minf(dz2,5.5)-1.0
        return {"kind":"fill","bot":Vector3(p.x,bot,p.y),"top":Vector3(p.x,road_y+0.6,p.y)}
    if c == 5 and field.relief == "coast":
        var e: Vector2 = samples[i]+nrms[i]*side*(hw[i]+PROFILE.VERGE+1.2)
        if field.coast_distance(e.x,e.y) > 16.0:
            return {}
        return {"kind":"cliff","bot":Vector3(e.x,road_y-0.4,e.y),"top":Vector3(e.x,rh[i]+0.95,e.y)}
    return {}

func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
    var nrm: Vector3 = (b-a).cross(d-a).normalized()
    for p in [a,b,c,a,c,d]:
        st.set_color(col)
        st.set_normal(nrm)
        st.add_vertex(p)

func _pier(st: SurfaceTool, p: Vector2, nrm: Vector2, hw: float, y0: float, y1: float, col: Color) -> void:
    # Wall pier across the deck (typical concrete viaduct pier).
    var t := Vector2(-nrm.y,nrm.x)
    var half_w: float = hw*0.75
    var half_t: float = 1.1
    var corners: Array = [p-nrm*half_w-t*half_t,p+nrm*half_w-t*half_t,p+nrm*half_w+t*half_t,p-nrm*half_w+t*half_t]
    for k in range(4):
        var a: Vector2 = corners[k]
        var b: Vector2 = corners[(k+1)%4]
        _quad(st,Vector3(a.x,y0,a.y),Vector3(b.x,y0,b.y),Vector3(b.x,y1,b.y),Vector3(a.x,y1,a.y),col)

func structure_counts() -> Dictionary:
    if structures == null or not structures.has_meta("counts"):
        return {}
    return structures.get_meta("counts")

# -------------------------------------------------------------- lighting

func _build_lighting() -> void:
    var sky_info: Dictionary = field.info["sky"]
    var env := Environment.new()
    env.background_mode = Environment.BG_SKY
    var sky := Sky.new()
    var sky_mat := ProceduralSkyMaterial.new()
    sky_mat.sky_top_color = Color(sky_info["top"])
    sky_mat.sky_horizon_color = Color(sky_info["horizon"])
    sky_mat.ground_horizon_color = Color(sky_info["horizon"]).darkened(0.1)
    sky_mat.ground_bottom_color = Color(sky_info["horizon"]).darkened(0.4)
    sky_mat.sun_angle_max = 20.0
    sky.sky_material = sky_mat
    env.sky = sky
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(sky_info["horizon"]).lerp(Color.WHITE,0.3)
    env.ambient_light_energy = float(sky_info["ambient"])
    env.fog_enabled = true
    env.fog_light_color = Color(sky_info["fog"])
    env.fog_density = float(sky_info["fog_density"])
    env.fog_sky_affect = 0.25
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    _fog_base = env.fog_density
    var we := WorldEnvironment.new()
    we.name = "Sky and fog"
    we.environment = env
    self.env = env
    add_child(we)
    var sun := DirectionalLight3D.new()
    sun.name = "Sun"
    var ang: Vector2 = sky_info["sun_angle"]
    sun.rotation_degrees = Vector3(ang.x,ang.y,0.0)
    sun.light_color = Color(sky_info["sun"])
    sun.light_energy = float(sky_info["energy"])
    sun.shadow_enabled = false
    add_child(sun)

## Builder overview cameras look from 600-1200 m: thinner haze there.
func set_fog_scale(k: float) -> void:
    if env != null:
        env.fog_density = _fog_base*k

func mesh_stats() -> Dictionary:
    var verts: int = 0
    var tris: int = 0
    var calls: int = 0
    for node in find_children("*","MeshInstance3D",true,false):
        var mi: MeshInstance3D = node
        if mi.mesh == null:
            continue
        for s in range(mi.mesh.get_surface_count()):
            calls += 1
            var arr: Array = mi.mesh.surface_get_arrays(s)
            var v: int = (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
            verts += v
            var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
            tris += (idx.size() if idx.size() > 0 else v)/3
    for node2 in find_children("*","MultiMeshInstance3D",true,false):
        var mm: MultiMesh = (node2 as MultiMeshInstance3D).multimesh
        if mm == null or mm.mesh == null:
            continue
        calls += mm.mesh.get_surface_count()
        for s2 in range(mm.mesh.get_surface_count()):
            var arr2: Array = mm.mesh.surface_get_arrays(s2)
            var v2: int = (arr2[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
            var idx2 = arr2[Mesh.ARRAY_INDEX]
            var t2: int = ((idx2 as PackedInt32Array).size() if idx2 != null and (idx2 as PackedInt32Array).size() > 0 else v2)/3
            tris += t2*mm.visible_instance_count if mm.visible_instance_count >= 0 else t2*mm.instance_count
            verts += v2*mm.instance_count
    return {"vertices":verts,"triangles":tris,"draw_calls":calls}
