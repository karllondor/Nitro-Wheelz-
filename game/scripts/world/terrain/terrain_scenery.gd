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
const STEPS = preload("res://scripts/world/step_runner.gd")
const CAT = preload("res://scripts/world/terrain/terrain_catalog.gd")
const FIELD = preload("res://scripts/world/terrain/terrain_field.gd")
const PROFILE = preload("res://scripts/world/terrain/road_profile.gd")
const MODS = preload("res://scripts/world/scenery_modules.gd")
const VEG_SHADER = preload("res://assets/shaders/terrain_vegetation.gdshader")
const SHADOW_SHADER = preload("res://assets/shaders/soft_shadow.gdshader")
const CITY_SHADER = preload("res://assets/shaders/city_facade.gdshader")

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
    # v0.1.27 roadside planting (behind the barrier, seen from the top-down
    # race camera): low, soft items only.
    "azalea":{"shape":"bush","col":Color(0.92,0.36,0.62),"h":[0.9,1.5]},
    "flowers_pink":{"shape":"flowers","col":Color(1.0,0.62,0.80),"h":[1.6,2.6]},
    "flowers_white":{"shape":"flowers","col":Color(0.96,0.95,0.88),"h":[1.4,2.4]},
    "flowers_gold":{"shape":"flowers","col":Color(0.98,0.80,0.24),"h":[1.4,2.4]},
    "heather":{"shape":"flowers","col":Color(0.62,0.36,0.64),"h":[1.8,2.8]},
    "fern":{"shape":"mat","col":Color(0.26,0.48,0.20),"h":[0.7,1.2]},
    "bush_green":{"shape":"bush","col":Color(0.28,0.46,0.22),"h":[1.0,1.8]},
    "bush_autumn":{"shape":"bush","col":Color(0.90,0.48,0.14),"h":[1.0,1.8]},
    "bush_red":{"shape":"bush","col":Color(0.80,0.24,0.12),"h":[0.9,1.6]},
    "dwarf_pine_low":{"shape":"mat","col":Color(0.20,0.36,0.19),"h":[1.0,1.8]},
    "spruce_young":{"shape":"tiers","col":Color(0.12,0.27,0.18),"h":[2.6,4.2]},
    "gorse_low":{"shape":"bush","col":Color(0.80,0.74,0.22),"h":[0.9,1.6]},
    "hawthorn_low":{"shape":"bush","col":Color(0.32,0.50,0.22),"h":[1.2,2.0]},
}
## Roadside mix per landscape: [kind, weight]; "stone" = small rock of the
## region's geology. Density = items per road sample and side.
const ROADSIDE: Dictionary = {
    "jp_sakura":{"mix":[["azalea",0.35],["flowers_pink",0.40],["stone",0.25]],"density":0.55},
    "jp_forest":{"mix":[["fern",0.45],["bush_green",0.30],["stone",0.25]],"density":0.60},
    "jp_touge":{"mix":[["bush_green",0.40],["fern",0.30],["stone",0.30]],"density":0.55},
    "pl_ojcow":{"mix":[["bush_autumn",0.30],["bush_red",0.20],["flowers_white",0.20],["stone",0.30]],"density":0.55},
    "pl_tatry":{"mix":[["dwarf_pine_low",0.35],["stone",0.40],["spruce_young",0.25]],"density":0.60},
    "ie_coast":{"mix":[["heather",0.40],["gorse_low",0.30],["stone",0.30]],"density":0.55},
    "ie_hills":{"mix":[["hawthorn_low",0.30],["gorse_low",0.25],["flowers_white",0.20],["stone",0.25]],"density":0.50},
}
## Soft planting may stand this far beyond the verge (behind the barrier);
## trees, boulders and buildings keep the full safety strip.
## v0.1.32: 2.0 m (was 0.9) - the owner's phone test found the scenery too
## close to the track.
const ROADSIDE_MIN_M: float = 2.0
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
var city_kinds: Dictionary = {}           # chunk -> {block kind: count} (Japan City)
var _meshes: Dictionary = {}
var _veg_mat: ShaderMaterial
var _shadow_mat: ShaderMaterial
var _rock_mat: StandardMaterial3D
var _city_mat: ShaderMaterial
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
    _city_mat = ShaderMaterial.new()
    _city_mat.shader = CITY_SHADER

# ------------------------------------------------------------------ build

func rebuild_all() -> void:
    STEPS.run_now(rebuild_steps())

func rebuild_steps() -> Array:
    var steps: Array = [_rebuild_begin]
    var cc: Vector2i = world.chunk_counts()
    for cz in range(cc.y):
        for cx in range(cc.x):
            var id := Vector2i(cx,cz)
            steps.append(func(): _build_chunk(id))
    return steps

func _rebuild_begin() -> void:
    for child in get_children():
        remove_child(child)
        child.queue_free()
    chunk_nodes.clear()
    city_kinds.clear()
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
    city_bounds.clear()
    _plan_frontage()

## Called by the world after a road edit with the chunks whose terrain
## changed; also refreshes every chunk whose nearby road segments changed
## (exclusion) and the chunks under the old / new venue.
func on_road_changed(dirty: Array) -> Array:
    var ids: Array = []
    STEPS.run_now([func():
        var steps: Array = on_road_changed_steps(dirty)
        steps.append(func(): ids.append_array(last_changed))
        return steps])
    return ids

var last_changed: Array = []

func on_road_changed_steps(dirty: Array) -> Array:
    var old_sig: Dictionary = road_sig.duplicate()
    var old_venue: Array = venue_keep.duplicate()
    _index_road()
    _build_venue()
    _plan_frontage()
    var todo: Dictionary = {}
    for id in dirty:
        todo[id] = true
    for id2 in road_sig.keys():
        if int(old_sig.get(id2,0)) != int(road_sig[id2]):
            todo[id2] = true
    for id3 in old_sig.keys():
        if not road_sig.has(id3):
            todo[id3] = true
    if old_venue != venue_keep:
        for r in old_venue+venue_keep:
            for id4 in _chunks_of_rect(r):
                todo[id4] = true
    last_changed = todo.keys()
    var steps: Array = []
    for id5 in todo.keys():
        steps.append(func(): _build_chunk(id5))
    return steps

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
            if relief == "urban" and field.mask_at(field.tint,x,z) < 0.45 and field.base_at(x,z) < 12.0:
                continue      # city: trees only in parks / up the hills (+ avenue trees)
            if relief == "urban" and road_clearance(Vector2(x,z)) < CITY_GRID_CLEAR_M:
                continue      # the frontage row owns the strip along the race road
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
    _roadside(node,id,x0,z0,span,per,shadows)
    _field_lines(per,shadows,node,x0,z0,span)
    if relief == "urban":
        _city_district(node,id,x0,z0,span,per,shadows)
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

## v0.1.27 roadside band (owner: from the top-down camera the road was just
## grey): low shrubs, flowers, ferns and small stones 0.9-6 m beyond the
## verge, i.e. behind the barrier, plus a forest edge row of trees right at
## the safety strip where the land is wooded.
func _roadside(node: Node3D, id: Vector2i, x0: float, z0: float, span: float, per: Dictionary,
        shadows: Array[Transform3D]) -> void:
    var road: Dictionary = world.road
    var arch: String = str(world.desc.get("archetype",""))
    if road.is_empty() or not ROADSIDE.has(arch):
        return
    var samples: Array[Vector2] = road["samples"]
    var hw: PackedFloat32Array = road["halfwidths"]
    var cls: PackedInt32Array = road["class"]
    var closed: bool = road["closed"]
    var n: int = samples.size()
    var conf: Dictionary = ROADSIDE[arch]
    var mix: Array = conf["mix"]
    var dens: float = float(conf["density"])
    var rng: RandomNumberGenerator = _rng_for(id,9)
    var rect := Rect2(x0,z0,span,span)
    var soft: Dictionary = {}         # kind -> [xforms, colours]
    var stones: Array = [[],[]]
    var rock_col: Color = Color(info["ground"]["rock"])
    for i in range(n):
        if not rect.has_point(samples[i]):
            continue
        if cls[i] >= 4:
            continue                     # bridges / cliff edges: nothing beside the deck
        var nrm: Vector2 = PROFILE._normal(samples,i,closed)
        var t := Vector2(nrm.y,-nrm.x)
        for side in [-1.0,1.0]:
            if rng.randf() > dens:
                continue
            var d: float = hw[i]+PROFILE.VERGE+rng.randf_range(ROADSIDE_MIN_M,7.0)
            var p: Vector2 = samples[i]+nrm*side*d+t*rng.randf_range(-2.0,2.0)
            if road_clearance(p) < PROFILE.VERGE+ROADSIDE_MIN_M or field.is_water(p.x,p.y):
                continue
            if field.relief == "coast" and field.coast_distance(p.x,p.y) < 4.0:
                continue
            var bad: bool = false
            for r in keep_out+venue_keep:
                if (r as Rect2).has_point(p):
                    bad = true
            if bad:
                continue
            var kind: String = _pick_weighted(mix,rng)
            var y: float = field.height_at(p.x,p.y)
            if kind == "stone":
                var sc: float = rng.randf_range(0.45,1.1)
                var bs := Basis(Vector3.UP,rng.randf_range(0,TAU)).scaled(Vector3(sc*rng.randf_range(0.9,1.4),sc*rng.randf_range(0.6,1.0),sc))
                stones[0].append(Transform3D(bs,Vector3(p.x,y-0.12*sc,p.y)))
                var c: Color = rock_col.lightened(rng.randf_range(-0.12,0.10))
                if arch == "jp_forest":
                    c = c.lerp(Color(0.30,0.42,0.22),0.45)
                stones[1].append(c)
                continue
            var spec: Dictionary = SPECIES[kind]
            var hr: Array = spec["h"]
            var h: float = rng.randf_range(float(hr[0]),float(hr[1]))
            var b2 := Basis(Vector3.UP,rng.randf_range(0,TAU)).scaled(Vector3(h*rng.randf_range(0.85,1.2),h,h*rng.randf_range(0.85,1.2)))
            if not soft.has(kind):
                soft[kind] = [[],[]]
            soft[kind][0].append(Transform3D(b2,Vector3(p.x,y-0.05,p.y)))
            var col: Color = Color(spec["col"]).lightened(rng.randf_range(-0.08,0.10))
            if kind == "bush_autumn" and rng.randf() < 0.4:
                col = Color(0.96,0.72,0.20).lightened(rng.randf_range(-0.08,0.08))
            soft[kind][1].append(col)
        # Forest edge: a tree row right at the safety strip where it is wooded.
        if float(info["forest"]) > 0.3 and i % 3 == 0:
            for side2 in [-1.0,1.0]:
                var q: Vector2 = samples[i]+nrm*side2*(hw[i]+PROFILE.VERGE+PROFILE.MARGIN+SAFETY_M+rng.randf_range(2.5,7.0))
                if field.mask_at(field.forest,q.x,q.y) < 0.18 or rng.randf() > 0.7 or field.is_water(q.x,q.y):
                    continue
                var sp: String = _pick_species(rng,q.x,q.y)
                var hr2: Array = SPECIES[sp]["h"]
                var th: float = rng.randf_range(float(hr2[0]),float(hr2[1]))
                if _blocked(q,th*0.22) or field.slope_at(q.x,q.y) > 1.1:
                    continue
                _add_tree(per,shadows,sp,q.x,q.y,th,rng)
    # Delineator posts every ~20 m on both sides (speed cue for the chase
    # camera), skipped on bridges / cliff edges and at the venue.
    var posts: Array = []
    var next_s: float = 0.0
    var run_s: float = 0.0
    for i2 in range(n):
        if i2 > 0:
            run_s += samples[i2-1].distance_to(samples[i2])
        if run_s < next_s:
            continue
        next_s = run_s+20.0
        if not rect.has_point(samples[i2]) or cls[i2] >= 4:
            continue
        var nrm2: Vector2 = PROFILE._normal(samples,i2,closed)
        for side3 in [-1.0,1.0]:
            var pp: Vector2 = samples[i2]+nrm2*side3*(hw[i2]+PROFILE.VERGE+1.0)
            if road_clearance(pp) < PROFILE.VERGE+ROADSIDE_MIN_M or field.is_water(pp.x,pp.y):
                continue
            var bad2: bool = false
            for r2 in keep_out+venue_keep:
                if (r2 as Rect2).has_point(pp):
                    bad2 = true
            if bad2:
                continue
            posts.append(Transform3D(Basis(Vector3.UP,atan2(nrm2.x,nrm2.y)),Vector3(pp.x,field.height_at(pp.x,pp.y)-0.05,pp.y)))
    if not posts.is_empty():
        _multimesh(node,"Roadside posts",_post_mesh(),_rock_mat,posts,[],false)
    # All soft planting of the chunk merged into ONE mesh (one draw call
    # instead of one MultiMesh per kind); instance colours baked in.
    var keys: Array = soft.keys()
    keys.sort()
    var merged := _merge_instances(soft,keys)
    if merged != null:
        var mi := MeshInstance3D.new()
        mi.name = "Roadside planting"
        mi.mesh = merged
        mi.material_override = _veg_mat
        mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        mi.position = _chunk_centre
        if draw_range > 0.0:
            mi.visibility_range_end = draw_range
        node.add_child(mi)
        roadside_counts[node.name] = 0
        for k2 in keys:
            roadside_counts[node.name] = int(roadside_counts[node.name])+(soft[k2][0] as Array).size()
        mi.set_meta("roadside_points",_points_of(soft,keys))
    if not (stones[0] as Array).is_empty():
        _multimesh(node,"Roadside stones",_rock_mesh("boulder"),_rock_mat,stones[0],stones[1],false)

var roadside_counts: Dictionary = {}

func _points_of(groups: Dictionary, keys: Array) -> PackedVector2Array:
    var pts := PackedVector2Array()
    for k in keys:
        for x in groups[k][0]:
            var o: Vector3 = (x as Transform3D).origin
            pts.append(Vector2(o.x,o.z))
    return pts

## Bake transformed copies of each kind's mesh (vertex colour x instance
## colour, foliage flag kept in UV) into one ArrayMesh around the chunk centre.
func _merge_instances(groups: Dictionary, keys: Array) -> ArrayMesh:
    var pos := PackedVector3Array()
    var nrm := PackedVector3Array()
    var col := PackedColorArray()
    var uv := PackedVector2Array()
    var idx := PackedInt32Array()
    for k in keys:
        var src: ArrayMesh = _species_mesh(str(k))
        var arr: Array = src.surface_get_arrays(0)
        var sp: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
        var sn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
        var sc: PackedColorArray = arr[Mesh.ARRAY_COLOR]
        var su: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
        var si: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
        var xs: Array = groups[k][0]
        var cs: Array = groups[k][1]
        for n_i in range(xs.size()):
            var xf: Transform3D = (xs[n_i] as Transform3D).translated(-_chunk_centre)
            var ic: Color = cs[n_i]
            var base: int = pos.size()
            for v in range(sp.size()):
                pos.append(xf*sp[v])
                nrm.append((xf.basis*sn[v]).normalized())
                var vc: Color = sc[v]
                col.append(Color(vc.r*ic.r,vc.g*ic.g,vc.b*ic.b,1.0))
                uv.append(su[v])
            for t in si:
                idx.append(base+t)
    if pos.is_empty():
        return null
    var out: Array = []
    out.resize(Mesh.ARRAY_MAX)
    out[Mesh.ARRAY_VERTEX] = pos
    out[Mesh.ARRAY_NORMAL] = nrm
    out[Mesh.ARRAY_COLOR] = col
    out[Mesh.ARRAY_TEX_UV] = uv
    out[Mesh.ARRAY_INDEX] = idx
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,out)
    return mesh

func _post_mesh() -> ArrayMesh:
    if _meshes.has("post"):
        return _meshes["post"]
    var b := _MeshBuild.new()
    b.box(Vector3(0,0.55,0),Vector3(0.07,0.55,0.07),Color(0.95,0.95,0.93),0.0)
    b.box(Vector3(0,0.86,0),Vector3(0.075,0.10,0.075),Color(0.06,0.06,0.07),0.0)
    b.box(Vector3(0,0.86,-0.08),Vector3(0.04,0.05,0.01),Color(0.95,0.25,0.10),0.0)
    var mesh: ArrayMesh = b.commit()
    _meshes["post"] = mesh
    return mesh

func _pick_weighted(mix: Array, rng: RandomNumberGenerator) -> String:
    var total: float = 0.0
    for m in mix:
        total += float(m[1])
    var r: float = rng.randf()*total
    for m2 in mix:
        r -= float(m2[1])
        if r <= 0.0:
            return str(m2[0])
    return str(mix[mix.size()-1][0])

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

## Japan City (v0.1.27): the street grid painted by the ground shader is
## filled block by block. Zones from a downtown centre: towers, office pairs
## and a department store in the core; mansions with balcony bands, offices
## and shop rows (awnings, fascia + vertical signs) in the middle ring;
## shotengai shop rows, convenience stores and car parks outside; parks
## with small shrines. Side streets get utility poles with wires, avenues
## street trees, avenue crossings traffic signals. Buildings are snapped to
## the 3 m window module of the facade shader and keep the road safety strip.
const CITY_RES: Array[Color] = [Color(0.86,0.84,0.80),Color(0.78,0.74,0.66),Color(0.70,0.70,0.72),
    Color(0.62,0.52,0.44),Color(0.84,0.80,0.72),Color(0.72,0.76,0.74),Color(0.80,0.70,0.66)]
const CITY_OFFICE: Array[Color] = [Color(0.74,0.75,0.77),Color(0.62,0.64,0.68),Color(0.82,0.80,0.76),Color(0.52,0.56,0.62)]
const CITY_TOWER: Array[Color] = [Color(0.58,0.64,0.70),Color(0.70,0.72,0.74),Color(0.46,0.52,0.58)]
const CITY_AWNING: Array[Color] = [Color(0.80,0.16,0.14),Color(0.14,0.36,0.62),Color(0.16,0.50,0.30),
    Color(0.92,0.62,0.12),Color(0.32,0.30,0.30),Color(0.88,0.86,0.82)]
const CITY_SIGN: Array[Color] = [Color(0.95,0.80,0.20),Color(0.90,0.24,0.24),Color(0.30,0.64,0.95),
    Color(0.95,0.95,0.90),Color(0.36,0.84,0.46),Color(0.95,0.46,0.66)]
const CITY_ROOF := Color(0.46,0.46,0.47)
## v0.1.27 street circuit (owner): buildings line the race road - facades
## stand on the sidewalk right behind the verge; the street grid's blocks
## and furniture stay behind that frontage row.
const CITY_SETBACK_M: float = PROFILE.VERGE+2.4
const CITY_GRID_CLEAR_M: float = PROFILE.VERGE+2.4+20.0
const CITY_FRONT_CAPS: Dictionary = {"shop":4,"mansion":7,"office":8}
var frontage: Array = []                  # planned road-frontage lots (whole road)
var city_bounds: Dictionary = {}          # chunk -> [[centre, r, b, half_u, half_v, top]]
var _cur_chunk: Vector2i = Vector2i.ZERO

func _city_district(node: Node3D, id: Vector2i, x0: float, z0: float, span: float,
        per: Dictionary, shadows: Array[Transform3D]) -> void:
    var g: Dictionary = field.city_grid()
    var pitch: Vector2 = g["pitch"]
    var off: Vector2 = g["off"]
    var lo := Vector2(INF,INF)
    var hi := Vector2(-INF,-INF)
    for c in [Vector2(x0,z0),Vector2(x0+span,z0),Vector2(x0,z0+span),Vector2(x0+span,z0+span)]:
        var l: Vector2 = field.city_local(c)
        lo = Vector2(minf(lo.x,l.x),minf(lo.y,l.y))
        hi = Vector2(maxf(hi.x,l.x),maxf(hi.y,l.y))
    var cb := _CityBuild.new()
    var kinds: Dictionary = {}
    _cur_chunk = id
    city_bounds[id] = []
    # Road frontage first (lots whose centre lies in this chunk).
    var crect := Rect2(x0,z0,span,span)
    for lot in frontage:
        var lc0: Vector2 = (lot["o"] as Vector2)+(lot["t"] as Vector2)*float(lot["f"])*0.5+(lot["n"] as Vector2)*float(lot["d"])*0.5
        if not crect.has_point(lc0):
            continue
        var lrng := RandomNumberGenerator.new()
        lrng.seed = int(lot["seed"])
        cb.set_frame(lot["o"],lot["t"],lot["n"])
        cb.base_y = float(lot["gy"])
        var ltop: float = _city_building(cb,lrng,str(lot["kind"]),float(lot["f"]),float(lot["d"]),0.0,float(lot["gy"]),true,CITY_FRONT_CAPS)
        _bounds_add(cb.o,cb.r,cb.b,0.0,float(lot["f"]),0.0,float(lot["d"]),ltop)
        kinds["frontage"] = int(kinds.get("frontage",0))+1
    for iv in range(int(floor((lo.y-off.y)/pitch.y))-1,int(ceil((hi.y-off.y)/pitch.y))+1):
        for iu in range(int(floor((lo.x-off.x)/pitch.x))-1,int(ceil((hi.x-off.x)/pitch.x))+1):
            var la: Array = field.city_line(0,iu)
            var lb: Array = field.city_line(0,iu+1)
            var lc: Array = field.city_line(1,iv)
            var ld: Array = field.city_line(1,iv+1)
            var u0: float = float(la[0])+float(la[1])*0.5
            var u1: float = float(lb[0])-float(lb[1])*0.5
            var v0: float = float(lc[0])+float(lc[1])*0.5
            var v1: float = float(ld[0])-float(ld[1])*0.5
            var cw: Vector2 = field.city_world(Vector2((u0+u1)*0.5,(v0+v1)*0.5))
            if cw.x < x0 or cw.x >= x0+span or cw.y < z0 or cw.y >= z0+span:
                continue
            if absf(cw.x) > FIELD.HALF_X-24.0 or absf(cw.y) > FIELD.HALF_Z-24.0:
                continue
            var rng := RandomNumberGenerator.new()
            rng.seed = FIELD.hash_seed(seed_value*31+iu*7919+iv*104729,"city",5)
            var near: bool = absf(cw.x) < FIELD.PLAY_HALF_X+70.0 and absf(cw.y) < FIELD.PLAY_HALF_Z+70.0
            var k: String = _city_block(cb,rng,u0,u1,v0,v1,cw,near,g)
            kinds[k] = int(kinds.get(k,0))+1
            if near:
                _city_street_kit(cb,rng,u0,u1,v0,v1,bool(lc[2]),bool(la[2]),per,shadows)
    city_kinds[id] = kinds
    if cb.pos.is_empty() and cb.gpos.is_empty():
        return
    var mi := MeshInstance3D.new()
    mi.name = "City blocks"
    mi.mesh = cb.commit(_city_mat,_mats[1],_chunk_centre)
    mi.position = _chunk_centre
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    if draw_range > 0.0:
        # Buildings are big silhouettes: they draw further than trees.
        mi.visibility_range_end = draw_range*1.6
    node.add_child(mi)

## Street-circuit frontage plan for the whole road: lots of shops, mansions
## and low offices facing the road on both sides, facade line at
## CITY_SETBACK_M from the road edge, gaps where grid streets reach the road,
## none over bridges, at the venue or off the map. Deterministic per seed.
func _plan_frontage() -> void:
    frontage.clear()
    if field.relief != "urban" or world.road.is_empty():
        return
    var road: Dictionary = world.road
    var samples: Array[Vector2] = road["samples"]
    var hw: PackedFloat32Array = road["halfwidths"]
    var cls: PackedInt32Array = road["class"]
    var closed: bool = road["closed"]
    var n: int = samples.size()
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_value*7907+13
    var boxes: Array = []
    for side in [-1.0,1.0]:
        var run: float = 0.0
        var next_s: float = 0.0
        for i in range(n):
            if i > 0:
                run += samples[i-1].distance_to(samples[i])
            if run < next_s:
                continue
            if cls[i] >= 4:
                next_s = run+6.0
                continue
            var a: Vector2 = samples[(i-1+n)%n] if (closed or i > 0) else samples[i]
            var b: Vector2 = samples[(i+1)%n] if (closed or i < n-1) else samples[i]
            var t: Vector2 = (b-a).normalized()
            var nn: Vector2 = Vector2(-t.y,t.x)*side
            var r: float = rng.randf()
            var kind: String = "shop" if r < 0.55 else ("mansion" if r < 0.82 else "office")
            var f: float = snappedf(rng.randf_range(6.0,9.0) if kind == "shop" else (rng.randf_range(12.0,21.0) if kind == "mansion" else rng.randf_range(15.0,24.0)),3.0)
            var d: float = snappedf(rng.randf_range(9.0,15.0),3.0)
            var o: Vector2 = samples[i]+nn*(hw[i]+CITY_SETBACK_M)
            var pts: Array = [o,o+t*f,o+t*f+nn*d,o+nn*d,o+t*f*0.5+nn*d*0.5]
            var ok: bool = true
            var lo: float = INF
            var hi: float = -INF
            for k in range(pts.size()):
                var q: Vector2 = pts[k]
                if road_clearance(q) < (CITY_SETBACK_M-0.8 if k < 2 else CITY_SETBACK_M):
                    ok = false
                    break
                if absf(q.x) > FIELD.HALF_X-8.0 or absf(q.y) > FIELD.HALF_Z-8.0 or field.is_water(q.x,q.y):
                    ok = false
                    break
                for rr in keep_out+venue_keep:
                    if (rr as Rect2).has_point(q):
                        ok = false
                var gh: float = field.height_at(q.x,q.y)
                lo = minf(lo,gh)
                hi = maxf(hi,gh)
            if ok and hi-lo > 3.0:
                ok = false
            var cand: Array = [o,t,nn,f,d]
            if ok:
                for bx in boxes:
                    if _rects_overlap(bx,cand):
                        ok = false
                        break
            if ok and _on_grid_street(o+t*f*0.5+nn*2.0):
                ok = false        # a side street meets the circuit here
            if ok:
                boxes.append(cand)
                frontage.append({"o":o,"t":t,"n":nn,"f":f,"d":d,"kind":kind,"gy":lo,"seed":rng.randi()})
                next_s = run+f+rng.randf_range(0.0,1.2)
            else:
                next_s = run+3.0

func _on_grid_street(p: Vector2) -> bool:
    var g: Dictionary = field.city_grid()
    var l: Vector2 = field.city_local(p)
    for axis in [0,1]:
        var c: float = l[axis]
        var pitch: float = float((g["pitch"] as Vector2)[axis])
        var off: float = float((g["off"] as Vector2)[axis])
        var line: Array = field.city_line(axis,int(round((c-off)/pitch)))
        if absf(c-float(line[0])) < float(line[1])*0.5:
            return true
    return false

## Two rectangles [origin, u axis, v axis, length u, length v] overlap (SAT).
func _rects_overlap(a: Array, b: Array) -> bool:
    var ca: Array = [a[0],(a[0] as Vector2)+(a[1] as Vector2)*float(a[3]),(a[0] as Vector2)+(a[1] as Vector2)*float(a[3])+(a[2] as Vector2)*float(a[4]),(a[0] as Vector2)+(a[2] as Vector2)*float(a[4])]
    var cbx: Array = [b[0],(b[0] as Vector2)+(b[1] as Vector2)*float(b[3]),(b[0] as Vector2)+(b[1] as Vector2)*float(b[3])+(b[2] as Vector2)*float(b[4]),(b[0] as Vector2)+(b[2] as Vector2)*float(b[4])]
    for ax in [a[1],a[2],b[1],b[2]]:
        var amin: float = INF
        var amax: float = -INF
        var bmin: float = INF
        var bmax: float = -INF
        for p in ca:
            var v: float = (p as Vector2).dot(ax)
            amin = minf(amin,v)
            amax = maxf(amax,v)
        for p2 in cbx:
            var v2: float = (p2 as Vector2).dot(ax)
            bmin = minf(bmin,v2)
            bmax = maxf(bmax,v2)
        if amax <= bmin+0.2 or bmax <= amin+0.2:
            return false
    return true

func _bounds_add(o: Vector2, r: Vector2, b: Vector2, u0: float, u1: float, v0: float, v1: float, top: float) -> void:
    if not city_bounds.has(_cur_chunk):
        city_bounds[_cur_chunk] = []
    var c: Vector2 = o+r*(u0+u1)*0.5+b*(v0+v1)*0.5
    (city_bounds[_cur_chunk] as Array).append([c,r,b,(u1-u0)*0.5+0.6,(v1-v0)*0.5+0.6,top])

## Roof height of the city building at p (-INF if none): the race chase
## camera rises over buildings instead of entering them.
func building_top_at(p: Vector2) -> float:
    if city_bounds.is_empty():
        return -INF
    var span: float = float(world.CHUNK_CELLS)*FIELD.STEP
    var cid := Vector2i(int(floor((p.x+FIELD.HALF_X)/span)),int(floor((p.y+FIELD.HALF_Z)/span)))
    var best: float = -INF
    for dz in [-1,0,1]:
        for dx in [-1,0,1]:
            for bb in city_bounds.get(cid+Vector2i(dx,dz),[]):
                var d: Vector2 = p-(bb[0] as Vector2)
                if absf(d.dot(bb[1])) <= float(bb[3]) and absf(d.dot(bb[2])) <= float(bb[4]):
                    best = maxf(best,float(bb[5]))
    return best

func frontage_summary() -> Dictionary:
    var min_gap: float = INF
    for lot in frontage:
        for k in [0.0,0.5,1.0]:
            var q: Vector2 = (lot["o"] as Vector2)+(lot["t"] as Vector2)*float(lot["f"])*k
            min_gap = minf(min_gap,road_clearance(q))
    return {"count":frontage.size(),"min_gap":min_gap}

## One block between four streets; returns its kind.
func _city_block(cb: _CityBuild, rng: RandomNumberGenerator, u0: float, u1: float, v0: float, v1: float,
        cw: Vector2, near: bool, g: Dictionary) -> String:
    if field.is_water(cw.x,cw.y) or field.base_at(cw.x,cw.y) > 12.5:
        return "none"
    # Snap the block interior to the 3 m facade module.
    var su0: float = ceil(u0/3.0)*3.0
    var su1: float = floor(u1/3.0)*3.0
    var sv0: float = ceil(v0/3.0)*3.0
    var sv1: float = floor(v1/3.0)*3.0
    if su1-su0 < 18.0 or sv1-sv0 < 18.0:
        return "none"
    if field.mask_at(field.tint,cw.x,cw.y) > 0.45:
        if near and rng.randf() < 0.45:
            _city_shrine(cb,rng,field.city_local(cw))
            return "park_shrine"
        return "park"
    var dd: float = cw.distance_to(g["downtown"])
    var roll: float = rng.randf()
    if dd < 180.0 and roll < 0.72:
        if roll < 0.34:
            return "tower" if _city_tower(cb,rng,su0,su1,sv0,sv1,near) else "plaza"
        if roll < 0.56:
            return "department" if _city_department(cb,rng,su0,su1,sv0,sv1,near) else "plaza"
        # Office pair facing both long streets, plaza between.
        var d: float = minf(snappedf((sv1-sv0)*0.40,3.0),21.0)
        _city_lot(cb,rng,"office",[Vector2(su0,sv0),Vector2(1,0),Vector2(0,1)],0.0,su1-su0,d,near)
        _city_lot(cb,rng,"office",[Vector2(su1,sv1),Vector2(-1,0),Vector2(0,-1)],0.0,su1-su0,d,near)
        return "offices"
    var zone: String = "core" if dd < 180.0 else ("mid" if dd < 340.0 else "outer")
    var row: float = clampf(snappedf((sv1-sv0)*0.40,3.0),9.0,18.0)
    var side: float = clampf(snappedf((su1-su0)*0.40,3.0),9.0,18.0)
    # Long rows along the U streets, then the short rows between them.
    _city_row(cb,rng,zone,[Vector2(su0,sv0),Vector2(1,0),Vector2(0,1)],su1-su0,row,near)
    _city_row(cb,rng,zone,[Vector2(su1,sv1),Vector2(-1,0),Vector2(0,-1)],su1-su0,row,near)
    _city_row(cb,rng,zone,[Vector2(su0,sv1-row),Vector2(0,-1),Vector2(1,0)],(sv1-sv0)-2.0*row,side,near)
    _city_row(cb,rng,zone,[Vector2(su1,sv0+row),Vector2(0,1),Vector2(-1,0)],(sv1-sv0)-2.0*row,side,near)
    return zone

## Lots along one block edge. fr = [origin, along, inwards] in grid space.
func _city_row(cb: _CityBuild, rng: RandomNumberGenerator, zone: String, fr: Array, length: float,
        depth: float, near: bool) -> void:
    var pos: float = 0.0
    var konbini: bool = false
    while pos+6.0 <= length:
        var r: float = rng.randf()
        var kind: String = "shop"
        match zone:
            "core":
                kind = "office" if r < 0.55 else ("mansion" if r < 0.80 else "shop")
            "mid":
                kind = "mansion" if r < 0.30 else ("office" if r < 0.48 else ("konbini" if r < 0.53 else "shop"))
            _:
                kind = "shop" if r < 0.62 else ("mansion" if r < 0.80 else ("konbini" if r < 0.88 else "parking"))
        if kind == "konbini":
            if konbini:
                kind = "shop"
            konbini = true
        var fr_rng: Array = {"shop":[6.0,9.0],"mansion":[15.0,27.0],"office":[18.0,30.0],
            "konbini":[12.0,15.0],"parking":[9.0,15.0]}[kind]
        var f: float = minf(snappedf(rng.randf_range(float(fr_rng[0]),float(fr_rng[1])),3.0),length-pos)
        if f < 6.0:
            break
        if rng.randf() < 0.07:
            pos += 3.0          # narrow alley
            continue
        if kind != "parking":
            _city_lot(cb,rng,kind,fr,pos,f,depth,near)
        pos += f

## Footprint check (grid space rectangle) and its ground: [ok, base y].
func _city_site(fr: Array, a0: float, a1: float, b0: float, b1: float) -> Array:
    var o: Vector2 = fr[0]
    var r: Vector2 = fr[1]
    var b: Vector2 = fr[2]
    var lo_y: float = INF
    var hi_y: float = -INF
    var na: int = maxi(1,int(ceil((a1-a0)/6.0)))
    var nb: int = maxi(1,int(ceil((b1-b0)/6.0)))
    for i in range(na+1):
        for j in range(nb+1):
            if i != 0 and i != na and j != 0 and j != nb and (i+j)%2 == 1:
                continue
            var l: Vector2 = o+r*lerpf(a0,a1,float(i)/float(na))+b*lerpf(b0,b1,float(j)/float(nb))
            var p: Vector2 = field.city_world(l)
            if absf(p.x) > FIELD.HALF_X-6.0 or absf(p.y) > FIELD.HALF_Z-6.0:
                return [false,0.0]
            if road_clearance(p) < CITY_GRID_CLEAR_M:
                return [false,0.0]
            for rr in keep_out+venue_keep:
                if (rr as Rect2).has_point(p):
                    return [false,0.0]
            if field.is_water(p.x,p.y):
                return [false,0.0]
            var h: float = field.height_at(p.x,p.y)
            lo_y = minf(lo_y,h)
            hi_y = maxf(hi_y,h)
    if hi_y-lo_y > 4.0:
        return [false,0.0]
    return [true,lo_y]

func _city_frame(cb: _CityBuild, fr: Array, along: float) -> void:
    var o: Vector2 = (fr[0] as Vector2)+(fr[1] as Vector2)*along
    cb.set_frame(field.city_world(o),field.city_world(fr[1]),field.city_world(fr[2]))

## One building on a street lot: frontage f from `pos` along the edge,
## depth d inwards (front face on the sidewalk line at v = 0).
func _city_lot(cb: _CityBuild, rng: RandomNumberGenerator, kind: String, fr: Array, pos: float, f: float,
        d: float, near: bool) -> void:
    var set_back: float = 6.0 if kind == "konbini" else 0.0
    var dep: float = d
    match kind:
        "shop":
            dep = minf(d,snappedf(rng.randf_range(9.0,15.0),3.0))
        "mansion":
            dep = minf(d,snappedf(rng.randf_range(9.0,12.0),3.0))
        "konbini":
            dep = minf(d-set_back,12.0)
    if dep < 6.0:
        return
    var site: Array = _city_site(fr,pos-0.5,pos+f+0.5,set_back-1.6,set_back+dep)
    if not bool(site[0]):
        return
    var gy: float = float(site[1])
    _city_frame(cb,fr,pos)
    cb.base_y = gy
    var top: float = _city_building(cb,rng,kind,f,dep,set_back,gy,near,{})
    _bounds_add(cb.o,cb.r,cb.b,0.0,f,set_back,set_back+dep,top)

## One street building in the current frame (u along the street, v inwards,
## facade at v = 0). caps: optional max floors per kind (street-circuit
## frontage stays low enough for the top-down camera). Returns the roof height.
func _city_building(cb: _CityBuild, rng: RandomNumberGenerator, kind: String, f: float, dep: float, set_back: float,
        gy: float, near: bool, caps: Dictionary) -> float:
    var roof: float = gy
    match kind:
        "shop":
            var floors: int = mini(rng.randi_range(2,4),int(caps.get("shop",99)))
            var top: float = gy+4.0+float(floors-1)*3.0+0.5
            roof = top
            var col: Color = CITY_RES[rng.randi_range(0,CITY_RES.size()-1)]
            cb.box(0.0,f,0.0,dep,gy-1.0,top,col,4,CITY_ROOF)
            if rng.randf() < 0.3 and floors >= 3:
                cb.box(0.0,f,3.0,dep,top,top+2.6,col.darkened(0.04),1,CITY_ROOF)
            if near:
                var aw: Color = CITY_AWNING[rng.randi_range(0,CITY_AWNING.size()-1)]
                cb.box(0.3,f-0.3,-1.5,0.0,gy+2.95,gy+3.2,aw,0,aw.lightened(0.1))
                cb.box(0.3,f-0.3,-1.6,-1.45,gy+2.6,gy+3.2,aw.darkened(0.12),0)
                var sg: Color = CITY_SIGN[rng.randi_range(0,CITY_SIGN.size()-1)]
                cb.box(0.4,f-0.4,-0.14,0.0,gy+3.35,gy+3.95,sg,0,Color(0,0,0,0),true)
                if floors >= 3 and rng.randf() < 0.6:
                    var sg2: Color = CITY_SIGN[rng.randi_range(0,CITY_SIGN.size()-1)]
                    var sh: float = minf(top-0.6,gy+4.4+rng.randf_range(3.0,6.0))
                    cb.box(f-1.1,f-0.7,-1.5,-0.3,gy+4.4,sh,sg2,0,Color(0,0,0,0),true)
                _city_roof_kit(cb,rng,f,dep,top)
        "mansion":
            var floors2: int = mini(rng.randi_range(5,11),int(caps.get("mansion",99)))
            var top2: float = gy+float(floors2)*3.0+0.6
            roof = top2
            var col2: Color = CITY_RES[rng.randi_range(0,CITY_RES.size()-1)]
            cb.box(0.0,f,0.0,dep,gy-1.0,top2,col2,1,CITY_ROOF)
            if near:
                var par: Color = col2.lightened(0.18)
                for fl in range(1,floors2):
                    var y: float = gy+float(fl)*3.0
                    cb.box(0.0,f,-1.3,0.0,y-0.15,y+1.05,par,0)
                var u: float = 6.0
                while u < f-1.0:
                    cb.box(u-0.15,u+0.15,-1.3,0.0,gy+2.85,top2-0.6,col2.darkened(0.08),0)
                    u += 6.0
                cb.box(f*0.5-2.0,f*0.5+2.0,-1.8,0.0,gy+2.6,gy+2.9,Color(0.85,0.85,0.84),0)
                cb.box(f*0.30,f*0.30+3.0,dep-5.0,dep-2.0,top2,top2+3.0,col2.darkened(0.06),0,CITY_ROOF)
                if rng.randf() < 0.6:
                    cb.box(f*0.66,f*0.66+2.4,dep-4.4,dep-2.0,top2,top2+2.2,Color(0.72,0.74,0.76),0)
        "office":
            var floors3: int = mini(rng.randi_range(7,15),int(caps.get("office",99)))
            var top3: float = gy+4.2+float(floors3-1)*3.6+1.0
            var col3: Color = CITY_OFFICE[rng.randi_range(0,CITY_OFFICE.size()-1)]
            cb.box(0.0,f,0.0,dep,gy-1.0,top3,col3,2,CITY_ROOF)
            if rng.randf() < 0.45 and f > 12.0 and dep > 12.0:
                cb.box(3.0,f-3.0,3.0,dep-3.0,top3,top3+3.6,col3.lightened(0.04),2,CITY_ROOF)
                top3 += 3.6
            roof = top3
            if near:
                cb.box(f*0.5-3.0,f*0.5+3.0,-2.2,0.0,gy+3.4,gy+3.8,Color(0.30,0.31,0.33),0)
                cb.box(f*0.25,f*0.6,dep*0.3,dep*0.6,top3,top3+2.4,Color(0.62,0.63,0.64),0)
                if rng.randf() < 0.35:
                    cb.box(f*0.75-0.15,f*0.75+0.15,dep*0.5-0.15,dep*0.5+0.15,top3,top3+9.0,Color(0.80,0.80,0.80),0)
        "konbini":
            var top4: float = gy+4.2
            roof = top4
            cb.box(0.0,f,set_back,set_back+dep,gy-1.0,top4,Color(0.92,0.92,0.90),7,CITY_ROOF)
            var stripes: Array = [[Color(0.10,0.46,0.78),Color(0.20,0.62,0.30)],[Color(0.95,0.52,0.10),Color(0.20,0.55,0.32)],
                [Color(0.85,0.14,0.16),Color(0.95,0.62,0.10)]]
            var st: Array = stripes[rng.randi_range(0,stripes.size()-1)]
            cb.box(0.0,f,set_back-0.12,set_back+0.02,gy+3.45,gy+3.80,st[0],0)
            cb.box(0.0,f,set_back-0.12,set_back+0.02,gy+3.80,gy+4.05,st[1],0)
            if near:
                cb.box(0.4,0.8,0.4,0.8,gy,gy+6.0,Color(0.70,0.70,0.70),0)
                cb.box(-0.4,1.6,0.3,0.9,gy+6.0,gy+7.6,st[0],0,Color(0,0,0,0),true)
                # Painted parking bays (low kerb stops).
                var u2: float = 2.6
                while u2 < f-1.0:
                    cb.box(u2-0.1,u2+0.1,set_back-5.2,set_back-0.6,gy+0.02,gy+0.06,Color(0.92,0.92,0.88),0)
                    u2 += 2.6
    return roof

func _city_roof_kit(cb: _CityBuild, rng: RandomNumberGenerator, f: float, d: float, top: float) -> void:
    var n: int = rng.randi_range(1,2)
    for k in range(n):
        var u: float = rng.randf_range(1.0,maxf(1.2,f-2.4))
        var v: float = rng.randf_range(2.0,maxf(2.2,d-2.0))
        cb.box(u,u+1.2,v,v+0.8,top,top+0.9,Color(0.80,0.80,0.78),0)

## Downtown tower: 3-storey podium over the block, shaft with a setback
## tier, plain crown, red aviation lights.
func _city_tower(cb: _CityBuild, rng: RandomNumberGenerator, su0: float, su1: float, sv0: float, sv1: float,
        near: bool) -> bool:
    var fr: Array = [Vector2(su0,sv0),Vector2(1,0),Vector2(0,1)]
    var w: float = su1-su0
    var d: float = sv1-sv0
    var site: Array = _city_site(fr,-0.5,w+0.5,-0.5,d+0.5)
    if not bool(site[0]):
        return false
    var gy: float = float(site[1])
    _city_frame(cb,fr,0.0)
    cb.base_y = gy
    var col: Color = CITY_OFFICE[rng.randi_range(0,CITY_OFFICE.size()-1)]
    var pod: float = gy+4.2+2.0*3.6+1.0
    cb.box(0.0,w,0.0,d,gy-1.0,pod,col,2,CITY_ROOF)
    var s: float = clampf(snappedf(minf(w,d)-12.0,3.0),21.0,36.0)
    var a0: float = snappedf((w-s)*0.5,3.0)
    var b0: float = snappedf((d-s)*0.5,3.0)
    var floors: int = rng.randi_range(22,40)
    var top: float = gy+6.0+float(floors-1)*3.8
    var tier: float = gy+6.0+float(int(float(floors)*0.68))*3.8
    var tc: Color = CITY_TOWER[rng.randi_range(0,CITY_TOWER.size()-1)]
    cb.box(a0,a0+s,b0,b0+s,pod-0.5,tier,tc,3,CITY_ROOF)
    cb.box(a0+3.0,a0+s-3.0,b0+3.0,b0+s-3.0,tier,top,tc.lightened(0.05),3,CITY_ROOF)
    cb.box(a0+4.5,a0+s-4.5,b0+4.5,b0+s-4.5,top,top+5.0,tc.lightened(0.18),0,Color(0.36,0.37,0.38))
    if near:
        for c in [Vector2(a0+4.8,b0+4.8),Vector2(a0+s-5.4,b0+4.8),Vector2(a0+4.8,b0+s-5.4),Vector2(a0+s-5.4,b0+s-5.4)]:
            cb.box(c.x,c.x+0.6,c.y,c.y+0.6,top+5.0,top+5.6,Color(1.0,0.16,0.10),0,Color(0,0,0,0),true)
        cb.box(w*0.5-4.0,w*0.5+4.0,-2.4,0.0,gy+4.2,gy+4.6,Color(0.30,0.31,0.33),0)
    return true

## Department store: big box, tall slit windows, rooftop billboard, banners.
func _city_department(cb: _CityBuild, rng: RandomNumberGenerator, su0: float, su1: float, sv0: float, sv1: float,
        near: bool) -> bool:
    var fr: Array = [Vector2(su0,sv0),Vector2(1,0),Vector2(0,1)]
    var w: float = su1-su0
    var d: float = minf(sv1-sv0,snappedf((sv1-sv0)*0.75,3.0))
    var site: Array = _city_site(fr,-0.5,w+0.5,-0.5,d+0.5)
    if not bool(site[0]):
        return false
    var gy: float = float(site[1])
    _city_frame(cb,fr,0.0)
    cb.base_y = gy
    var floors: int = rng.randi_range(6,8)
    var top: float = gy+5.0+float(floors-1)*4.5+1.0
    var col: Color = [Color(0.86,0.84,0.80),Color(0.80,0.74,0.64),Color(0.74,0.72,0.70)][rng.randi_range(0,2)]
    cb.box(0.0,w,0.0,d,gy-1.0,top,col,6,CITY_ROOF)
    if near:
        var sg: Color = CITY_SIGN[rng.randi_range(0,CITY_SIGN.size()-1)]
        cb.box(w*0.2,w*0.2+0.6,2.0,2.6,top,top+4.0,Color(0.40,0.40,0.42),0)
        cb.box(w*0.8-0.6,w*0.8,2.0,2.6,top,top+4.0,Color(0.40,0.40,0.42),0)
        cb.box(w*0.18,w*0.82,1.6,2.0,top+3.0,top+9.0,sg,0,Color(0,0,0,0),true)
        for k in range(3):
            var u: float = w*(0.25+0.25*float(k))
            var bc: Color = CITY_SIGN[rng.randi_range(0,CITY_SIGN.size()-1)]
            cb.box(u-1.0,u+1.0,-0.6,-0.2,gy+6.0,gy+6.0+minf(14.0,top-gy-8.0),bc,0,Color(0,0,0,0),true)
        cb.box(0.0,w,-2.6,0.0,gy+4.4,gy+4.8,Color(0.26,0.27,0.29),0)
    return true

## Small shrine in a park: vermilion torii in front of a timber hall.
func _city_shrine(cb: _CityBuild, rng: RandomNumberGenerator, c: Vector2) -> void:
    var fr: Array = [c-Vector2(4.0,8.0),Vector2(1,0),Vector2(0,1)]
    var site: Array = _city_site(fr,-1.0,9.0,-1.0,14.0)
    if not bool(site[0]):
        return
    var gy: float = float(site[1])
    _city_frame(cb,fr,0.0)
    cb.base_y = gy
    var ver := Color(0.82,0.22,0.12)
    cb.box(0.6,1.1,0.0,0.5,gy-0.5,gy+4.6,ver,0)
    cb.box(6.9,7.4,0.0,0.5,gy-0.5,gy+4.6,ver,0)
    cb.box(-0.4,8.4,-0.1,0.6,gy+4.6,gy+5.2,Color(0.14,0.13,0.12),0)
    cb.box(0.2,7.8,0.0,0.5,gy+3.7,gy+4.1,ver,0)
    cb.box(1.0,7.0,7.0,12.0,gy-0.5,gy+3.0,Color(0.40,0.27,0.17),0)
    cb.gable(0.4,7.6,6.4,12.6,gy+3.0,2.2,Color(0.24,0.25,0.26))

## Street furniture on the block's south (U) street and west (V) street.
func _city_street_kit(cb: _CityBuild, rng: RandomNumberGenerator, u0: float, u1: float, v0: float, v1: float,
        south_ave: bool, west_ave: bool, per: Dictionary, shadows: Array[Transform3D]) -> void:
    # South street: trees on avenues, poles with wires on side streets.
    _street_side(cb,rng,[Vector2(u0,v0-1.2),Vector2(1,0),Vector2(0,-1)],u1-u0,south_ave,per,shadows)
    _street_side(cb,rng,[Vector2(u0-1.2,v1),Vector2(0,-1),Vector2(-1,0)],v1-v0,west_ave,per,shadows)
    if south_ave or west_ave:
        # Traffic signals at the south-west crossing.
        var p: Vector2 = field.city_world(Vector2(u0-1.4,v0-1.4))
        if road_clearance(p) > CITY_GRID_CLEAR_M and not field.is_water(p.x,p.y):
            var gy: float = field.height_at(p.x,p.y)
            cb.set_frame(p,field.city_world(Vector2(1,0)),field.city_world(Vector2(0,1)))
            cb.base_y = gy
            var pole := Color(0.58,0.60,0.58)
            cb.box(-0.14,0.14,-0.14,0.14,gy-0.3,gy+6.2,pole,0)
            cb.box(-0.08,0.08,-5.0,0.0,gy+5.7,gy+5.9,pole,0)      # arm over the south street
            cb.box(-0.65,0.65,-5.0,-4.6,gy+5.2,gy+5.65,Color(0.20,0.21,0.22),0)
            var lit: Color = [Color(0.25,0.95,0.55),Color(0.98,0.18,0.12)][rng.randi_range(0,1)]
            cb.box(-0.55,-0.25,-5.06,-5.0,gy+5.28,gy+5.58,lit,0,Color(0,0,0,0),true)
            cb.box(-5.0,0.0,-0.08,0.08,gy+5.7,gy+5.9,pole,0)      # arm over the west street
            cb.box(-5.0,-4.6,-0.65,0.65,gy+5.2,gy+5.65,Color(0.20,0.21,0.22),0)

func _street_side(cb: _CityBuild, rng: RandomNumberGenerator, fr: Array, length: float, avenue: bool,
        per: Dictionary, shadows: Array[Transform3D]) -> void:
    var o: Vector2 = fr[0]
    var r: Vector2 = fr[1]
    if avenue:
        var t: float = 5.0
        while t < length-3.0:
            var p: Vector2 = field.city_world(o+r*t)
            if not _blocked(p,1.5) and not field.is_water(p.x,p.y) and road_clearance(p) >= CITY_GRID_CLEAR_M:
                _add_tree(per,shadows,"street_tree",p.x,p.y,rng.randf_range(6.0,8.0),rng)
            t += 9.0
        return
    var prev: float = -1.0
    var t2: float = 4.0
    var k: int = 0
    while t2 < length-2.0:
        var p2: Vector2 = field.city_world(o+r*t2)
        var ok: bool = road_clearance(p2) > CITY_GRID_CLEAR_M and not field.is_water(p2.x,p2.y)
        for rr in keep_out+venue_keep:
            if (rr as Rect2).has_point(p2):
                ok = false
        if ok:
            var gy: float = field.height_at(p2.x,p2.y)
            _city_frame(cb,fr,t2)
            cb.base_y = gy
            var pole := Color(0.62,0.62,0.60)
            cb.box(-0.15,0.15,-0.15,0.15,gy-0.5,gy+9.0,pole,0)
            cb.box(-0.06,0.06,-0.9,0.9,gy+8.2,gy+8.4,pole.darkened(0.1),0)
            if k%2 == 0:
                cb.box(-0.35,0.35,0.15,0.75,gy+6.2,gy+7.2,Color(0.56,0.58,0.60),0)
            if prev >= 0.0:
                # Wires back to the previous pole (frame-aligned, sagging a little).
                for wy in [8.35,7.7]:
                    cb.box(prev-t2,0.0,-0.55,-0.5,gy+wy-0.25,gy+wy-0.21,Color(0.10,0.10,0.11),0)
            prev = t2
        else:
            prev = -1.0
        k += 1
        t2 += 26.0

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
                if nm.begins_with("Roadside"):
                    key = "roadside"
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
    # v0.1.27 start lights before the start line (every event), and real
    # start / finish areas instead of a cut-off road on open routes.
    _start_lights(acc,samples,hw,rh,closed)
    if not closed:
        venue_info["route_ends"] = _route_ends(acc,samples,hw,rh,mode,venue)
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

## Arc-length index helper: first sample at or beyond s metres.
func _index_at(samples: Array[Vector2], s_m: float) -> int:
    var acc_s: float = 0.0
    for i in range(1,samples.size()):
        acc_s += samples[i-1].distance_to(samples[i])
        if acc_s >= s_m:
            return i
    return samples.size()-1

## Start light pole (owner request): on the right of the road a few metres
## before the start line, a dark panel with four green lamps facing the
## grid, on an arm reaching over the barrier.
func _start_lights(acc, samples: Array[Vector2], hw: PackedFloat32Array, rh: PackedFloat32Array, closed: bool) -> void:
    var n: int = samples.size()
    if n < 4:
        return
    var line_i: int = _index_at(samples,18.0) if not closed else 0
    var i: int = maxi(0,line_i-2) if not closed else (n-2)%n
    var j: int = mini(i+1,n-1)
    var t: Vector2 = (samples[j]-samples[i]).normalized()
    var nrm := Vector2(-t.y,t.x)
    var p: Vector2 = samples[i]+nrm*(hw[i]+1.6)
    var y: float = rh[i]
    acc.set_frame([p,t,nrm])
    var pole := Color(0.22,0.23,0.25)
    acc.box(-0.18,0.18,-0.18,0.18,y-0.5,y+5.4,pole)
    acc.box(-0.12,0.12,-2.2,0.0,y+5.0,y+5.25,pole)                    # arm over the barrier
    acc.box(-0.20,0.20,-2.6,-1.6,y+2.6,y+5.25,Color(0.06,0.06,0.07))  # lamp panel
    for k in range(4):
        var ly: float = y+2.85+float(k)*0.58
        acc.box(-0.26,-0.20,-2.42,-1.78,ly,ly+0.42,Color(0.22,1.0,0.42),true)
        acc.box(-0.34,-0.20,-2.48,-1.72,ly+0.42,ly+0.50,Color(0.04,0.04,0.05))   # visor
    venue_info["start_lights"] = [p.x,p.y]

## Open routes: a staging paddock behind the start (team vans, cars,
## gazebos, flags) and a parc ferme after the finish, both as paved areas
## that continue the road past its end barriers. Returns what was built.
func _route_ends(acc, samples: Array[Vector2], hw: PackedFloat32Array, rh: PackedFloat32Array, mode: String,
        venue: String) -> Dictionary:
    var out: Dictionary = {}
    var n: int = samples.size()
    var colours: Array[Color] = [Color(0.92,0.20,0.22),Color(0.96,0.96,0.94),Color(0.20,0.36,0.70),Color(0.95,0.62,0.12)]
    for pad in road_pads():
        var end: String = str(pad["end"])
        var w: float = float(pad["w"])
        var d: float = float(pad["d"])
        var y: float = float(pad["y"])
        var fr: Array = [pad["o"],pad["u"],pad["v"]]
        acc.set_frame(fr)
        var c: Vector2 = (fr[0] as Vector2)+(fr[1] as Vector2)*w*0.5+(fr[2] as Vector2)*d*0.5
        var lo: float = INF
        for a in [0.0,0.5,1.0]:
            for b in [0.0,0.5,1.0]:
                var q: Vector2 = (fr[0] as Vector2)+(fr[1] as Vector2)*w*a+(fr[2] as Vector2)*d*b
                lo = minf(lo,field.height_at(q.x,q.y))
        var slab := Color(0.30,0.30,0.32)
        acc.box(0.0,w,0.0,d,minf(lo,y)-1.5,y-0.02,slab.darkened(0.25),false,slab)
        # Low concrete wall around the far edges.
        acc.box(0.0,w,d-0.6,d,y,y+0.9,Color(0.72,0.72,0.70))
        acc.box(0.0,0.6,0.0,d,y,y+0.9,Color(0.72,0.72,0.70))
        acc.box(w-0.6,w,0.0,d,y,y+0.9,Color(0.72,0.72,0.70))
        # Painted bays along both long sides.
        var u: float = 2.0
        while u < w-3.0:
            acc.box(u,u+0.16,d-7.0,d-1.2,y,y+0.02,Color(0.92,0.92,0.88))
            u += 3.2
        var rng := RandomNumberGenerator.new()
        rng.seed = seed_value*31+(1 if end == "start" else 2)
        # Parked cars (start: competitors waiting; finish: parc ferme).
        var u2: float = 2.6
        while u2 < w-4.0:
            if rng.randf() < 0.75:
                var cc: Color = Color.from_hsv(rng.randf(),rng.randf_range(0.4,0.85),rng.randf_range(0.55,0.95))
                acc.box(u2+0.2,u2+2.0,d-6.4,d-2.0,y,y+0.75,cc,false,cc)
                acc.box(u2+0.35,u2+1.85,d-5.4,d-3.1,y+0.75,y+1.25,Color(0.12,0.14,0.17))
            u2 += 3.2
        if end == "start":
            # Team vans + gazebos on the near half, flags along the road.
            for k in range(2 if mode == "practice" else 4):
                var vu: float = 2.0+float(k)*(w-6.0)/3.0
                var vc: Color = colours[k%colours.size()]
                acc.box(vu,vu+2.2,6.0,12.0,y,y+2.6,Color(0.92,0.92,0.92),false,Color(0.85,0.85,0.86))
                acc.box(vu-0.05,vu+2.25,7.5,10.5,y+1.2,y+1.7,vc)
                if mode != "practice":
                    for pu in [vu+2.8,vu+7.0]:
                        for pv in [6.0,10.0]:
                            acc.box(pu,pu+0.1,pv,pv+0.1,y,y+2.5,Color(0.75,0.75,0.76))
                    acc.box(vu+2.6,vu+7.3,5.8,10.3,y+2.5,y+2.8,vc,false,vc)
            # Start banner on two posts (practice: there is no start gantry).
            if mode != "practice":
                pass
            else:
                acc.box(0.8,1.1,0.4,0.7,y,y+5.5,Color(0.80,0.80,0.80))
                acc.box(w-1.1,w-0.8,0.4,0.7,y,y+5.5,Color(0.80,0.80,0.80))
                acc.box(0.8,w-0.8,0.45,0.65,y+4.3,y+5.4,STYLE_BANNER(venue),true)
        else:
            # Parc ferme: marshal cabin, checkered flag posts, cones.
            acc.box(1.2,6.2,6.0,10.0,y,y+2.8,Color(0.90,0.90,0.88),false,Color(0.32,0.33,0.35))
            acc.box(1.0,6.4,5.94,6.0,y+1.3,y+2.2,Color(0.22,0.32,0.42))
            for fk in range(4):
                var fu: float = 8.0+float(fk)*(w-10.0)/3.0
                acc.box(fu,fu+0.1,2.0,2.1,y,y+4.5,Color(0.8,0.8,0.8))
                for cx in range(4):
                    for cy in range(3):
                        var col: Color = Color(0.95,0.95,0.95) if (cx+cy)%2 == 0 else Color(0.06,0.06,0.07)
                        acc.box(fu+0.1+float(cx)*0.3,fu+0.4+float(cx)*0.3,2.02,2.08,y+3.6+float(cy)*0.3,y+3.9+float(cy)*0.3,col)
            for k2 in range(6):
                var cu: float = w*0.3+float(k2)*1.8
                acc.box(cu,cu+0.45,1.6,2.05,y,y+0.7,Color(1.0,0.45,0.08))
        var r := Rect2(c,Vector2.ZERO)
        for a2 in [-0.5,0.5]:
            for b2 in [-0.5,0.5]:
                r = r.expand(c+(fr[1] as Vector2)*w*a2+(fr[2] as Vector2)*d*b2)
        venue_keep.append(r.grow(3.0))
        out[end] = true
    return out

func road_pads() -> Array:
    return world.road.get("end_pads",[]) if not world.road.is_empty() else []

func STYLE_BANNER(venue: String) -> Color:
    match venue:
        "paddock_eu":
            return Color(0.85,0.12,0.20)
        "paddock_ie":
            return Color(0.10,0.55,0.32)
    return Color(0.95,0.22,0.36)

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
        "flowers":
            # Low cluster of blossoms (unit radius) on the grass.
            for kf in range(13):
                var a: float = rng.randf_range(0,TAU)
                var rr: float = rng.randf_range(0.0,0.48)
                b.box(Vector3(cos(a)*rr,0.10+rng.randf_range(0.0,0.08),sin(a)*rr),Vector3(0.07,0.05,0.07),Color(1,1,1),1.0)
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
    var ck: Dictionary = {}
    for id in city_kinds.keys():
        for k in (city_kinds[id] as Dictionary).keys():
            ck[k] = int(ck.get(k,0))+int(city_kinds[id][k])
    return {"counts":counts.duplicate(),"venue":venue_info.duplicate(true),"landmarks":landmark_info.duplicate(true),
        "keep_out":keep_out.size(),"city":ck,"frontage":frontage_summary()}

## Minimum distance from the soft roadside planting to the road edge (it
## must stay behind the barrier: verge + ROADSIDE_MIN_M); INF if none.
func min_roadside_clearance() -> Array:
    var best: float = INF
    var count: int = 0
    for id in chunk_nodes.keys():
        var node: Node3D = chunk_nodes[id]
        for child in node.get_children():
            if child is MultiMeshInstance3D and str(child.name).begins_with("Roadside"):
                var mm: MultiMesh = (child as MultiMeshInstance3D).multimesh
                var base: Vector3 = (child as Node3D).position
                for k in range(mm.instance_count):
                    var o: Vector3 = mm.get_instance_transform(k).origin+base
                    best = minf(best,road_clearance(Vector2(o.x,o.z)))
                    count += 1
            elif child is MeshInstance3D and child.has_meta("roadside_points"):
                for q in (child.get_meta("roadside_points") as PackedVector2Array):
                    best = minf(best,road_clearance(q))
                    count += 1
    return [best,count]

## Minimum distance from any solid scenery item (tree / rock / building
## footprint) to the road edge; used by the safety exclusion test.
func min_item_clearance() -> float:
    var best: float = INF
    for id in chunk_nodes.keys():
        var node: Node3D = chunk_nodes[id]
        for child in node.get_children():
            if child is MultiMeshInstance3D and str(child.name) != "Tree shadows" and not str(child.name).begins_with("Roadside"):
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

## Japan City geometry: boxes in a block-aligned frame with the facade
## style + building base in UV (city_facade.gdshader), plus unshaded signs.
class _CityBuild:
    var pos := PackedVector3Array()
    var nrm := PackedVector3Array()
    var col := PackedColorArray()
    var uv := PackedVector2Array()
    var uv2 := PackedVector2Array()
    var idx := PackedInt32Array()
    var gpos := PackedVector3Array()
    var gnrm := PackedVector3Array()
    var gcol := PackedColorArray()
    var gidx := PackedInt32Array()
    var o := Vector2.ZERO
    var r := Vector2.RIGHT
    var b := Vector2.DOWN
    var base_y: float = 0.0

    func set_frame(origin: Vector2, along: Vector2, inwards: Vector2) -> void:
        o = origin
        r = along
        b = inwards

    func w(u: float, v: float, y: float) -> Vector3:
        var p: Vector2 = o+r*u+b*v
        return Vector3(p.x,y,p.y)

    func _quad(a: Vector3, bb: Vector3, c: Vector3, d: Vector3, n: Vector3, colour: Color, style: float, glow: bool) -> void:
        # Wind so that (bb-a)x(c-a) points along n; Godot front faces are
        # clockwise seen from outside -> indices a, c, b.
        if (bb-a).cross(c-a).dot(n) < 0.0:
            var t: Vector3 = bb
            bb = d
            d = t
        if glow:
            var g0: int = gpos.size()
            for p in [a,bb,c,d]:
                gpos.append(p)
                gnrm.append(n)
                gcol.append(colour)
            gidx.append_array([g0,g0+2,g0+1,g0,g0+3,g0+2])
            return
        # Window grid starts at the face's own edge (UV2.x), so windows line
        # up with the corners whatever the building's orientation.
        var off: float = 0.0
        if absf(n.y) < 0.5:
            var t2 := Vector2(-n.z,n.x).normalized()
            off = INF
            for pc in [a,bb,c,d]:
                off = minf(off,Vector2(pc.x,pc.z).dot(t2))
        var i0: int = pos.size()
        for p2 in [a,bb,c,d]:
            pos.append(p2)
            nrm.append(n)
            col.append(colour)
            uv.append(Vector2(base_y,style))
            uv2.append(Vector2(off,0.0))
        idx.append_array([i0,i0+2,i0+1,i0,i0+3,i0+2])

    ## Box in the frame (u along the street, v inwards, y up); the side
    ## faces carry the facade style, the top is a plain roof.
    func box(u0: float, u1: float, v0: float, v1: float, y0: float, y1: float, colour: Color, style: int = 0,
            top: Color = Color(0,0,0,0), glow: bool = false) -> void:
        var c: Array[Vector3] = [w(u0,v0,y0),w(u1,v0,y0),w(u1,v1,y0),w(u0,v1,y0),
            w(u0,v0,y1),w(u1,v0,y1),w(u1,v1,y1),w(u0,v1,y1)]
        var centre: Vector3 = (c[0]+c[6])*0.5
        var faces: Array = [[4,5,6,7],[0,1,5,4],[1,2,6,5],[2,3,7,6],[3,0,4,7]]
        for fi in range(faces.size()):
            var f: Array = faces[fi]
            var mid: Vector3 = (c[f[0]]+c[f[1]]+c[f[2]]+c[f[3]])*0.25
            var n: Vector3 = (mid-centre)
            n.y = n.y if fi == 0 else 0.0
            n = n.normalized() if n.length() > 0.0001 else Vector3.UP
            var tint: Color = top if fi == 0 and top.a > 0.0 else colour
            if fi > 0 and not glow:
                tint = tint.darkened(0.05*float(fi%2))
            _quad(c[f[0]],c[f[1]],c[f[2]],c[f[3]],n,tint,0.0 if fi == 0 else float(style),glow)

    ## Gable roof along u over [u0,u1] x [v0,v1] from y0, ridge h higher.
    func gable(u0: float, u1: float, v0: float, v1: float, y0: float, h: float, colour: Color) -> void:
        var vm: float = (v0+v1)*0.5
        var a0: Vector3 = w(u0,v0,y0)
        var a1: Vector3 = w(u1,v0,y0)
        var r0: Vector3 = w(u0,vm,y0+h)
        var r1: Vector3 = w(u1,vm,y0+h)
        var b0: Vector3 = w(u0,v1,y0)
        var b1: Vector3 = w(u1,v1,y0)
        var up := Vector3.UP
        var n1: Vector3 = (a1-a0).cross(r0-a0).normalized()
        if n1.dot(up) < 0.0:
            n1 = -n1
        var n2: Vector3 = (b1-b0).cross(r0-b0).normalized()
        if n2.dot(up) < 0.0:
            n2 = -n2
        _quad(a0,a1,r1,r0,n1,colour,0.0,false)
        _quad(b0,b1,r1,r0,n2,colour.darkened(0.08),0.0,false)
        for e in [[a0,b0,r0],[a1,b1,r1]]:
            var n3: Vector3 = (e[1]-e[0]).cross(e[2]-e[0]).normalized()
            var away: Vector3 = (e[0]-(a0+a1+b0+b1)*0.25)
            away.y = 0.0
            if n3.dot(away) < 0.0:
                n3 = -n3
            var i0: int = pos.size()
            for p in e:
                pos.append(p)
                nrm.append(n3)
                col.append(colour.darkened(0.15))
                uv.append(Vector2(base_y,0.0))
                uv2.append(Vector2.ZERO)
            if (e[1]-e[0]).cross(e[2]-e[0]).dot(n3) > 0.0:
                idx.append_array([i0,i0+2,i0+1])
            else:
                idx.append_array([i0,i0+1,i0+2])

    func commit(mat: Material, glow_mat: Material, origin: Vector3) -> ArrayMesh:
        var mesh := ArrayMesh.new()
        if not pos.is_empty():
            var p2 := PackedVector3Array()
            p2.resize(pos.size())
            for k in range(pos.size()):
                p2[k] = pos[k]-origin
            var arr: Array = []
            arr.resize(Mesh.ARRAY_MAX)
            arr[Mesh.ARRAY_VERTEX] = p2
            arr[Mesh.ARRAY_NORMAL] = nrm
            arr[Mesh.ARRAY_COLOR] = col
            arr[Mesh.ARRAY_TEX_UV] = uv
            arr[Mesh.ARRAY_TEX_UV2] = uv2
            arr[Mesh.ARRAY_INDEX] = idx
            mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arr)
            mesh.surface_set_material(mesh.get_surface_count()-1,mat)
        if not gpos.is_empty():
            var g2 := PackedVector3Array()
            g2.resize(gpos.size())
            for k2 in range(gpos.size()):
                g2[k2] = gpos[k2]-origin
            var arr2: Array = []
            arr2.resize(Mesh.ARRAY_MAX)
            arr2[Mesh.ARRAY_VERTEX] = g2
            arr2[Mesh.ARRAY_NORMAL] = gnrm
            arr2[Mesh.ARRAY_COLOR] = gcol
            arr2[Mesh.ARRAY_INDEX] = gidx
            mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arr2)
            mesh.surface_set_material(mesh.get_surface_count()-1,glow_mat)
        return mesh
