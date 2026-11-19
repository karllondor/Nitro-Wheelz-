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
        if (variant == "red") != (car.find_child("NW rear screen banner",true,false) != null):
            _fail("NW banner belongs to the red drift spec only")
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

    # --- HUD layout: drawn PAUSE/CAM == touch targets, no overlaps.
    for screen in [Vector2(1280,2844),Vector2(1280,2276),Vector2(1280,720)]:
        var m: Dictionary = STYLE.metrics(screen)
        var full := Rect2(Vector2.ZERO,screen)
        for key in ["header","total","score","chase","pause","camera","angle","speed"]:
            if not full.encloses(Rect2(m[key])):
                _fail("HUD element off-screen: "+key)
                return
        for a in ["pause","camera"]:
            for b in ["header","total","score","chase"]:
                if Rect2(m[a]).intersects(Rect2(m[b])):
                    _fail("HUD button "+a+" overlaps "+b)
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
    if hud.target_time <= 0.0:
        _fail("HUD has no chasing time target")
        return
    race.queue_free()
    await process_frame

    # --- Stars are projected from real pace with the finish-screen tiers.
    var probe: NitroRaceHUD = HUD.new()
    probe.track_id = "shin_kawa_v2"
    probe.target_time = 100.0
    probe.race_time = 30.0
    probe.lap = 2
    probe.track_progress = 0.0
    var state: Dictionary = probe.chase_state()
    if int(state["stars"]) != 1 or absf(float(state["chase"])-82.0) > 0.01:
        _fail("Projected stars/chasing time incorrect: "+str(state))
        return
    probe.race_time = 1.0
    probe.lap = 1
    probe.track_progress = 0.01
    if int(probe.chase_state()["stars"]) != 0:
        _fail("Stars must stay empty before pace can be projected")
        return
    probe.free()

    # --- Bundled OFL font renders.
    if STYLE.text_width("SHIN-KAWA 02:00.81",30.0) < 50.0:
        _fail("Exo 2 HUD font did not load")
        return
    print("PASS: die-cast car proportions/styles, x1.15 race car, sky + cloud shadows, seamless kerbs, scenery clearance, HUD/touch agreement, projected stars, OFL font")
    print("NOT RUN: on-device look, GPU cost of scenery/smoke on Android, human comparison with approved reference")
    quit(0)

func _fail(msg: String) -> void:
    printerr("FAIL: "+msg)
    quit(1)
