extends SceneTree
## v0.1.13 regression for the approved-reference art pass:
## die-cast car proportions, continuous kerb pattern, scenery clearance,
## HUD/touch rectangle agreement, HUD star projection and fonts.
const CAR = preload("res://scripts/vehicles/lada_lowpoly.gd")
const TRACK = preload("res://scripts/world/drift_track.gd")
const STYLE = preload("res://scripts/ui/hud_style.gd")
const HUD = preload("res://scripts/ui/race_hud.gd")
const TRACKS: Array[String] = ["res://tracks/shin_kawa_v2.json","res://tracks/benchmark_oval.json",
    "res://tracks/benchmark_sweepers.json","res://tracks/shin_kawa_full_circuit.json"]

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    # --- Car: smooth shader-painted shell at true VAZ-2106 proportions.
    for variant in ["red","white"]:
        var car: NitroLadaLowPoly = CAR.new()
        car.paint_variant = variant
        root.add_child(car)
        await process_frame
        var shell: MeshInstance3D = car.find_child("Diecast body shell",true,false) as MeshInstance3D
        if shell == null or shell.mesh == null:
            _fail("Die-cast body shell missing for "+variant)
            return
        if shell.mesh.get_surface_count() < 6:
            _fail("Shell should batch paint/glass/chrome/trim/lamps into material surfaces")
            return
        var paint: Material = shell.mesh.surface_get_material(0)
        if not (paint is ShaderMaterial):
            _fail("Body paint must use the die-cast paint shader")
            return
        var box: AABB = shell.mesh.get_aabb()
        if absf(box.size.z-CAR.BODY_LENGTH_M) > 0.04:
            _fail("Shell length %.3f diverges from 4.166 m" % box.size.z)
            return
        if box.size.x > CAR.DRIFT_BODY_WIDTH_M+0.03 or box.size.x < 1.80:
            _fail("Widebody width %.3f outside 1.80-1.94 m" % box.size.x)
            return
        if box.end.y < 1.30 or box.end.y > 1.50:
            _fail("Roof height %.3f m does not read as a lowered 2106 saloon" % box.end.y)
            return
        if bool(car.get("flat_body")) != (variant == "red"):
            _fail("Red sheet must be faceted low-poly, white sheet smooth")
            return
        if car.find_child("NW rear screen banner",true,false) != null:
            _fail("Owner asked to remove the NW rear-screen banner")
            return
        if car.find_child("Soft contact shadow",true,false) == null:
            _fail("Contact shadow missing")
            return
        for wheel in car.rolling_wheels:
            if wheel.get_child_count() == 0 or not (wheel.get_child(0) is MeshInstance3D):
                _fail("Wheel mesh missing")
                return
        car.queue_free()
        await process_frame

    # --- RYU-32 coupe (owner's blue reference sheet): true sheet proportions,
    # wing, open engine bay with ITB trumpets, four rolling wheels.
    var coupe: NitroCoupeLowPoly = load("res://scripts/vehicles/coupe_lowpoly.gd").new()
    root.add_child(coupe)
    await process_frame
    var cshell: MeshInstance3D = coupe.find_child("Diecast body shell",true,false) as MeshInstance3D
    if cshell == null or not (cshell.mesh.surface_get_material(0) is ShaderMaterial):
        _fail("Coupe die-cast shell missing")
        return
    var cbox: AABB = cshell.mesh.get_aabb()
    if absf(cbox.size.z-coupe.BODY_LENGTH_M) > 0.10 or cbox.end.y < 1.22 or cbox.end.y > 1.36:
        _fail("Coupe shell %.3f m long / %.3f m high diverges from 4.545 / 1.29" % [cbox.size.z,cbox.end.y])
        return
    for part in ["Fixed rear wing","Exposed V8 engine bay","Soft contact shadow"]:
        if coupe.find_child(part,true,false) == null:
            _fail("Coupe part missing: "+part)
            return
    if coupe.rolling_wheels.size() != 4 or absf(coupe.FRONT_AXLE_Z-coupe.REAR_AXLE_Z+2.615) > 0.001:
        _fail("Coupe wheelbase/wheels wrong")
        return
    var cat = load("res://scripts/vehicles/car_catalog.gd")
    var made: Node3D = cat.make("blue")
    var is_coupe: bool = (made is NitroGlbCar) if cat.factory_test_models() else (made is NitroCoupeLowPoly)
    made.free()
    if not is_coupe or cat.valid("nope") != "red":
        _fail("Car catalog must build the coupe for 'blue' and fall back to red")
        return
    coupe.queue_free()
    await process_frame

    # --- Track art: even kerb blocks (seamless loop) and clear scenery.
    for path in TRACKS:
        var t: NitroDriftTrack = TRACK.new()
        t.track_data_path = path
        root.add_child(t)
        await process_frame
        if not t.track_valid:
            _fail("Track failed to compile: "+path)
            return
        var blocks: int = maxi(2,int(round(t.length_metres/(t.KERB_BLOCK_M*2.0)))*2)
        var block_len: float = t.length_metres/float(blocks)
        if blocks%2 != 0 or block_len < 2.4 or block_len > 3.6:
            _fail("Kerb pattern would not close seamlessly on "+path)
            return
        var shadows: MeshInstance3D = t.find_child("Cloud shadows",true,false) as MeshInstance3D
        if shadows == null or not (shadows.material_override is ShaderMaterial):
            _fail("Drifting cloud shadows missing on "+path)
            return
        var env_node: WorldEnvironment = t.find_child("*",true,false) as WorldEnvironment
        for child in t.get_children():
            if child is WorldEnvironment:
                env_node = child
        if env_node == null or env_node.environment.background_mode != Environment.BG_SKY or env_node.environment.sky == null:
            _fail("Cloudy sky missing on "+path)
            return
        if t.find_child("Blue white kerbs",true,false) == null:
            _fail("Kerbs missing on "+path)
            return
        for label in ["Tree trunks","Verge blossom clusters","Cherry blossom voxels"]:
            if t.find_child(label,true,false) == null:
                _fail(label+" missing on "+path)
                return
        if t.tree_positions.size() < 10 or t.flower_positions.size() < 20:
            _fail("Too little scenery on "+path)
            return
        for p in t.tree_positions:
            if t.road_clearance(p) < 3.0:
                _fail("Tree placed within 3 m of a road edge on "+path)
                return
        for f in t.flower_positions:
            if t.road_clearance(f) < 1.0:
                _fail("Flower decal placed on the driving surface on "+path)
                return
        t.queue_free()
        await process_frame

    # --- HUD layout v3: drawn PAUSE/CAM == touch targets, no overlaps,
    # nothing in the front-camera keep-out, chase inside the header.
    for screen in [Vector2(1280,2844),Vector2(1280,2276),Vector2(1280,720)]:
        var m: Dictionary = STYLE.metrics(screen)
        var full := Rect2(Vector2.ZERO,screen)
        for key in ["header","map","lap","total_label","total","name","chase","score","pause","camera","angle","speed"]:
            if not full.encloses(Rect2(m[key])):
                _fail("HUD element off-screen: "+key)
                return
        var head: Rect2 = m["header"]
        for key in ["map","lap","total_label","total","name","chase"]:
            if not head.encloses(Rect2(m[key])):
                _fail("Header element outside the header: "+key)
                return
        var parts: Array[String] = ["map","lap","total_label","total","name","chase"]
        for i in range(parts.size()):
            for j in range(i+1,parts.size()):
                if Rect2(m[parts[i]]).intersects(Rect2(m[parts[j]])):
                    _fail("Header elements overlap: %s / %s" % [parts[i],parts[j]])
                    return
        var dead: Rect2 = m["dead"]
        if bool(m["portrait"]):
            if dead.size.x < screen.x*0.15 or dead.position.y > 0.0:
                _fail("Portrait HUD must keep a top-centre camera keep-out")
                return
            for key in parts:
                if Rect2(m[key]).intersects(dead):
                    _fail("HUD text inside the front-camera keep-out: "+key)
                    return
            if Rect2(m["total"]).position.x < screen.x*0.6:
                _fail("TOTAL SCORE must sit on the right")
                return
        for a in ["pause","camera"]:
            for b in ["header","score"]:
                if Rect2(m[a]).intersects(Rect2(m[b])):
                    _fail("HUD button "+a+" overlaps "+b)
                    return
        if Rect2(m["score"]).intersects(head):
            _fail("Live chain readout must sit outside the header")
            return
        if Rect2(m["speed"]).intersects(Rect2(m["angle"])) or Rect2(m["angle"]).position.y < Rect2(m["speed"]).end.y:
            _fail("Speedometer must sit above the drift angle")
            return
        if Rect2(m["pause"]).intersects(Rect2(m["camera"])):
            _fail("PAUSE and CAM overlap")
            return
    var race: Node3D = (load("res://scenes/race.tscn") as PackedScene).instantiate()
    root.add_child(race)
    await process_frame
    var touch: NitroRaceTouch = race.get("touch")
    var layout: Dictionary = touch._layout(Vector2(1280,2844))
    var metrics: Dictionary = STYLE.metrics(Vector2(1280,2844))
    if Rect2(layout["pause"]) != Rect2(metrics["pause"]) or Rect2(layout["camera"]) != Rect2(metrics["camera"]):
        _fail("Touch PAUSE/CAM targets differ from drawn HUD buttons")
        return
    var race_car: Node3D = race.get("car_root")
    if absf(race_car.scale.x-1.15) > 0.001:
        _fail("Race car must read 15% larger than the stock shell")
        return
    var hud: NitroRaceHUD = race.get("hud")
    if hud.track_points.size() < 8:
        _fail("HUD minimap has no track outline")
        return
    race.queue_free()
    await process_frame

    # --- Chase pill compares the running score with the local best.
    var probe: NitroRaceHUD = HUD.new()
    probe.best_score = -1
    if not str(probe.chase_label()["text"]).begins_with("FIRST RUN"):
        _fail("Chase pill must invite a first run when no local score exists")
        return
    probe.best_score = 5000
    probe.score = 1200
    var chasing: Dictionary = probe.chase_label()
    if bool(chasing["beating"]) or not str(chasing["text"]).contains("5,000"):
        _fail("Chase pill must show the best score being chased: "+str(chasing))
        return
    probe.score = 4800
    probe.drift_score = 200
    probe.combo = 2.0
    if not bool(probe.chase_label()["beating"]):
        _fail("Banked + live chain beyond the best must read NEW BEST")
        return
    var screen := Vector2(1280,2844)
    var ms: Dictionary = STYLE.metrics(screen)
    probe.car_screen = Vector2(640,1650)
    var anchor: Vector2 = probe.callout_anchor(ms,screen)
    if anchor.y >= 1650.0 or anchor.y <= Rect2(ms["score"]).end.y:
        _fail("Scoring callouts must pop above the car, below the live chain")
        return
    # Minimap: dot always on the centreline; long side laid horizontally.
    var tall := PackedVector2Array()
    for k in range(200):
        var ang: float = TAU*float(k)/200.0
        tall.append(Vector2(cos(ang)*40.0,sin(ang)*160.0))
    probe.track_points = tall
    for f in [0.0,0.13,0.5,0.77,0.999]:
        var on_line: Vector2 = probe.point_at_progress(f)
        var nearest: float = INF
        for p in tall:
            nearest = minf(nearest,p.distance_to(on_line))
        if nearest > 3.2:
            _fail("Minimap dot left the white line at progress %.3f" % f)
            return
    var map_rect := Rect2(0,0,360,160)
    probe._rebuild_outline(map_rect)
    var lo := Vector2(INF,INF)
    var hi := Vector2(-INF,-INF)
    for q in probe._outline_cache:
        lo = Vector2(minf(lo.x,q.x),minf(lo.y,q.y))
        hi = Vector2(maxf(hi.x,q.x),maxf(hi.y,q.y))
    if (hi-lo).x < (hi-lo).y*2.0:
        _fail("A tall track must be turned so its long side is horizontal")
        return
    probe.lap = 2
    probe.lap_limit = 3
    probe.track_progress = 0.5
    if absf(probe.overall_progress()-0.5) > 0.001:
        _fail("Three-segment progress line mis-computed")
        return
    probe.free()

    # --- Bundled OFL font renders.
    if STYLE.text_width("SHIN-KAWA 02:00.81",30.0) < 50.0:
        _fail("Exo 2 HUD font did not load")
        return
    print("PASS: die-cast car proportions/styles, RYU-32 coupe, x1.15 race car, sky + cloud shadows, seamless kerbs, scenery clearance, HUD v3 layout (camera keep-out, chase in header), minimap orientation + on-line dot, touch agreement, chase-score pill, OFL font")
    print("NOT RUN: on-device look, GPU cost of scenery/smoke on Android, human comparison with approved reference")
    quit(0)

func _fail(msg: String) -> void:
    printerr("FAIL: "+msg)
    quit(1)
