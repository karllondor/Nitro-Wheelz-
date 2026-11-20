extends SceneTree
## v0.1.25 terrain adaptation + scenery zoning + compatibility:
##  * local edits: terrain farther than bench + influence from the road is
##    never touched; removing the road restores the generated terrain;
##    chunks without road nearby are never rebuilt;
##  * safety exclusion: no tree / rock / hedge inside verge + barrier strip +
##    run-off of the road; ONE venue next to the start, sized by event mode
##    (practice < club < pro), on every archetype;
##  * Track DNA broad-phase validator == the former O(n^2) scan (same first
##    error) on shipped, generated, terrain and deliberately broken tracks;
##  * legacy flat tracks load flat (no heights, no terrain); a terrain track
##    whose knot heights do not match its points gets heights solved again.
const CAT = preload("res://scripts/world/terrain/terrain_catalog.gd")
const FIELD = preload("res://scripts/world/terrain/terrain_field.gd")
const TT = preload("res://scripts/world/terrain/terrain_track.gd")
const PROFILE = preload("res://scripts/world/terrain/road_profile.gd")
const WORLD = preload("res://scripts/world/terrain/terrain_world.gd")
const SCEN = preload("res://scripts/world/terrain/terrain_scenery.gd")
const DNA = preload("res://scripts/world/track_dna.gd")
const GRID = preload("res://scripts/world/track_grid.gd")
const TRACK = preload("res://scripts/world/drift_track.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(msg: String) -> void:
    print("FAIL: "+msg)
    quit(1)

func _world(a: String, seed_value: int, mode: String = "club") -> NitroTerrainWorld:
    var w := WORLD.new()
    w.with_lighting = false
    w.setup(CAT.descriptor(a,seed_value,-1,mode))
    w.field.bake()
    root.add_child(w)
    w.build()
    return w

var city_mix: String = ""
var roadside: PackedStringArray = []

func _run() -> void:
    var t0: int = Time.get_ticks_msec()
    # --- locality of road adaptation
    var w: NitroTerrainWorld = _world("jp_touge",2)
    var grid: NitroTrackGrid = TT.new_grid()
    var gen: Dictionary = TT.generate_loop(grid,w.field,w.descriptor(),5,18)
    if not bool(gen.get("ok",false)):
        _fail("Touge loop generation failed")
        return
    var comp: Dictionary = gen["eval"]["compiled"]
    var res: Dictionary = w.set_road(comp["centerline"],comp["halfwidths"],comp["heights"],true)
    var cc: Vector2i = w.chunk_counts()
    if (res["dirty"] as Array).size() >= cc.x*cc.y:
        _fail("A road must not rebuild every terrain chunk")
        return
    var samples: Array = comp["centerline"]
    var reach: float = 12.0+WORLD.BENCH_M+WORLD.INFLUENCE_M+1.0
    var touched_far: int = 0
    var changed: int = 0
    for j in range(0,w.field.nz,2):
        for i in range(0,w.field.nx,2):
            var k: int = j*w.field.nx+i
            if w.field.height[k] == w.field.base[k]:
                continue
            changed += 1
            var p := Vector2(-FIELD.HALF_X+float(i)*FIELD.STEP,-FIELD.HALF_Z+float(j)*FIELD.STEP)
            var near: bool = false
            for s in range(0,samples.size(),3):
                if p.distance_to(samples[s]) < reach+8.0:
                    near = true
                    break
            if not near:
                touched_far += 1
    if touched_far > 0 or changed == 0:
        _fail("Terrain changed far from the road (%d vertices) / not at all (%d)" % [touched_far,changed])
        return
    var span: float = float(WORLD.CHUNK_CELLS)*FIELD.STEP
    for id in res["dirty"]:
        var lo := Vector2(-FIELD.HALF_X+float(id.x)*span,-FIELD.HALF_Z+float(id.y)*span)
        var rect := Rect2(lo,Vector2(span,span)).grow(reach+8.0)
        var any: bool = false
        for s2 in samples:
            if rect.has_point(s2):
                any = true
                break
        if not any:
            _fail("Chunk %s rebuilt with no road nearby" % [id])
            return
    var counts: Dictionary = w.structure_counts()
    if float(counts.get("cut_wall_m",0.0))+float(counts.get("fill_wall_m",0.0))+float(counts.get("bridge_m",0.0)) <= 0.0:
        _fail("A mountain-pass loop needs retaining walls or bridges (%s)" % [counts])
        return
    # Safety exclusion on the touge world.
    var clear: float = w.scenery.min_item_clearance()
    var need: float = PROFILE.VERGE+PROFILE.MARGIN+SCEN.SAFETY_M
    if clear < need-0.01:
        _fail("Scenery inside the safety strip (%.2f m < %.2f m)" % [clear,need])
        return
    # Removing the road restores the generated terrain exactly.
    w.set_road([] as Array[Vector2],PackedFloat32Array(),PackedFloat32Array(),false)
    if w.field.height != w.field.base:
        _fail("Clearing the road must restore the generated terrain")
        return
    w.queue_free()
    # --- one venue per world, sized by event mode, on every archetype
    var venue_sizes: PackedStringArray = []
    for a in CAT.ORDER:
        var wa: NitroTerrainWorld = _world(a,1)
        var ga: NitroTrackGrid = TT.new_grid()
        var ra: Dictionary = TT.generate_loop(ga,wa.field,wa.descriptor(),7)
        var ca: Dictionary = ra["eval"]["compiled"]
        wa.set_road(ca["centerline"],ca["halfwidths"],ca["heights"],true)
        var verts: Array[int] = []
        for mode in ["practice","club","pro"]:
            wa.desc["event_mode"] = mode
            wa.scenery._build_venue()
            var vi: Dictionary = wa.scenery.venue_info
            if vi.get("pad",null) == null:
                _fail("%s (%s): no room for the venue next to the start" % [a,mode])
                return
            if wa.scenery.venue_node.get_child_count() != 1:
                _fail("%s: exactly one venue expected" % a)
                return
            var mi: MeshInstance3D = wa.scenery.venue_node.get_child(0)
            var nv: int = 0
            for si in range(mi.mesh.get_surface_count()):
                nv += (mi.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
            verts.append(nv)
            for q in (vi.get("corners",[]) as Array)+(vi.get("grandstand_corners",[]) as Array):
                if wa.scenery.road_clearance(Vector2(float(q[0]),float(q[1]))) < PROFILE.VERGE+PROFILE.MARGIN-0.5:
                    _fail("%s (%s): venue footprint on the road strip" % [a,mode])
                    return
        if not (verts[0] < verts[1] and verts[1] <= verts[2]):
            _fail("%s: practice < club <= pro venue expected (%s)" % [a,verts])
            return
        var cl: float = wa.scenery.min_item_clearance()
        if cl < need-0.01:
            _fail("%s: scenery inside the safety strip (%.2f m)" % [a,cl])
            return
        if a == "jp_city":
            if int(wa.scenery.summary()["counts"].get("City blocks",0)) == 0:
                _fail("City track needs city blocks")
                return
            # v0.1.27: varied districts, not one repeated block type.
            var ck: Dictionary = wa.scenery.summary()["city"]
            var kinds: int = 0
            for kk in ["tower","offices","department","core","mid","outer","park","park_shrine","plaza"]:
                if int(ck.get(kk,0)) > 0:
                    kinds += 1
            if kinds < 4:
                _fail("City needs at least 4 kinds of blocks (%s)" % [ck])
                return
            city_mix = str(ck)
        else:
            # v0.1.27 roadside planting: present, and only behind the barrier.
            var rs: Array = wa.scenery.min_roadside_clearance()
            if int(rs[1]) == 0:
                _fail("%s: roadside planting expected beside the road" % a)
                return
            if float(rs[0]) < PROFILE.VERGE+SCEN.ROADSIDE_MIN_M-0.01:
                _fail("%s: roadside planting %.2f m from the road edge (inside the verge)" % [a,float(rs[0])])
                return
            roadside.append("%s %d" % [str(CAT.info(a)["short"]),int(rs[1])])
        if str(CAT.info(a)["country"]) == "ireland" and int(wa.scenery.venue_info.get("stone_walls",0)) == 0:
            _fail("%s: Irish roads need dry-stone walls" % a)
            return
        venue_sizes.append("%s %d/%d/%d" % [str(CAT.info(a)["short"]),verts[0],verts[1],verts[2]])
        wa.queue_free()
    # --- Track DNA broad phase == full scan
    var cases: Array = []
    for f in ["benchmark_oval","benchmark_sweepers","shin_kawa_full_circuit","shin_kawa_v2"]:
        var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tracks/%s.json" % f))
        cases.append(raw)
    for sd in range(1,13):
        var g := GRID.new(9,14)
        if g.generate(sd*7919,20+sd%9):
            cases.append(g.to_track_data("gen","gen"))
    var broken: Array = []
    for raw2 in cases.duplicate():
        var pts: Array = (raw2["control_points"] as Array).duplicate(true)
        var n: int = pts.size()
        # pull one knot onto another part of the loop -> overlap / crossing
        pts[n/2] = [float(pts[0][0])+3.0,float(pts[0][1])+2.0]
        var bad: Dictionary = raw2.duplicate(true)
        bad["control_points"] = pts
        broken.append(bad)
    cases.append_array(broken)
    var compared: int = 0
    var invalid: int = 0
    for data in cases:
        var widths := PackedFloat32Array()
        var points: Array[Vector2] = []
        for p2 in data["control_points"]:
            points.append(Vector2(float(p2[0]),float(p2[1])))
            widths.append(float(data.get("width_m",24.0)))
        var curve: Dictionary = DNA.sample_curve(points,widths)
        var fast: PackedStringArray = DNA.validate_geometry(curve["centerline"],curve["left_edge"],curve["right_edge"],curve["halfwidths"],true)
        var slow: PackedStringArray = _slow_validate(curve["centerline"],curve["left_edge"],curve["right_edge"],curve["halfwidths"])
        if fast != slow:
            _fail("Broad phase differs from the full scan: %s vs %s" % [fast,slow])
            return
        compared += 1
        if not fast.is_empty():
            invalid += 1
    if invalid == 0:
        _fail("Equivalence check needs invalid tracks too")
        return
    # --- legacy + migration
    for f2 in ["benchmark_oval","shin_kawa_v2"]:
        var tr: NitroDriftTrack = TRACK.new()
        tr.track_data_path = "res://tracks/%s.json" % f2
        root.add_child(tr)
        if not tr.heights.is_empty() or tr.terrain != null or not tr.closed_loop or tr.start_index != 0:
            _fail("Legacy track %s must stay a flat closed loop" % f2)
            return
        tr.queue_free()
    var desc: Dictionary = CAT.descriptor("ie_hills",4)
    var fh: NitroTerrainField = FIELD.new("ie_hills",4)
    fh.bake()
    var gh: NitroTrackGrid = TT.new_grid()
    var rh: Dictionary = TT.generate_loop(gh,fh,desc,9)
    var data2: Dictionary = (rh["data"] as Dictionary).duplicate(true)
    data2.erase("elevation")
    var path: String = "user://nitro_track_qa_terrain_noelev.json"
    var file := FileAccess.open(path,FileAccess.WRITE)
    file.store_string(JSON.stringify(data2))
    file.close()
    var tm: NitroDriftTrack = TRACK.new()
    tm.track_data_path = path
    root.add_child(tm)
    if tm.terrain == null or tm.heights.size() != tm.centerline.size():
        _fail("Terrain track without knot heights must get solved heights on its terrain")
        return
    var expect: PackedFloat32Array = rh["eval"]["compiled"]["heights"]
    var worst: float = 0.0
    for i2 in range(tm.heights.size()):
        worst = maxf(worst,absf(tm.heights[i2]-expect[i2]))
    if worst > 0.5:
        _fail("Re-solved heights differ from the saved profile by %.2f m" % worst)
        return
    tm.queue_free()
    DirAccess.remove_absolute(path)
    print("PASS: terrain adaptation local only (%d terrain vertices changed, none beyond %.0f m of the road, %d of %d chunks rebuilt), road removal restores the terrain, walls/bridges on the pass, safety strip %.1f m kept on all 8 archetypes, one venue per world practice<club<=pro vertices (%s), city blocks (%s), roadside planting behind the barrier (%s), Irish stone walls, DNA broad phase == full scan on %d tracks (%d invalid), legacy flat tracks stay flat, missing knot heights re-solved (max %.2f m) - %.1f s" % [
        changed,reach,(res["dirty"] as Array).size(),cc.x*cc.y,need,", ".join(venue_sizes),city_mix,", ".join(roadside),compared,invalid,worst,
        float(Time.get_ticks_msec()-t0)/1000.0])
    quit(0)

## The v0.1.24 closed-loop validator, verbatim O(n^2) reference.
func _slow_validate(center: Array[Vector2],left: Array[Vector2],right: Array[Vector2],halfwidths: PackedFloat32Array) -> PackedStringArray:
    var errors := PackedStringArray()
    var n: int = center.size()
    if n < 8 or left.size()!=n or right.size()!=n or halfwidths.size()!=n:
        errors.append("Invalid sample array dimensions")
        return errors
    for i in range(n):
        var next_i: int = (i+1)%n
        if center[i].distance_to(center[next_i]) < DNA.MIN_SEGMENT_M:
            errors.append("Zero-length edge at %d" % i)
            return errors
        var a: Vector2 = center[(i-2+n)%n]
        var b: Vector2 = center[i]
        var c: Vector2 = center[(i+2)%n]
        var cross: float = absf((b-a).cross(c-a))
        if cross > 0.00001:
            var radius: float = a.distance_to(b)*b.distance_to(c)*c.distance_to(a)/(2.0*cross)
            if radius < maxf(DNA.MIN_RADIUS_M,halfwidths[i]+2.0):
                errors.append("Curve radius %.1f m too small at sample %d" % [radius,i])
                return errors
    for ring in [center,left,right]:
        for i in range(n):
            var a2: Vector2 = ring[i]
            var b2: Vector2 = ring[(i+1)%n]
            for j in range(i+2,n):
                if i==0 and j==n-1:
                    continue
                if Geometry2D.segment_intersects_segment(a2,b2,ring[j],ring[(j+1)%n]) != null:
                    errors.append("Self-intersecting road / wall ring at segments %d and %d" % [i,j])
                    return errors
    var progress := PackedFloat32Array()
    var perimeter: float = 0.0
    for k in range(n):
        progress.append(perimeter)
        perimeter += center[k].distance_to(center[(k+1)%n])
    for i in range(n):
        var a3: Vector2 = center[i]
        var b3: Vector2 = center[(i+1)%n]
        for j in range(i+2,n):
            var along: float = progress[j]-progress[i]
            if minf(along,perimeter-along) <= DNA.LOCAL_ARC_NEIGHBOURHOOD_M:
                continue
            var clearance: float = DNA._segment_distance(a3,b3,center[j],center[(j+1)%n])
            var safe: float = halfwidths[i]+halfwidths[j]+DNA.MIN_CLEARANCE_M
            if clearance < safe:
                errors.append("Road corridors overlap near samples %d/%d (%.1fm vs %.1fm)" % [i,j,clearance,safe])
                return errors
    return errors
