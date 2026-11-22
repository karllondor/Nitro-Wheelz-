extends SceneTree
## v0.1.36 (owner request 2026-11-22, driftit.app comparison): visual details that
## cost little and give scale and speed.
##  * barrier advertising band: one mesh on the inner face of both walls, outside
##    the road, between 0.4 and 1.1 m, writing never mirrored (u runs with the
##    driving direction on the left wall and against it on the right wall);
##  * NITRO WHEELZ road inscription: only on straights >= 45 m and away from the
##    start line, inside the painted edge lines, lying on the asphalt;
##  * builder previews (build_from_samples) stay free of decoration;
##  * tyre marks: shader with soft edges (UV across, vertex alpha) instead of the
##    hard dark quads; thinner than before;
##  * lighter asphalt, smaller and fainter cloud shadows.
const TRACK = preload("res://scripts/world/drift_track.gd")
const RACE = preload("res://scenes/race.tscn")

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    printerr("FAIL: "+message)
    quit(1)

func _find(parent: Node, prefix: String) -> Array:
    var out: Array = []
    for c in parent.get_children():
        if str(c.name).begins_with(prefix):
            out.append(c)
    return out

func _shader_default(code: String, name: String) -> float:
    var re := RegEx.new()
    re.compile("uniform\\s+float\\s+"+name+"[^=]*=\\s*([0-9.]+)\\s*;")
    var m: RegExMatch = re.search(code)
    return float(m.get_string(1)) if m != null else -1.0

func _run() -> void:
    # ---------------------------------------------------------------- oval
    var oval: NitroDriftTrack = TRACK.new()
    oval.track_data_path = "res://tracks/benchmark_oval.json"
    root.add_child(oval)
    oval.build()
    if not oval.track_valid:
        _fail("the benchmark oval did not build")
        return
    var bands: Array = _find(oval,"Barrier advertising band")
    if bands.size() != 1:
        _fail("expected exactly one barrier advertising band, found %d" % bands.size())
        return
    var band: MeshInstance3D = bands[0]
    var arr: Array = band.mesh.surface_get_arrays(0)
    var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
    var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
    var segs: int = oval.centerline.size()
    if verts.size() != 12*segs:
        _fail("band vertex count %d, expected %d (6 per segment and wall)" % [verts.size(),12*segs])
        return
    if not (uvs[1].x > uvs[0].x) or not (uvs[6*segs+1].x < uvs[6*segs].x):
        _fail("the writing would be mirrored on one of the walls")
        return
    var lo: float = INF
    var hi: float = -INF
    for k in range(0,verts.size(),7):
        var v: Vector3 = verts[k]
        lo = minf(lo,v.y)
        hi = maxf(hi,v.y)
        var info: Dictionary = oval.sample_info(Vector2(v.x,v.z))
        if float(info["distance"]) < float(info["width"]):
            _fail("a board lies on the road, not on the wall")
            return
    if lo < 0.39 or hi > 1.11:
        _fail("band height %.2f .. %.2f outside the wall face" % [lo,hi])
        return
    var spots: Array = oval.road_logo_spots()
    if spots.size() != 1:
        _fail("the oval must get exactly one inscription (its long straight), got %d" % spots.size())
        return
    var spot: Dictionary = spots[0]
    var gap: float = minf(float(spot["arc"]),oval.length_metres-float(spot["arc"]))
    if gap < TRACK.LOGO_END_MARGIN_M or float(spot["run"]) < TRACK.LOGO_MIN_STRAIGHT_M:
        _fail("inscription too close to the start line or on a short straight")
        return
    var logos: Array = _find(oval,"NITRO WHEELZ road inscription")
    if logos.size() != 1:
        _fail("inscription mesh missing")
        return
    var lv: PackedVector3Array = (logos[0] as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
    for v2 in lv:
        var info2: Dictionary = oval.sample_info(Vector2(v2.x,v2.z))
        if float(info2["distance"]) > float(info2["width"])-TRACK.LINE_INSET-0.3:
            _fail("the inscription reaches the painted edge line / kerb")
            return
        if v2.y < 0.055 or v2.y > 0.075:
            _fail("the inscription does not lie on the asphalt (y=%.3f)" % v2.y)
            return
    # Sweepers: corners only, must not crash and must not paint a corner.
    var sweepers: NitroDriftTrack = TRACK.new()
    sweepers.track_data_path = "res://tracks/benchmark_sweepers.json"
    root.add_child(sweepers)
    sweepers.build()
    if not sweepers.road_logo_spots().is_empty():
        _fail("an inscription was placed on the corner-only sweepers")
        return
    # Full circuit: several straights, capped.
    var full: NitroDriftTrack = TRACK.new()
    full.track_data_path = "res://tracks/shin_kawa_full_circuit.json"
    root.add_child(full)
    full.build()
    var n_full: int = full.road_logo_spots().size()
    if n_full < 2 or n_full > TRACK.LOGO_MAX_COUNT:
        _fail("full circuit inscriptions %d, expected 2 .. %d" % [n_full,TRACK.LOGO_MAX_COUNT])
        return
    # Builder preview stays plain.
    var preview: NitroDriftTrack = TRACK.new()
    root.add_child(preview)
    var pts: Array[Vector2] = []
    for k in range(64):
        var a: float = TAU*float(k)/64.0
        pts.append(Vector2(cos(a)*60.0,sin(a)*40.0))
    preview.build_from_samples(pts,6.0,true)
    if not _find(preview,"Barrier advertising band").is_empty() or not _find(preview,"NITRO WHEELZ road inscription").is_empty():
        _fail("the quick builder preview must not carry race decoration")
        return
    # ------------------------------------------------------------ constants
    if TRACK.ASPHALT_TINT.r < 1.5:
        _fail("the asphalt is not lighter than the v0.1.35 tint (1.0)")
        return
    var cloud: Shader = load("res://assets/shaders/cloud_shadows.gdshader")
    var strength: float = _shader_default(cloud.code,"strength")
    var coverage: float = _shader_default(cloud.code,"coverage")
    var scale_m: float = _shader_default(cloud.code,"scale_m")
    if strength < 0.0 or strength > 0.32 or coverage < 0.52 or scale_m > 90.0 or scale_m < 20.0:
        _fail("cloud shadows too big / dark (strength %.2f coverage %.2f scale %.0f m)" % [strength,coverage,scale_m])
        return
    # ------------------------------------------------------------ tyre marks
    var race: Node3D = RACE.instantiate()
    root.add_child(race)
    await process_frame
    await process_frame
    if not (race.skid_material is ShaderMaterial):
        _fail("tyre marks must use the soft-edged shader")
        return
    race.skid_segments.append(PackedVector2Array([Vector2(0,0),Vector2(1.2,0)]))
    race.skid_segments.append(PackedVector2Array([Vector2(1.2,0),Vector2(2.4,0.2)]))
    race.skid_heights.append(0.0)
    race.skid_heights.append(0.0)
    race._refresh_skid_mesh()
    var sa: Array = race.skid_mesh.surface_get_arrays(0)
    var sv: PackedVector3Array = sa[Mesh.ARRAY_VERTEX]
    var su: PackedVector2Array = sa[Mesh.ARRAY_TEX_UV]
    var sc: PackedColorArray = sa[Mesh.ARRAY_COLOR]
    if sv.size() != 12 or su.size() != 12 or sc.size() != 12:
        _fail("tyre mark mesh lacks UV / colour (verts %d, uv %d, colours %d)" % [sv.size(),su.size(),sc.size()])
        return
    var width: float = absf(sv[2].z-sv[0].z)
    if width > 0.2*2.0+0.001 or width < 0.1:
        _fail("tyre mark width %.2f m outside 0.1 .. 0.4" % width)
        return
    if su[0].x != 0.0 or su[2].x != 1.0:
        _fail("tyre mark UV does not run across the mark")
        return
    for c in sc:
        if c.a < 0.5 or c.a > 1.0:
            _fail("tyre mark segment intensity %.2f outside 0.5 .. 1" % c.a)
            return
    var mark_strength: float = _shader_default(race.SKID_SHADER.code,"strength")
    if mark_strength < 0.2 or mark_strength > 0.45:
        _fail("tyre mark opacity %.2f not in the soft range 0.2 .. 0.45 (was 0.50 hard-edged)" % mark_strength)
        return
    print("PASS: track details - barrier advertising band on both walls (%d vertices, writing not mirrored), NITRO WHEELZ inscription only on long straights away from the start (oval 1, full circuit %d, sweepers 0) inside the edge lines, builder previews plain, lighter asphalt (tint %.2f), cloud shadows smaller / fainter (strength %.2f, %.0f m), soft thin tyre marks (opacity %.2f, width %.2f m)" % [verts.size(),n_full,TRACK.ASPHALT_TINT.r,strength,scale_m,mark_strength,width])
    quit(0)
