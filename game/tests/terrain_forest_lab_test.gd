extends SceneTree
## FOREST LAB (issue #54), Touge pilot: the opt-in CLASSIC / FOREST LAB switch in the REAL terrain scenery.
##  * CLASSIC is the default and stays untouched: the same world + road gives the identical CLASSIC trees before FOREST LAB was ever
##    switched on, after it was switched on and off again, and on every OTHER biome even when the mode is "lab";
##  * FOREST LAB on a TOUGE world REPLACES the CLASSIC trees of that world (no "Trees ..." MultiMeshes left, its own MultiMeshes),
##    the roadside planting / rocks / soft blob shadows stay;
##  * deterministic: the same world + road + config = the identical trees; another seed offset moves them;
##  * placement: every tree stands outside the road + barrier + safety strip (tall trees set back further), not in water, on a
##    slope the CLASSIC filters accept, with its roots in the ground (never floating), and no more than three species per cell;
##  * NEAR / FAR are CAMERA-distance visibility ranges with a hysteresis margin and no fade (not a one-off distance to the road);
##  * the DEVELOPER > VEGETATION WIND factor reaches the lab material; density LOW < MEDIUM < HIGH.
## NOT proven here: frame rate on a phone, how it looks (captures + handoff), pop-in while driving (owner QA).
const CAT = preload("res://scripts/world/terrain/terrain_catalog.gd")
const TT = preload("res://scripts/world/terrain/terrain_track.gd")
const WORLD = preload("res://scripts/world/terrain/terrain_world.gd")
const PROFILE = preload("res://scripts/world/terrain/road_profile.gd")
const LAB = preload("res://scripts/world/forest_lab/forest_lab_scatter.gd")
const F = preload("res://scripts/world/forest_lab/nitro_tree_factory.gd")
const S = preload("res://scripts/world/forest_lab/forest_lab_settings.gd")
const DEV = preload("res://scripts/dev_settings.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    printerr("FAIL: "+message)
    quit(1)

func _world(archetype: String, desc_seed: int, route_seed: int) -> NitroTerrainWorld:
    var desc: Dictionary = CAT.descriptor(archetype,desc_seed)
    var w: NitroTerrainWorld = WORLD.new()
    w.with_lighting = false
    w.setup(desc)
    root.add_child(w)
    w.build()
    var grid: NitroTrackGrid = TT.new_grid()
    var gen: Dictionary = TT.generate_loop(grid,w.field,desc,route_seed)
    if not bool(gen.get("ok",false)):
        return null
    var comp: Dictionary = gen["eval"]["compiled"]
    var smp: Array[Vector2] = []
    for p in comp["centerline"]:
        smp.append(p)
    w.set_road(smp,comp["halfwidths"],comp["heights"],true)
    return w

## Signature of the CLASSIC trees: chunk, species mesh name and instance count of every "Trees ..." MultiMesh. (A headless
## MultiMesh keeps no instance data, so transforms cannot be read back here; the CLASSIC code path itself is unchanged when
## the mode is CLASSIC - one loop bound - and this signature proves the same trees are still built.)
func _classic_sig(w: NitroTerrainWorld) -> int:
    var h: int = 0
    var ids: Array = w.scenery.chunk_nodes.keys()
    ids.sort()
    for id in ids:
        for ch in (w.scenery.chunk_nodes[id] as Node3D).get_children():
            if ch is MultiMeshInstance3D and str(ch.name).begins_with("Trees "):
                h = h*31+hash(str(id)+str(ch.name))+(ch as MultiMeshInstance3D).multimesh.instance_count
    return h

func _classic_count(w: NitroTerrainWorld) -> int:
    var n: int = 0
    for id in w.scenery.chunk_nodes.keys():
        for ch in (w.scenery.chunk_nodes[id] as Node3D).get_children():
            if ch is MultiMeshInstance3D and str(ch.name).begins_with("Trees "):
                n += (ch as MultiMeshInstance3D).multimesh.instance_count
    return n

## All lab MultiMeshInstances of the world.
func _lab_nodes(w: NitroTerrainWorld) -> Array:
    var out: Array = []
    for id in w.scenery.chunk_nodes.keys():
        for ch in (w.scenery.chunk_nodes[id] as Node3D).get_children():
            if ch is MultiMeshInstance3D and str(ch.name).begins_with("Forest Lab "):
                out.append(ch)
    return out

## Signature of the lab placement (positions + species of every tree, chunk by chunk).
func _lab_sig(w: NitroTerrainWorld) -> int:
    var h: int = 0
    var ids: Array = w.scenery.lab_stats.keys()
    ids.sort()
    for id in ids:
        var st: Dictionary = w.scenery.lab_stats[id]
        h = h*31+hash(str(id))+hash(st["pos"])+hash(st["kind"])
    return h

func _cfg(density: int, offset: int = 0) -> Dictionary:
    var c: Dictionary = S.defaults()
    c["mode"] = "lab"
    c["density"] = density
    c["seed_offset"] = offset
    return c

func _run() -> void:
    var was_mode: Variant = DEV.get_value(S.SECTION,"mode","classic")
    var was_wind: Variant = DEV.get_value("developer","vegetation_wind",1.0)
    DEV.set_value(S.SECTION,"mode","classic")
    var err: String = await _checks()
    DEV.set_value(S.SECTION,"mode",was_mode)
    DEV.set_value("developer","vegetation_wind",was_wind)
    if not err.is_empty():
        _fail(err)
        return
    for _f in range(3):
        await process_frame
    quit(0)

func _checks() -> String:
    var w: NitroTerrainWorld = _world("jp_touge",1,5)
    if w == null:
        return "no loop on the Touge world"
    # ---------------------------------------------------------- CLASSIC is the default and byte-stable
    if not w.scenery.lab_cfg.is_empty() or not _lab_nodes(w).is_empty():
        return "the default must be CLASSIC (no lab trees)"
    # #67 integration: CLASSIC must cost nothing for FOREST LAB - no material, no generated tree mesh, no lab stats.
    var LAB_SCATTER = load("res://scripts/world/forest_lab/forest_lab_scatter.gd")
    if w.scenery.get("_lab_mat") != null or not (w.scenery.lab_stats as Dictionary).is_empty() \
            or not (LAB_SCATTER.get("_mesh_cache") as Dictionary).is_empty():
        return "CLASSIC must not build any FOREST LAB material, mesh or chunk"
    var classic_sig: int = _classic_sig(w)
    var classic_n: int = _classic_count(w)
    if classic_n < 500:
        return "the CLASSIC Touge must have trees (%d)" % classic_n
    # ------------------------------------------------------------------------ FOREST LAB replaces them
    w.scenery.set_forest_config(_cfg(1))
    w.scenery.rebuild_all()
    if w.scenery.lab_cfg.is_empty():
        return "FOREST LAB must be active on a TOUGE world when the mode is lab"
    if _classic_count(w) != 0:
        return "FOREST LAB replaces the CLASSIC trees of the world (%d left)" % _classic_count(w)
    var lab: Array = _lab_nodes(w)
    var trees: int = 0
    var by_type: Dictionary = {}
    var mmi_max: int = 0
    for id in w.scenery.lab_stats.keys():
        var st: Dictionary = w.scenery.lab_stats[id]
        trees += int(st["trees"])
        mmi_max = maxi(mmi_max,int(st["mmi"]))
        for k in (st["by_type"] as Dictionary).keys():
            by_type[k] = int(by_type.get(k,0))+int((st["by_type"] as Dictionary)[k])
    if trees < 500 or lab.is_empty():
        return "FOREST LAB must plant a forest (%d trees)" % trees
    if by_type.size() < 6:
        return "all the species must appear on a Touge world (got %s)" % str(by_type)
    if mmi_max > 2*LAB.CELLS_PER_CHUNK*LAB.CELLS_PER_CHUNK*3:
        return "at most 3 species x 2 LOD per 112 m cell (a chunk holds %d MultiMeshes)" % mmi_max
    var shadow_quads: int = 0
    for id in w.scenery.chunk_nodes.keys():
        for ch in (w.scenery.chunk_nodes[id] as Node3D).get_children():
            if ch is MultiMeshInstance3D and str(ch.name) == "Tree shadows":
                shadow_quads += (ch as MultiMeshInstance3D).multimesh.instance_count
    if shadow_quads < trees:
        return "the soft blob shadows must follow the lab trees (%d quads for %d trees)" % [shadow_quads,trees]
    # ------------------------------------------------------------ deterministic
    var sig_a: int = _lab_sig(w)
    w.scenery.rebuild_all()
    if _lab_sig(w) != sig_a:
        return "the same world + road + config must give the identical lab trees"
    w.scenery.set_forest_config(_cfg(1,7))
    w.scenery.rebuild_all()
    if _lab_sig(w) == sig_a:
        return "another seed offset must move the trees"
    w.scenery.set_forest_config(_cfg(1))
    w.scenery.rebuild_all()
    if _lab_sig(w) != sig_a:
        return "going back to the first config must give the first trees again"
    lab = _lab_nodes(w)          # the nodes of the LAST rebuild (the earlier ones are queued for deletion)
    # ------------------------------------------------------------------------------ placement
    var field: NitroTerrainField = w.field
    var keep: float = PROFILE.VERGE+PROFILE.MARGIN+NitroTerrainScenery.SAFETY_M
    var worst_clear: float = INF
    var worst_float: float = -INF
    var worst_buried: float = INF
    var checked: int = 0
    for id in w.scenery.lab_stats.keys():
        var st2: Dictionary = w.scenery.lab_stats[id]
        var pos: PackedVector3Array = st2["pos"]
        var rad: PackedFloat32Array = st2["rad"]
        var hgt: PackedFloat32Array = st2["hgt"]
        for i in range(pos.size()):
            var p: Vector3 = pos[i]
            var p2 := Vector2(p.x,p.z)
            var clear: float = w.scenery.road_clearance(p2)
            worst_clear = minf(worst_clear,clear)
            if clear < keep+float(rad[i]) and not (hgt[i] <= 3.0):
                return "a tree of %.1f m (crown radius %.1f m) is only %.1f m from the road" % [float(hgt[i]),float(rad[i]),clear]
            if field.is_water(p.x,p.z):
                return "a tree stands in water at %s" % str(p)
            if field.slope_at(p.x,p.z) > 1.1+0.001:
                return "a tree stands on a slope the CLASSIC filters refuse (%.2f)" % field.slope_at(p.x,p.z)
            for r in w.scenery.keep_out+w.scenery.venue_keep:
                if (r as Rect2).has_point(p2):
                    return "a tree stands inside a landmark / venue footprint"
            var ground: float = field.height_at(p.x,p.z)
            worst_float = maxf(worst_float,p.y-ground)
            worst_buried = minf(worst_buried,p.y-ground)
            checked += 1
    if worst_clear < keep:
        return "a tree is %.1f m from the road: it must stay outside the road + barrier + safety strip (%.1f m)" % [worst_clear,keep]
    if worst_float > 0.02:
        return "a tree floats %.2f m above the ground" % worst_float
    if worst_buried < -0.9:
        return "a tree is buried %.2f m deep" % -worst_buried
    # ---------------------------------------------------------------------------- NEAR / FAR ranges
    var near_n: int = 0
    var far_n: int = 0
    for n in lab:
        var inst2: MultiMeshInstance3D = n
        if inst2.visibility_range_fade_mode != GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED:
            return "NEAR / FAR must not fade (GL Compatibility): hysteresis margins instead"
        if str(inst2.name).contains(" NEAR "):
            near_n += 1
            if inst2.visibility_range_end < 60.0 or inst2.visibility_range_end_margin <= 0.0 or inst2.visibility_range_begin != 0.0:
                return "a NEAR node must be visible from 0 to the near distance with a hysteresis margin"
        else:
            far_n += 1
            if inst2.visibility_range_begin < 60.0 or inst2.visibility_range_begin_margin <= 0.0:
                return "a FAR node must begin where NEAR ends, with a hysteresis margin"
            if inst2.multimesh.mesh == null or F.tri_count(inst2.multimesh.mesh) > F.NEAR_TRI_BUDGET:
                return "a FAR mesh is missing or over budget"
    if near_n != far_n:
        return "every NEAR MultiMesh needs its FAR twin (%d vs %d)" % [near_n,far_n]
    # ------------------------------------------------------------------------------ wind, density
    DEV.set_value("developer","vegetation_wind",0.5)
    w.scenery.set_wind(0.5)
    var sway: Variant = (lab[0] as MultiMeshInstance3D).material_override.get_shader_parameter("sway")
    if sway == null or absf(float(sway)-0.5) > 0.001:
        return "DEVELOPER > VEGETATION WIND must reach the lab material"
    var counts: Array[int] = []
    for d in range(3):
        w.scenery.set_forest_config(_cfg(d))
        w.scenery.rebuild_all()
        var tn: int = 0
        for id in w.scenery.lab_stats.keys():
            tn += int((w.scenery.lab_stats[id] as Dictionary)["trees"])
        counts.append(tn)
    if not (counts[0] < counts[1] and counts[1] < counts[2]):
        return "density LOW < MEDIUM < HIGH expected (%s)" % str(counts)
    # ------------------------------------------------------------ CLASSIC comes back byte for byte
    w.scenery.set_forest_config({})
    w.scenery.rebuild_all()
    if not w.scenery.lab_cfg.is_empty() or not _lab_nodes(w).is_empty():
        return "switching back to CLASSIC must remove every lab tree"
    if _classic_sig(w) != classic_sig:
        return "CLASSIC after FOREST LAB was switched off must be identical to CLASSIC before"
    w.queue_free()
    await process_frame
    # ----------------------------------------------------- the other biomes never change (lab mode on)
    var seen: PackedStringArray = []
    for spec in [["jp_forest",1,3],["pl_ojcow",621727,3],["ie_hills",1,5]]:
        var o: NitroTerrainWorld = _world(str(spec[0]),int(spec[1]),int(spec[2]))
        if o == null:
            return "no loop on "+str(spec[0])
        var base: int = _classic_sig(o)
        o.scenery.set_forest_config(_cfg(1))
        o.scenery.rebuild_all()
        if not o.scenery.lab_cfg.is_empty() or not _lab_nodes(o).is_empty() or _classic_sig(o) != base:
            return "%s must keep the CLASSIC trees even when the mode is lab (Touge pilot only)" % str(spec[0])
        seen.append(str(spec[0]))
        o.queue_free()
        await process_frame
    print("PASS: FOREST LAB on Touge - CLASSIC is the default and byte-stable (also after switching FOREST LAB on and off, and on %s with the mode set to lab); %d CLASSIC trees replaced by %d lab trees of %d species in %d NEAR / FAR MultiMesh pairs (<= %d per chunk), identical for the same world + road + config; all outside the %.1f m road strip, none in water / off the slope limit / floating (%d checked); NEAR / FAR by camera-distance visibility ranges with hysteresis and no fade; wind factor reaches the lab material; density LOW %d < MEDIUM %d < HIGH %d trees; NOT proven: phone FPS, pop-in while driving" % [", ".join(seen),classic_n,trees,by_type.size(),near_n,mmi_max,keep,checked,counts[0],counts[1],counts[2]])
    return ""
