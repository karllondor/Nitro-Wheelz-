extends SceneTree
## Park tutorial bugfix (#27 owner phone QA c7082510153), regression tests on the REAL race scene with REAL
## touch events (InputEventScreenTouch through the touch layer, not Input actions):
##  1. ROOT CAUSE: a lesson schematic used to switch the touch layer OFF and nothing switched it on again:
##     GAS / stick / handbrake were dead and the pressed state stuck for lessons 6-10. Now: the layer stays
##     on, a thumb released during a card is released, the dismissing tap is not a pedal press, and the
##     cards end by themselves (the clock runs while the car is frozen).
##  2. NAVIGATION: distance / side / arrow are recomputed from the live car every call (never stale), the
##     on-screen arrow follows the heading and points at the real left donut.
##  3. MARKERS: a ring on the pavement around the cone(s) of the exercise, a guide line from the car while
##     far, gold ring inside the zone.
##  4. A real donut with the real touch controls completes DONUT LEFT and the tutorial advances to 7/10
##     (DONUT RIGHT) and saves it; wrong way / far from the cone / straight driving never do.
##  5. SKIP clears the markers; the Park layout and the cones are unchanged.
const DRIVE = preload("res://scripts/driving/drive_model.gd")
const CARS = preload("res://scripts/vehicles/car_catalog.gd")
const LAYOUT = preload("res://scripts/park/park_layout.gd")
const PROGRESS = preload("res://scripts/park/park_progress.gd")
const TUTORIAL = preload("res://scripts/park/park_tutorial.gd")
const RACE = preload("res://scenes/race.tscn")
const DT: float = 1.0/120.0

var _saved_progress: Variant = null
var _car_before: Variant = null

func _initialize() -> void:
    _saved_progress = FileAccess.get_file_as_string(PROGRESS.PATH) if FileAccess.file_exists(PROGRESS.PATH) else null
    if ProjectSettings.has_setting("nitro/car_variant"):
        _car_before = ProjectSettings.get_setting("nitro/car_variant")
    call_deferred("_run")

func _restore() -> void:
    if _saved_progress != null:
        var f := FileAccess.open(PROGRESS.PATH,FileAccess.WRITE)
        f.store_string(str(_saved_progress))
        f.close()
    elif FileAccess.file_exists(PROGRESS.PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESS.PATH))
    if _car_before != null:
        ProjectSettings.set_setting("nitro/car_variant",_car_before)

func _fail(message: String) -> void:
    _restore()
    printerr("FAIL: "+message)
    quit(1)

func _touch(i: int, p: Vector2, on: bool) -> void:
    var e := InputEventScreenTouch.new()
    e.index = i
    e.position = root.get_final_transform()*p
    e.pressed = on
    Input.parse_input_event(e)
    Input.flush_buffered_events()

func _new_race() -> Node3D:
    ProjectSettings.set_setting("nitro/car_variant","e30")
    ProjectSettings.set_setting("nitro/selected_track","res://tracks/nitro_wheelz_park.json")
    ProjectSettings.set_setting("nitro/park_mode","tutorial")
    ProjectSettings.set_setting("nitro/park_reset",true)
    var race: Node3D = RACE.instantiate()
    root.add_child(race)
    return race

func _frames(n: int) -> void:
    for i in range(n):
        await process_frame

func _steps(race: Node3D, n: int) -> void:
    for k in range(n):
        race._physics_process(DT)

## Where the car's own circle sits relative to its start with the digital controls the touch layer
## produces (steer value s, full throttle, the handbrake for the first 0.35 s).
func _orbit_offset(steer_value: float) -> Vector2:
    var m = DRIVE.new()
    m.apply_profile(CARS.handling("e30"))
    m.reset(Vector2.ZERO,0.0)
    m.velocity = m.forward()*(45.0/3.6)
    var t: float = 0.0
    var acc := Vector2.ZERO
    var n: int = 0
    while t < 16.0:
        m.step(1.0/240.0,steer_value,1.0,0.0,1.0 if t < 0.35 else 0.0)
        t += 1.0/240.0
        if t > 6.0 and int(t/(1.0/240.0))%24 == 0:
            acc += m.position
            n += 1
    return acc/float(n)

func _donut_with_touch(race: Node3D, around: Vector2, side: float, seconds: float, handbrake: bool = true) -> void:
    # side -1 = stick left, +1 = right; full throttle; the handbrake flick for 0.35 s
    await _frames(3)                # presses right after a dismissed card are ignored on purpose
    var geo: Dictionary = race.touch._layout()
    var gas: Vector2 = Rect2(geo["gas"]).get_center()
    var stick: Vector2 = Vector2(geo["joystick_center"])+Vector2(side*float(geo["joystick_radius"])*1.0,0.0)
    var drift: Vector2 = Rect2(geo["drift"]).get_center()
    _touch(0,gas,true)
    _touch(1,stick,true)
    race.touch.visible = true
    var steer_now: float = race.touch.steer
    var off: Vector2 = _orbit_offset(steer_now)
    race.model.reset(around-Vector2(off.x,off.y)*Vector2(1.0,1.0),0.0)
    race.model.velocity = race.model.forward()*(45.0/3.6)
    if handbrake:
        _touch(2,drift,true)
    var k: int = 0
    while float(k)*DT < seconds:
        if handbrake and k == 42:
            _touch(2,drift,false)
        race._physics_process(DT)
        k += 1
        if race.park.tutorial.phase == "success":
            break
    _touch(0,gas,false)
    _touch(1,stick,false)
    if handbrake and k < 42:
        _touch(2,drift,false)

func _run() -> void:
    var race: Node3D = _new_race()
    for i in range(30):
        await process_frame
    var park = race.park
    var tut: NitroParkTutorial = park.tutorial
    race.touch.visible = true
    var geo: Dictionary = race.touch._layout()
    var gas_c: Vector2 = Rect2(geo["gas"]).get_center()
    var stick_c: Vector2 = Vector2(geo["joystick_center"])
    var stick_r: float = float(geo["joystick_radius"])
    # layout guards: the Park and the cones are as the owner saw them
    if LAYOUT.DONUT_LEFT != Vector2(-105.0,0.0) or LAYOUT.START_POS != Vector2(0.0,30.0) or park.cones.positions.size() != 80:
        _fail("the Park layout / cone count changed (DONUT_LEFT %s, START %s, cones %d)" % [str(LAYOUT.DONUT_LEFT),str(LAYOUT.START_POS),park.cones.positions.size()])
        return
    # ------------------------------------------------ 1. controls lifecycle (the root cause)
    if tut.phase != "welcome" or tut.lesson_index != 0 or not race.touch.is_processing_input():
        _fail("a fresh tutorial must open with the welcome card and a live touch layer (phase %s)" % tut.phase)
        return
    _touch(0,gas_c,true)            # the tap that dismisses the card happens to land on the GAS pedal
    if tut.phase != "active" or race.touch.throttle != 0.0 or race.touch.contacts.has(0):
        _fail("the dismissing tap must not become a throttle press (phase %s, throttle %.1f)" % [tut.phase,race.touch.throttle])
        return
    _touch(0,gas_c,false)
    await _frames(3)
    _touch(0,gas_c,true)            # now a real press
    if race.touch.throttle != 1.0:
        _fail("GAS did not respond after the welcome card")
        return
    _steps(race,120*5)
    if tut.lesson_index < 1 or not PROGRESS.is_completed("gas"):
        _fail("holding the real touch GAS did not complete lesson 1 (lesson %d)" % tut.lesson_index)
        return
    # lesson 6 starts while both thumbs are down (as when lesson 5 completes under the player's hands)
    _touch(1,stick_c+Vector2(-stick_r*0.6,0.0),true)
    tut.start(5)
    if tut.phase != "intro" or not race.touch.is_processing_input():
        _fail("lesson 6 must open with its schematic and a LIVE touch layer (phase %s, processing %s)" % [tut.phase,str(race.touch.is_processing_input())])
        return
    var frozen_at: Vector2 = race.model.position
    _steps(race,60)
    if race.model.position != frozen_at:
        _fail("the car moved while the schematic was up")
        return
    _touch(0,gas_c,false)           # the thumbs come OFF during the card
    _touch(1,stick_c,false)
    if race.touch.throttle != 0.0 or race.touch.steer != 0.0 or race.touch.contacts.size() != 0:
        _fail("a thumb released during a card stayed pressed (throttle %.1f steer %.2f contacts %d): the stuck-input bug" % [race.touch.throttle,race.touch.steer,race.touch.contacts.size()])
        return
    _touch(5,Vector2(300,300),true)  # tap the schematic away
    _touch(5,Vector2(300,300),false)
    if tut.phase != "active":
        _fail("the tap did not dismiss the schematic")
        return
    await _frames(3)
    _touch(0,gas_c,true)
    _touch(1,stick_c+Vector2(-stick_r,0.0),true)
    if race.touch.throttle != 1.0 or race.touch.steer > -0.9:
        _fail("after the schematic GAS / stick are dead (throttle %.1f, steer %.2f): the reported bug" % [race.touch.throttle,race.touch.steer])
        return
    var before: Vector2 = race.model.position
    _steps(race,240)
    if race.model.position.distance_to(before) < 3.0:
        _fail("the car does not move with the real touch controls after the schematic")
        return
    _touch(0,gas_c,false)
    _touch(1,stick_c,false)
    # the cards end by themselves although the car is frozen (no physics tick feeds the clock)
    tut.start(6)
    if tut.phase != "intro":
        _fail("lesson 7 must open with its schematic")
        return
    park._process(TUTORIAL.OVERLAY_SECONDS+0.5)
    if tut.phase != "active":
        _fail("the schematic never ended by itself (the old 8 s timeout was dead code)")
        return
    tut.start(0)
    park._process(TUTORIAL.WELCOME_SECONDS-1.0)
    if tut.phase != "welcome":
        _fail("the welcome card ended too early")
        return
    park._process(2.0)
    if tut.phase != "active":
        _fail("the welcome card never ended by itself")
        return
    # ------------------------------------------------ 2. navigation is live
    tut.start(5)
    tut.dismiss_intro()
    var target: Vector2 = LAYOUT.DONUT_LEFT
    var last_d: float = INF
    for sample in [[Vector2(0,30),0.0],[Vector2(-30,22),-60.0],[Vector2(-70,6),-90.0],[Vector2(-95,2),-90.0]]:
        race.model.position = Vector2(sample[0])
        race.model.heading = deg_to_rad(float(sample[1]))
        race.model.velocity = Vector2.ZERO
        park.after_step(DT,0.0,0.0,0.0,0.0)
        var want: float = race.model.position.distance_to(target)
        if absf(park.guide.target_dist-want) > 0.01 or park.guide.target != target:
            _fail("distance not live: label %.2f, true %.2f at %s" % [park.guide.target_dist,want,str(sample[0])])
            return
        if want >= last_d:
            _fail("the distance did not decrease while the car approached (%.1f after %.1f)" % [want,last_d])
            return
        last_d = want
        var rows: Array = park.guide._coach_rows()
        if want > 17.0 and not str(rows[1]["t"]).contains(str(int(round(want)))):
            _fail("the banner shows a stale distance: %s (true %.0f)" % [str(rows[1]["t"]),want])
            return
    if not bool(park.nav_state()["in_zone"]) and race.model.position.distance_to(target) <= 17.0:
        _fail("inside the exercise radius the state must say 'you are there'")
        return
    var sides: Dictionary = {}
    for h in [0.0,-90.0,90.0,180.0]:
        race.model.position = Vector2(0,30)
        race.model.heading = deg_to_rad(h)
        sides[int(h)] = str(park.nav_state()["side"])
    if sides != {0:"left",-90:"ahead",90:"behind",180:"right"}:
        _fail("side relative to the car heading is wrong: %s" % str(sides))
        return
    # the on-screen arrow follows the heading and points at the real donut
    race.model.position = Vector2(-75,4)
    race.model.heading = deg_to_rad(-90.0)
    for k in range(240):
        race.call("_update_camera",DT)
    var cam: Camera3D = race.get_viewport().get_camera_3d()
    var nav: Dictionary = park.nav_state()
    var sc: Dictionary = park.nav_screen(cam,nav)
    var tp: Vector2 = cam.unproject_position(Vector3(target.x,0.5,target.y))
    var want_dir: Vector2 = (tp-Vector2(sc["car"])).normalized()
    if Vector2(sc["dir"]).dot(want_dir) < 0.95:
        _fail("the arrow does not point at the donut on screen (cos %.2f)" % Vector2(sc["dir"]).dot(want_dir))
        return
    race.model.heading = deg_to_rad(90.0)
    for k in range(240):
        race.call("_update_camera",DT)
    var sc2: Dictionary = park.nav_screen(cam,park.nav_state())
    if Vector2(sc["dir"]).dot(Vector2(sc2["dir"])) > 0.5:
        _fail("the on-screen arrow did not change when the car turned around (cos %.2f): a stuck arrow" % Vector2(sc["dir"]).dot(Vector2(sc2["dir"])))
        return
    # ------------------------------------------------ 3. markers on the pavement
    if park.rings.size() != 1 or Vector2(park.rings[0].position.x,park.rings[0].position.z) != target:
        _fail("lesson 6 needs ONE ring on the left cone (rings %d)" % park.rings.size())
        return
    var aabb: AABB = park.rings[0].mesh.get_aabb()
    if absf(aabb.size.x*0.5-LAYOUT.DONUT_RADIUS) > 1.0:
        _fail("the ring radius %.1f m is not the exercise radius %.1f m" % [aabb.size.x*0.5,LAYOUT.DONUT_RADIUS])
        return
    race.model.position = Vector2(0,30)
    park.after_step(DT,0.0,0.0,0.0,0.0)
    if park.guide_line == null or not park.guide_line.visible:
        _fail("the guide line must show while the car is far from the exercise")
        return
    park._animate_markers()
    var far_col: Color = park._ring_mat.albedo_color
    race.model.position = Vector2(-92,1)
    park.after_step(DT,0.0,0.0,0.0,0.0)
    park._animate_markers()
    if park.guide_line.visible or park._ring_mat.albedo_color.g > far_col.g+0.0 and park._ring_mat.albedo_color.b > far_col.b-0.2:
        _fail("inside the zone the guide line must go and the ring turn gold")
        return
    var rows_in: Array = park.guide._coach_rows()
    if str(rows_in[0]["t"]) != TUTORIAL.txt(TUTORIAL.NAV_HERE_LEFT):
        _fail("inside the zone the banner must say what to do: %s" % str(rows_in[0]["t"]))
        return
    tut.start(7)
    tut.dismiss_intro()
    if park.rings.size() != 2:
        _fail("the eight needs a ring at each cone (rings %d)" % park.rings.size())
        return
    tut.start(9)
    tut.dismiss_intro()
    if park.rings.size() != 1:
        _fail("the route needs a ring at its start (rings %d)" % park.rings.size())
        return
    # ------------------------------------------------ 4. a real donut, real touch controls -> 7/10
    tut.start(5)
    tut.dismiss_intro()
    await _donut_with_touch(race,target,-1.0,22.0)
    if tut.phase != "success" or not PROGRESS.is_completed("donut_left"):
        _fail("a real left donut with the real touch controls did not complete DONUT LEFT (phase %s, progress %.2f)" % [tut.phase,tut.progress()])
        return
    _steps(race,int(1.9/DT))
    if tut.lesson_index != 6 or tut.title_text() != "DONUT W PRAWO":
        _fail("the tutorial did not advance to 7/10 DONUT RIGHT (lesson %d)" % (tut.lesson_index+1))
        return
    if Vector2(park.nav_state().get("target",Vector2.ZERO)) != LAYOUT.DONUT_RIGHT and tut.phase == "active":
        _fail("the navigation did not switch to the right cone")
        return
    # negatives (same controls): wrong way, far from the cone, straight driving
    tut.start(5)
    tut.dismiss_intro()
    var hints: Array = []
    tut.hint_shown.connect(func(t: String): hints.append(t))
    await _donut_with_touch(race,target,1.0,24.0)       # RIGHT circle around the LEFT cone
    if tut.phase == "success" or tut.progress() > 0.05:
        _fail("a circle in the wrong direction counted (progress %.2f)" % tut.progress())
        return
    if not hints.has(TUTORIAL.txt(TUTORIAL.WRONG_WAY_LEFT)):
        _fail("circling the wrong way must give the hint to circle LEFT (hints %s)" % str(hints))
        return
    tut.start(5)
    tut.dismiss_intro()
    await _donut_with_touch(race,target+Vector2(0,70),-1.0,22.0)    # a good donut, 70 m from the cone
    if tut.phase == "success" or tut.progress() > 0.05:
        _fail("a donut far from the cone counted (progress %.2f)" % tut.progress())
        return
    tut.start(5)
    tut.dismiss_intro()
    race.model.reset(Vector2(-60,0),deg_to_rad(-90.0))
    race.model.velocity = race.model.forward()*8.0
    await _frames(3)
    _touch(0,gas_c,true)
    _steps(race,120*8)
    _touch(0,gas_c,false)
    if tut.phase == "success" or tut.progress() > 0.2:
        _fail("driving straight past the cone counted (progress %.2f)" % tut.progress())
        return
    # ------------------------------------------------ 5. SKIP keeps everything calm
    tut.start(5)
    tut.dismiss_intro()
    park.skip_tutorial()
    if park.rings.size() != 0 or park.guide_line != null or park.guide.target != null or not race.touch.is_processing_input():
        _fail("SKIP must clear the markers and leave the controls live")
        return
    _restore()
    race.queue_free()
    await process_frame
    print("PASS: Park tutorial bugfix - touch layer stays live after a schematic (no dead / stuck GAS, stick, handbrake), the dismissing tap is not a pedal press, cards end by themselves, distance / side / on-screen arrow are live from the car (and follow the heading to the real donut), rings + guide line on the pavement, a real donut with REAL touch controls completes DONUT LEFT and advances to 7/10 DONUT RIGHT, wrong way / far / straight never count, SKIP clears the markers, 80 cones retained")
    print("NOT RUN: the tutorial on the owner's phone")
    quit(0)
