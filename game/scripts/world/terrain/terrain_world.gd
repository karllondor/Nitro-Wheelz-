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
const STEPS = preload("res://scripts/world/step_runner.gd")
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
## Race sets a draw range for vegetation / rocks (0 = everything, builder).
var scenery_range: float = 0.0
## Urban: distance of each terrain vertex from the road edge (street paint
## mask; INF = far from the road).
var road_gap: PackedFloat32Array = PackedFloat32Array()

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
    STEPS.run_now(build_steps())

## build() as steps (one per terrain / scenery chunk) for frame-sliced
## loading with a moving loading animation.
func build_steps() -> Array:
    var steps: Array = [_build_begin]
    var cc: Vector2i = chunk_counts()
    for cz in range(cc.y):
        for cx in range(cc.x):
            var id := Vector2i(cx,cz)
            steps.append(func(): _build_chunk(id))
    steps.append(_build_after_chunks)
    return steps

var _build_t0: int = 0

func _build_begin() -> void:
    _build_t0 = Time.get_ticks_usec()
    for child in get_children():
        remove_child(child)
        child.queue_free()
    stream_node=null
    _stream_limits.clear()
    chunk_nodes.clear()
    chunk_hash.clear()
    ground_mat = ShaderMaterial.new()
    ground_mat.shader = GROUND_SHADER
    ground_mat.set_shader_parameter("detail",DETAIL)
    # Rock strata by geology (v0.1.27).
    var strata: Dictionary = {"limestone":[0.85,1.3],"granite":[0.55,0.7],"basalt":[0.75,1.6],
        "mossy":[0.35,1.0],"earth_cut":[0.45,1.1],"none":[0.0,1.0]}
    var sp: Array = strata.get(str(field.info["rock_kind"]),[0.4,1.0])
    ground_mat.set_shader_parameter("strata",float(sp[0]))
    ground_mat.set_shader_parameter("strata_scale",float(sp[1]))
    if field.relief == "urban":
        road_gap.resize(field.base.size())
        road_gap.fill(INF)
        var g: Dictionary = field.city_grid()
        ground_mat.set_shader_parameter("city",1.0)
        ground_mat.set_shader_parameter("city_u",g["u"])
        ground_mat.set_shader_parameter("city_pitch",g["pitch"])
        ground_mat.set_shader_parameter("city_off",g["off"])
        ground_mat.set_shader_parameter("city_every",float(g["every"]))
        ground_mat.set_shader_parameter("city_phase",Vector2(g["phase"]))
        ground_mat.set_shader_parameter("city_side_w",float(g["side_w"]))
        ground_mat.set_shader_parameter("city_ave_w",float(g["ave_w"]))
        ground_mat.set_shader_parameter("city_walk",float(g["walk"]))
    if with_lighting:
        _build_lighting()
    _build_far_ring()
    _build_water()

func _build_after_chunks() -> Array:
    if field.relief == "coast":
        _build_cliff_face()
    structures = Node3D.new()
    structures.name = "Road structures"
    add_child(structures)
    scenery = SCENERY.new()
    scenery.name = "Scenery"
    add_child(scenery)
    scenery.setup(self)
    scenery.draw_range = scenery_range
    var more: Array = scenery.rebuild_steps()
    more.append(func(): last_stats = {"build_ms":float(Time.get_ticks_usec()-_build_t0)/1000.0,"bake_ms":field.bake_ms,
        "chunks":chunk_nodes.size()})
    return more

# ------------------------------------------------------------ road adapt

## Adapt the terrain to a road (or clear it with an empty sample list).
## Returns {"dirty": [chunk ids], "ms": time, "class": per-sample classes}.
func set_road(samples: Array[Vector2], halfwidths: PackedFloat32Array, heights: PackedFloat32Array,
        closed: bool) -> Dictionary:
    STEPS.run_now(set_road_steps(samples,halfwidths,heights,closed))
    return road_result

## Result of the last set_road() / set_road_steps() run.
var road_result: Dictionary = {}

## set_road() as steps: classify + deform, then one step per rebuilt
## terrain chunk, structures, then the scenery chunks that changed.
func set_road_steps(samples: Array[Vector2], halfwidths: PackedFloat32Array, heights: PackedFloat32Array,
        closed: bool) -> Array:
    return [func(): return _set_road_begin(samples,halfwidths,heights,closed)]

func _set_road_begin(samples: Array[Vector2], halfwidths: PackedFloat32Array, heights: PackedFloat32Array,
        closed: bool) -> Array:
    var t0: int = Time.get_ticks_usec()
    road = {}
    var cls := PackedInt32Array()
    if samples.size() >= 2 and heights.size() == samples.size():
        var c: Dictionary = PROFILE.classify(field,samples,halfwidths,heights,closed)
        cls = c["class"]
        road = {"samples":samples,"halfwidths":halfwidths,"heights":heights,"closed":closed,
            "class":cls,"summary":c}
        if not closed:
            road["end_pads"] = end_pads(samples,halfwidths,heights)
    if field.relief == "canyon":
        _refresh_stream_limits()
    _deform()
    var dirty: Array = []
    var cc: Vector2i = chunk_counts()
    for cz in range(cc.y):
        for cx in range(cc.x):
            var id := Vector2i(cx,cz)
            if _chunk_hash(id) != int(chunk_hash.get(id,-1)):
                dirty.append(id)
    var more: Array = []
    for id2 in dirty:
        more.append(func(): _build_chunk(id2))
    more.append(func():
        _build_structures()
        if field.relief == "canyon":
            _build_stream()
        var tail: Array = scenery.on_road_changed_steps(dirty) if scenery != null else []
        tail.append(func():
            last_stats = {"dirty":dirty.size(),"ms":float(Time.get_ticks_usec()-t0)/1000.0}
            road_result = {"dirty":dirty,"ms":last_stats["ms"],"class":cls,"summary":road.get("summary",{})})
        return tail)
    return more

## v0.1.27 open routes: a paved staging area behind the start and a parc
## ferme after the finish, on the road's own line and height; the terrain is
## cut / filled for them like for the road (scenery fills them with vans,
## tents, parked cars). Skipped over water / the sea cliff / off the map.
func end_pads(samples: Array[Vector2], hw: PackedFloat32Array, rh: PackedFloat32Array) -> Array:
    var out: Array = []
    var n: int = samples.size()
    if n < 3:
        return out
    var mode: String = str(desc.get("event_mode","club"))
    for end in ["start","finish"]:
        var e: int = 0 if end == "start" else n-1
        var inner: int = 1 if end == "start" else n-2
        var away: Vector2 = (samples[e]-samples[inner]).normalized()
        var side := Vector2(-away.y,away.x)
        var w: float = hw[e]*2.0+18.0
        var d: float = 34.0 if mode == "practice" else 46.0
        var o: Vector2 = samples[e]-side*w*0.5+away*0.6
        var ok: bool = true
        for a in [0.0,0.5,1.0]:
            for b in [0.0,0.5,1.0]:
                var q: Vector2 = o+side*w*a+away*d*b
                if absf(q.x) > FIELD.HALF_X-30.0 or absf(q.y) > FIELD.HALF_Z-30.0 or field.is_water(q.x,q.y):
                    ok = false
                if field.relief == "coast" and field.coast_distance(q.x,q.y) < 8.0:
                    ok = false
        if ok:
            out.append({"end":end,"o":o,"u":side,"v":away,"w":w,"d":d,"y":rh[e]})
    return out

func _deform() -> void:
    var h: PackedFloat32Array = field.base.duplicate()
    if field.relief == "urban":
        road_gap.resize(h.size())
        road_gap.fill(INF)
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
    var canyon: bool = field.relief == "canyon"
    var rocky: bool = str(field.info["rock_kind"]) in ["granite","limestone","basalt"]
    var urban: bool = field.relief == "urban"
    for k in touched.keys():
        var d2: float = sqrt(best_d[k])
        if urban:
            road_gap[k] = d2-best_w[k]
        var core: float = best_w[k]+BENCH_M
        if d2 > core+INFLUENCE_M-6.0:
            continue
        if coast and field.water[k] == 1:
            continue
        if canyon:
            # v0.1.27: the road never fills or cuts the stream channel; it
            # crosses on a bridge (class 4) and the water runs on under it.
            var kx: float = -FIELD.HALF_X+float(k%nx)*FIELD.STEP
            var kz: float = -FIELD.HALF_Z+float(k/nx)*FIELD.STEP
            if absf(field.stream_offset(kx,kz)) < PROFILE.STREAM_CHANNEL_M:
                # Only clear the deck: banks under the bridge drop below it.
                if d2 <= best_w[k]+3.0:
                    h[k] = minf(field.base[k],best_h[k]-ROAD_SINK-2.4)
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
    # Start / finish pads of open routes: flat at the pad level, cut / fill
    # slopes around them (never touching the road bench).
    for pad in road.get("end_pads",[]):
        var o: Vector2 = pad["o"]
        var ua: Vector2 = pad["u"]
        var va: Vector2 = pad["v"]
        var pw: float = pad["w"]
        var pd: float = pad["d"]
        var py: float = float(pad["y"])-ROAD_SINK
        var c0: Vector2 = o+ua*pw*0.5+va*pd*0.5
        var reach: float = maxf(pw,pd)*0.5+40.0
        var i0: int = maxi(0,int(ceil((c0.x-reach+FIELD.HALF_X)/FIELD.STEP)))
        var i1: int = mini(nx-1,int(floor((c0.x+reach+FIELD.HALF_X)/FIELD.STEP)))
        var j0: int = maxi(0,int(ceil((c0.y-reach+FIELD.HALF_Z)/FIELD.STEP)))
        var j1: int = mini(field.nz-1,int(floor((c0.y+reach+FIELD.HALF_Z)/FIELD.STEP)))
        for gj in range(j0,j1+1):
            for gi in range(i0,i1+1):
                var k2: int = gj*nx+gi
                if best_d[k2] < INF and sqrt(best_d[k2]) <= best_w[k2]+BENCH_M:
                    continue
                var q := Vector2(-FIELD.HALF_X+float(gi)*FIELD.STEP,-FIELD.HALF_Z+float(gj)*FIELD.STEP)
                var lu: float = (q-c0).dot(ua)
                var lv: float = (q-c0).dot(va)
                var out_d: float = Vector2(maxf(absf(lu)-pw*0.5,0.0),maxf(absf(lv)-pd*0.5,0.0)).length()
                var orig: float = h[k2]
                var dz: float = orig-py
                var slope: float = 1.6 if dz > 0.0 else 0.9
                var tgt2: float = py+signf(dz)*minf(absf(dz),out_d*slope)
                if absf(tgt2-orig) > 0.01:
                    h[k2] = tgt2
    if canyon:
        _clear_lowered_stream_bed(h)
    field.height = h

func _chunk_hash(id: Vector2i) -> int:
    var acc: int = 7
    var i0: int = id.x*CHUNK_CELLS
    var j0: int = id.y*CHUNK_CELLS
    for j in range(j0,j0+CHUNK_CELLS+1):
        for i in range(i0,i0+CHUNK_CELLS+1):
            acc = (acc*131+int(round(field.height[j*field.nx+i]*50.0))) & 0x7fffffff
            if not road_gap.is_empty():
                acc = (acc*7+int(round(clampf(road_gap[j*field.nx+i],0.0,20.0)))) & 0x7fffffff
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
    if field.relief == "urban":
        # Street paint mask (alpha): not next to the race road, not on the
        # shore, not up the hills behind the city.
        var a: float = 1.0-smoothstep(10.0,14.0,b)
        if not road_gap.is_empty():
            a *= smoothstep(9.0,15.0,road_gap[k])
        if b < FIELD.SEA_LEVEL+1.0:
            a = 0.0
        col.a = a
    return col

func _vertex(i: int, j: int) -> Vector3:
    var x: float = -FIELD.HALF_X+float(i)*FIELD.STEP
    var z: float = -FIELD.HALF_Z+float(j)*FIELD.STEP
    var y: float = field.height[j*field.nx+i]
    if field.relief == "coast":
        # Snap the grid onto the cliff line (local x, mirrored per seed).
        var d: float = field.coast_distance(x,z)
        if d >= 0.0 and d < FIELD.STEP:
            x -= (d-0.3)*field.mx
        elif d < 0.0 and d > -FIELD.STEP:
            x += (-d-0.3)*field.mx
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
        _build_stream()

## Water is a continuous strip in the canyon's local frame. Each crossing
## constrains BOTH ends of every intersecting strip cell. Linear interpolation
## then keeps the entire cell below the lowest deck vertex of that span.
const STREAM_HALF_M: float = 4.6
const STREAM_STEP_M: float = 3.0
const STREAM_DECK_CLEAR_M: float = 2.2
const STREAM_ROAD_MARGIN_M: float = 2.0
const STREAM_RAMP_SLOPE: float = 0.5
var stream_node: MeshInstance3D
var _stream_limits := PackedFloat32Array()

func stream_natural_level(lz: float) -> float:
    var wc: Vector2 = field.to_world(field.stream_x(lz),lz)
    return field.base_at(wc.x,wc.y)+1.0

func stream_level(lz: float) -> float:
    var u := clampf((lz+FIELD.HALF_Z)/STREAM_STEP_M,0,_stream_limits.size()-1)
    var i := floori(u)
    var j := mini(i+1,_stream_limits.size()-1)
    var za := i*STREAM_STEP_M-FIELD.HALF_Z
    var zb := j*STREAM_STEP_M-FIELD.HALF_Z
    return lerpf(minf(stream_natural_level(za),_stream_limits[i]),
        minf(stream_natural_level(zb),_stream_limits[j]),u-i)

func _refresh_stream_limits() -> void:
    var count := roundi(2*FIELD.HALF_Z/STREAM_STEP_M)+1
    _stream_limits.resize(count)
    _stream_limits.fill(INF)
    if road.is_empty():
        return
    var samples: Array[Vector2] = road.samples
    var left := PackedVector2Array()
    var right := PackedVector2Array()
    var n := samples.size()
    for i in range(n):
        var prev := (i-1+n)%n if road.closed else maxi(i-1,0)
        var next := (i+1)%n if road.closed else mini(i+1,n-1)
        var t := (samples[next]-samples[prev]).normalized()
        var side := Vector2(-t.y,t.x)*(float(road.halfwidths[i])+STREAM_ROAD_MARGIN_M)
        var l := samples[i]-side
        var r := samples[i]+side
        # Keep the original longitudinal clearance through the bridge approach
        # and sides, even where the pavement only grazes one bank.
        var centre: Vector2 = field.to_local(samples[i].x,samples[i].y)
        if absf(centre.x-field.stream_x(centre.y))<STREAM_HALF_M+road.halfwidths[i]+STREAM_ROAD_MARGIN_M:
            var lo := maxi(0,floori((centre.y-4.0+FIELD.HALF_Z)/STREAM_STEP_M))
            var hi := mini(count-1,ceili((centre.y+4.0+FIELD.HALF_Z)/STREAM_STEP_M))
            for k in range(lo,hi+1):
                _stream_limits[k]=minf(_stream_limits[k],road.heights[i]-STREAM_DECK_CLEAR_M)
        left.append(field.to_local(l.x,l.y))
        right.append(field.to_local(r.x,r.y))
    for i in range(n if road.closed else n-1):
        var j := (i+1)%n
        var deck := PackedVector2Array([left[i],right[i],right[j],left[j]])
        var bounds := Rect2(deck[0],Vector2.ZERO)
        for p in deck:
            bounds=bounds.expand(p)
        var first := maxi(0,floori((bounds.position.y+FIELD.HALF_Z)/STREAM_STEP_M))
        var last := mini(count-2,floori((bounds.end.y+FIELD.HALF_Z)/STREAM_STEP_M))
        var limit := minf(road.heights[i],road.heights[j])-STREAM_DECK_CLEAR_M
        for k in range(first,last+1):
            var za := k*STREAM_STEP_M-FIELD.HALF_Z
            var zb := za+STREAM_STEP_M
            var xa := field.stream_x(za)
            var xb := field.stream_x(zb)
            if bounds.end.x<minf(xa,xb)-STREAM_HALF_M or bounds.position.x>maxf(xa,xb)+STREAM_HALF_M:
                continue
            var water := PackedVector2Array([Vector2(xa-STREAM_HALF_M,za),Vector2(xa+STREAM_HALF_M,za),
                Vector2(xb+STREAM_HALF_M,zb),Vector2(xb-STREAM_HALF_M,zb)])
            if Geometry2D.intersect_polygons(deck,water).is_empty():
                continue
            _stream_limits[k]=minf(_stream_limits[k],limit)
            _stream_limits[k+1]=minf(_stream_limits[k+1],limit)
    # Propagate the tightest cap in both directions until natural water is lower.
    var rise := STREAM_STEP_M*STREAM_RAMP_SLOPE
    for i in range(1,count):
        _stream_limits[i]=minf(_stream_limits[i],_stream_limits[i-1]+rise)
    for i in range(count-2,-1,-1):
        _stream_limits[i]=minf(_stream_limits[i],_stream_limits[i+1]+rise)

## The lowered surface would otherwise disappear into the original stream bed.
## Touch only terrain cells under a lowered strip, leaving the natural channel
## and every road vertex intact. Each surrounding cell corner is below both
## water endpoints, so the two ground triangles cannot protrude through it.
func _clear_lowered_stream_bed(h: PackedFloat32Array) -> void:
    var origin := Vector2(FIELD.HALF_X,FIELD.HALF_Z)
    for k in range(_stream_limits.size()-1):
        var za := k*STREAM_STEP_M-FIELD.HALF_Z
        var zb := za+STREAM_STEP_M
        var ya := stream_natural_level(za)
        var yb := stream_natural_level(zb)
        if _stream_limits[k]>=ya and _stream_limits[k+1]>=yb:
            continue
        var a := field.to_world(field.stream_x(za),za)
        var b := field.to_world(field.stream_x(zb),zb)
        var side := Vector2(STREAM_HALF_M,0)
        var lo := Vector2i(((a.min(b)-side+origin)/FIELD.STEP).floor())
        var hi := Vector2i(((a.max(b)+side+origin)/FIELD.STEP).ceil())
        var bed := minf(minf(ya,_stream_limits[k]),minf(yb,_stream_limits[k+1]))-0.30
        for j in range(maxi(0,lo.y),mini(field.nz-1,hi.y)+1):
            for i in range(maxi(0,lo.x),mini(field.nx-1,hi.x)+1):
                var idx := j*field.nx+i
                h[idx]=minf(h[idx],bed)

func _build_stream() -> void:
    if _stream_limits.is_empty():
        _refresh_stream_limits()
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var prev_l := Vector3.ZERO
    var prev_r := Vector3.ZERO
    var first: bool = true
    for i in range(_stream_limits.size()):
        var z := i*STREAM_STEP_M-FIELD.HALF_Z
        var cx: float = field.stream_x(z)
        var y := minf(stream_natural_level(z),_stream_limits[i])
        var wl: Vector2 = field.to_world(cx-STREAM_HALF_M,z)
        var wr: Vector2 = field.to_world(cx+STREAM_HALF_M,z)
        var l := Vector3(wl.x,y,wl.y)
        var r := Vector3(wr.x,y,wr.y)
        if not first:
            for p in [prev_l,prev_r,l,l,prev_r,r]:
                st.set_normal(Vector3.UP)
                st.add_vertex(p)
        prev_l = l
        prev_r = r
        first = false
    var mesh: ArrayMesh = st.commit()
    if stream_node == null:
        stream_node = MeshInstance3D.new()
        stream_node.name = "Stream"
        stream_node.material_override = _water_material()
        add_child(stream_node)
    stream_node.mesh = mesh

func _build_cliff_face() -> void:
    # v0.1.27: dedicated vertical rock face along the sea cliff with basalt
    # strata (alternating bands and small ledges), a surf line at its foot
    # and sea stacks offshore. Built in the seed's local frame, then mirrored.
    var g: Dictionary = field.info["ground"]
    var rock: Color = Color(g["rock"])
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var foam := SurfaceTool.new()
    foam.begin(Mesh.PRIMITIVE_TRIANGLES)
    var z: float = -FIELD.HALF_Z-60.0
    var step: float = 5.0
    var rows: int = 10
    var prev: Array = []
    var prev_f: Array = []
    var nx: float = -field.mx
    while z <= FIELD.HALF_Z+60.0:
        var x: float = field.coast_x(z)-0.45
        var wtop: Vector2 = field.to_world(x+3.0,z)
        var top: float = field.raw_height(wtop.x,wtop.y)-0.2
        var col: Array = []
        for r in range(rows+1):
            var f: float = float(r)/float(rows)
            var y: float = lerpf(-8.0,top,f)
            var jitter: float = 1.6*field._n(5,z*1.7,y*1.3)+0.9*sin(z*0.9+y*0.5)
            var ledge: float = 0.9 if r % 3 == 1 else 0.0            # strata ledges
            var lx: float = x-maxf(0.0,jitter)-0.2-ledge
            var w: Vector2 = field.to_world(lx,z)
            col.append(Vector3(w.x,y,w.y))
        if not prev.is_empty():
            for r in range(rows):
                var band: float = 0.86 if r % 2 == 0 else 1.0
                var shade: float = (0.70+0.30*(float(r)/float(rows)))*band
                var rc: Color = rock*shade
                if r == 0:
                    rc = rc.darkened(0.40)
                var a: Vector3 = prev[r]
                var b: Vector3 = col[r]
                var c: Vector3 = col[r+1]
                var d: Vector3 = prev[r+1]
                for p in [a,b,c,a,c,d]:
                    st.set_color(rc)
                    st.set_normal(Vector3(nx,0.0,0.0))
                    st.add_vertex(p)
        # Surf line: a white band on the water along the foot of the cliff.
        var f0: Vector2 = field.to_world(x-0.5,z)
        var f1: Vector2 = field.to_world(x-7.0-3.0*absf(sin(z*0.07)),z)
        var fc: Array = [Vector3(f0.x,0.18,f0.y),Vector3(f1.x,0.18,f1.y)]
        if not prev_f.is_empty():
            for p in [prev_f[0],fc[0],fc[1],prev_f[0],fc[1],prev_f[1]]:
                foam.set_color(Color(0.92,0.95,0.97,1.0))
                foam.set_normal(Vector3.UP)
                foam.add_vertex(p)
        prev = col
        prev_f = fc
        z += step
    # Sea stacks: jagged basalt columns standing offshore.
    var rng := RandomNumberGenerator.new()
    rng.seed = field.terrain_seed*977+13
    var count: int = rng.randi_range(4,7)
    for k in range(count):
        var lz: float = rng.randf_range(-FIELD.HALF_Z*0.95,FIELD.HALF_Z*0.95)
        var lx: float = field.coast_x(lz)-rng.randf_range(26.0,130.0)
        var rad: float = rng.randf_range(6.0,15.0)
        var top2: float = float(field.macro.get("cliff_h",58.0))*rng.randf_range(0.40,0.92)
        _stack(st,field.to_world(lx,lz),rad,top2,rock,rng)
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
    var fm: ArrayMesh = foam.commit()
    var fmat := StandardMaterial3D.new()
    fmat.vertex_color_use_as_albedo = true
    fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    fmat.cull_mode = BaseMaterial3D.CULL_DISABLED
    fm.surface_set_material(0,fmat)
    var fnode := MeshInstance3D.new()
    fnode.name = "Surf line"
    fnode.mesh = fm
    fnode.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(fnode)

func _stack(st: SurfaceTool, c: Vector2, rad: float, top: float, rock: Color, rng: RandomNumberGenerator) -> void:
    var sides: int = 8
    var tiers: int = 5
    var rings: Array = []
    for t in range(tiers+1):
        var f: float = float(t)/float(tiers)
        var y: float = lerpf(-9.0,top,f)
        var rr: float = rad*(1.0-0.28*f)
        var ring: Array = []
        for k in range(sides):
            var a: float = TAU*float(k)/float(sides)
            var j: float = rr*rng.randf_range(0.80,1.15)
            ring.append(Vector3(c.x+cos(a)*j,y,c.y+sin(a)*j))
        rings.append(ring)
    for t in range(tiers):
        var shade: Color = rock*(0.78+0.22*float(t)/float(tiers))*(0.88 if t % 2 == 0 else 1.0)
        for k in range(sides):
            var a: Vector3 = rings[t][k]
            var b: Vector3 = rings[t][(k+1)%sides]
            var d: Vector3 = rings[t+1][(k+1)%sides]
            var e: Vector3 = rings[t+1][k]
            var n: Vector3 = ((a+b)*0.5-Vector3(c.x,(a.y+e.y)*0.5,c.y)).normalized()
            for p in [a,b,d,a,d,e]:
                st.set_color(shade)
                st.set_normal(n)
                st.add_vertex(p)
    var cap: Vector3 = Vector3(c.x,top+rad*0.15,c.y)
    for k in range(sides):
        for p in [rings[tiers][k],rings[tiers][(k+1)%sides],cap]:
            st.set_color(Color(0.36,0.48,0.26))     # grass on the stack top
            st.set_normal(Vector3.UP)
            st.add_vertex(p)

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
    # Bridges. v0.1.27 (owner reference: Polish stone bridges and viaducts):
    # Poland / Ireland get masonry ARCH bridges whose arches grow with the
    # height of the valley (low stream bridges: two or three flat arches;
    # deep valleys: tall piers with round arches, like a railway viaduct);
    # Japan keeps the concrete slab + wall piers.
    var arch_style: bool = str(field.info["country"]) != "japan"
    var runs: Array = []
    var cur_run: Array = []
    for i2 in range(n):
        if cls[i2] == 4:
            cur_run.append(i2)
        elif not cur_run.is_empty():
            runs.append(cur_run)
            cur_run = []
    if not cur_run.is_empty():
        runs.append(cur_run)
    for run in runs:
        # Include one sample either side so the bridge meets the embankment.
        var idx: Array = []
        var first: int = int(run[0])
        var last: int = int(run[run.size()-1])
        if first > 0 or closed:
            idx.append((first-1+n)%n)
        idx.append_array(run)
        if last < n-1 or closed:
            idx.append((last+1)%n)
        if idx.size() < 2:
            continue
        if arch_style:
            _arch_bridge(st,samples,hw,rh,nrms,idx,wall_col,count)
        else:
            _slab_bridge(st,samples,hw,rh,nrms,idx,count)
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

## Concrete deck slab + girders + wall piers (Japan).
func _slab_bridge(st: SurfaceTool, samples: Array[Vector2], hw: PackedFloat32Array, rh: PackedFloat32Array,
        nrms: Array[Vector2], idx: Array, count: Dictionary) -> void:
    var since_pier: float = 999.0
    for k in range(idx.size()-1):
        var i2: int = idx[k]
        var j2: int = idx[k+1]
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

## Masonry arch bridge / viaduct along samples idx: spandrel walls with the
## arch openings cut out, arch barrels, piers with a string course at the
## springing line, parapets with coping. Arch span and rise follow the
## clearance (deeper valley = bigger, rounder arches on taller piers).
func _arch_bridge(st: SurfaceTool, samples: Array[Vector2], hw: PackedFloat32Array, rh: PackedFloat32Array,
        nrms: Array[Vector2], idx: Array, stone: Color, count: Dictionary) -> void:
    var m: int = idx.size()
    var s_at := PackedFloat32Array()
    s_at.resize(m)
    var clear_max: float = 0.0
    for k in range(m):
        if k > 0:
            s_at[k] = s_at[k-1]+samples[idx[k-1]].distance_to(samples[idx[k]])
        var p: Vector2 = samples[idx[k]]
        var g: float = field.height_at(p.x,p.y)
        if field.is_water(p.x,p.y):
            g = minf(g,-1.0)
        clear_max = maxf(clear_max,rh[idx[k]]-1.2-g)
    var total: float = s_at[m-1]
    if total < 4.0:
        return
    var want: float = clampf(clear_max*0.9,9.0,26.0)
    var arches: int = maxi(1,int(round(total/want)))
    var span: float = total/float(arches)
    var rise: float = minf(span*0.5,maxf(1.6,clear_max*0.6))
    var crown: float = 0.9
    var tone: Color = stone.lerp(Color(0.66,0.62,0.55),0.5)
    var dark: Color = tone.darkened(0.22)
    var intr := PackedFloat32Array()
    intr.resize(m)
    for k2 in range(m):
        var u: float = fposmod(s_at[k2],span)
        if k2 == m-1:
            u = span
        var x: float = (u-span*0.5)/(span*0.5)
        var y_spring: float = rh[idx[k2]]-1.2-crown-rise
        intr[k2] = y_spring+rise*sqrt(maxf(0.0,1.0-x*x))
    for k3 in range(m-1):
        var i: int = idx[k3]
        var j: int = idx[k3+1]
        var sh: Color = tone.lightened(0.05*float((k3*7)%3)-0.04)
        for side in [-1.0,1.0]:
            var a: Vector2 = samples[i]+nrms[i]*side*(hw[i]+1.0)
            var b: Vector2 = samples[j]+nrms[j]*side*(hw[j]+1.0)
            # Spandrel wall from the arch line up to the parapet top.
            _quad(st,Vector3(a.x,intr[k3],a.y),Vector3(b.x,intr[k3+1],b.y),Vector3(b.x,rh[j]+1.0,b.y),Vector3(a.x,rh[i]+1.0,a.y),sh)
            # Parapet coping.
            var ai: Vector2 = samples[i]+nrms[i]*side*(hw[i]+0.4)
            var bi: Vector2 = samples[j]+nrms[j]*side*(hw[j]+0.4)
            _quad(st,Vector3(ai.x,rh[i]+1.0,ai.y),Vector3(bi.x,rh[j]+1.0,bi.y),Vector3(b.x,rh[j]+1.0,b.y),Vector3(a.x,rh[i]+1.0,a.y),tone.lightened(0.12))
            _quad(st,Vector3(ai.x,rh[i]+0.05,ai.y),Vector3(bi.x,rh[j]+0.05,bi.y),Vector3(bi.x,rh[j]+1.0,bi.y),Vector3(ai.x,rh[i]+1.0,ai.y),sh.darkened(0.05))
        # Arch barrel (soffit).
        var l0: Vector2 = samples[i]-nrms[i]*(hw[i]+1.0)
        var r0: Vector2 = samples[i]+nrms[i]*(hw[i]+1.0)
        var l1: Vector2 = samples[j]-nrms[j]*(hw[j]+1.0)
        var r1: Vector2 = samples[j]+nrms[j]*(hw[j]+1.0)
        _quad(st,Vector3(l0.x,intr[k3],l0.y),Vector3(l1.x,intr[k3+1],l1.y),Vector3(r1.x,intr[k3+1],r1.y),Vector3(r0.x,intr[k3],r0.y),dark)
        count["bridge_m"] = float(count["bridge_m"])+samples[i].distance_to(samples[j])
    # Piers (and abutments at both ends) at every springing point.
    var pier_t: float = clampf(span*0.16,1.8,3.6)
    for q in range(arches+1):
        var sq: float = span*float(q)
        var k4: int = 0
        while k4 < m-2 and s_at[k4+1] < sq:
            k4 += 1
        var f: float = clampf((sq-s_at[k4])/maxf(s_at[k4+1]-s_at[k4],0.01),0.0,1.0)
        var pa: Vector2 = samples[idx[k4]]
        var pb: Vector2 = samples[idx[k4+1]]
        var pp: Vector2 = pa.lerp(pb,f)
        var nn: Vector2 = nrms[idx[k4]].lerp(nrms[idx[k4+1]],f).normalized()
        var deck: float = lerpf(rh[idx[k4]],rh[idx[k4+1]],f)
        var spring: float = deck-1.2-crown-rise
        # Lowest ground under the pier footprint (terrain as adapted).
        var ground: float = INF
        for o in [-1.0,0.0,1.0]:
            var gp: Vector2 = pp+nn*o*(lerpf(hw[idx[k4]],hw[idx[k4+1]],f)+1.0)
            ground = minf(ground,field.height_at(gp.x,gp.y))
        if field.is_water(pp.x,pp.y):
            ground = minf(ground,-1.5)
        var w2: float = lerpf(hw[idx[k4]],hw[idx[k4+1]],f)+1.0
        var t := Vector2(-nn.y,nn.x)
        var end_pier: bool = q == 0 or q == arches
        var top: float = deck+1.0 if end_pier else spring+0.4
        var half_t: float = pier_t*(0.9 if end_pier else 0.5)
        if ground < top-0.5:
            # Tall piers batter out towards the ground.
            var flare: float = 1.0+clampf((spring-ground)/60.0,0.0,0.25)
            _box_xz(st,pp,nn,t,w2+0.3,half_t,ground-1.5,spring,tone.darkened(0.06),w2*flare+0.3,half_t*flare)
            if not end_pier:
                _box_xz(st,pp,nn,t,w2+0.55,half_t+0.25,spring-0.35,spring+0.05,tone.lightened(0.10),w2+0.55,half_t+0.25)
            count["pier"] = int(count["pier"])+1

## Upright box around p: half sizes along nrm (across) and t (along), with
## optional larger half sizes at the bottom (battered pier).
func _box_xz(st: SurfaceTool, p: Vector2, nrm: Vector2, t: Vector2, half_n: float, half_t: float, y0: float, y1: float,
        col: Color, bot_n: float = -1.0, bot_t: float = -1.0) -> void:
    var bn: float = half_n if bot_n < 0.0 else bot_n
    var bt: float = half_t if bot_t < 0.0 else bot_t
    var top_c: Array = [p-nrm*half_n-t*half_t,p+nrm*half_n-t*half_t,p+nrm*half_n+t*half_t,p-nrm*half_n+t*half_t]
    var bot_c: Array = [p-nrm*bn-t*bt,p+nrm*bn-t*bt,p+nrm*bn+t*bt,p-nrm*bn+t*bt]
    for k in range(4):
        var a: Vector2 = bot_c[k]
        var b: Vector2 = bot_c[(k+1)%4]
        var c: Vector2 = top_c[(k+1)%4]
        var d: Vector2 = top_c[k]
        _quad(st,Vector3(a.x,y0,a.y),Vector3(b.x,y0,b.y),Vector3(c.x,y1,c.y),Vector3(d.x,y1,d.y),col.darkened(0.06*float(k%2)))
    _quad(st,Vector3(top_c[0].x,y1,top_c[0].y),Vector3(top_c[1].x,y1,top_c[1].y),Vector3(top_c[2].x,y1,top_c[2].y),Vector3(top_c[3].x,y1,top_c[3].y),col.lightened(0.08))

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
    # v0.1.27 colour pass (owner: terrain races looked desaturated next to
    # the classic tracks): a cooler, lower ambient so asphalt and shadows
    # stay deep, linear tone mapping like the classic tracks, a touch of
    # saturation, and DEPTH fog that starts 220 m away, so the road and the
    # first rows of trees (all the top-down camera sees) are never hazed;
    # aerial perspective stays on the distant mountains.
    env.ambient_light_color = Color(sky_info["horizon"]).lerp(Color(sky_info["top"]),0.35).lerp(Color.WHITE,0.15)
    env.ambient_light_energy = float(sky_info["ambient"])*0.82
    env.fog_enabled = true
    env.fog_mode = Environment.FOG_MODE_DEPTH
    env.fog_depth_begin = 220.0
    env.fog_depth_end = 2400.0
    env.fog_depth_curve = 1.4
    env.fog_light_color = Color(sky_info["fog"])
    env.fog_density = clampf(float(sky_info["fog_density"])*480.0,0.35,0.75)
    env.fog_sky_affect = 0.25
    env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
    env.adjustment_enabled = true
    env.adjustment_saturation = 1.12
    env.adjustment_contrast = 1.05
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
        env.fog_enabled = k > 0.001
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
