extends SceneTree
## Issue #18 (v0.1.33 phone capture 1000077052.jpg): the minimap of an OPEN
## (point-to-point) route drew a false straight segment from the finish back to
## the start, and the dot's arc length wrapped the same way.
##  * unit: an open outline never closes (last point != first point, ends exactly
##    on the last real point), progress is clamped to 0..1 (1.0 = last real
##    point, never the first), every progress value lies on the REAL polyline
##    (no point on the made-up last -> first chord), START != FINISH markers;
##    a circuit keeps the legacy periodic behaviour (outline closed, progress
##    wraps, bit-identical to the old formula);
##  * the cached outline rebuilds when the topology / points change;
##  * a real generated open route (Irish hills, seed 2): the race gives the HUD
##    closed_loop = false and the start / finish fractions of the track; the dot
##    placed from the race's own progress sits on the road at every sample, the
##    FINISH marker sits on the finish line and the START marker on the start;
##  * a real closed circuit keeps closed_loop = true.
const CAT = preload("res://scripts/world/terrain/terrain_catalog.gd")
const FIELD = preload("res://scripts/world/terrain/terrain_field.gd")
const TT = preload("res://scripts/world/terrain/terrain_track.gd")
const HUD = preload("res://scripts/ui/race_hud.gd")
const RACE = preload("res://scenes/race.tscn")
const ROUTE_PATH: String = "user://nitro_track_qa_minimap_route.json"
const RECT: Rect2 = Rect2(0,0,300,100)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var err: String = _unit()
    if err.is_empty():
        err = await _integration()
    DirAccess.remove_absolute(ROUTE_PATH)
    if not err.is_empty():
        printerr("FAIL: "+err)
        quit(1)
        return
    print("PASS: open-route minimap - no closing segment (outline ends on the last real point), progress clamped 0..1 and always on the real polyline, distinct START / FINISH markers, outline cache rebuilds on topology change; circuits keep their periodic behaviour; a real generated route and a real circuit feed the HUD the right topology and the dot follows the road")
    for _f in range(3):
        await process_frame
    quit(0)

# A wiggly arch whose end is far from its start with nothing in between: a
# closing chord would cut straight across the empty middle of the map (exactly
# the diagonal on the phone).
func _zigzag(n: int) -> PackedVector2Array:
    var pts := PackedVector2Array()
    for i in range(n):
        var t: float = PI*float(i)/float(n-1)
        pts.append(Vector2(200.0-200.0*cos(t),100.0*sin(t)+8.0*sin(t*9.0)))
    return pts

func _circle(n: int) -> PackedVector2Array:
    var pts := PackedVector2Array()
    for i in range(n):
        var a: float = TAU*float(i)/float(n)
        pts.append(Vector2(cos(a)*150.0,sin(a)*100.0))
    return pts

func _dist_to_polyline(p: Vector2, pts: PackedVector2Array, closed: bool) -> float:
    var best: float = INF
    var segs: int = pts.size() if closed else pts.size()-1
    for i in range(segs):
        var a: Vector2 = pts[i]
        var b: Vector2 = pts[(i+1)%pts.size()]
        best = minf(best,p.distance_to(Geometry2D.get_closest_point_to_segment(p,a,b)))
    return best

func _unit() -> String:
    var hud: NitroRaceHUD = HUD.new()
    # ----- open route
    var pts: PackedVector2Array = _zigzag(300)
    hud.track_points = pts
    hud.closed_loop = false
    hud._rebuild_outline(RECT)
    var cache: PackedVector2Array = hud._outline_cache
    var first_px: Vector2 = hud._map_point(pts[0],RECT)
    var last_px: Vector2 = hud._map_point(pts[pts.size()-1],RECT)
    if cache[0].distance_to(first_px) > 0.01 or cache[cache.size()-1].distance_to(last_px) > 0.01:
        return "Open outline must run from the first to the LAST real point (ends %s / %s, wanted %s / %s)" % [cache[0],cache[cache.size()-1],first_px,last_px]
    if cache[0].distance_to(cache[cache.size()-1]) < 20.0:
        return "Open outline must not close on itself (first and last point %.1f px apart)" % cache[0].distance_to(cache[cache.size()-1])
    # Odd point count: the sampling step skips the real last point; the outline must still end on it.
    var odd: PackedVector2Array = _zigzag(307)
    hud.track_points = odd
    hud._rebuild_outline(RECT)
    if hud._outline_cache[hud._outline_cache.size()-1].distance_to(hud._map_point(odd[odd.size()-1],RECT)) > 0.01:
        return "Open outline must end on the last real point also when the sampling step skips it"
    hud.track_points = pts
    hud._rebuild_outline(RECT)
    # Progress: ends and clamping.
    if hud.point_at_progress(0.0).distance_to(pts[0]) > 0.001 or hud.point_at_progress(-0.3).distance_to(pts[0]) > 0.001:
        return "Open progress 0 (and below) must be the first point"
    if hud.point_at_progress(1.0).distance_to(pts[pts.size()-1]) > 0.001 or hud.point_at_progress(1.7).distance_to(pts[pts.size()-1]) > 0.001:
        return "Open progress 1 (and above) must stay on the LAST real point, not wrap to the start (got %s)" % hud.point_at_progress(1.0)
    # Arc length without the closing chord.
    var total: float = 0.0
    for i in range(pts.size()-1):
        total += pts[i].distance_to(pts[i+1])
    var run: float = 0.0
    var want: Vector2 = pts[pts.size()-1]
    for i2 in range(pts.size()-1):
        var seg: float = pts[i2].distance_to(pts[i2+1])
        if run+seg >= total*0.5:
            want = pts[i2].lerp(pts[i2+1],(total*0.5-run)/seg)
            break
        run += seg
    if hud.point_at_progress(0.5).distance_to(want) > 0.01:
        return "Open progress 0.5 must be half of the REAL arc length (got %s, wanted %s)" % [hud.point_at_progress(0.5),want]
    # Every progress value lies on the real polyline; the old code put the last
    # 'segment' of the arc on the chord from the finish to the start.
    var worst: float = 0.0
    for k in range(0,1001):
        worst = maxf(worst,_dist_to_polyline(hud.point_at_progress(float(k)/1000.0),pts,false))
    if worst > 0.01:
        return "A progress value left the real route by %.2f m (false closing segment)" % worst
    # Markers: distinct places.
    hud.start_progress = 0.04
    hud.finish_progress = 0.93
    if hud.point_at_progress(hud.start_progress).distance_to(hud.point_at_progress(hud.finish_progress)) < 50.0:
        return "START and FINISH must be two different places on an open route"
    # Control (the v0.1.33 behaviour): the same points treated as a circuit put
    # the last stretch of the arc on the chord from the finish back to the
    # start; the checks above must be able to see exactly that.
    var old: NitroRaceHUD = HUD.new()
    old.track_points = pts
    old.closed_loop = true
    old._rebuild_outline(RECT)
    if old._outline_cache[0].distance_to(old._outline_cache[old._outline_cache.size()-1]) > 0.001:
        return "Control: a closed outline must join its end to the start (the old diagonal)"
    var worst_old: float = 0.0
    for k3 in range(0,1001):
        worst_old = maxf(worst_old,_dist_to_polyline(old.point_at_progress(float(k3)/1000.0),pts,false))
    if worst_old < 20.0:
        return "Control: the old wrap would leave the route by far more than %.1f m; the open-route check is blind" % worst_old
    old.free()
    # ----- cache invalidation: same rect, changed topology / points
    var sig_open: Array = hud._signature()
    if hud._outline_sig != sig_open:
        return "The outline cache must remember what it was built from"
    hud.closed_loop = true
    if hud._signature() == hud._outline_sig:
        return "Switching topology must invalidate the cached outline"
    hud.closed_loop = false
    hud.track_points = _zigzag(120)
    if hud._signature() == hud._outline_sig:
        return "A different track must invalidate the cached outline"
    # ----- circuit: legacy periodic behaviour stays
    var ring: PackedVector2Array = _circle(240)
    var c: NitroRaceHUD = HUD.new()
    c.track_points = ring
    c.closed_loop = true
    c._rebuild_outline(RECT)
    if c._outline_cache[0].distance_to(c._outline_cache[c._outline_cache.size()-1]) > 0.001:
        return "A circuit outline must stay closed"
    var n: int = ring.size()
    var cum := PackedFloat32Array([0.0])
    for i3 in range(n):
        cum.append(cum[i3]+ring[i3].distance_to(ring[(i3+1)%n]))
    for k2 in range(0,1001,7):
        var f: float = float(k2)/1000.0
        var t: float = fposmod(f,1.0)*cum[n]
        var i4: int = clampi(cum.bsearch(t)-1,0,n-1)
        var legacy: Vector2 = ring[i4].lerp(ring[(i4+1)%n],clampf((t-cum[i4])/maxf(cum[i4+1]-cum[i4],0.0001),0.0,1.0))
        if c.point_at_progress(f).distance_to(legacy) > 0.001:
            return "Circuit progress changed from the legacy periodic formula at %.3f" % f
    if _dist_to_polyline(c.point_at_progress(0.9995),ring,true) > 0.01:
        return "Circuit progress near the lap line must stay on the closing segment of the circuit"
    hud.free()
    c.free()
    return ""

func _write(path: String, data: Dictionary) -> void:
    var f := FileAccess.open(path,FileAccess.WRITE)
    f.store_string(JSON.stringify(data))
    f.close()

func _race(path: String) -> Node3D:
    ProjectSettings.set_setting("nitro/selected_track",path)
    var race: Node3D = RACE.instantiate()
    race.set_physics_process(false)
    race.set_process(false)
    root.add_child(race)
    return race

func _integration() -> String:
    var hdesc: Dictionary = CAT.descriptor("ie_hills",2)
    var hf: NitroTerrainField = FIELD.new("ie_hills",2)
    hf.bake()
    var rgrid: NitroTrackGrid = TT.new_grid()
    var route: Dictionary = TT.generate_route(rgrid,hf,hdesc,5)
    if not bool(route.get("ok",false)):
        return "Open route generation failed"
    _write(ROUTE_PATH,route["data"])
    var rr: Node3D = _race(ROUTE_PATH)
    var hud: NitroRaceHUD = rr.hud
    var tr: NitroDriftTrack = rr.track
    if tr.closed_loop or hud.closed_loop:
        return "The HUD of an open route must not be closed (track %s, hud %s)" % [tr.closed_loop,hud.closed_loop]
    if absf(hud.finish_progress-tr.finish_progress) > 1e-5:
        return "HUD finish fraction must equal the track's (%.5f vs %.5f)" % [hud.finish_progress,tr.finish_progress]
    var want_start: float = float(tr.arc_lengths[tr.start_index])/maxf(tr.length_metres,1.0)
    if absf(hud.start_progress-want_start) > 1e-5 or hud.start_progress <= 0.0:
        return "HUD start fraction must be the start line's (%.5f vs %.5f)" % [hud.start_progress,want_start]
    # The dot is placed from the race's own progress of the car: along the whole
    # road it must sit exactly where the car is (no wrap, no chord).
    var worst: float = 0.0
    var count: int = tr.centerline.size()
    for i in range(0,count,maxi(1,count/60)):
        var pos: Vector2 = tr.centerline[i]
        var prog: float = float(tr.sample_info(pos)["progress"])
        worst = maxf(worst,hud.point_at_progress(prog).distance_to(pos))
    var tail: Vector2 = tr.centerline[count-1]
    worst = maxf(worst,hud.point_at_progress(float(tr.sample_info(tail)["progress"])).distance_to(tail))
    if worst > 0.5:
        return "Minimap dot drifts %.2f m off the road on an open route" % worst
    if hud.point_at_progress(hud.finish_progress).distance_to(tr.centerline[tr.finish_index]) > 0.5:
        return "FINISH marker must sit on the finish line"
    if hud.point_at_progress(hud.start_progress).distance_to(tr.start_position()) > 0.5:
        return "START marker must sit on the start line"
    if hud.point_at_progress(1.0).distance_to(tail) > 0.5:
        return "Progress 1.0 must be the end of the route, not its start"
    root.remove_child(rr)
    rr.free()
    # A real circuit stays closed.
    var rc: Node3D = _race("res://tracks/shin_kawa_v2.json")
    var ok: bool = rc.hud.closed_loop and rc.track.closed_loop
    root.remove_child(rc)
    rc.free()
    if not ok:
        return "A circuit must keep closed_loop = true in the HUD"
    return ""
