extends RefCounted
class_name NitroForestLabScatter
## FOREST LAB (issue #54): the Touge-only placement and MultiMesh builder that terrain_scenery.gd calls INSTEAD of its
## CLASSIC tree loop when DEVELOPER > FOREST LAB is switched on for a TOUGE world (default OFF; every other biome and every
## build that never switches it on keeps the CLASSIC trees byte for byte).
##
## What it does (and what it deliberately does not):
##  * deterministic: the same world seed + road + config places the identical trees (own RNG salt, never touches the
##    CLASSIC stream; the field / road are only READ);
##  * the same filters as CLASSIC (water, slope, road + barrier + safety strip, landmark / venue footprints) plus a wider
##    set-back for TALL trees and a lower, softer road edge, so hairpins and the lower serpentines stay visible from the
##    Chase camera; start, finish, bridges and walls are inside the road / venue clearances;
##  * species grow in PATCHES (dark conifer stands, mixed deciduous stands, a rare sakura grove), not as a uniform mix, which
##    also keeps the number of MultiMeshes per cell low;
##  * one MultiMesh per cell (112 m) x species x LOD, shared meshes and ONE shared material; a cell holds at most THREE species
##    (one conifer, one deciduous, shrubs) to keep draw calls down; NEAR (0 .. near_distance from the cell centre) and FAR
##    (beyond) switch by visibility range with a hysteresis margin, so the choice follows the CAMERA, not the road;
##  * the soft blob shadows of CLASSIC are reused (no per-tree dynamic shadows: #48 stays out of this).
const F = preload("res://scripts/world/forest_lab/nitro_tree_factory.gd")
const SETTINGS = preload("res://scripts/world/forest_lab/forest_lab_settings.gd")
const FIELD = preload("res://scripts/world/terrain/terrain_field.gd")

const CELLS_PER_CHUNK: int = 2                # 112 m cells: few, well-filled MultiMeshes (the draw-call count is the mobile risk)
const LOD_MARGIN_M: float = 15.0
const SALT: int = 54
## Target height range (m) per species id (NitroTreeFactory.Type), Touge scale: tall cedar-like firs, mid pines.
const HEIGHT_RANGE: Dictionary = {0:[10.0,15.0],1:[15.0,22.0],2:[11.0,15.0],3:[6.0,8.5],4:[1.2,2.1],5:[9.0,12.0],6:[7.5,10.0],7:[7.5,10.0]}
## Crown radius as a share of tree height (clearance + blob shadow).
const CROWN_PER_H: Dictionary = {0:0.32,1:0.16,2:0.55,3:0.56,4:0.80,5:0.28,6:0.59,7:0.35}
const TALL_M: float = 9.0
const TALL_EXTRA_SETBACK_M: float = 4.0
const SOFT_EDGE_M: float = 30.0           # within this distance of the road only lower, softer species / sizes
const LOW_SPECIES: Array[int] = [4,3,7,5,0]
const DECIDUOUS: Array[int] = [2,3,4,5,6,7]

static var _mesh_cache: Dictionary = {}
static var gen_ms: float = 0.0            # time spent generating meshes since the process started (measured, not guessed)

## {} = CLASSIC. The Touge pilot only: any other landscape stays CLASSIC even when the mode is "lab".
static func active_config(info: Dictionary, override: Dictionary = {}) -> Dictionary:
    var cfg: Dictionary = override if not override.is_empty() else SETTINGS.read()
    if str(cfg.get("mode","classic")) != "lab":
        return {}
    if str(info.get("short","")) != "TOUGE":
        return {}
    return cfg

static func mesh_for(tree_type: int, lod: int, season: int, params: Dictionary) -> ArrayMesh:
    var key: String = F.params_key(tree_type,lod,season,params)
    if _mesh_cache.has(key):
        return _mesh_cache[key]
    var t0: int = Time.get_ticks_usec()
    var m: ArrayMesh = F.make_mesh(tree_type,lod,season,params)
    gen_ms += float(Time.get_ticks_usec()-t0)/1000.0
    _mesh_cache[key] = m
    return m

static func clear_cache() -> void:
    _mesh_cache.clear()
    gen_ms = 0.0

## The species a CELL may hold: one dominant conifer (pine or fir), one deciduous species (none in a dark conifer stand,
## the sakura only in a rare scenic grove) and the shrubs: at most three MultiMeshes per cell and LOD.
static func _pool(ch: int, g: float, mix: Dictionary) -> Dictionary:
    var w0: float = float(mix.get(0,0.0))
    var w1: float = float(mix.get(1,0.0))
    var con: int = 0 if float(ch&0xff)/255.0 < w0/maxf(w0+w1,0.0001) else 1
    var dec: int = -1
    if g >= 0.30:
        var cands: Array[int] = []
        if g > 0.93:
            cands.append(6)
        else:
            cands.append_array([2,5,7,3])
        var tot: float = 0.0
        for t in cands:
            tot += float(mix.get(t,0.0))
        var r: float = float((ch>>8)&0xff)/255.0*tot
        var acc: float = 0.0
        dec = cands[cands.size()-1]
        for t in cands:
            acc += float(mix.get(t,0.0))
            if r <= acc:
                dec = t
                break
    return {"con":con,"dec":dec}

static func _pick_type(rng: RandomNumberGenerator, pool: Dictionary, g: float, mix: Dictionary, soft_edge: bool) -> int:
    var con: int = int(pool["con"])
    var dec: int = int(pool["dec"])
    var wc: float = float(mix.get(0,0.0))+float(mix.get(1,0.0))
    var wd: float = 0.0
    if dec >= 0:
        wd = float(mix.get(2,0.0))+float(mix.get(5,0.0))+float(mix.get(7,0.0))+float(mix.get(3,0.0))+float(mix.get(6,0.0))
        wd *= 3.0 if g > 0.68 else 1.0
    var ws: float = float(mix.get(4,0.0))
    if soft_edge:                       # a lower, softer road edge
        wc *= 1.0 if LOW_SPECIES.has(con) else 0.35
        wd *= 1.0 if LOW_SPECIES.has(dec) else 0.35
    var total: float = wc+wd+ws
    if total <= 0.0:
        return con
    var r: float = rng.randf()*total
    if r <= wc:
        return con
    if r <= wc+wd:
        return dec
    return F.Type.SHRUB

static func _season_for(base: int, tree_type: int, cell_hash: int) -> int:
    if base < F.Season.AUTUMN_GOLD or not DECIDUOUS.has(tree_type):
        return base
    var r: int = (cell_hash>>5)%10
    if r < 6:
        return base
    return F.Season.AUTUMN_GOLD+((base-F.Season.AUTUMN_GOLD+1+(1 if r > 7 else 0))%3)

## Builds the lab trees of ONE chunk. `sc` = the NitroTerrainScenery (its field / road clearance are read, never written).
## Returns {"trees","mmi","by_type","tris_near","tris_far","pos","kind","rad","hgt"} and appends the blob shadows to `shadows`.
static func build_chunk(sc: Node3D, node: Node3D, id: Vector2i, x0: float, z0: float, span: float, cfg: Dictionary,
        shadows: Array[Transform3D], material: Material) -> Dictionary:
    var field: Object = sc.get("field")
    var info: Dictionary = sc.get("info")
    var dmult: float = SETTINGS.DENSITY_MULT[clampi(int(cfg.get("density",1)),0,2)]
    var spacing: float = 11.0/sqrt(dmult)
    var cells: int = int(span/spacing)
    var cell_span: float = span/float(CELLS_PER_CHUNK)
    var season: int = clampi(int(cfg.get("season",F.Season.SUMMER)),0,4)
    var scale_all: float = float(cfg.get("scale",1.0))
    var near_d: float = float(cfg.get("near_distance",120.0))
    var mix: Dictionary = cfg.get("mix",SETTINGS.DEFAULT_MIX)
    var seed_v: int = int(sc.get("seed_value"))
    var rng := RandomNumberGenerator.new()
    rng.seed = FIELD.hash_seed(seed_v*7919+id.x*131+id.y*977+SALT+int(cfg.get("seed_offset",0)),str(info.get("short","")),SALT)
    var groups: Dictionary = {}
    var by_type: Dictionary = {}
    var trees: int = 0
    # The placement itself (what the MultiMeshes are filled from): tests read THIS, because a headless MultiMesh keeps no data.
    var pos_all := PackedVector3Array()
    var kind_all := PackedInt32Array()
    var rad_all := PackedFloat32Array()
    var hgt_all := PackedFloat32Array()
    for b in range(cells):
        for a in range(cells):
            var x: float = x0+(float(a)+rng.randf_range(0.1,0.9))*spacing
            var z: float = z0+(float(b)+rng.randf_range(0.1,0.9))*spacing
            var roll: float = rng.randf()
            var dens: float = float(field.call("mask_at",field.get("forest"),x,z))
            if roll > dens:
                continue
            if bool(field.call("is_water",x,z)):
                continue
            var slope: float = float(field.call("slope_at",x,z))
            if slope > 1.1:
                continue
            var p2 := Vector2(x,z)
            var clear: float = float(sc.call("road_clearance",p2))
            var soft: bool = clear < 14.0+SOFT_EDGE_M
            var cx: int = clampi(int(floor((x-x0)/cell_span)),0,CELLS_PER_CHUNK-1)
            var cz: int = clampi(int(floor((z-z0)/cell_span)),0,CELLS_PER_CHUNK-1)
            var ch: int = hash(Vector3i(id.x*CELLS_PER_CHUNK+cx,id.y*CELLS_PER_CHUNK+cz,seed_v+int(cfg.get("seed_offset",0))))
            var ox: float = x0+(float(cx)+0.5)*cell_span
            var oz: float = z0+(float(cz)+0.5)*cell_span
            var g: float = float(field.call("_n",5,ox*0.6,oz*0.6))*0.5+0.5       # slow noise: stands of ~100 m
            var pool: Dictionary = _pool(ch,g,mix)
            var tt: int = _pick_type(rng,pool,g,mix,soft)
            var hr: Array = HEIGHT_RANGE[tt]
            var h: float = rng.randf_range(float(hr[0]),float(hr[1]))*scale_all
            if soft and tt != F.Type.SHRUB:
                h *= 0.78
            var wide: float = rng.randf_range(0.9,1.15)
            var tall: float = rng.randf_range(0.92,1.1)
            var rad: float = float(CROWN_PER_H[tt])*h*wide
            var extra: float = TALL_EXTRA_SETBACK_M if h > TALL_M else 0.0
            if bool(sc.call("_blocked",p2,rad+extra)):
                continue
            var rot: float = rng.randf_range(0.0,TAU)
            var tint: float = rng.randf_range(0.93,1.07)
            rng.randf()                                        # consumed always: keeps the stream aligned
            var variant: int = (ch>>3)&1
            var sea: int = _season_for(season,tt,ch)
            var gkey: String = "%d,%d|%d|%d|%d" % [cx,cz,tt,variant,sea]
            if not groups.has(gkey):
                groups[gkey] = {"xf":[],"col":[],"type":tt,"variant":variant,"season":sea,
                    "origin":Vector3(x0+(float(cx)+0.5)*cell_span,0.0,z0+(float(cz)+0.5)*cell_span)}
            var sf: float = h/float(F.BASE_HEIGHT[tt])
            var y: float = float(field.call("height_at",x,z))-(0.25+0.5*slope*0.35)
            var lean := Basis(Vector3(rng.randf_range(-1,1),0,rng.randf_range(-1,1)).normalized(),rng.randf_range(0.0,0.035))
            var basis: Basis = lean*Basis(Vector3.UP,rot).scaled(Vector3(wide*sf,tall*sf,wide*sf))
            (groups[gkey]["xf"] as Array).append(Transform3D(basis,Vector3(x,y,z)))
            (groups[gkey]["col"] as Array).append(Color(tint,tint,tint*rng.randf_range(0.97,1.03)))
            by_type[tt] = int(by_type.get(tt,0))+1
            trees += 1
            pos_all.append(Vector3(x,y,z))
            kind_all.append(tt)
            rad_all.append(rad)
            hgt_all.append(h)
            # the same soft blob shadow CLASSIC trees get
            var nrm: Vector3 = sc.call("_ground_normal",x,z)
            var up: Vector3 = nrm
            var right: Vector3 = up.cross(Vector3.FORWARD).normalized()
            var fwd: Vector3 = right.cross(up).normalized()
            var r: float = rad*0.85
            shadows.append(Transform3D(Basis(right*r*2.2,up,fwd*r*2.5),
                Vector3(x+0.18*h,float(field.call("height_at",x+0.18*h,z+0.26*h))+0.18,z+0.26*h)))
    var draw_range: float = float(sc.get("draw_range"))
    var keys: Array = groups.keys()
    keys.sort()
    var mmi: int = 0
    var tris_near: int = 0
    var tris_far: int = 0
    for key in keys:
        var g: Dictionary = groups[key]
        var params: Dictionary = SETTINGS.params_for(cfg,int(g["type"]))
        params = params.duplicate()
        params["variant"] = int(g["variant"])
        var xf: Array = g["xf"]
        for lod in [F.LOD.NEAR,F.LOD.FAR]:
            var mesh: ArrayMesh = mesh_for(int(g["type"]),lod,int(g["season"]),params)
            var mm := MultiMesh.new()
            mm.transform_format = MultiMesh.TRANSFORM_3D
            mm.use_colors = true
            mm.mesh = mesh
            mm.instance_count = xf.size()
            var origin: Vector3 = g["origin"]
            for k in range(xf.size()):
                mm.set_instance_transform(k,(xf[k] as Transform3D).translated(-origin))
                mm.set_instance_color(k,(g["col"] as Array)[k])
            var inst := MultiMeshInstance3D.new()
            inst.name = "Forest Lab %s %s %s" % [F.species_name(int(g["type"])),"NEAR" if lod == F.LOD.NEAR else "FAR",str(key)]
            inst.multimesh = mm
            inst.material_override = material
            inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            inst.position = origin
            inst.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
            if lod == F.LOD.NEAR:
                inst.visibility_range_end = near_d
                inst.visibility_range_end_margin = LOD_MARGIN_M
                tris_near += F.tri_count(mesh)*xf.size()
            else:
                inst.visibility_range_begin = near_d
                inst.visibility_range_begin_margin = LOD_MARGIN_M
                if draw_range > 0.0:
                    inst.visibility_range_end = draw_range
                    inst.visibility_range_end_margin = 40.0
                tris_far += F.tri_count(mesh)*xf.size()
            node.add_child(inst)
            mmi += 1
    return {"trees":trees,"mmi":mmi,"by_type":by_type,"tris_near":tris_near,"tris_far":tris_far,
        "pos":pos_all,"kind":kind_all,"rad":rad_all,"hgt":hgt_all}
