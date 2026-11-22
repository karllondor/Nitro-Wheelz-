extends SceneTree
## Issue #27 scripted proof (developer tool, headless, prints a trace):
##   godot --headless --path game --script res://tests/park_nav_trace.gd
## A pilot drives from the start towards the exercise of lesson 6/10 with the REAL touch controls,
## steering only from what the guidance says (side / angle of nav_state()), until "you are there";
## then a left donut with the real touch controls completes the lesson and the tutorial advances.
const LAYOUT = preload("res://scripts/park/park_layout.gd")
const PROGRESS = preload("res://scripts/park/park_progress.gd")
const DRIVE = preload("res://scripts/driving/drive_model.gd")
const CARS = preload("res://scripts/vehicles/car_catalog.gd")
const RACE = preload("res://scenes/race.tscn")
const DT: float = 1.0/120.0

func _initialize() -> void:
    call_deferred("_run")

func _touch(i: int, p: Vector2, on: bool) -> void:
    var e := InputEventScreenTouch.new()
    e.index = i
    e.position = root.get_final_transform()*p        # window coordinates (the UI is stretched)
    e.pressed = on
    Input.parse_input_event(e)
    Input.flush_buffered_events()

func _drag(i: int, p: Vector2) -> void:
    var e := InputEventScreenDrag.new()
    e.index = i
    e.position = root.get_final_transform()*p
    Input.parse_input_event(e)
    Input.flush_buffered_events()

func _run() -> void:
    var saved: Variant = FileAccess.get_file_as_string(PROGRESS.PATH) if FileAccess.file_exists(PROGRESS.PATH) else null
    ProjectSettings.set_setting("nitro/car_variant","e30")
    ProjectSettings.set_setting("nitro/selected_track","res://tracks/nitro_wheelz_park.json")
    ProjectSettings.set_setting("nitro/park_mode","tutorial")
    ProjectSettings.set_setting("nitro/park_reset",true)
    var race: Node3D = RACE.instantiate()
    root.add_child(race)
    for i in range(30):
        await process_frame
    race.touch.visible = true
    var park = race.park
    var tut = park.tutorial
    tut.start(5)
    tut.dismiss_intro()
    for i in range(4):
        await process_frame
    var geo: Dictionary = race.touch._layout()
    var gas: Vector2 = Rect2(geo["gas"]).get_center()
    var sc: Vector2 = Vector2(geo["joystick_center"])
    var sr: float = float(geo["joystick_radius"])
    print("TRACE lesson %d/10 %s - pilot starts at %s heading north, exercise at %s" % [tut.lesson_index+1,tut.title_text(),str(race.model.position),str(LAYOUT.DONUT_LEFT)])
    _touch(1,sc,true)
    var gas_down: bool = false
    var t: float = 0.0
    var last_print: float = -10.0
    var arrived: float = -1.0
    while t < 60.0:
        var nav: Dictionary = park.nav_state()
        if nav.is_empty():
            break
        if bool(nav["in_zone"]):
            arrived = t
            break
        var raw: float = clampf(float(nav["angle"])/40.0,-1.0,1.0)
        _drag(1,sc+Vector2(raw*sr*0.95,0.0))
        var want_gas: bool = race.model.speed_kmh() < 38.0
        if want_gas and not gas_down:
            _touch(0,gas,true)
            gas_down = true
        elif not want_gas and gas_down:
            _touch(0,gas,false)
            gas_down = false
        race._physics_process(DT)
        t += DT
        if t-last_print >= 2.0:
            last_print = t
            var rows: Array = park.guide._coach_rows()
            print("TRACE t=%5.1fs pos=(%6.1f,%6.1f) heading=%4.0f deg speed=%3.0f km/h | label=%3d m side=%-6s angle=%+4.0f | banner: %s" % [
                t,race.model.position.x,race.model.position.y,rad_to_deg(race.model.heading),race.model.speed_kmh(),
                int(round(float(nav["dist"]))),str(nav["side"]),float(nav["angle"]),str(rows[1]["t"]) if rows.size() > 1 else str(rows[0]["t"])])
    _touch(0,gas,false)
    _touch(1,sc,false)
    print("TRACE %s after %.1f s: distance %.1f m, banner: %s" % ["ARRIVED in the exercise zone" if arrived >= 0.0 else "did NOT arrive",t,race.model.position.distance_to(LAYOUT.DONUT_LEFT),str(park.guide._coach_rows()[0]["t"])])
    # the donut itself (the car's own circle centred on the cone, as a player who lined up)
    var m = DRIVE.new()
    m.apply_profile(CARS.handling("e30"))
    m.reset(Vector2.ZERO,0.0)
    m.velocity = m.forward()*(45.0/3.6)
    var acc := Vector2.ZERO
    var n: int = 0
    var tt: float = 0.0
    var steer_probe: float = -1.0
    while tt < 16.0:
        m.step(1.0/240.0,steer_probe,1.0,0.0,1.0 if tt < 0.35 else 0.0)
        tt += 1.0/240.0
        if tt > 6.0 and int(tt/(1.0/240.0))%24 == 0:
            acc += m.position
            n += 1
    var off: Vector2 = acc/float(n)
    race.model.reset(LAYOUT.DONUT_LEFT-off,0.0)
    race.model.velocity = race.model.forward()*(45.0/3.6)
    _touch(0,gas,true)
    _touch(1,sc+Vector2(-sr,0.0),true)
    _touch(2,Rect2(geo["drift"]).get_center(),true)
    var k: int = 0
    var done_at: float = -1.0
    while float(k)*DT < 22.0:
        if k == 42:
            _touch(2,Rect2(geo["drift"]).get_center(),false)
        race._physics_process(DT)
        k += 1
        if k%240 == 0:
            print("TRACE donut t=%4.1fs progress %3.0f%% in_zone=%s banner: %s" % [float(k)*DT,tut.progress()*100.0,str(park.nav_state().get("in_zone",false)),str(park.guide._coach_rows()[0]["t"])])
        if tut.phase == "success":
            done_at = float(k)*DT
            break
    _touch(0,gas,false)
    _touch(1,sc,false)
    print("TRACE donut completed: %s at %.1f s, saved=%s, toast=%s" % [str(tut.phase == "success"),done_at,str(PROGRESS.is_completed("donut_left")),tut.success_text()])
    for i in range(int(1.9/DT)):
        race._physics_process(DT)
    print("TRACE advanced to lesson %d/10 %s (phase %s), next exercise at %s" % [tut.lesson_index+1,tut.title_text(),tut.phase,str(LAYOUT.DONUT_RIGHT)])
    if saved != null:
        var f := FileAccess.open(PROGRESS.PATH,FileAccess.WRITE)
        f.store_string(str(saved))
        f.close()
    elif FileAccess.file_exists(PROGRESS.PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESS.PATH))
    quit(0)
