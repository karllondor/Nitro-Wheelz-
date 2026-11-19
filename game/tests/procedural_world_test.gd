extends SceneTree
## Procedural world, phase A (Japan Drift Town) - fail-closed regression.
##  1. Adjacency: a stand-alone garage + a neighbouring lot created by
##     extending the road becomes ONE joined 2 x 1 workshop (no inner wall,
##     continuous roof); removing the tile restores the stand-alone garage
##     with its exterior walls; builder UNDO returns the previous version.
##  2. Determinism: same tiles + seed = identical placements (ids and
##     footprints), builder path (grid links) == race path (saved JSON).
##  3. Safety: on 12 generated circuits no building, fence or tree footprint
##     comes closer to the COMPILED Track DNA road than its setback, and no
##     building overlaps another building or a tree.
##  4. Incremental: one tile edit re-plans only nearby cells and rebuilds
##     few chunks; untouched chunks keep their nodes.
##  5. Track DNA unchanged: the world adds a "world" block only; the road
##     control points are identical with or without it.
const GRID = preload("res://scripts/world/track_grid.gd")
const WORLD = preload("res://scripts/world/procedural_world.gd")
const RULES = preload("res://scripts/world/scenery_rules.gd")
const DNA = preload("res://scripts/world/track_dna.gd")
const TRACK = preload("res://scripts/world/drift_track.gd")
const SEED: int = 2106

func _initialize() -> void:
    call_deferred("_run")

func _fail(msg: String) -> void:
    printerr("FAIL: "+msg)
    quit(1)

func _chain(g: NitroTrackGrid, cells: Array) -> void:
    for i in range(cells.size()-1):
        g.link(cells[i],cells[i+1])

## Find an open straight chain whose one-tile extension turns a stand-alone
## garage into the left/right half of a two-cell workshop.
func find_join_case(w: NitroProceduralWorld) -> Dictionary:
    for y in range(2,10):
        for x0 in range(1,4):
            for length in range(2,4):
                var g: NitroTrackGrid = GRID.new(8,12)
                var cells: Array = []
                for k in range(length):
                    cells.append(Vector2i(x0+k,y))
                _chain(g,cells)
                w.generate(g.links,8,12,SEED)
                var before: Dictionary = w.plan_cells.duplicate()
                var ext := Vector2i(x0+length,y)
                g.link(cells[cells.size()-1],ext)
                w.update(g.links)
                for c in w.plan_cells.keys():
                    var p: Dictionary = w.plan_cells[c]
                    if str(p["role"]) != "lot" or not before.has(c) or str(before[c]["role"]) != "lot":
                        continue
                    var row_after: Array = RULES.row_of(w.plan_cells,c)
                    var row_before: Array = RULES.row_of(before,c)
                    if row_before.size() == 1 and row_after.size() == 2 and Vector2i(before[c]["f"]) == Vector2i(p["f"]) \
                            and absf(float(before[c]["v"])-float(p["v"])) < 0.01:
                        return {"cells":cells,"ext":ext,"cell":c,"partner":row_after[1] if row_after[0] == c else row_after[0]}
    return {}

func _run() -> void:
    var w: NitroProceduralWorld = WORLD.new()
    root.add_child(w)
    # 1) Adjacency join / split.
    var case: Dictionary = find_join_case(w)
    if case.is_empty():
        _fail("No road extension joins a stand-alone garage into a 2 x 1 workshop")
        return
    var g: NitroTrackGrid = GRID.new(8,12)
    _chain(g,case["cells"])
    w.generate(g.links,8,12,SEED)
    var c: Vector2i = case["cell"]
    var key_single: String = w.keys[c]
    if RULES.row_of(w.plan_cells,c).size() != 1 or not key_single.contains("|0|0|1|0|"):
        _fail("Expected a stand-alone garage before the extension: "+key_single)
        return
    var before_ids: Array = _ids(w)
    g.link((case["cells"] as Array).back(),case["ext"])
    var st: Dictionary = w.update(g.links)
    var key_joined: String = w.keys[c]
    var partner: Vector2i = case["partner"]
    var side_c: int = 1 if RULES.joined(w.plan_cells,c,1) else -1
    if RULES.row_of(w.plan_cells,c).size() != 2 or not RULES.joined(w.plan_cells,c,side_c) \
            or not RULES.joined(w.plan_cells,partner,-side_c):
        _fail("Garage did not join its new neighbour: "+key_joined)
        return
    # Joined side: no gable / outer wall there, roof runs to the cell edge.
    var a = WORLD.MODS.Acc.new()
    a.set_frame(w.rules.frame(c,w.plan_cells[c]["f"]))
    var p: Dictionary = w.plan_cells[c]
    WORLD.MODS.workshop(a,float(p["v"]),float(p["d"]),side_c == -1,side_c == 1,2,0 if side_c == 1 else 1,0,0)
    var edge_u: float = RULES.S if side_c == 1 else 0.0
    var at_edge: int = 0
    var fr: Array = w.rules.frame(c,p["f"])
    for v3 in a.pos:
        var local: Vector2 = Vector2(v3.x,v3.z)-Vector2(fr[0])
        var u: float = local.dot(Vector2(fr[1]))
        if absf(u-edge_u) < 0.01 and v3.y > 4.0:
            at_edge += 1
    if at_edge < 4:
        _fail("Joined workshop roof does not reach the shared edge (%d vertices)" % at_edge)
        return
    # Two tiles changed (old end + new tile): at most their 4 x 3 tile
    # neighbourhood is re-planned and at most 3 x 2 chunks are rebuilt.
    if int(st["rebuilt_chunks"]) > 6 or int(st["planned_cells"]) > 12*16:
        _fail("Extension rebuilt too much: "+str(st))
        return
    # Removing the tile restores the stand-alone garage exactly.
    g.erase(case["ext"])
    w.update(g.links)
    if str(w.keys[c]) != key_single or _ids(w) != before_ids:
        _fail("Removing the tile did not restore the stand-alone garage")
        return
    # Builder UNDO goes through the same path.
    var builder: Node = (load("res://scenes/track_builder.tscn") as PackedScene).instantiate()
    root.add_child(builder)
    await process_frame
    var bg: NitroTrackGrid = builder.get("grid")
    bg.clear()
    _chain(bg,case["cells"])
    builder.set("world_seed",SEED)
    builder.call("_rebuild")
    var bw: NitroProceduralWorld = builder.get("world")
    var k0: String = bw.keys.get(c,"")
    builder.call("begin_stroke",(case["cells"] as Array).back())
    builder.call("move_stroke",case["ext"])
    builder.call("end_stroke")
    var k1: String = bw.keys.get(c,"")
    builder.call("_undo")
    var k2: String = bw.keys.get(c,"")
    if k0 != key_single or k1 != key_joined or k2 != key_single:
        _fail("Builder stroke / UNDO did not join and restore the garage (%s / %s / %s)" % [k0,k1,k2])
        return
    builder.queue_free()
    await process_frame
    # 2) Determinism + builder path == race path.
    var lg: NitroTrackGrid = GRID.new(8,12)
    lg.generate(4242,24)
    var w1: NitroProceduralWorld = WORLD.new()
    var w2: NitroProceduralWorld = WORLD.new()
    root.add_child(w1)
    root.add_child(w2)
    w1.generate(lg.links,8,12,SEED)
    w2.generate(lg.links,8,12,SEED)
    if _placements_sig(w1) != _placements_sig(w2):
        _fail("Same tiles + seed gave different worlds")
        return
    var data: Dictionary = lg.to_track_data("QA World","qa_world")
    data["world"] = w1.descriptor()
    var f := FileAccess.open("user://nitro_track_qa_world.json",FileAccess.WRITE)
    f.store_string(JSON.stringify(data,"  ",false,true))
    f.close()
    var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://nitro_track_qa_world.json"))
    var rg = TRACK.world_grid(raw)
    if rg == null:
        _fail("Saved world track not recognised by the race")
        return
    var w3: NitroProceduralWorld = WORLD.new()
    root.add_child(w3)
    w3.generate(rg.links,rg.cols,rg.rows,int(raw["world"]["seed"]))
    if _placements_sig(w3) != _placements_sig(w1):
        _fail("Race world differs from the builder world")
        return
    var other: NitroProceduralWorld = WORLD.new()
    root.add_child(other)
    other.generate(lg.links,8,12,SEED+1)
    if _placements_sig(other) == _placements_sig(w1):
        _fail("A different seed should give a different world")
        return
    # Track DNA untouched by the world block.
    var plain: Dictionary = lg.to_track_data("QA World","qa_world")
    if plain["control_points"] != data["control_points"] or not bool(DNA.compile(data)["ok"]):
        _fail("World block changed the road")
        return
    # A reshaped road (node editor) must not keep the tile world.
    var reshaped: Dictionary = raw.duplicate(true)
    reshaped["control_points"][3] = [float(reshaped["control_points"][3][0])+4.0,float(reshaped["control_points"][3][1])]
    if TRACK.world_grid(reshaped) != null:
        _fail("A road that no longer matches its tiles kept the tile world")
        return
    # Race scene builds it (no roadside props of its own).
    ProjectSettings.set_setting("nitro/selected_track","user://nitro_track_qa_world.json")
    var race: Node3D = (load("res://scenes/race.tscn") as PackedScene).instantiate()
    root.add_child(race)
    await process_frame
    var tr = race.get("track")
    if tr.world == null or tr.with_props or _placements_sig(tr.world) != _placements_sig(w1):
        _fail("Race did not build the identical world")
        return
    race.queue_free()
    await process_frame
    # 3) Safety against the compiled road, many circuits.
    var worst: float = INF
    var counted: Dictionary = {"building":0,"fence":0,"tree":0}
    for s in range(12):
        var sg: NitroTrackGrid = GRID.new(8,12)
        if not sg.generate(9000+s*37,22+s%7):
            continue
        var comp: Dictionary = DNA.compile(sg.to_track_data("s","s"))
        if not bool(comp["ok"]):
            continue
        var sw: NitroProceduralWorld = WORLD.new()
        root.add_child(sw)
        sw.generate(sg.links,8,12,SEED+s)
        var items: Array = sw.placements()
        var need: Dictionary = {"building":6.0,"fence":4.6,"tree":2.9}
        var buildings: Array = []
        var bcells: Array = []
        var trees: Array = []
        for it in items:
            counted[it["kind"]] = int(counted[it["kind"]])+1
            var fp: PackedVector2Array = it["footprint"]
            var clear: float = _min_clearance(comp,fp)
            worst = minf(worst,clear-float(need[it["kind"]]))
            if clear < float(need[it["kind"]]):
                _fail("%s at %s only %.2f m from the race road (needs %.1f)" % [it["kind"],str(it["cell"]),clear,float(need[it["kind"]])])
                return
            if str(it["kind"]) == "building":
                buildings.append(fp)
                bcells.append(str(it["cell"])+" "+str(it["id"]))
            elif str(it["kind"]) == "tree":
                trees.append(fp)
        for i in range(buildings.size()):
            for j in range(i+1,buildings.size()):
                if _overlap(buildings[i],buildings[j]) > 0.6:
                    _fail("Two buildings overlap: %s / %s (%.1f m2)" % [bcells[i],bcells[j],_overlap(buildings[i],buildings[j])])
                    return
            for t in trees:
                if _overlap(buildings[i],t) > 0.05:
                    _fail("A tree stands inside a building")
                    return
        sw.queue_free()
    # 4) Incremental update keeps untouched chunks.
    var iw: NitroProceduralWorld = WORLD.new()
    root.add_child(iw)
    iw.generate(lg.links,8,12,SEED)
    var nodes_before: Dictionary = iw.chunk_nodes.duplicate()
    var edit: Vector2i = lg.links.keys()[0]
    var ig: NitroTrackGrid = GRID.new(8,12)
    ig.restore(lg.snapshot())
    ig.erase(edit)
    var ist: Dictionary = iw.update(ig.links)
    var kept: int = 0
    for k in nodes_before.keys():
        if iw.chunk_nodes.get(k) == nodes_before[k]:
            kept += 1
    if int(ist["rebuilt_chunks"]) > 6 or kept < nodes_before.size()-int(ist["rebuilt_chunks"]):
        _fail("Incremental update rebuilt too much: "+str(ist)+" kept %d/%d" % [kept,nodes_before.size()])
        return
    var full_ms: float = float(w1.last_stats["ms"])
    print("WORLD full build %.0f ms, one-tile edit %.0f ms (%d cells re-planned, %d of %d chunks rebuilt), %s" % [
        full_ms,float(ist["ms"]),int(ist["planned_cells"]),int(ist["rebuilt_chunks"]),nodes_before.size(),str(w1.mesh_stats())])
    print("WORLD safety margin over the setbacks: %.2f m (min), items checked %s" % [worst,str(counted)])
    print("PASS: garage joins into a 2x1 workshop when the road grows and splits back when it shrinks (builder UNDO too), deterministic seed, builder world == race world, never on or near the race road, no overlaps, incremental chunk rebuilds, Track DNA unchanged")
    print("NOT RUN: Android / Web frame rate with the world (device)")
    quit(0)

func _ids(w: NitroProceduralWorld) -> Array:
    var out: Array = []
    for it in w.placements():
        out.append(str(it["id"])+str(it["cell"]))
    return out

func _placements_sig(w: NitroProceduralWorld) -> Array:
    var out: Array = []
    for it in w.placements():
        var fp: PackedVector2Array = it["footprint"]
        out.append([str(it["id"]),str(it["cell"]),str(fp)])
    return out

## Smallest clearance of a footprint (vertices + edge midpoints) from the
## compiled race road edge.
func _min_clearance(comp: Dictionary, fp: PackedVector2Array) -> float:
    var cl: Array = comp["centerline"]
    var hw: PackedFloat32Array = comp["halfwidths"]
    var pts: Array = []
    for i in range(fp.size()):
        pts.append(fp[i])
        pts.append((fp[i]+fp[(i+1)%fp.size()])*0.5)
    var best: float = INF
    var n: int = cl.size()
    for p in pts:
        for i in range(n):
            var a: Vector2 = cl[i]
            var b: Vector2 = cl[(i+1)%n]
            var ab: Vector2 = b-a
            var t: float = clampf((Vector2(p)-a).dot(ab)/maxf(ab.length_squared(),0.000001),0.0,1.0)
            best = minf(best,Vector2(p).distance_to(a+ab*t)-lerpf(hw[i],hw[(i+1)%n],t))
    # A footprint enclosing the road would have every point "outside" it:
    # also reject any road sample inside the footprint.
    for i in range(0,n,3):
        if Geometry2D.is_point_in_polygon(cl[i],fp):
            return -1.0
    return best

func _overlap(a: PackedVector2Array, b: PackedVector2Array) -> float:
    var area: float = 0.0
    for poly in Geometry2D.intersect_polygons(a,b):
        var s: float = 0.0
        for i in range(poly.size()):
            s += poly[i].cross(poly[(i+1)%poly.size()])
        area += absf(s)*0.5
    return area
