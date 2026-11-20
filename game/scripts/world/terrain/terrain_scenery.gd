extends Node3D
class_name NitroTerrainScenery
## Region scenery of the terrain-first world, zoned around the road:
##
##  * vegetation: per-archetype species mix (sakura, Japanese black pine,
##    sugi cedar, autumn beech/maple, spruce, dwarf mountain pine, gorse,
##    wind-bent trees, oak, hawthorn hedgerows...) placed on the forest mask,
##    one MultiMesh per (chunk, species) so a road edit only refills the
##    chunks it touched and the frustum culls whole chunks;
##  * rocks by geology (limestone, granite, basalt, mossy boulders);
##  * field boundaries: Irish hawthorn hedgerows / dry-stone walls;
##  * ONE venue next to the start (event mode practice / club / pro) and the
##    archetype's landmarks OUTSIDE the play area (village, castle rock,
##    mountain hut, lighthouse, tower-house ruin, harbour expressway,
##    skyline). City blocks stand back from the road, never on road tiles;
##  * safety exclusion: nothing solid within road half-width + verge +
##    barrier margin + run-off of the road.
const CAT = preload("res://scripts/world/terrain/terrain_catalog.gd")
const FIELD = preload("res://scripts/world/terrain/terrain_field.gd")
const PROFILE = preload("res://scripts/world/terrain/road_profile.gd")
const MODS = preload("res://scripts/world/scenery_modules.gd")
const VEG_SHADER = preload("res://assets/shaders/terrain_vegetation.gdshader")
const SHADOW_SHADER = preload("res://assets/shaders/soft_shadow.gdshader")

const SAFETY_M: float = 6.0          # run-off beyond verge + barrier margin
const ROAD_CELL: float = 32.0

# Species: crown shape, colour, size range (m), trunk share.
const SPECIES: Dictionary = {
    "sakura":{"shape":"voxel","col":Color(1.0,0.70,0.84),"h":[6.0,8.5]},
    "pine_jp":{"shape":"pads","col":Color(0.22,0.38,0.22),"h":[7.0,11.0]},
    "cedar":{"shape":"spire","col":Color(0.16,0.32,0.19),"h":[16.0,24.0]},
    "broadleaf_green":{"shape":"round","col":Color(0.32,0.54,0.24),"h":[10.0,15.0]},
    "street_tree":{"shape":"round_small","col":Color(0.34,0.56,0.26),"h":[6.0,8.0]},
    "autumn_gold":{"shape":"round","col":Color(0.96,0.72,0.20),"h":[10.0,16.0]},
    "autumn_red":{"shape":"round","col":Color(0.84,0.26,0.13),"h":[9.0,14.0]},
    "autumn_orange":{"shape":"round","col":Color(0.95,0.50,0.15),"h":[9.0,15.0]},
    "pine_eu":{"shape":"umbrella","col":Color(0.20,0.34,0.20),"h":[14.0,20.0]},
    "spruce":{"shape":"tiers","col":Color(0.12,0.27,0.18),"h":[14.0,24.0]},
    "dwarf_pine":{"shape":"mat","col":Color(0.20,0.36,0.19),"h":[1.6,2.6]},
    "gorse":{"shape":"bush","col":Color(0.62,0.66,0.22),"h":[1.4,2.4]},
    "windswept":{"shape":"lean","col":Color(0.28,0.42,0.20),"h":[4.0,6.5]},
    "oak":{"shape":"round","col":Color(0.30,0.48,0.21),"h":[12.0,17.0]},
    "hawthorn":{"shape":"bush","col":Color(0.32,0.50,0.22),"h":[3.0,4.6]},
}
const TRUNK := Color(0.30,0.22,0.16)

var world: NitroTerrainWorld
var field: NitroTerrainField
var info: Dictionary = {}
var seed_value: int = 1
var chunk_nodes: Dictionary = {}          # Vector2i -> Node3D
var road_cells: Dictionary = {}           # Vector2i -> Array of [a, b, hw]
var road_sig: Dictionary = {}             # chunk -> signature of road segments near it
var keep_out: Array = []                  # Rect2 footprints of landmarks (fixed per world)
var venue_keep: Array = []                # Rect2 footprints of the venue (follows the start)
var venue_rect: Rect2 = Rect2()
var venue_info: Dictionary = {}
var landmark_info: Array = []
var counts: Dictionary = {}
var _meshes: Dictionary = {}
var _veg_mat: ShaderMaterial
var _shadow_mat: ShaderMaterial
var _rock_mat: StandardMaterial3D
var _mats: Array = []
var landmark_node: Node3D
var venue_node: Node3D
## Race: vegetation / rocks of a chunk stop drawing beyond this distance
## (metres from the chunk centre; 0 = always, used by the builder overview).
var draw_range: float = 0.0
var _chunk_centre: Vector3 = Vector3.ZERO

func setup(w: NitroTerrainWorld) -> void:
    world = w
    field = w.field
    info = field.info
    var sc: int = int(w.desc.get("scenery_seed",-1))
    seed_value = sc if sc >= 0 else int(w.desc.get("terrain_seed",1))
    _veg_mat = ShaderMaterial.new()
    _veg_mat.shader = VEG_SHADER
    _shadow_mat = ShaderMaterial.new()
    _shadow_mat.shader = SHADOW_SHADER
    _shadow_mat.set_shader_parameter("core",Vector2(0.16,0.16))
    _shadow_mat.set_shader_parameter("softness",0.30)
    _shadow_mat.set_shader_parameter("corner",0.16)
    _shadow_mat.set_shader_parameter("opacity",0.42)
    _rock_mat = StandardMaterial3D.new()
    _rock_mat.vertex_color_use_as_albedo = true
    _rock_mat.roughness = 0.95
    _mats = MODS.materials()

# ------------------------------------------------------------------ build

func rebuild_all() -> void:
    for child in get_children():
        remove_child(child)
        child.queue_free()
    chunk_nodes.clear()
    keep_out.clear()
    landmark_info.clear()
    counts = {}
    _index_road()
    landmark_node = Node3D.new()
    landmark_node.name = "Landmarks"
    add_child(landmark_node)
    _build_landmarks()
    venue_node = Node3D.new()
    venue_node.name = "Venue"
    add_child(venue_node)
    _build_venue()
    var cc: Vector2i = world.chunk_counts()
    for cz in range(cc.y):
        for cx in range(cc.x):
            _build_chunk(Vector2i(cx,cz))

## Called by the world after a road edit with the chunks whose terrain
## changed; also refreshes every chunk whose nearby road segments changed
## (exclusion) and the chunks under the old / new venue.
func on_road_changed(dirty: Array) -> Array:
    var old_sig: Dictionary = road_sig.duplicate()
    var old_venue: Rect2 = _venue_bounds()
    _index_road()
    _build_venue()
    var todo: Dictionary = {}
    for id in dirty:
        todo[id] = true
    for id2 in road_sig.keys():
        if int(old_sig.get(id2,0)) != int(road_sig[id2]):
            todo[id2] = true
    for id3 in old_sig.keys():
        if not road_sig.has(id3):
            todo[id3] = true
    var new_venue: Rect2 = _venue_bounds()
    if old_venue != new_venue:
        for r in [old_venue,new_venue]:
            for id4 in _chunks_of_rect(r):
                todo[id4] = true
    for id5 in todo.keys():
        _build_chunk(id5)
    return todo.keys()

func _venue_bounds() -> Rect2:
    var out := Rect2()
    for r in venue_keep:
        out = r if out.size == Vector2.ZERO else out.merge(r)
    return out

func _chunks_of_rect(r: Rect2) -> Array:
    var out: Array = []
    if r.size == Vector2.ZERO:
        return out
    var span: float = float(world.CHUNK_CELLS)*FIELD.STEP
    var cc: Vector2i = world.chunk_counts()
    var a := Vector2i(int(floor((r.position.x+FIELD.HALF_X)/span)),int(floor((r.position.y+FIELD.HALF_Z)/span)))
    var b := Vector2i(int(floor((r.end.x+FIELD.HALF_X)/span)),int(floor((r.end.y+FIELD.HALF_Z)/span)))
    for z in range(maxi(a.y,0),mini(b.y,cc.y-1)+1):
        for x in range(maxi(a.x,0),mini(b.x,cc.x-1)+1):
            out.append(Vector2i(x,z))
    return out

# ------------------------------------------------------------- road index

func _index_road() -> void:
    road_cells.clear()
    road_sig.clear()
    var road: Dictionary = world.road
    if road.is_empty():
        return
    var samples: Array[Vector2] = road["samples"]
    var hw: PackedFloat32Array = road["halfwidths"]
    var closed: bool = road["closed"]
    var n: int = samples.size()
    var segs: int = n if closed else n-1
    var span: float = float(world.CHUNK_CELLS)*FIELD.STEP
    var reach: float = 40.0
    for i in range(segs):
        var a: Vector2 = samples[i]
        var b: Vector2 = samples[(i+1)%n]
        var w: float = maxf(hw[i],hw[(i+1)%n])
        var lo := Vector2(minf(a.x,b.x),minf(a.y,b.y))-Vector2.ONE*(w+reach)
        var hi := Vector2(maxf(a.x,b.x),maxf(a.y,b.y))+Vector2.ONE*(w+reach)
        for cz in range(int(floor(lo.y/ROAD_CELL)),int(floor(hi.y/ROAD_CELL))+1):
            for cx in range(int(floor(lo.x/ROAD_CELL)),int(floor(hi.x/ROAD_CELL))+1):
                var key := Vector2i(cx,cz)
                if not road_cells.has(key):
                    road_cells[key] = []
                road_cells[key].append([a,b,w])
        # Chunk signatures (which segments run near each scenery chunk).
        var ca := Vector2i(int(floor((lo.x+FIELD.HALF_X)/span)),int(floor((lo.y+FIELD.HALF_Z)/span)))
        var cb := Vector2i(int(floor((hi.x+FIELD.HALF_X)/span)),int(floor((hi.y+FIELD.HALF_Z)/span)))
        for z in range(ca.y,cb.y+1):
            for x in range(ca.x,cb.x+1):
                var id := Vector2i(x,z)
                var h: int = int(road_sig.get(id,11))
                h = (h*131+int(a.x*4.0)*7+int(a.y*4.0)*13+int(w*10.0)) & 0x7fffffff
                road_sig[id] = h

## Distance from p to the nearest road EDGE (negative = on the road);
## INF when no road is within ~40 m.
func road_clearance(p: Vector2) -> float:
    var key := Vector2i(int(floor(p.x/ROAD_CELL)),int(floor(p.y/ROAD_CELL)))
    var segs: Array = road_cells.get(key,[])
    var best: float = INF
    for s in segs:
        var a: Vector2 = s[0]
        var b: Vector2 = s[1]
        var ab: Vector2 = b-a
        var t: float = clampf((p-a).dot(ab)/maxf(ab.length_squared(),0.0001),0.0,1.0)
        best = minf(best,p.distance_to(a+ab*t)-float(s[2]))
    return best

func _blocked(p: Vector2, radius: float) -> bool:
    if road_clearance(p) < PROFILE.VERGE+PROFILE.MARGIN+SAFETY_M+radius:
        return true
    for r in keep_out+venue_keep:
        if (r as Rect2).grow(radius).has_point(p):
            return true
    return false

# ------------------------------------------------------- per-chunk scatter

func _rng_for(id: Vector2i, salt: int) -> RandomNumberGenerator:
    var rng := RandomNumberGenerator.new()
    rng.seed = FIELD.hash_seed(seed_value*7919+id.x*131+id.y*977+salt,str(info.get("short","")),salt)
    return rng

func _pick_species(rng: RandomNumberGenerator, x: float, z: float) -> String:
    var trees: Dictionary = info["trees"]
    var keys: Array = trees.keys()
    keys.sort()
    # Groves: a slow noise shifts the pick so species cluster.
    var bias: float = field._n(5,x*0.6,z*0.6)*0.5+0.5
    var r: float = fposmod(rng.randf()*0.55+bias*0.45,1.0)
    var total: float = 0.0
    for k in keys:
        total += float(trees[k])
    var acc: float = 0.0
    for k2 in keys:
        acc += float(trees[k2])/total
        if r <= acc:
            return str(k2)
    return str(keys[keys.size()-1])

func _build_chunk(id: Vector2i) -> void:
    var old: Node3D = chunk_nodes.get(id,null)
    if old != null:
        remove_child(old)
        old.queue_free()
    var node := Node3D.new()
    node.name = "Scenery chunk %d_%d" % [id.x,id.y]
    add_child(node)
    chunk_nodes[id] = node
    var span: float = float(world.CHUNK_CELLS)*FIELD.STEP
    var x0: float = -FIELD.HALF_X+float(id.x)*span
    var z0: float = -FIELD.HALF_Z+float(id.y)*span
    var rng: RandomNumberGenerator = _rng_for(id,1)
    _chunk_centre = Vector3(x0+span*0.5,0.0,z0+span*0.5)
    var per: Dictionary = {}        # species -> [xforms, colours]
    var shadows: Array[Transform3D] = []
    var spacing: float = 11.0 if float(info["forest"]) > 0.4 else 12.0
    var cells: int = int(span/spacing)
    var relief: String = field.relief
    for b in range(cells):
        for a in range(cells):
            var x: float = x0+(float(a)+rng.randf_range(0.1,0.9))*spacing
            var z: float = z0+(float(b)+rng.randf_range(0.1,0.9))*spacing
            var dens: float = field.mask_at(field.forest,x,z)
            var roll: float = rng.randf()
            if roll > dens:
                continue
            if field.is_water(x,z):
                continue
            if relief == "coast" and field.coast_distance(x,z) < 6.0:
                continue
            var sp: String = _pick_species(rng,x,z)
            var spec: Dictionary = SPECIES[sp]
            var hr: Array = spec["h"]
            var h: float = rng.randf_range(float(hr[0]),float(hr[1]))
            var rad: float = h*0.22 if spec["shape"] in ["spire","tiers","umbrella"] else h*0.35
            if _blocked(Vector2(x,z),rad):
                continue
            if field.slope_at(x,z) > 1.1:
                continue
            _add_tree(per,shadows,sp,x,z,h,rng)
    _scatter_rocks(node,id,x0,z0,span)
    _field_lines(per,shadows,node,x0,z0,span)
    if relief == "urban":
        _city_blocks(node,id,x0,z0,span)
    var keys: Array = per.keys()
    keys.sort()
    for sp2 in keys:
        var pair: Array = per[sp2]
        var parts: PackedStringArray = str(sp2).split("#")
        _multimesh(node,"Trees %s" % sp2,_species_mesh(parts[0],int(parts[1]) if parts.size() > 1 else 0),
            _veg_mat,pair[0],pair[1])
        counts["tree_"+str(sp2)] = int(counts.get("tree_"+str(sp2),0))
    var quad := PlaneMesh.new()
    quad.size = Vector2.ONE
    _multimesh(node,"Tree shadows",quad,_shadow_mat,shadows,[])
    _recount()

func _add_tree(per: Dictionary, shadows: Array[Transform3D], sp: String, x: float, z: float, h: float,
        rng: RandomNumberGenerator) -> void:
    var y: float = field.height_at(x,z)-0.25
    # v0.1.27 variety: own proportions per tree (slim / broad), a slight
    # lean and one of two crown variants per species.
    var wide: float = rng.randf_range(0.82,1.22)
    var tall: float = rng.randf_range(0.88,1.12)
    var lean := Basis(Vector3(rng.randf_range(-1,1),0,rng.randf_range(-1,1)).normalized(),rng.randf_range(0.0,0.07))
    var basis := lean*Basis(Vector3.UP,rng.randf_range(0.0,TAU)).scaled(Vector3(wide*h,tall*h,wide*h))
    if sp == "windswept":
        # Prevailing Atlantic wind from the sea: lean away from the cliff.
        basis = Basis(Vector3.FORWARD,-0.20*field.mx)*Basis(Vector3.UP,rng.randf_range(-0.4,0.4)).scaled(Vector3(wide*h,tall*h,wide*h))
    var key: String = "%s#%d" % [sp,rng.randi_range(0,1)]
    if not per.has(key):
        per[key] = [[],[]]
    per[key][0].append(Transform3D(basis,Vector3(x,y,z)))
    var col: Color = SPECIES[sp]["col"]
    col = col.lightened(rng.randf_range(-0.10,0.12))
    if sp.begins_with("autumn"):
        col = col.lerp(Color(0.95,0.62,0.18),rng.randf_range(0.0,0.25))
    per[key][1].append(col)
    var nrm: Vector3 = _ground_normal(x,z)
    var r: float = h*(0.45 if SPECIES[sp]["shape"] not in ["spire","tiers","umbrella"] else 0.30)
    var up: Vector3 = nrm
    var right: Vector3 = up.cross(Vector3.FORWARD).normalized()
    var fwd: Vector3 = right.cross(up).normalized()
    var sb := Basis(right*r*2.2,up,fwd*r*2.5)
    shadows.append(Transform3D(sb,Vector3(x+0.18*h,field.height_at(x+0.18*h,z+0.26*h)+0.18,z+0.26*h)))

func _ground_normal(x: float, z: float) -> Vector3:
    var dx: float = (field.height_at(x+4.0,z)-field.height_at(x-4.0,z))/8.0
    var dz: float = (field.height_at(x,z+4.0)-field.height_at(x,z-4.0))/8.0
    return Vector3(-dx,1.0,-dz).normalized()

func _scatter_rocks(node: Node3D, id: Vector2i, x0: float, z0: float, span: float) -> void:
    var kind: String = str(info["rock_kind"])
    if kind == "none":
        return
    var rng: RandomNumberGenerator = _rng_for(id,2)
    var groups: Dictionary = {}        # variant -> [xforms, colours]
    var base_col: Color = Color(info["ground"]["rock"])
    var tries: int = 90
    for _k in range(tries):
        var x: float = x0+rng.randf()*span
        var z: float = z0+rng.randf()*span
        var rk: float = field.mask_at(field.rock,x,z)
        var want: float = rk*0.8+0.05
        if kind == "mossy":
            want = field.mask_at(field.forest,x,z)*0.12
        if rng.randf() > want or field.is_water(x,z):
            continue
        var s: float = rng.randf_range(0.8,3.2)*(1.6 if kind in ["granite","limestone"] and rk > 0.5 else 1.0)
        if _blocked(Vector2(x,z),s):
            continue
        var basis := Basis(Vector3.UP,rng.randf_range(0,TAU))*Basis(Vector3.RIGHT,rng.randf_range(-0.3,0.3))
        var tall: float = rng.randf_range(0.70,1.15)
        var variant: String = "boulder"
        match kind:
            "granite":
                variant = "slab" if rng.randf() < 0.45 else "boulder"
            "limestone":
                variant = "slab"
                if rk > 0.45 and rng.randf() < 0.22:
                    # Ojcow-style limestone pillar (ostaniec)
                    variant = "pillar"
                    tall = rng.randf_range(3.0,6.5)
                    s *= 1.3
            "basalt":
                variant = "columns" if rng.randf() < 0.55 else "slab"
        basis = basis.scaled(Vector3(s*rng.randf_range(0.9,1.4),s*tall,s*rng.randf_range(0.9,1.3)))
        if not groups.has(variant):
            groups[variant] = [[],[]]
        groups[variant][0].append(Transform3D(basis,Vector3(x,field.height_at(x,z)-0.25*s,z)))
        var c: Color = base_col.lightened(rng.randf_range(-0.12,0.14))
        if kind == "mossy":
            c = c.lerp(Color(0.30,0.40,0.22),0.45)
        groups[variant][1].append(c)
    var gk: Array = groups.keys()
    gk.sort()
    for v in gk:
        _multimesh(node,"Rocks "+str(v),_rock_mesh(str(v)),_rock_mat,groups[v][0],groups[v][1],false)

## Irish field boundaries: hawthorn hedgerows (hills) / dry-stone walls
## (coast), following the same field pattern as the ground tint.
func _field_lines(per: Dictionary, shadows: Array[Transform3D], node: Node3D, x0: float, z0: float, span: float) -> void:
    var mode: String = ""
    if str(info["tint_mask"]) == "fields":
        mode = "hedge"
    elif field.relief == "coast":
        mode = "wall"
    if mode == "":
        return
    var acc = MODS.Acc.new()
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_value*31+int(x0)*7+int(z0)
    var stone := Color(0.58,0.58,0.55)
    for axis in [0,1]:
        var period: float = 70.0 if axis == 0 else 52.0
        var lines_lo: int = int(floor(((x0 if axis == 0 else z0)-20.0)/period))
        var lines_hi: int = int(ceil(((x0 if axis == 0 else z0)+span+20.0)/period))
        for li in range(lines_lo,lines_hi+1):
            var t: float = 0.0
            var prev := Vector3.INF
            while t <= span:
                var along: float = (z0 if axis == 0 else x0)+t
                # Solve c + 14*n(c) = period*li for the boundary coordinate.
                var c: float = float(li)*period
                for _it in range(3):
                    if axis == 0:
                        c = float(li)*period-field._n(5,c,along)*14.0
                    else:
                        c = float(li)*period-field._n(5,c,along)*14.0
                var x: float = c if axis == 0 else along
                var z: float = along if axis == 0 else c
                var ok: bool = x >= x0 and x < x0+span and z >= z0 and z < z0+span
                ok = ok and field.inside(x,z) and not field.is_water(x,z) and not _blocked(Vector2(x,z),1.5)
                if field.relief == "coast":
                    ok = ok and field.coast_distance(x,z) > 10.0
                ok = ok and field.slope_at(x,z) < 0.6
                if ok and mode == "hedge":
                    if rng.randf() < 0.75:
                        _add_tree(per,shadows,"hawthorn",x,z,rng.randf_range(2.6,3.8),rng)
                    prev = Vector3.INF
                elif ok:
                    var p := Vector3(x,field.height_at(x,z),z)
                    if prev != Vector3.INF:
                        _wall_piece(acc,prev,p,stone.lightened(rng.randf_range(-0.08,0.08)))
                    prev = p
                else:
                    prev = Vector3.INF
                t += 7.0 if mode == "hedge" else 6.0
    if not acc.idx.is_empty():
        var mi := MeshInstance3D.new()
        mi.name = "Dry-stone walls"
        mi.mesh = acc.commit(_mats[0],_mats[1])
        mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        node.add_child(mi)

func _wall_piece(acc, a: Vector3, b: Vector3, col: Color) -> void:
    var d: Vector3 = b-a
    var side: Vector3 = Vector3(-d.z,0.0,d.x).normalized()*0.35
    var top: float = 1.05
    acc.quad(a-side+Vector3(0,-0.4,0),b-side+Vector3(0,-0.4,0),b-side*0.7+Vector3(0,top,0),a-side*0.7+Vector3(0,top,0),col)
    acc.quad(b+side+Vector3(0,-0.4,0),a+side+Vector3(0,-0.4,0),a+side*0.7+Vector3(0,top,0),b+side*0.7+Vector3(0,top,0),col.darkened(0.08))
    acc.quad(a-side*0.7+Vector3(0,top,0),b-side*0.7+Vector3(0,top,0),b+side*0.7+Vector3(0,top,0),a+side*0.7+Vector3(0,top,0),col.lightened(0.06))

## Japanese city: blocks of mid-rise buildings set back from the road
## (>= verge + barrier margin + 14 m), parks stay open.
func _city_blocks(node: Node3D, id: Vector2i, x0: float, z0: float, span: float) -> void:
    var acc = MODS.Acc.new()
    var rng: RandomNumberGenerator = _rng_for(id,3)
    var block: float = 44.0
    var n: int = int(span/block)
    var built: int = 0
    var facades: Array[Color] = [Color(0.80,0.79,0.76),Color(0.68,0.70,0.72),Color(0.86,0.83,0.76),
        Color(0.56,0.58,0.62),Color(0.74,0.66,0.58),Color(0.90,0.90,0.88)]
    for b in range(n):
        for a in range(n):
            var cx: float = x0+(float(a)+0.5)*block
            var cz: float = z0+(float(b)+0.5)*block
            if field.mask_at(field.tint,cx,cz) > 0.45 or field.is_water(cx,cz):
                continue
            if absf(cx) > FIELD.HALF_X-30.0 or absf(cz) > FIELD.HALF_Z-30.0:
                continue
            var lots: int = rng.randi_range(1,3)
            for l in range(lots):
                var w: float = rng.randf_range(12.0,20.0)
                var d: float = rng.randf_range(12.0,18.0)
                var px: float = cx+rng.randf_range(-block*0.5+w*0.5+3.0,block*0.5-w*0.5-3.0)
                var pz: float = cz+rng.randf_range(-block*0.5+d*0.5+3.0,block*0.5-d*0.5-3.0)
                var ok: bool = true
                for corner in [Vector2(-w,-d),Vector2(w,-d),Vector2(w,d),Vector2(-w,d),Vector2.ZERO]:
                    var q: Vector2 = Vector2(px,pz)+corner*0.5
                    if road_clearance(q) < PROFILE.VERGE+PROFILE.MARGIN+14.0:
                        ok = false
                        break
                    for r in keep_out+venue_keep:
                        if (r as Rect2).has_point(q):
                            ok = false
                if not ok:
                    continue
                var gy: float = INF
                for corner2 in [Vector2(-w,-d),Vector2(w,-d),Vector2(w,d),Vector2(-w,d)]:
                    gy = minf(gy,field.height_at(px+corner2.x*0.5,pz+corner2.y*0.5))
                var floors: int = rng.randi_range(2,9) if l == 0 else rng.randi_range(2,5)
                var top: float = gy+0.5+float(floors)*3.3
                acc.set_frame([Vector2(px-w*0.5,pz-d*0.5),Vector2.RIGHT,Vector2.DOWN*-1.0])
                var fc: Color = facades[rng.randi_range(0,facades.size()-1)]
                acc.box(0.0,w,0.0,d,gy-1.0,top,fc,false,Color(0.42,0.43,0.45))
                # window bands
                for f in range(floors):
                    var y: float = gy+1.4+float(f)*3.3
                    acc.box(-0.05,w+0.05,-0.05,d+0.05,y,y+1.1,Color(0.20,0.26,0.32))
                # roof equipment
                acc.box(w*0.2,w*0.45,d*0.3,d*0.6,top,top+2.2,Color(0.55,0.56,0.57))
                built += 1
    if built > 0:
        var mi := MeshInstance3D.new()
        mi.name = "City blocks"
        mi.mesh = acc.commit(_mats[0],_mats[1])
        mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        node.add_child(mi)
        counts["city_buildings"] = int(counts.get("city_buildings",0))

func _recount() -> void:
    var c: Dictionary = {}
    for id in chunk_nodes.keys():
        var node: Node3D = chunk_nodes[id]
        if not is_instance_valid(node):
            continue
        for child in node.get_children():
            if child is MultiMeshInstance3D:
                var nm: String = str(child.name)
                var key: String = "rocks" if nm.begins_with("Rocks") else ("shadows" if nm == "Tree shadows" else nm.replace("Trees ","tree_"))
                c[key] = int(c.get(key,0))+(child as MultiMeshInstance3D).multimesh.instance_count
            elif child is MeshInstance3D:
                c[str(child.name)] = int(c.get(str(child.name),0))+1
    var trees: int = 0
    for k in c.keys():
        if str(k).begins_with("tree_"):
            trees += int(c[k])
    c["trees_total"] = trees
    counts = c

# ------------------------------------------------------------------ venue

## One venue next to the start line; size by event mode. Returns its info.
func _build_venue() -> void:
    for child in venue_node.get_children():
        venue_node.remove_child(child)
        child.queue_free()
    venue_rect = Rect2()
    venue_info = {}
    venue_keep.clear()
    var road: Dictionary = world.road
    if road.is_empty():
        return
    var samples: Array[Vector2] = road["samples"]
    var hw: PackedFloat32Array = road["halfwidths"]
    var rh: PackedFloat32Array = road["heights"]
    var closed: bool = road["closed"]
    var mode: String = str(world.desc.get("event_mode","club"))
    var venue: String = str(info["venue"])
    var acc = MODS.Acc.new()
    var n: int = samples.size()
    var p0: Vector2 = samples[0]
    var t0: Vector2 = (samples[1]-samples[0]).normalized()
    var nrm := Vector2(-t0.y,t0.x)
    var y0: float = rh[0]
    var w0: float = hw[0]
    # Start gantry over the road (club / pro), timing hut for practice.
    if mode != "practice":
        _gantry(acc,p0,t0,nrm,w0,y0,venue)
    # Paddock pad beside the start (not for a mountain-pass start).
    var pad_w: float = 30.0 if mode == "practice" else (40.0 if mode == "club" else 56.0)
    var pad_d: float = 16.0 if mode == "practice" else 24.0
    if venue == "touge_start":
        pad_w = 22.0
        pad_d = 12.0
    var best: Dictionary = {}
    # Candidates beside the road near the start, walking along the samples
    # (up to ~250 m either way on a loop, forward only on an open route).
    var cands: Array = []
    for step in range(0,64,6):
        for sgn in ([1,-1] if closed else [1]):
            var k: int = step*sgn
            if not closed and (k < 0 or k >= n-1):
                continue
            cands.append(posmod(k,n))
    for side in [1.0,-1.0]:
        for ci in cands:
            var ck: int = ci
            var tk: Vector2 = (samples[mini(ck+1,n-1)]-samples[maxi(ck-1,0)]).normalized() if not closed \
                else (samples[(ck+1)%n]-samples[(ck-1+n)%n]).normalized()
            var nk := Vector2(-tk.y,tk.x)
            var gap: float = hw[ck]+PROFILE.VERGE+PROFILE.MARGIN+SAFETY_M+pad_d*0.5+2.0
            var c: Vector2 = samples[ck]+nk*side*gap
            var along: float = float(absi(ck if ck <= n/2 else n-ck))*4.5
            var r := _rect_from(c,tk,pad_w,pad_d)
            var ok: bool = true
            var lo: float = INF
            var hi: float = -INF
            for q in _rect_points(c,tk,nk,pad_w,pad_d):
                if not field.inside(q.x,q.y) or field.is_water(q.x,q.y):
                    ok = false
                    break
                if road_clearance(q) < PROFILE.VERGE+PROFILE.MARGIN+SAFETY_M-0.5:
                    ok = false
                    break
                if field.relief == "coast" and field.coast_distance(q.x,q.y) < 12.0:
                    ok = false
                    break
                var gh: float = field.height_at(q.x,q.y)
                lo = minf(lo,gh)
                hi = maxf(hi,gh)
            if not ok or hi-lo > 16.0:
                continue
            var score: float = hi-lo+absf(along)*0.03
            if best.is_empty() or score < float(best["score"]):
                best = {"c":c,"side":side,"lo":lo,"hi":hi,"score":score,"rect":r,"along":along,"t":tk,"n":nk}
    if not best.is_empty():
        var c2: Vector2 = best["c"]
        var top: float = float(best["hi"])+0.25
        var side2: float = best["side"]
        var tb: Vector2 = best["t"]
        var nb: Vector2 = best["n"]
        venue_rect = best["rect"]
        _pad(acc,c2,tb,nb*side2,pad_w,pad_d,float(best["lo"])-1.2,top,venue)
        _paddock_items(acc,c2,tb,nb*side2,pad_w,pad_d,top,mode,venue)
        var corners: Array = []
        for cu in [-0.5,0.5]:
            for cv in [-0.5,0.5]:
                var cq: Vector2 = c2+tb*pad_w*cu+nb*pad_d*cv
                corners.append([cq.x,cq.y])
        venue_info = {"pad":[c2.x,c2.y],"corners":corners,"side":side2,"width":pad_w,"depth":pad_d,"top":top,
            "drop":float(best["hi"])-float(best["lo"]),"mode":mode,"venue":venue}
    else:
        venue_info = {"pad":null,"mode":mode,"venue":venue,"reason":"NO ROOM NEXT TO THE START"}
    if mode == "pro" and venue != "touge_start":
        var gs: Dictionary = _grandstand(acc,samples,hw,rh,closed,-(float(best.get("side",1.0))))
        venue_info["grandstand"] = not gs.is_empty()
        if gs.is_empty():
            venue_info.erase("grandstand_corners")
    if str(info["country"]) == "ireland":
        venue_info["stone_walls"] = _roadside_walls(acc)
    var mi := MeshInstance3D.new()
    mi.name = "Venue %s (%s)" % [venue,mode]
    mi.mesh = acc.commit(_mats[0],_mats[1])
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    venue_node.add_child(mi)
    if venue_rect.size != Vector2.ZERO:
        venue_keep.append(venue_rect)

func _rect_from(c: Vector2, t: Vector2, w: float, d: float) -> Rect2:
    var r := Rect2(c,Vector2.ZERO)
    for q in _rect_points(c,t,Vector2(-t.y,t.x),w,d):
        r = r.expand(q)
    return r.grow(3.0)

func _rect_points(c: Vector2, t: Vector2, nrm: Vector2, w: float, d: float) -> Array:
    var out: Array = []
    for a in [-0.5,0.0,0.5]:
        for b in [-0.5,0.0,0.5]:
            out.append(c+t*w*a+nrm*d*b)
    return out

func _frame(c: Vector2, t: Vector2, nrm: Vector2, w: float, d: float) -> Array:
    # Acc frame with u along t (0..w) and v along nrm (0..d) from the corner.
    return [c-t*w*0.5-nrm*d*0.5,t,nrm]

func _pad(acc, c: Vector2, t: Vector2, nrm: Vector2, w: float, d: float, bottom: float, top: float, venue: String) -> void:
    acc.set_frame(_frame(c,t,nrm,w,d))
    var slab := Color(0.56,0.56,0.55) if venue != "paddock_ie" else Color(0.50,0.51,0.50)
    acc.box(0.0,w,0.0,d,bottom,top,slab.darkened(0.15),false,slab)
    # painted bay lines
    var k: float = 4.0
    while k < w-2.0:
        acc.box(k,k+0.18,1.0,d*0.42,top,top+0.02,Color(0.92,0.92,0.90))
        k += 5.5

## Paddock contents by event mode (owner reference renders: a compact pit
## building with three numbered bays and a race-control tower, pop-up
## tents, ambulance + fire engine on standby, flags and cones; never an
## endless row of garages). v = 0 is the road side of the pad.
func _paddock_items(acc, c: Vector2, t: Vector2, nrm: Vector2, w: float, d: float, top: float, mode: String, venue: String) -> void:
    acc.set_frame(_frame(c,t,nrm,w,d))
    var canopy: Array[Color] = [Color(0.92,0.20,0.22),Color(0.98,0.98,0.96),Color(0.20,0.36,0.70)]
    var building: Color = Color(0.20,0.21,0.24)
    if venue == "paddock_eu":
        canopy = [Color(0.95,0.95,0.95),Color(0.85,0.12,0.18),Color(0.25,0.25,0.28)]
    elif venue == "paddock_ie":
        canopy = [Color(0.12,0.52,0.30),Color(0.96,0.96,0.94),Color(0.95,0.55,0.15)]
    var big: bool = mode != "practice" and venue != "touge_start"
    if big:
        # Pit building: 3 bays (21 m) along the back of the pad + tower.
        var x0: float = 2.0
        acc.box(x0,x0+22.0,d-8.5,d-0.5,top,top+5.2,building,false,Color(0.30,0.31,0.34))
        for bay in range(3):
            var u0: float = x0+0.8+float(bay)*7.0
            acc.box(u0,u0+5.6,d-8.56,d-8.5,top,top+3.6,Color(0.08,0.08,0.09))          # open bay
            acc.box(u0+2.2,u0+3.4,d-8.6,d-8.56,top+4.0,top+4.8,Color(0.95,0.95,0.95),true) # bay number plate
        acc.box(x0,x0+22.0,d-8.62,d-8.5,top+5.2,top+5.9,canopy[0],true)                # fascia strip
        acc.box(x0+23.0,x0+29.0,d-7.0,d-1.0,top,top+7.0,Color(0.86,0.86,0.84),false,Color(0.30,0.31,0.33))
        acc.box(x0+22.6,x0+29.4,d-7.4,d-0.6,top+7.0,top+9.6,Color(0.18,0.30,0.40))     # glazed control room
        acc.box(x0+22.4,x0+29.6,d-7.6,d-0.4,top+9.6,top+10.1,Color(0.25,0.25,0.27))
        # Ambulance + fire engine on standby near the exit.
        acc.box(w-14.0,w-8.4,2.6,4.8,top,top+2.5,Color(0.98,0.85,0.10),false,Color(0.95,0.95,0.95))
        acc.box(w-7.4,w-0.8,2.4,4.9,top,top+3.0,Color(0.80,0.10,0.10),false,Color(0.70,0.08,0.08))
    else:
        # Practice / mountain-pass start: one timing cabin.
        acc.box(w-8.0,w-1.5,d-6.0,d-1.0,top,top+3.0,Color(0.90,0.90,0.88),false,Color(0.34,0.35,0.37))
        acc.box(w-7.6,w-1.9,d-6.05,d-5.95,top+1.2,top+2.3,Color(0.25,0.35,0.45))
    var tents: int = 1 if mode == "practice" else (2 if mode == "club" else 4)
    if venue == "touge_start":
        tents = 0 if mode == "practice" else 1
    var tv: float = 9.0 if big else d-7.0
    for i in range(tents):
        var u1: float = (32.0 if big else 2.0)+float(i)*8.5
        if u1+7.0 > w-1.0:
            break
        var col: Color = canopy[i%canopy.size()]
        for pu in [u1,u1+6.6]:
            for pv in [tv,tv+6.0]:
                acc.box(pu,pu+0.12,pv,pv+0.12,top,top+2.6,Color(0.75,0.75,0.76))
        acc.box(u1-0.2,u1+6.92,tv-0.2,tv+6.2,top+2.6,top+2.9,col,false,col)
    # Flags along the road side of the pad.
    var flags: int = 0 if mode == "practice" else (4 if mode == "club" else 8)
    for i2 in range(flags):
        var u: float = 2.0+float(i2)*(w-4.0)/maxf(float(flags-1),1.0)
        acc.box(u,u+0.10,0.8,0.9,top,top+5.0,Color(0.80,0.80,0.80))
        acc.box(u+0.10,u+1.4,0.82,0.88,top+3.8,top+4.9,canopy[i2%canopy.size()])
    for i3 in range(6):
        var u2: float = 3.0+float(i3)*2.2
        acc.box(u2,u2+0.45,2.0,2.45,top,top+0.7,Color(1.0,0.45,0.08))

## Irish roads: dry-stone walls along both sides, outside the verge and
## barrier strip (gaps at the paddock and over bridges / cliff walls).
func _roadside_walls(acc) -> int:
    var road: Dictionary = world.road
    if road.is_empty():
        return 0
    var samples: Array[Vector2] = road["samples"]
    var hw: PackedFloat32Array = road["halfwidths"]
    var cls: PackedInt32Array = road["class"]
    var closed: bool = road["closed"]
    var n: int = samples.size()
    var stone := Color(0.56,0.56,0.53)
    var pieces: int = 0
    for side in [-1.0,1.0]:
        var prev := Vector3.INF
        for k in range(0,n+(1 if closed else 0),2):
            var i: int = k%n
            var nrm: Vector2 = PROFILE._normal(samples,i,closed)
            var q: Vector2 = samples[i]+nrm*side*(hw[i]+PROFILE.VERGE+3.2)
            var ok: bool = cls[i] < 4 and road_clearance(q) > PROFILE.VERGE+2.0
            for r in venue_keep:
                if (r as Rect2).grow(4.0).has_point(q):
                    ok = false
            if ok and field.relief == "coast" and field.coast_distance(q.x,q.y) < 6.0:
                ok = false
            if not ok:
                prev = Vector3.INF
                continue
            var p := Vector3(q.x,field.height_at(q.x,q.y),q.y)
            if prev != Vector3.INF and prev.distance_to(p) < 14.0:
                _wall_piece(acc,prev,p,stone)
                pieces += 1
            prev = p
    return pieces

func _gantry(acc, p: Vector2, t: Vector2, nrm: Vector2, w: float, y: float, venue: String) -> void:
    var span: float = w+2.6
    var col: Color = Color(0.86,0.86,0.86)
    var banner: Color = Color(0.95,0.22,0.36)
    if venue == "paddock_eu":
        banner = Color(0.85,0.12,0.20)
    elif venue == "paddock_ie":
        banner = Color(0.10,0.55,0.32)
    for side in [-1.0,1.0]:
        var q: Vector2 = p+nrm*side*span
        acc.set_frame([q-t*0.6-nrm*0.6,t,nrm])
        acc.box(0.0,1.2,0.0,1.2,y-2.0,y+7.6,col)
    acc.set_frame([p-nrm*span-t*0.7,nrm,t])
    acc.box(0.0,span*2.0,0.0,1.4,y+6.0,y+7.8,col.darkened(0.1))
    acc.box(span*0.55,span*1.45,-0.06,1.46,y+6.15,y+7.65,banner,true)

## Covered grandstand on the start straight (pro only), behind the barrier
## and run-off, on the side opposite the paddock.
func _grandstand(acc, samples: Array[Vector2], hw: PackedFloat32Array, rh: PackedFloat32Array, closed: bool,
        side: float) -> Dictionary:
    var n: int = samples.size()
    var i: int = mini(4,n-2)
    var p: Vector2 = samples[i]
    var t: Vector2 = (samples[i+1]-samples[i]).normalized()
    var nrm := Vector2(-t.y,t.x)*side
    var len_m: float = 44.0
    var depth: float = 12.0
    var c: Vector2 = p+nrm*(hw[i]+PROFILE.VERGE+PROFILE.MARGIN+SAFETY_M+depth*0.5+1.0)
    var lo: float = INF
    var hi: float = -INF
    for q in _rect_points(c,t,nrm,len_m,depth):
        if not field.inside(q.x,q.y) or field.is_water(q.x,q.y):
            return {}
        if road_clearance(q) < PROFILE.VERGE+PROFILE.MARGIN+SAFETY_M-0.5:
            return {}
        var gh: float = field.height_at(q.x,q.y)
        lo = minf(lo,gh)
        hi = maxf(hi,gh)
    if hi-lo > 12.0:
        return {}
    var base: float = maxf(hi,rh[i]-0.4)
    acc.set_frame(_frame(c,t,nrm,len_m,depth))
    acc.box(0.0,len_m,0.0,depth,lo-1.0,base+0.4,Color(0.55,0.55,0.56))
    for row in range(6):
        var v0: float = 1.0+float(row)*1.7
        acc.box(0.0,len_m,v0,depth,base+0.4+float(row)*0.75,base+1.15+float(row)*0.75,
            Color(0.20,0.40,0.72) if row%2 == 0 else Color(0.85,0.85,0.86))
    for u in [0.0,len_m*0.5,len_m-0.4]:
        acc.box(u,u+0.4,depth-0.6,depth-0.2,base,base+9.0,Color(0.70,0.70,0.72))
    acc.box(-1.0,len_m+1.0,2.0,depth+0.5,base+9.0,base+9.4,Color(0.92,0.92,0.94))
    var r := _rect_from(c,t,len_m,depth)
    venue_keep.append(r)
    var corners: Array = []
    for cu in [-0.5,0.5]:
        for cv in [-0.5,0.5]:
            var cq: Vector2 = c+t*len_m*cu+nrm*depth*cv
            corners.append([cq.x,cq.y])
    venue_info["grandstand_corners"] = corners
    return {"rect":r}

# -------------------------------------------------------------- landmarks

func _band_site(score_fn: Callable, step: float = 24.0) -> Vector2:
    var best := Vector2.INF
    var best_s: float = INF
    var x: float = -FIELD.HALF_X+40.0
    while x <= FIELD.HALF_X-40.0:
        var z: float = -FIELD.HALF_Z+40.0
        while z <= FIELD.HALF_Z-40.0:
            var u: float = x/FIELD.PLAY_HALF_X
            var v: float = z/FIELD.PLAY_HALF_Z
            var e: float = FIELD._edge(u,v)
            if e > 1.10 and not field.is_water(x,z):
                var s: float = score_fn.call(x,z)
                if s < best_s:
                    best_s = s
                    best = Vector2(x,z)
            z += step
        x += step
    return best

func _build_landmarks() -> void:
    var acc = MODS.Acc.new()
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_value*104729+17
    for lm in info["landmarks"]:
        var name: String = str(lm)
        var site := Vector2.INF
        match name:
            "village_jp","village_jp_small":
                site = _band_site(func(x,z): return field.slope_at(x,z)*60.0+field.base_at(x,z)*0.15+rng.randf()*2.0)
                if site != Vector2.INF:
                    _village_jp(acc,site,rng,14 if name == "village_jp" else 6)
            "castle_rock":
                site = _band_site(func(x,z): return absf(field.base_at(x,z)-58.0)*0.3+field.slope_at(x,z)*10.0+rng.randf())
                if site != Vector2.INF:
                    _castle_rock(acc,site,rng)
            "mountain_hut":
                site = _band_site(func(x,z): return field.slope_at(x,z)*40.0+absf(field.base_at(x,z)-150.0)*0.08+rng.randf())
                if site != Vector2.INF:
                    _mountain_hut(acc,site,rng)
            "lighthouse":
                var lh_score := func(x,z): return absf(field.coast_distance(x,z)-16.0)*1.5+field.slope_at(x,z)*20.0+(0.0 if absf(z) > FIELD.PLAY_HALF_Z else 400.0)+rng.randf()
                site = _band_site(lh_score,16.0)
                if site != Vector2.INF:
                    _lighthouse(acc,site)
            "castle_ruin":
                var ruin_score := func(x,z): return -field.base_at(x,z)*0.25+field.slope_at(x,z)*25.0+rng.randf()*3.0+(200.0 if field.relief == "coast" and field.coast_distance(x,z) < 40.0 else 0.0)
                site = _band_site(ruin_score)
                if site != Vector2.INF:
                    _tower_house(acc,site,rng)
            "volcano":
                site = Vector2(-900.0,-2700.0)
                _volcano(acc,site)
            "expressway":
                _expressway(acc)
                site = Vector2(0.0,FIELD.PLAY_HALF_Z+22.0)
            "skyline":
                _skyline(acc,rng)
                site = Vector2(0.0,-FIELD.HALF_Z)
        landmark_info.append({"kind":name,"site":[site.x,site.y] if site != Vector2.INF else null})
    if not acc.idx.is_empty() or not acc.eidx.is_empty():
        var mi := MeshInstance3D.new()
        mi.name = "Landmark buildings"
        mi.mesh = acc.commit(_mats[0],_mats[1])
        mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        landmark_node.add_child(mi)

func _ground_min(c: Vector2, r: float) -> float:
    var m: float = INF
    for o in [Vector2.ZERO,Vector2(r,0),Vector2(-r,0),Vector2(0,r),Vector2(0,-r)]:
        m = minf(m,field.height_at(c.x+o.x,c.y+o.y))
    return m

## Rural Japanese houses: two storeys, dark kawara hip / gable roofs,
## plaster or timber walls, aligned to one lane; utility poles.
func _village_jp(acc, site: Vector2, rng: RandomNumberGenerator, count: int) -> void:
    var axis: float = rng.randf_range(0.0,PI)
    var t := Vector2(cos(axis),sin(axis))
    var nrm := Vector2(-t.y,t.x)
    var walls: Array[Color] = [Color(0.92,0.90,0.84),Color(0.80,0.72,0.58),Color(0.55,0.42,0.30),Color(0.88,0.86,0.80)]
    var roofs: Array[Color] = [Color(0.22,0.24,0.28),Color(0.30,0.32,0.36),Color(0.36,0.30,0.26)]
    var placed: int = 0
    for k in range(count*3):
        if placed >= count:
            break
        var along: float = floor(float(k)*0.5)*17.0*(1.0 if k%4 < 2 else -1.0)
        var side: float = 1.0 if k%2 == 0 else -1.0
        var c: Vector2 = site+t*along+nrm*side*rng.randf_range(11.0,15.0)
        if not field.inside(c.x,c.y) or field.is_water(c.x,c.y) or field.slope_at(c.x,c.y) > 0.35:
            continue
        if FIELD._edge(c.x/FIELD.PLAY_HALF_X,c.y/FIELD.PLAY_HALF_Z) < 1.06:
            continue
        var w: float = rng.randf_range(9.0,12.0)
        var d: float = rng.randf_range(7.0,9.0)
        var gy: float = _ground_min(c,6.0)
        var storeys: int = rng.randi_range(1,2)
        var top: float = gy+0.6+float(storeys)*2.9
        acc.set_frame(_frame(c,t,nrm*side,w,d))
        acc.box(-0.3,w+0.3,-0.3,d+0.3,gy-1.5,gy+0.6,Color(0.52,0.52,0.50))   # stone base
        acc.box(0.0,w,0.0,d,gy+0.6,top,walls[rng.randi_range(0,walls.size()-1)])
        acc.box(w*0.15,w*0.85,-0.05,0.0,gy+0.8,gy+2.6,Color(0.30,0.24,0.18))  # sliding doors
        var rc: Color = roofs[rng.randi_range(0,roofs.size()-1)]
        _hip_roof(acc,w,d,top,1.0,rc)
        placed += 1
        keep_out.append(_rect_from(c,t,w+6.0,d+6.0))
    # Utility poles along the lane.
    for k2 in range(-4,5):
        var q: Vector2 = site+t*float(k2)*22.0+nrm*7.0
        if not field.inside(q.x,q.y):
            continue
        var gy2: float = field.height_at(q.x,q.y)
        acc.set_frame([q,t,nrm])
        acc.box(-0.15,0.15,-0.15,0.15,gy2-0.5,gy2+9.0,Color(0.48,0.46,0.44))
        acc.box(-1.0,1.0,-0.06,0.06,gy2+8.0,gy2+8.2,Color(0.30,0.30,0.30))

func _hip_roof(acc, w: float, d: float, y: float, eave: float, col: Color) -> void:
    var rh: float = d*0.42
    var a: Vector3 = acc.w(-eave,-eave,y)
    var b: Vector3 = acc.w(w+eave,-eave,y)
    var c: Vector3 = acc.w(w+eave,d+eave,y)
    var dd: Vector3 = acc.w(-eave,d+eave,y)
    var r0: Vector3 = acc.w(d*0.5,d*0.5,y+rh)
    var r1: Vector3 = acc.w(w-d*0.5,d*0.5,y+rh)
    var centre: Vector3 = (a+c)*0.5+Vector3(0,rh*0.3,0)
    acc._face(a,b,r1,r0,centre,col,false)
    acc._face(c,dd,r0,r1,centre,col.darkened(0.06),false)
    acc._tri_out(b,c,r1,centre,col.darkened(0.03))
    acc._tri_out(dd,a,r0,centre,col.darkened(0.09))
    acc.box(-eave,w+eave,-eave,d+eave,y-0.25,y,col.darkened(0.2))

## Ojcow-like limestone club / pillar with a small castle on the crag
## (generic design, not a replica of a specific castle).
func _castle_rock(acc, site: Vector2, rng: RandomNumberGenerator) -> void:
    var gy: float = _ground_min(site,10.0)
    var lime := Color(0.86,0.84,0.78)
    var r: float = 7.0
    var y: float = gy-2.0
    for k in range(9):
        var rr: float = r*(0.72+0.28*sin(float(k)*0.9))*(1.0 if k < 6 else 1.25)
        var hgt: float = 4.2
        acc.set_frame([site+Vector2(rng.randf_range(-0.8,0.8),rng.randf_range(-0.8,0.8)),Vector2.RIGHT,Vector2(0,1)])
        acc.box(-rr,rr,-rr*0.85,rr*0.85,y,y+hgt,lime.darkened(rng.randf_range(0.0,0.12)))
        y += hgt
    keep_out.append(Rect2(site-Vector2.ONE*14.0,Vector2.ONE*28.0))
    # Castle on a second crag nearby.
    var c2: Vector2 = site+Vector2(46.0,18.0)
    if field.inside(c2.x,c2.y) and not field.is_water(c2.x,c2.y):
        var g2: float = _ground_min(c2,14.0)
        acc.set_frame([c2-Vector2(12,9),Vector2.RIGHT,Vector2(0,1)])
        acc.box(-2.0,26.0,-2.0,20.0,g2-2.0,g2+9.0,lime.darkened(0.06))          # crag
        acc.box(0.0,24.0,0.0,18.0,g2+9.0,g2+17.0,Color(0.90,0.88,0.82))         # walls
        _hip_roof(acc,24.0,18.0,g2+17.0,0.6,Color(0.62,0.26,0.18))
        acc.box(18.0,24.0,-1.0,5.0,g2+9.0,g2+27.0,Color(0.92,0.90,0.84))        # tower
        acc.box(17.6,24.4,-1.4,5.4,g2+27.0,g2+28.0,Color(0.45,0.20,0.15))
        keep_out.append(Rect2(c2-Vector2(18,15),Vector2(40,34)))

func _mountain_hut(acc, site: Vector2, rng: RandomNumberGenerator) -> void:
    var t := Vector2.RIGHT.rotated(rng.randf_range(0,PI))
    var nrm := Vector2(-t.y,t.x)
    var gy: float = _ground_min(site,10.0)
    acc.set_frame(_frame(site,t,nrm,22.0,12.0))
    acc.box(-0.5,22.5,-0.5,12.5,gy-2.5,gy+1.2,Color(0.50,0.50,0.50))          # granite base
    acc.box(0.0,22.0,0.0,12.0,gy+1.2,gy+7.0,Color(0.52,0.36,0.22))            # timber
    var a: Array[Vector3] = [acc.w(-1.2,-1.2,gy+7.0),acc.w(-1.2,13.2,gy+7.0),acc.w(-1.2,6.0,gy+14.0)]
    var b: Array[Vector3] = [acc.w(23.2,-1.2,gy+7.0),acc.w(23.2,13.2,gy+7.0),acc.w(23.2,6.0,gy+14.0)]
    acc.prism(a,b,Color(0.30,0.26,0.24))
    keep_out.append(_rect_from(site,t,28.0,18.0))

func _lighthouse(acc, site: Vector2) -> void:
    var gy: float = _ground_min(site,5.0)
    acc.set_frame([site,Vector2.RIGHT,Vector2(0,1)])
    acc.box(-6.0,6.0,-4.0,4.0,gy-1.0,gy+3.0,Color(0.92,0.92,0.90),false,Color(0.30,0.30,0.32))  # keeper's house
    for k in range(6):
        var r: float = 2.6-float(k)*0.14
        var col: Color = Color(0.96,0.96,0.95) if k%2 == 0 else Color(0.10,0.10,0.12)
        acc.box(-r,r,-r,r,gy+float(k)*3.6,gy+float(k+1)*3.6,col)
    var top: float = gy+21.6
    acc.box(-1.9,1.9,-1.9,1.9,top,top+2.2,Color(1.0,0.92,0.60),true)
    acc.box(-2.2,2.2,-2.2,2.2,top+2.2,top+3.0,Color(0.10,0.10,0.12))
    keep_out.append(Rect2(site-Vector2.ONE*10.0,Vector2.ONE*20.0))

## Irish tower house ruin with a bawn wall fragment.
func _tower_house(acc, site: Vector2, rng: RandomNumberGenerator) -> void:
    var gy: float = _ground_min(site,8.0)
    var stone := Color(0.55,0.55,0.52)
    acc.set_frame([site-Vector2(5,4),Vector2.RIGHT,Vector2(0,1)])
    acc.box(0.0,10.0,0.0,8.0,gy-1.5,gy+15.0,stone)
    acc.box(-0.3,4.0,-0.3,8.3,gy+15.0,gy+17.5,stone.darkened(0.05))     # broken parapet
    acc.box(6.5,10.3,5.0,8.3,gy+15.0,gy+16.6,stone.darkened(0.08))
    for k in range(3):
        acc.box(4.2,5.6,-0.06,0.0,gy+3.0+float(k)*4.2,gy+4.4+float(k)*4.2,Color(0.12,0.12,0.12))
    acc.box(-14.0,-12.8,-6.0,12.0,gy-1.0,gy+2.6,stone.lightened(0.04))
    acc.box(-14.0,0.0,12.0,13.2,gy-1.0,gy+rng.randf_range(1.2,2.6),stone.lightened(0.04))
    keep_out.append(Rect2(site-Vector2(18,12),Vector2(32,30)))

## Distant snow-capped volcanic cone on the Japanese horizon (generic
## stratovolcano silhouette, outside the playable world).
func _volcano(acc, c: Vector2) -> void:
    var seg: int = 28
    var base_r: float = 1500.0
    var top_r: float = 110.0
    var base_y: float = -20.0
    var top_y: float = 1050.0
    var snow_f: float = 0.62
    var rock := Color(0.40,0.44,0.52)
    var snow := Color(0.96,0.97,1.0)
    for k in range(seg):
        var a0: float = TAU*float(k)/float(seg)
        var a1: float = TAU*float(k+1)/float(seg)
        var d0 := Vector2(cos(a0),sin(a0))
        var d1 := Vector2(cos(a1),sin(a1))
        # concave profile: wide base, steeper top
        var mid_r: float = lerpf(base_r,top_r,0.78)
        var mid_y: float = lerpf(base_y,top_y,snow_f)
        var b0 := Vector3(c.x+d0.x*base_r,base_y,c.y+d0.y*base_r)
        var b1 := Vector3(c.x+d1.x*base_r,base_y,c.y+d1.y*base_r)
        var jag: float = 1.0+0.08*sin(float(k)*2.7)
        var m0 := Vector3(c.x+d0.x*mid_r*jag,mid_y,c.y+d0.y*mid_r*jag)
        var m1 := Vector3(c.x+d1.x*mid_r,mid_y,c.y+d1.y*mid_r)
        var t0 := Vector3(c.x+d0.x*top_r,top_y,c.y+d0.y*top_r)
        var t1 := Vector3(c.x+d1.x*top_r,top_y,c.y+d1.y*top_r)
        acc.quad(b0,b1,m1,m0,rock)
        acc.quad(m0,m1,t1,t0,snow)
    var crater := Vector3(c.x,top_y-30.0,c.y)
    for k2 in range(seg):
        var a2: float = TAU*float(k2)/float(seg)
        var a3: float = TAU*float(k2+1)/float(seg)
        acc.tri(Vector3(c.x+cos(a2)*top_r,top_y,c.y+sin(a2)*top_r),Vector3(c.x+cos(a3)*top_r,top_y,c.y+sin(a3)*top_r),crater,snow.darkened(0.15))

## Elevated harbour expressway just outside the south edge of the play area.
func _expressway(acc) -> void:
    var z: float = FIELD.PLAY_HALF_Z+22.0
    var x: float = -FIELD.HALF_X-300.0
    var deck: float = 17.0
    acc.set_frame([Vector2.ZERO,Vector2.RIGHT,Vector2(0,1)])
    acc.box(x,-x,z-9.0,z+9.0,deck,deck+1.6,Color(0.62,0.62,0.63),false,Color(0.30,0.30,0.32))
    acc.box(x,-x,z-9.4,z-8.6,deck+1.6,deck+4.2,Color(0.80,0.82,0.80))     # noise walls
    acc.box(x,-x,z+8.6,z+9.4,deck+1.6,deck+4.2,Color(0.80,0.82,0.80))
    var px: float = x
    while px <= -x:
        var g: float = field.height_at(px,z) if field.inside(px,z) else field.raw_height(px,z)
        acc.box(px-1.4,px+1.4,z-2.2,z+2.2,minf(g,0.0)-1.0,deck,Color(0.66,0.66,0.66))
        acc.box(px-1.6,px+1.6,z-8.0,z+8.0,deck-1.6,deck,Color(0.60,0.60,0.61))
        px += 34.0
    keep_out.append(Rect2(Vector2(x,z-12.0),Vector2(-2.0*x,24.0)))

## Distant city: towers beyond the detailed terrain + harbour cranes.
func _skyline(acc, rng: RandomNumberGenerator) -> void:
    for k in range(70):
        var ang: float = rng.randf_range(-PI*0.95,-PI*0.05)
        var dist: float = rng.randf_range(820.0,1500.0)
        var c := Vector2(cos(ang)*dist*0.9,sin(ang)*dist)
        var g: float = field.raw_height(c.x,c.y)
        var w: float = rng.randf_range(18.0,40.0)
        var d: float = rng.randf_range(18.0,40.0)
        var h: float = rng.randf_range(30.0,140.0)
        acc.set_frame([c,Vector2.RIGHT,Vector2(0,1)])
        var col := Color(0.60,0.64,0.70).lerp(Color(0.82,0.82,0.84),rng.randf())
        acc.box(-w*0.5,w*0.5,-d*0.5,d*0.5,g-2.0,g+h,col,false,col.darkened(0.2))
        if k%3 == 0:
            acc.box(-w*0.5-0.05,w*0.5+0.05,-d*0.5-0.05,d*0.5+0.05,g+h*0.6,g+h*0.62,Color(1.0,0.85,0.6),true)
    # Harbour cranes on the quay (south, beyond the expressway).
    for k2 in range(4):
        var cx: float = -240.0+float(k2)*150.0
        var cz: float = FIELD.PLAY_HALF_Z+52.0
        acc.set_frame([Vector2(cx,cz),Vector2.RIGHT,Vector2(0,1)])
        var g2: float = maxf(field.height_at(cx,cz),0.5)
        for o in [-6.0,6.0]:
            acc.box(o-0.8,o+0.8,-6.0,-4.6,g2,g2+30.0,Color(0.86,0.30,0.20))
            acc.box(o-0.8,o+0.8,4.6,6.0,g2,g2+30.0,Color(0.86,0.30,0.20))
        acc.box(-7.0,7.0,-14.0,40.0,g2+30.0,g2+33.0,Color(0.86,0.30,0.20))

# ----------------------------------------------------------------- meshes

func _species_mesh(sp: String, variant: int = 0) -> ArrayMesh:
    var shape: String = str(SPECIES[sp]["shape"])
    var mkey: String = "%s#%d" % [shape,variant]
    if _meshes.has(mkey):
        return _meshes[mkey]
    var b := _MeshBuild.new()
    var rng := RandomNumberGenerator.new()
    rng.seed = 4242+shape.hash()+variant*7919
    match shape:
        "voxel":
            b.box(Vector3(0,0.22,0),Vector3(0.05,0.44,0.05),TRUNK,0.0)
            var used: Dictionary = {}
            var placed: int = 0
            for k in range(60):
                if placed >= 13:
                    break
                var p := Vector3(rng.randf_range(-1,1),rng.randf_range(-0.5,1),rng.randf_range(-1,1))
                if p.length() > 1.0:
                    continue
                var cell := Vector3i(int(round(p.x*3.0)),int(round(p.y*2.0)),int(round(p.z*3.0)))
                if used.has(cell):
                    continue
                used[cell] = true
                placed += 1
                var c := Vector3(cell)*Vector3(0.16,0.12,0.16)+Vector3(0,0.66,0)
                var s: float = rng.randf_range(0.82,1.0)
                b.box(c,Vector3(0.16,0.12,0.16)*s,Color(1,1,1).darkened(0.18*(1.0-float(cell.y+1)/3.0)),1.0)
        "pads":
            b.cylinder(Vector3(0,0.0,0),0.04,0.03,0.62,5,TRUNK,0.0)
            for k2 in range(4):
                var c2 := Vector3(rng.randf_range(-0.25,0.25),0.48+float(k2)*0.14,rng.randf_range(-0.25,0.25))
                b.blob(c2,Vector3(0.32-float(k2)*0.04,0.07,0.28-float(k2)*0.03),7,2,1.0,rng)
        "spire":
            b.cylinder(Vector3(0,0,0),0.03,0.02,0.25,5,TRUNK,0.0)
            b.cone(Vector3(0,0.15,0),0.20,0.85,8,1.0)
        "tiers":
            b.cylinder(Vector3(0,0,0),0.03,0.02,0.2,5,TRUNK,0.0)
            for k3 in range(4):
                var r: float = 0.24-float(k3)*0.045
                b.cone(Vector3(0,0.12+float(k3)*0.2,0),r,0.34,8,0.85+0.05*float(k3))
        "umbrella":
            b.cylinder(Vector3(0,0,0),0.03,0.02,0.72,5,Color(0.55,0.32,0.20),0.0)
            b.blob(Vector3(0,0.78,0),Vector3(0.24,0.13,0.24),8,3,1.0,rng)
            b.blob(Vector3(0.08,0.70,0.05),Vector3(0.18,0.10,0.16),7,2,0.92,rng)
        "round":
            b.cylinder(Vector3(0,0,0),0.045,0.03,0.42,6,TRUNK,0.0)
            b.blob(Vector3(0,0.62,0),Vector3(0.34,0.30,0.34),9,4,1.0,rng)
            b.blob(Vector3(0.14,0.52,0.10),Vector3(0.22,0.20,0.22),7,3,0.9,rng)
        "round_small":
            b.cylinder(Vector3(0,0,0),0.04,0.03,0.5,5,TRUNK,0.0)
            b.blob(Vector3(0,0.72,0),Vector3(0.24,0.24,0.24),8,3,1.0,rng)
        "mat":
            b.blob(Vector3(0,0.25,0),Vector3(1.4,0.35,1.1),9,3,1.0,rng)
        "bush":
            b.blob(Vector3(0,0.42,0),Vector3(0.62,0.50,0.55),8,3,1.0,rng)
        "lean":
            b.cylinder(Vector3(0,0,0),0.06,0.04,0.55,5,TRUNK,0.0)
            b.blob(Vector3(0.22,0.66,0),Vector3(0.48,0.22,0.30),8,3,1.0,rng)
    var mesh: ArrayMesh = b.commit()
    _meshes[mkey] = mesh
    return mesh

## v0.1.27 rocks by geology: faceted, angular bodies (flat-shaded facets,
## lighter tops) instead of one smooth blob. Variants: "boulder", "slab",
## "pillar" (limestone ostaniec), "columns" (basalt hexagonal columns).
func _rock_mesh(variant: String = "boulder") -> ArrayMesh:
    var mkey: String = "rock_"+variant
    if _meshes.has(mkey):
        return _meshes[mkey]
    var b := _MeshBuild.new()
    var rng := RandomNumberGenerator.new()
    rng.seed = 99+variant.hash()
    match variant:
        "slab":
            b.facets(Vector3(0,0.22,0),Vector3(0.85,0.32,0.62),6,3,rng,0.20)
        "pillar":
            b.facets(Vector3(0,0.50,0),Vector3(0.42,0.62,0.38),6,4,rng,0.16)
            b.facets(Vector3(0.10,1.05,0.04),Vector3(0.30,0.24,0.28),5,2,rng,0.20)
        "columns":
            for k in range(5):
                var a: float = TAU*float(k)/5.0
                var c := Vector3(cos(a)*0.32,0,sin(a)*0.32) if k > 0 else Vector3.ZERO
                b.hex_column(c,0.22,rng.randf_range(0.55,1.0))
        _:
            b.facets(Vector3(0,0.34,0),Vector3(0.62,0.48,0.58),6,3,rng,0.24)
    var mesh: ArrayMesh = b.commit()
    _meshes[mkey] = mesh
    return mesh

func _multimesh(parent: Node3D, label: String, mesh: Mesh, material: Material,
        transforms: Array, colours: Array, custom: bool = true) -> void:
    if transforms.is_empty():
        return
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.use_colors = not colours.is_empty()
    mm.mesh = mesh
    mm.instance_count = transforms.size()
    # Instances relative to the chunk centre so the node's distance (used by
    # the visibility range) is the chunk's distance from the camera.
    var origin: Vector3 = _chunk_centre
    for k in range(transforms.size()):
        mm.set_instance_transform(k,(transforms[k] as Transform3D).translated(-origin))
        if mm.use_colors:
            mm.set_instance_color(k,colours[k])
    var node := MultiMeshInstance3D.new()
    node.name = label
    node.multimesh = mm
    node.material_override = material
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    node.position = origin
    if draw_range > 0.0:
        node.visibility_range_end = draw_range
        node.visibility_range_end_margin = 40.0
        node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
    parent.add_child(node)

func summary() -> Dictionary:
    return {"counts":counts.duplicate(),"venue":venue_info.duplicate(true),"landmarks":landmark_info.duplicate(true),
        "keep_out":keep_out.size()}

## Minimum distance from any solid scenery item (tree / rock / building
## footprint) to the road edge; used by the safety exclusion test.
func min_item_clearance() -> float:
    var best: float = INF
    for id in chunk_nodes.keys():
        var node: Node3D = chunk_nodes[id]
        for child in node.get_children():
            if child is MultiMeshInstance3D and str(child.name) != "Tree shadows":
                var mm: MultiMesh = (child as MultiMeshInstance3D).multimesh
                var base: Vector3 = (child as Node3D).position
                for k in range(mm.instance_count):
                    var o: Vector3 = mm.get_instance_transform(k).origin+base
                    best = minf(best,road_clearance(Vector2(o.x,o.z)))
    return best

# Small mesh builder: vertex colour carries shading, alpha = species tint.
class _MeshBuild:
    var pos := PackedVector3Array()
    var nrm := PackedVector3Array()
    var col := PackedColorArray()
    var uv := PackedVector2Array()
    var idx := PackedInt32Array()

    func _v(p: Vector3, n: Vector3, c: Color) -> int:
        pos.append(p)
        nrm.append(n)
        col.append(Color(c.r,c.g,c.b,1.0))
        uv.append(Vector2(c.a,0.0))
        return pos.size()-1

    func _tri(a: int, b: int, c: int) -> void:
        # Front faces wind clockwise seen from outside (Godot).
        var n: Vector3 = (pos[b]-pos[a]).cross(pos[c]-pos[a])
        var centre: Vector3 = (pos[a]+pos[b]+pos[c])/3.0
        if n.dot(nrm[a]+nrm[b]+nrm[c]) > 0.0:
            idx.append_array([a,c,b])
        else:
            idx.append_array([a,b,c])

    func box(c: Vector3, half: Vector3, colour: Color, tint: float) -> void:
        var cc: Color = Color(colour.r,colour.g,colour.b,tint)
        var dirs: Array = [Vector3.RIGHT,Vector3.LEFT,Vector3.UP,Vector3.DOWN,Vector3.BACK,Vector3.FORWARD]
        for d in dirs:
            var u: Vector3 = Vector3(d.y,d.z,d.x)
            var v: Vector3 = d.cross(u)
            var shade: Color = cc
            if d == Vector3.DOWN:
                shade = Color(cc.r*0.7,cc.g*0.7,cc.b*0.7,tint)
            elif d != Vector3.UP:
                shade = Color(cc.r*0.88,cc.g*0.88,cc.b*0.88,tint)
            var o: Vector3 = c+d*half
            var a: int = _v(o+(-u-v)*half,d,shade)
            var b: int = _v(o+(u-v)*half,d,shade)
            var e: int = _v(o+(u+v)*half,d,shade)
            var f: int = _v(o+(-u+v)*half,d,shade)
            _tri(a,b,e)
            _tri(a,e,f)

    func cylinder(base: Vector3, r0: float, r1: float, h: float, seg: int, colour: Color, tint: float) -> void:
        for k in range(seg):
            var a0: float = TAU*float(k)/float(seg)
            var a1: float = TAU*float(k+1)/float(seg)
            var d0 := Vector3(cos(a0),0,sin(a0))
            var d1 := Vector3(cos(a1),0,sin(a1))
            var cc := Color(colour.r,colour.g,colour.b,tint)
            var i0: int = _v(base+d0*r0,d0,cc)
            var i1: int = _v(base+d1*r0,d1,cc)
            var i2: int = _v(base+d1*r1+Vector3(0,h,0),d1,cc)
            var i3: int = _v(base+d0*r1+Vector3(0,h,0),d0,cc)
            _tri(i0,i1,i2)
            _tri(i0,i2,i3)

    func cone(base: Vector3, r: float, h: float, seg: int, light: float) -> void:
        var tip: Vector3 = base+Vector3(0,h,0)
        var slope: float = r/h
        for k in range(seg):
            var a0: float = TAU*float(k)/float(seg)
            var a1: float = TAU*float(k+1)/float(seg)
            var d0 := Vector3(cos(a0),slope,sin(a0)).normalized()
            var d1 := Vector3(cos(a1),slope,sin(a1)).normalized()
            var dm := ((d0+d1)*0.5).normalized()
            var lo := Color(0.72*light,0.72*light,0.72*light,1.0)
            var hi := Color(1.0*light,1.0*light,1.0*light,1.0)
            var i0: int = _v(base+Vector3(cos(a0),0,sin(a0))*r,d0,lo)
            var i1: int = _v(base+Vector3(cos(a1),0,sin(a1))*r,d1,lo)
            var i2: int = _v(tip,dm,hi)
            _tri(i0,i1,i2)
            # underside
            var j0: int = _v(base+Vector3(cos(a0),0,sin(a0))*r,Vector3.DOWN,lo*0.8)
            var j1: int = _v(base+Vector3(cos(a1),0,sin(a1))*r,Vector3.DOWN,lo*0.8)
            var j2: int = _v(base,Vector3.DOWN,lo*0.8)
            _tri(j0,j1,j2)

    func blob(c: Vector3, radii: Vector3, seg: int, rings: int, light: float, rng: RandomNumberGenerator,
            jitter: float = 0.12) -> void:
        var grid: Array = []
        for r in range(rings+1):
            var row: Array = []
            var phi: float = PI*float(r)/float(rings)
            for k in range(seg):
                var th: float = TAU*float(k)/float(seg)
                var d := Vector3(sin(phi)*cos(th),cos(phi),sin(phi)*sin(th))
                var j: float = 1.0+rng.randf_range(-jitter,jitter) if r > 0 and r < rings else 1.0
                var p: Vector3 = c+d*radii*j
                var shade: float = light*(0.68+0.32*(0.5+0.5*d.y))
                row.append(_v(p,d,Color(shade,shade,shade,1.0)))
            grid.append(row)
        for r2 in range(rings):
            for k2 in range(seg):
                var a: int = grid[r2][k2]
                var b: int = grid[r2][(k2+1)%seg]
                var cc: int = grid[r2+1][(k2+1)%seg]
                var d2: int = grid[r2+1][k2]
                if r2 > 0:
                    _tri(a,b,cc)
                if r2 < rings-1:
                    _tri(a,cc,d2)

    ## Angular rock: jittered ellipsoid with flat-shaded facets (each
    ## triangle its own normal), lighter towards the top.
    func facets(c: Vector3, radii: Vector3, seg: int, rings: int, rng: RandomNumberGenerator, jitter: float) -> void:
        var grid: Array = []
        for r in range(rings+1):
            var row: Array = []
            var phi: float = PI*float(r)/float(rings)
            for k in range(seg):
                var th: float = TAU*(float(k)+(0.5 if r % 2 == 1 else 0.0))/float(seg)
                var d := Vector3(sin(phi)*cos(th),cos(phi),sin(phi)*sin(th))
                var j: float = 1.0+rng.randf_range(-jitter,jitter) if r > 0 and r < rings else 1.0
                var p: Vector3 = c+d*radii*j
                if r == rings:
                    p.y = c.y-radii.y*0.55            # flat underside sits on the ground
                row.append(p)
            grid.append(row)
        for r2 in range(rings):
            for k2 in range(seg):
                var a: Vector3 = grid[r2][k2]
                var b: Vector3 = grid[r2][(k2+1)%seg]
                var cc: Vector3 = grid[r2+1][(k2+1)%seg]
                var d2: Vector3 = grid[r2+1][k2]
                for tri in [[a,b,cc],[a,cc,d2]]:
                    var n: Vector3 = (tri[1]-tri[0]).cross(tri[2]-tri[0])
                    if n.length() < 1e-6:
                        continue
                    n = n.normalized()
                    if n.dot((tri[0]+tri[1]+tri[2])/3.0-c) < 0.0:
                        n = -n
                    var shade: float = 0.66+0.34*clampf(0.5+0.5*n.y,0.0,1.0)
                    var i0: int = _v(tri[0],n,Color(shade,shade,shade,1.0))
                    var i1: int = _v(tri[1],n,Color(shade,shade,shade,1.0))
                    var i2: int = _v(tri[2],n,Color(shade,shade,shade,1.0))
                    _tri(i0,i1,i2)

    ## Basalt column: hexagonal prism with a flat, lighter top.
    func hex_column(c: Vector3, r: float, h: float) -> void:
        var ring: Array = []
        for k in range(6):
            var a: float = TAU*float(k)/6.0
            ring.append(Vector3(cos(a)*r,0,sin(a)*r)+c)
        for k in range(6):
            var a2: Vector3 = ring[k]
            var b2: Vector3 = ring[(k+1)%6]
            var n: Vector3 = ((a2+b2)*0.5-c).normalized()
            var col := Color(0.78,0.78,0.78,1.0)
            var i0: int = _v(a2,n,col)
            var i1: int = _v(b2,n,col)
            var i2: int = _v(b2+Vector3(0,h,0),n,col)
            var i3: int = _v(a2+Vector3(0,h,0),n,col)
            _tri(i0,i1,i2)
            _tri(i0,i2,i3)
        var top: int = _v(c+Vector3(0,h,0),Vector3.UP,Color(1,1,1,1))
        for k in range(6):
            var i4: int = _v(ring[k]+Vector3(0,h,0),Vector3.UP,Color(1,1,1,1))
            var i5: int = _v(ring[(k+1)%6]+Vector3(0,h,0),Vector3.UP,Color(1,1,1,1))
            _tri(top,i4,i5)

    func commit() -> ArrayMesh:
        var arr: Array = []
        arr.resize(Mesh.ARRAY_MAX)
        arr[Mesh.ARRAY_VERTEX] = pos
        arr[Mesh.ARRAY_NORMAL] = nrm
        arr[Mesh.ARRAY_COLOR] = col
        arr[Mesh.ARRAY_TEX_UV] = uv
        arr[Mesh.ARRAY_INDEX] = idx
        var mesh := ArrayMesh.new()
        mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arr)
        return mesh
