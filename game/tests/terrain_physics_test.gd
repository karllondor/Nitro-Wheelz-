extends SceneTree
## v0.1.25 terrain race integration + Developer Mode elevation physics:
##  * grade force presets 0/25/50/75/100 % on the SAME saved road: 0 % keeps
##    a parked car parked, higher presets roll it downhill faster (monotonic),
##    acceleration magnitude = g * sin(atan(grade)) * preset;
##  * flat tracks: 100 % grade force changes nothing (bit-identical trace);
##  * car height = road height (snap), body pitch follows the heading grade;
##  * chase camera never inside the terrain;
##  * open route: 1 lap, finish line ends the run, end-cap barriers hold;
##  * telemetry readout lists every diagnostic.
const CAT = preload("res://scripts/world/terrain/terrain_catalog.gd")
const FIELD = preload("res://scripts/world/terrain/terrain_field.gd")
const TT = preload("res://scripts/world/terrain/terrain_track.gd")
const PHYS = preload("res://scripts/world/terrain/physics_dev.gd")
const RACE = preload("res://scenes/race.tscn")
const DT: float = 1.0/120.0
const LOOP_PATH: String = "user://nitro_track_qa_terrain_loop.json"
const ROUTE_PATH: String = "user://nitro_track_qa_terrain_route.json"

var saved_settings: Dictionary = {}
var failed: bool = false

func _initialize() -> void:
    call_deferred("_run")

func _fail(msg: String) -> void:
    failed = true
    PHYS.save_settings(saved_settings)
    print("FAIL: "+msg)
    quit(1)

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

func _kill(race: Node3D) -> void:
    root.remove_child(race)
    race.free()

func _run() -> void:
    saved_settings = PHYS.load_settings()
    # --- pure maths
    if PHYS.grade_acceleration(Vector2(1,0),0.06,0) != Vector2.ZERO:
        _fail("0 % grade force must add nothing")
        return
    var a100: Vector2 = PHYS.grade_acceleration(Vector2(1,0),0.06,100)
    if absf(a100.length()-9.81*sin(atan(0.06))) > 1e-4 or a100.x >= 0.0:
        _fail("100 % grade force must be g*sin(atan(grade)) downhill (got %s)" % a100)
        return
    if absf(PHYS.grade_acceleration(Vector2(1,0),0.06,50).length()*2.0-a100.length()) > 1e-4:
        _fail("Grade force must scale linearly with the preset")
        return
    # --- saved terrain loop on a steep archetype (Tatry)
    var desc: Dictionary = CAT.descriptor("pl_tatry",1)
    var field: NitroTerrainField = FIELD.new("pl_tatry",1)
    field.bake()
    var grid: NitroTrackGrid = TT.new_grid()
    var gen: Dictionary = TT.generate_loop(grid,field,desc,11)
    if not bool(gen.get("ok",false)):
        _fail("Tatry loop generation failed")
        return
    _write(LOOP_PATH,gen["data"])
    var comp: Dictionary = gen["eval"]["compiled"]
    var h: PackedFloat32Array = comp["heights"]
    var c: Array = comp["centerline"]
    var steep: int = 0
    var best: float = 0.0
    for i in range(c.size()):
        var g: float = (h[(i+1)%c.size()]-h[i])/maxf((c[i] as Vector2).distance_to(c[(i+1)%c.size()]),0.01)
        if absf(g) > best:
            best = absf(g)
            steep = i
    if best < 0.03:
        _fail("Test road needs a real slope (max grade %.3f)" % best)
        return
    # --- presets: park the car on the steepest sample, coast 2 s, no input
    var speeds: Array[float] = []
    for pct in PHYS.GRADE_STEPS:
        PHYS.save_settings({"grade_force":pct,"camera_pitch":true,"banking":false,"grounding":"snap",
            "suspension":false,"telemetry":true})
        var race: Node3D = _race(LOOP_PATH)
        if race.track.terrain == null or race.track.heights.size() != race.track.centerline.size():
            _fail("Race did not rebuild the terrain world / road heights from the saved track")
            return
        var p: Vector2 = c[steep]
        var t: Vector2 = ((c[(steep+1)%c.size()] as Vector2)-p).normalized()
        race.model.reset(p,atan2(t.x,-t.y))
        race.race_started = true
        for k in range(240):
            race._physics_process(DT)
        speeds.append(race.model.speed_mps())
        if absf(race.car_y-race.track.road_height_at(race.model.position)) > 0.02:
            _fail("Snap grounding: car height must equal the road height")
            return
        if absf(race.car_root.position.y-race.car_y) > 0.001:
            _fail("Car model must sit at the computed height")
            return
        for k2 in range(30):
            race._process(DT)
        var ground: float = race.track.terrain.height_at(race.chase.position.x,race.chase.position.z)
        if race.chase.position.y < ground+2.4:
            _fail("Chase camera inside the terrain (%.1f vs ground %.1f)" % [race.chase.position.y,ground])
            return
        var tele: String = race.telemetry_text()
        for word in ["grade road","grade force","camera pitch","traction","banking","grounding","suspension","contact"]:
            if not tele.contains(word):
                _fail("Telemetry misses '%s'" % word)
                return
        _kill(race)
    if speeds[0] > 0.05:
        _fail("0 %% grade force: a parked car must stay parked (%.3f m/s)" % speeds[0])
        return
    for k3 in range(1,speeds.size()):
        if speeds[k3] < speeds[k3-1]-0.001:
            _fail("Grade presets must roll the car monotonically faster: %s" % [speeds])
            return
    if speeds[4] < 0.2:
        _fail("100 %% grade force must roll the car downhill (%.3f m/s)" % speeds[4])
        return
    # --- full throttle UPHILL for 3 s: gravity must slow the climb
    var climb: Array[float] = []
    for pct3 in [0,100]:
        PHYS.save_settings({"grade_force":pct3,"camera_pitch":true,"banking":false,"grounding":"snap","suspension":false,"telemetry":false})
        var rc: Node3D = _race(LOOP_PATH)
        var up_dir: Vector2 = ((c[(steep+1)%c.size()] as Vector2)-(c[steep] as Vector2)).normalized()
        if h[(steep+1)%c.size()] < h[steep]:
            up_dir = -up_dir
        rc.model.reset(c[steep],atan2(up_dir.x,-up_dir.y))
        rc.race_started = true
        Input.action_press("throttle")
        for k7 in range(180):
            rc._physics_process(DT)
        Input.action_release("throttle")
        climb.append(rc.model.speed_mps())
        _kill(rc)
    if climb[1] >= climb[0]:
        _fail("Uphill at 100 %% must be slower than flat handling (%.2f vs %.2f m/s)" % [climb[1],climb[0]])
        return
    # --- body pitch follows the road (uphill heading = nose up)
    PHYS.save_settings({"grade_force":0,"camera_pitch":true,"banking":false,"grounding":"snap","suspension":false,"telemetry":false})
    var rp: Node3D = _race(LOOP_PATH)
    var up_i: int = steep
    var tt: Vector2 = ((c[(up_i+1)%c.size()] as Vector2)-(c[up_i] as Vector2)).normalized()
    var uphill: bool = h[(up_i+1)%c.size()] > h[up_i]
    rp.model.reset(c[up_i],atan2(tt.x,-tt.y) if uphill else atan2(-tt.x,tt.y))
    for k4 in range(60):
        rp._physics_process(DT)
    if rp.body_pitch < 0.01:
        _fail("Facing uphill must pitch the nose up (pitch %.3f rad, grade %.3f)" % [rp.body_pitch,rp.heading_grade])
        return
    _kill(rp)
    # --- flat track: 100 % grade force is bit-identical to 0 %
    var traces: Array = []
    for pct2 in [0,100]:
        PHYS.save_settings({"grade_force":pct2,"camera_pitch":true,"banking":false,"grounding":"snap","suspension":false,"telemetry":false})
        var rf: Node3D = _race("res://tracks/benchmark_oval.json")
        if not rf.track.heights.is_empty() or rf.track.terrain != null:
            _fail("Legacy flat track must stay flat (no heights, no terrain)")
            return
        Input.action_press("throttle")
        Input.action_press("steer_right",0.4)
        for k5 in range(360):
            rf._physics_process(DT)
        Input.action_release("throttle")
        Input.action_release("steer_right")
        traces.append([rf.model.position,rf.model.velocity,rf.model.heading,rf.car_root.position.y])
        _kill(rf)
    if traces[0] != traces[1] or float(traces[0][3]) != 0.0:
        _fail("Flat track trace changed with grade force: %s vs %s" % [traces[0],traces[1]])
        return
    # --- open route: one lap, finish line, end caps
    var hdesc: Dictionary = CAT.descriptor("ie_hills",2)
    var hf: NitroTerrainField = FIELD.new("ie_hills",2)
    hf.bake()
    var rgrid: NitroTrackGrid = TT.new_grid()
    var route: Dictionary = TT.generate_route(rgrid,hf,hdesc,5)
    if not bool(route.get("ok",false)):
        _fail("Open route generation failed")
        return
    _write(ROUTE_PATH,route["data"])
    var rr: Node3D = _race(ROUTE_PATH)
    if not bool(rr.route_mode) or rr.track.closed_loop or int(rr.hud.lap_limit) != 1:
        _fail("Open route must race as one lap without a wrap segment")
        return
    var tr: NitroDriftTrack = rr.track
    # v0.1.27: open routes end in a staging paddock / parc ferme (no cut-off
    # road) and the start has a light pole.
    var vinfo: Dictionary = tr.terrain.scenery.venue_info
    var ends: Dictionary = vinfo.get("route_ends",{})
    if not bool(ends.get("start",false)) or not bool(ends.get("finish",false)) or not vinfo.has("start_lights"):
        _fail("Open route needs start / finish areas and start lights (%s)" % [vinfo.get("route_ends",{})])
        return
    if tr.start_index <= 0 or tr.finish_index >= tr.centerline.size()-1 or tr.finish_progress >= 1.0:
        _fail("Open route needs a start inside the first tile and a finish before the end cap")
        return
    var last: Vector2 = tr.centerline[tr.centerline.size()-1]
    var te: Vector2 = (last-tr.centerline[tr.centerline.size()-2]).normalized()
    var beyond: Dictionary = tr.resolve_body(last+te*2.0,atan2(te.x,-te.y),te*20.0)
    if not bool(beyond["hit"]) or (Vector2(beyond["position"])-last).dot(te) > 0.0:
        _fail("End-cap barrier must stop the car at the end of an open route")
        return
    var first: Vector2 = tr.centerline[0]
    var t0: Vector2 = (tr.centerline[1]-first).normalized()
    var before: Dictionary = tr.resolve_body(first-t0*2.0,atan2(-t0.x,t0.y),-t0*15.0)
    if not bool(before["hit"]) or (Vector2(before["position"])-first).dot(t0) < 0.0:
        _fail("Start end-cap barrier must hold the car on the road")
        return
    var fi: int = maxi(tr.finish_index-6,1)
    var fp: Vector2 = tr.centerline[fi]
    var ft: Vector2 = (tr.centerline[fi+1]-fp).normalized()
    rr.model.reset(fp,atan2(ft.x,-ft.y))
    rr.model.velocity = ft*18.0
    rr.race_started = true
    rr.last_progress = float(tr.sample_info(fp)["progress"])
    for k6 in range(360):
        rr._physics_process(DT)
        if rr.finished:
            break
    if not rr.finished or rr.lap_splits.size() != 1:
        _fail("Crossing the finish line must end an open-route run (finished=%s)" % rr.finished)
        return
    _kill(rr)
    PHYS.save_settings(saved_settings)
    DirAccess.remove_absolute(LOOP_PATH)
    DirAccess.remove_absolute(ROUTE_PATH)
    print("PASS: elevation physics presets 0/25/50/75/100 %% monotonic (%.2f/%.2f/%.2f/%.2f/%.2f m/s after 2 s parked on %.1f %%; rolling resistance holds the low presets), uphill full throttle 3 s %.1f -> %.1f m/s at 100 %%, 0 %% = parked, flat track bit-identical at 100 %%, snap grounding + nose-up pitch, chase camera above terrain, telemetry, open route finish + end caps + start / finish areas + start lights" % [speeds[0],speeds[1],speeds[2],speeds[3],speeds[4],best*100.0,climb[0],climb[1]])
    # Let freed races release their audio playbacks before the engine exits
    # (a quit in the same frame could leave the audio thread spinning).
    for _f in range(3):
        await process_frame
    quit(0)
