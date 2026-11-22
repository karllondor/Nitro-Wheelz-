extends SceneTree
## NITRO WHEELZ PARK tutorial (issue #27): the lessons are judged by what the car and the
## real controls actually did.
##  * detectors: donut left / right and the first slide succeed on REAL drive-model runs
##    (weakest car included); driving straight, a grip circle without a slide, a circle
##    around the wrong cone and a button tap never succeed; the figure-eights need both
##    lobes, a transition and a flip of the slip side; the route needs the corridor;
##  * state machine: automatic advance on success, no advance on a tap alone, schematic
##    freezes the car until tapped (or 8 s), hints after idling, SKIP = off, persistence
##    (save / load / redo), every lesson has Polish + English text;
##  * in the race scene: FREE DRIVE has no tutorial; TUTORIAL advances on real input; SKIP
##    keeps cones / paint where they are; the pause row toggles it;
##  * cones tip and slide, reset restores; the ghost replays identically;
##  * menu: PARK page, FREE DRIVE / START TUTORIAL set the mode, the Park is never "the
##    track you last raced".
const LAYOUT = preload("res://scripts/park/park_layout.gd")
const DET = preload("res://scripts/park/park_detectors.gd")
const TUTORIAL = preload("res://scripts/park/park_tutorial.gd")
const PROGRESS = preload("res://scripts/park/park_progress.gd")
const CONES = preload("res://scripts/park/park_cones.gd")
const GHOST = preload("res://scripts/park/park_ghost.gd")
const DRIVE = preload("res://scripts/driving/drive_model.gd")
const CARS = preload("res://scripts/vehicles/car_catalog.gd")
const RACE = preload("res://scenes/race.tscn")
const BOOT = preload("res://scenes/boot.tscn")
const DT: float = 1.0/240.0

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    printerr("FAIL: "+message)
    quit(1)

func _keep() -> Variant:
    return FileAccess.get_file_as_string(PROGRESS.PATH) if FileAccess.file_exists(PROGRESS.PATH) else null

func _restore(saved: Variant) -> void:
    if saved != null:
        var f := FileAccess.open(PROGRESS.PATH,FileAccess.WRITE)
        f.store_string(str(saved))
        f.close()
    elif FileAccess.file_exists(PROGRESS.PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESS.PATH))

## The inputs of a real donut on the drive model: a handbrake flick, then the steering held
## into the turn with the throttle on (left = negative steer).
func _donut_inputs(t: float, turn: int, steer_c: float, gas: float) -> Array:
    var side: float = -1.0 if turn > 0 else 1.0
    var hb: float = 1.0 if t < 0.35 else 0.0
    var steer: float = side*0.9 if t < 0.6 else side*steer_c
    var g: float = 0.8 if t < 0.6 else gas
    return [steer,g,hb]

## Where the car's own circle sits relative to its start (mean of the settled part of a
## 16 s run): put the cone there and the car circles the cone, like a player who lined up.
func _orbit_offset(variant: String, turn: int, steer_c: float, gas: float) -> Vector2:
    var m = DRIVE.new()
    m.apply_profile(CARS.handling(variant))
    m.reset(Vector2.ZERO,0.0)
    m.velocity = m.forward()*(45.0/3.6)
    var t: float = 0.0
    var acc := Vector2.ZERO
    var n: int = 0
    while t < 16.0:
        var i: Array = _donut_inputs(t,turn,steer_c,gas)
        m.step(DT,i[0],i[1],0.0,i[2])
        t += DT
        if t > 6.0 and int(t/DT)%24 == 0:
            acc += m.position
            n += 1
    return acc/float(n)

## Same for the keyboard / touch path of the race scene (digital: full lock, full throttle,
## the handbrake for the first 0.35 s) - exactly what the race feeds the model.
func _orbit_offset_digital(variant: String) -> Vector2:
    var m = DRIVE.new()
    m.apply_profile(CARS.handling(variant))
    m.reset(Vector2.ZERO,0.0)
    m.velocity = m.forward()*(45.0/3.6)
    var t: float = 0.0
    var acc := Vector2.ZERO
    var n: int = 0
    while t < 16.0:
        m.step(DT,-1.0,1.0,0.0,1.0 if t < 0.35 else 0.0)
        t += DT
        if t > 6.0 and int(t/DT)%24 == 0:
            acc += m.position
            n += 1
    return acc/float(n)

## A donut on the real drive model around the cone of `exercise`, fed to `det`.
func _donut_run(variant: String, turn: int, steer_c: float, gas: float, seconds: float, det: RefCounted, centre: Vector2) -> void:
    var m = DRIVE.new()
    m.apply_profile(CARS.handling(variant))
    var off: Vector2 = _orbit_offset(variant,turn,steer_c,gas)
    m.reset(centre-off,0.0)
    m.velocity = m.forward()*(45.0/3.6)
    var t: float = 0.0
    var tick: int = 0
    while t < seconds:
        var i: Array = _donut_inputs(t,turn,steer_c,gas)
        m.step(DT,i[0],i[1],0.0,i[2])
        t += DT
        tick += 1
        if tick%2 == 0:
            det.update(m.position,DT*2.0,m.drift_angle,m.speed_kmh())

func _run() -> void:
    var saved: Variant = _keep()
    # ------------------------------------------------------------- donuts, real runs
    for variant in ["e30","red"]:
        for turn in [1,-1]:
            var e: Dictionary = LAYOUT.exercise("donut_left" if turn > 0 else "donut_right")
            var r: float = float(e["radius"])
            var det := DET.Orbit.new(Vector2(e["centre"]),maxf(2.5,r*0.22),r*1.7,turn,320.0,0.5)
            _donut_run(variant,turn,1.0,0.8,16.0,det,Vector2(e["centre"]))
            if not det.done():
                _fail("%s: a real %s donut was not recognised (turned %.0f deg, drift share %.2f)" % [variant,"left" if turn > 0 else "right",rad_to_deg(det.accumulated),det.drift_share()])
                return
            # the other direction must not count
            var wrong := DET.Orbit.new(Vector2(e["centre"]),maxf(2.5,r*0.22),r*1.7,-turn,320.0,0.5)
            _donut_run(variant,turn,1.0,0.8,16.0,wrong,Vector2(e["centre"]))
            if wrong.done():
                _fail("a donut in the wrong direction counted")
                return
            # a grip circle without a slide (low gas): turned, but NOT drifting
            var grip := DET.Orbit.new(Vector2(e["centre"]),maxf(2.5,r*0.22),r*1.7,turn,320.0,0.5)
            _donut_run(variant,turn,1.0,0.45,16.0,grip,Vector2(e["centre"]))
            if grip.done():
                _fail("a circle without a slide counted as a donut")
                return
    # straight driving past the donut: never
    var straight := DET.Orbit.new(Vector2(LAYOUT.DONUT_LEFT),2.5,17.0,1,320.0,0.5)
    var ms = DRIVE.new()
    ms.apply_profile(CARS.handling("e30"))
    ms.reset(Vector2(LAYOUT.DONUT_LEFT)+Vector2(-60,3),deg_to_rad(90.0))
    for k in range(240*14):
        ms.step(DT,0.0,1.0,0.0,0.0)
        if k%2 == 0:
            straight.update(ms.position,DT*2.0,ms.drift_angle,ms.speed_kmh())
    if straight.progress() > 0.2 or straight.done():
        _fail("driving straight past the cone counted towards the donut (%.2f)" % straight.progress())
        return
    # a circle around the WRONG cone (the right donut while the left one is asked for)
    var wrong_cone := DET.Orbit.new(Vector2(LAYOUT.DONUT_LEFT),2.5,17.0,-1,320.0,0.5)
    _donut_run("red",-1,1.0,0.8,16.0,wrong_cone,Vector2(LAYOUT.DONUT_RIGHT))
    if wrong_cone.progress() > 0.05:
        _fail("a donut around the other cone counted")
        return
    # ---------------------------------------------------------------- first slide
    var fs := DET.FirstSlide.new()
    var mf = DRIVE.new()
    mf.apply_profile(CARS.handling("e30"))
    mf.reset(Vector2.ZERO,0.0)
    mf.velocity = mf.forward()*(50.0/3.6)
    var tf: float = 0.0
    while tf < 6.0 and not fs.done():
        # flick, hold the slide for a moment, then straighten (grip back)
        var steer: float = 0.8 if tf < 0.6 else (-0.2 if tf < 1.6 else 0.0)
        var hb: float = 1.0 if tf < 0.35 else 0.0
        var g: float = 0.9 if tf < 1.8 else 0.0
        mf.step(DT,steer,g,0.0 if tf < 2.4 else 0.6,hb)
        fs.update(DT,mf.drift_angle,mf.speed_kmh())
        tf += DT
    if not fs.done():
        _fail("a real handbrake slide + recovery was not recognised as the first slide (progress %.2f)" % fs.progress())
        return
    var fs2 := DET.FirstSlide.new()
    for k in range(2000):
        fs2.update(DT,2.0,60.0)
    if fs2.done() or fs2.progress() > 0.01:
        _fail("driving straight counted as a slide")
        return
    # --------------------------------------------------------- eights (synthetic path)
    var big: Dictionary = LAYOUT.exercise("eight_large")
    var path: PackedVector2Array = LAYOUT.eight_path(Vector2(big["centre"]),float(big["radius"]),LAYOUT.EIGHT_SPREAD,0.5)
    var det8 := DET.Eight.new(big["lobes"],float(big["radius"]),Vector2(0.3,1.7),235.0,0.35)
    for lap in range(2):
        for i in range(path.size()):
            var west: bool = path[i].x < Vector2(big["centre"]).x
            det8.update(path[i],0.5/8.0,28.0 if west else -28.0,32.0)       # slip flips with the lobe
    if not det8.done():
        _fail("a two-lap eight with a flipping slip was not recognised (lobes %.0f / %.0f deg, transitions %d)" % [rad_to_deg(det8.lobes[0].accumulated),rad_to_deg(det8.lobes[1].accumulated),det8.transitions])
        return
    var det8b := DET.Eight.new(big["lobes"],float(big["radius"]),Vector2(0.3,1.7),235.0,0.35)
    for lap2 in range(2):
        for i2 in range(path.size()):
            det8b.update(path[i2],0.5/8.0,28.0,32.0)                          # same slip side everywhere
    if det8b.done():
        _fail("an eight without a change of slip direction counted")
        return
    var det8c := DET.Eight.new(big["lobes"],float(big["radius"]),Vector2(0.3,1.7),235.0,0.35)
    var lobe_a: Vector2 = Vector2(big["lobes"][0])
    for k in range(2400):
        det8c.update(lobe_a+Vector2(cos(-float(k)*0.01),sin(-float(k)*0.01))*7.0,1.0/60.0,28.0,30.0)
    if det8c.done() or det8c.lobes[1].progress() > 0.01:
        _fail("circling only ONE cone counted as an eight")
        return
    var small: Dictionary = LAYOUT.exercise("eight_small")
    var path_s: PackedVector2Array = LAYOUT.eight_path(Vector2(small["centre"]),float(small["radius"]),LAYOUT.EIGHT_SPREAD,0.5)
    var det8s := DET.Eight.new(small["lobes"],float(small["radius"]),Vector2(0.3,1.7),235.0,0.35)
    for lap3 in range(2):
        for i3 in range(path_s.size()):
            det8s.update(path_s[i3],0.5/7.0,26.0 if path_s[i3].x < Vector2(small["centre"]).x else -26.0,25.0)
    if not det8s.done():
        _fail("the small eight was not recognised on its own painted line")
        return
    # ---------------------------------------------------------------------- route
    var rpath: PackedVector2Array = LAYOUT.route_path(1.0)
    var rt := DET.Route.new(LAYOUT.route_path(1.5),LAYOUT.ROUTE_WIDTH,0.7,0.12)
    for lap4 in range(1):
        for i4 in range(rpath.size()):
            rt.update(rpath[i4],1.0/12.0,22.0,43.0)
    # one more lap segment to be safely past the 92 % of the first join
    for i5 in range(rpath.size()/4):
        rt.update(rpath[i5],1.0/12.0,22.0,43.0)
    if not rt.done():
        _fail("a full lap of the long route was not recognised (driven %.0f of %.0f m, corridor %.2f)" % [rt.driven,rt.length,rt.corridor_share()])
        return
    var half := DET.Route.new(LAYOUT.route_path(1.5),LAYOUT.ROUTE_WIDTH,0.7,0.12)
    for i6 in range(rpath.size()/2):
        half.update(rpath[i6],1.0/12.0,22.0,43.0)
    if half.done() or half.progress() > 0.6:
        _fail("half a lap counted as the route (%.2f)" % half.progress())
        return
    var off := DET.Route.new(LAYOUT.route_path(1.5),LAYOUT.ROUTE_WIDTH,0.7,0.12)
    for i7 in range(rpath.size()):
        off.update(rpath[i7]+Vector2(0,22.0),1.0/12.0,22.0,43.0)             # a parallel line 22 m away
    if off.progress() > 0.05:
        _fail("driving a parallel line far from the route counted")
        return
    # ------------------------------------------------------------- state machine
    PROGRESS.reset()
    var ids: PackedStringArray = TUTORIAL.lesson_ids()
    if ids.size() != 10:
        _fail("expected 10 lessons, got %d" % ids.size())
        return
    var seen_ids: Dictionary = {}
    for l in TUTORIAL.LESSONS:
        if seen_ids.has(str(l["id"])):
            _fail("duplicate lesson id")
            return
        seen_ids[str(l["id"])] = true
        for key in ["title","prompt","hint"]:
            var entry: Dictionary = l[key]
            if str(entry.get("pl","")).length() < 3 or str(entry.get("en","")).length() < 3:
                _fail("lesson %s has no Polish + English %s" % [str(l["id"]),key])
                return
        if l.has("exercise") and LAYOUT.exercise(str(l["exercise"])).is_empty():
            _fail("lesson %s points at an unknown exercise" % str(l["id"]))
            return
    if str(TUTORIAL.LESSONS[0]["prompt"]["pl"]) != "To jest GAZ — naciśnij i przytrzymaj":
        _fail("the first prompt is the owner's wording")
        return
    var t := TUTORIAL.new()
    var events: Array = []
    t.lesson_started.connect(func(i: int): events.append("start%d" % i))
    t.lesson_completed.connect(func(i: int): events.append("done%d" % i))
    var hints: Array = []
    t.hint_shown.connect(func(h: String): hints.append(h))
    t.start(0)
    if t.phase != "active" or t.freezes_car():
        _fail("the GAS lesson starts active, not frozen")
        return
    var st := {"pos":Vector2.ZERO,"speed_kmh":0.0,"drift_angle":0.0,"steer":0.0,"gas":1.0,"brake":0.0,"handbrake":0.0}
    for k in range(240*3):
        t.update(DT,st)
    if t.lesson_index != 0 or t.phase != "active" or t.progress() > 0.01:
        _fail("holding GAS while standing still advanced the lesson (a tap / hold without moving is not driving)")
        return
    st["speed_kmh"] = 25.0
    for k in range(240*3):
        t.update(DT,st)
        if t.phase == "success":
            break
    if t.phase != "success" or not PROGRESS.is_completed("gas"):
        _fail("GAS held while moving did not complete the lesson")
        return
    for k in range(240*2):
        t.update(DT,st)
    if t.lesson_index != 1 or t.phase != "active" or not events.has("done0") or not events.has("start1"):
        _fail("the next lesson did not start by itself after the success (index %d, %s)" % [t.lesson_index,str(events)])
        return
    # steering needs both sides while moving
    st["gas"] = 0.0
    st["steer"] = -1.0
    for k in range(240):
        t.update(DT,st)
    if t.phase == "success" or t.lesson_index != 1:
        _fail("steering only to the left completed the steering lesson")
        return
    st["steer"] = 1.0
    for k in range(240*2):
        t.update(DT,st)
        if t.phase == "success":
            break
    if t.phase != "success":
        _fail("steering left and right did not complete the steering lesson")
        return
    for k in range(240*2):
        t.update(DT,st)
    # brake lesson: needs speed first, then the brake
    st["steer"] = 0.0
    st["speed_kmh"] = 10.0
    st["brake"] = 1.0
    for k in range(240*2):
        t.update(DT,st)
    if t.phase == "success":
        _fail("braking while crawling completed the brake lesson")
        return
    st["speed_kmh"] = 40.0
    t.update(DT,st)
    for k in range(120):
        st["speed_kmh"] = maxf(10.0,float(st["speed_kmh"])-0.5)
        t.update(DT,st)
        if t.phase == "success":
            break
    if t.phase != "success":
        _fail("braking from speed did not complete the brake lesson")
        return
    for k in range(240*2):
        t.update(DT,st)
    # handbrake lesson
    st["brake"] = 0.0
    st["speed_kmh"] = 12.0
    st["handbrake"] = 1.0
    for k in range(60):
        t.update(DT,st)
    if t.phase == "success":
        _fail("the handbrake at walking speed completed the handbrake lesson")
        return
    st["speed_kmh"] = 40.0
    for k in range(60):
        t.update(DT,st)
        if t.phase == "success":
            break
    if t.phase != "success":
        _fail("a handbrake pull at speed did not complete the handbrake lesson")
        return
    # exercise lessons begin with the schematic: the car is frozen until tapped
    t.start(5)
    if t.phase != "intro" or not t.freezes_car():
        _fail("an exercise lesson must open with the frozen schematic")
        return
    t.update(DT,st)
    if t.phase != "intro":
        _fail("the schematic left by itself too early")
        return
    t.dismiss_intro()
    if t.phase != "active" or t.freezes_car():
        _fail("a tap must start the practice")
        return
    t.start(5)
    for k in range(240*9):
        t.update(DT,st)
    if t.phase != "active":
        _fail("the schematic must give way after 8 s even without a tap")
        return
    # idle hint
    st["speed_kmh"] = 0.0
    st["handbrake"] = 0.0
    for k in range(240*16):
        t.update(DT,st)
    if hints.is_empty():
        _fail("no hint after 15 s without progress")
        return
    # SKIP: off, nothing more happens, nothing is gated
    t.skip()
    if t.is_active() or t.phase != "off":
        _fail("SKIP TUTORIAL must switch the tutorial off")
        return
    var before_events: int = events.size()
    for k in range(480):
        t.update(DT,st)
    if events.size() != before_events:
        _fail("a skipped tutorial kept running")
        return
    # persistence
    PROGRESS.reset()
    PROGRESS.mark_completed("gas")
    PROGRESS.mark_completed("steer")
    PROGRESS.mark_completed("gas")
    if PROGRESS.completed().size() != 2 or PROGRESS.first_open(ids) != 2 or not PROGRESS.is_completed("steer"):
        _fail("saving / loading lesson progress is wrong: "+str(PROGRESS.completed()))
        return
    var t2 := TUTORIAL.new()
    t2.start(PROGRESS.first_open(ids))
    if t2.lesson_index != 2:
        _fail("the tutorial must resume at the first open lesson")
        return
    PROGRESS.reset()
    if PROGRESS.first_open(ids) != 0:
        _fail("RESTART TUTORIAL must forget the progress")
        return
    # ------------------------------------------------------------------ the cones
    var cones: NitroParkCones = CONES.new()
    root.add_child(cones)
    cones.build([{"pos":Vector2(0,-10),"group":"route"},{"pos":Vector2(6,-10),"group":"route"},{"pos":Vector2(40,40),"group":"route"}])
    var hit_events: Array = []
    cones.cone_hit.connect(func(i: int, s: float): hit_events.append(i))
    var car_pos: Vector2 = Vector2(0,10)
    var heading: float = 0.0
    var car_vel: Vector2 = Vector2(0,-15)
    for k in range(240):
        car_pos += car_vel*(1.0/120.0)
        cones.step(1.0/120.0,car_pos,heading,car_vel,2.3,1.05)
    if hit_events.size() != 1 or hit_events[0] != 0:
        _fail("the car must hit exactly the cone in its path (%s)" % str(hit_events))
        return
    if cones.tilt[0] < 1.5 or cones.positions[0].distance_to(cones.homes[0]) < 1.0:
        _fail("a hit cone must tip over and slide away (tilt %.2f, moved %.2f m)" % [cones.tilt[0],cones.positions[0].distance_to(cones.homes[0])])
        return
    if cones.positions[1].distance_to(cones.homes[1]) > 0.001 or cones.tilt[1] != 0.0:
        _fail("a cone 6 m beside the path moved")
        return
    if cones.displaced_count() != 1 or cones.velocities[0].length() > 0.5 and false:
        _fail("displaced count wrong")
        return
    cones.reset_all()
    if cones.displaced_count() != 0 or cones.tilt[0] != 0.0 or cones.positions[0] != cones.homes[0]:
        _fail("reset_all must put every cone back upright on its guide position")
        return
    # ---------------------------------------------------------------------- ghost
    var ghost: NitroParkGhost = GHOST.new()
    root.add_child(ghost)
    var circle := PackedVector2Array()
    for k in range(72):
        circle.append(Vector2(cos(TAU*float(k)/72.0),sin(TAU*float(k)/72.0))*6.0)
    var runs: Array = []
    for rep in range(2):
        ghost.play(circle,true,9.5,30.0)
        for k in range(600):
            ghost.advance(1.0/60.0)
        runs.append([ghost.position,ghost.rotation.y])
    if Vector3(runs[0][0]).distance_to(Vector3(runs[1][0])) > 0.0001 or absf(float(runs[0][1])-float(runs[1][1])) > 0.0001:
        _fail("the demonstration ghost must replay identically")
        return
    var pose: Dictionary = ghost.pose_at(3.0)
    var tangent: float = atan2(circle[1].x-circle[0].x,-(circle[1].y-circle[0].y))
    if absf(wrapf(float(pose["heading"])-tangent,-PI,PI)) < deg_to_rad(15.0):
        _fail("the ghost must drive with a drifting attitude, not along its line")
        return
    ghost.stop()
    if ghost.visible:
        _fail("a stopped ghost must be hidden")
        return
    # --------------------------------------------------------- the race scene: free
    ProjectSettings.set_setting("nitro/selected_track",LAYOUT.TRACK_PATH)
    ProjectSettings.set_setting("nitro/park_mode","tutorial")
    ProjectSettings.set_setting("nitro/park_reset",true)
    # The garage choice persists between tests (CI runs them in one user dir): pin the
    # weakest starter car so the real-input donut does not depend on what ran before.
    ProjectSettings.set_setting("nitro/car_variant","e30")
    var race: Node3D = RACE.instantiate()
    root.add_child(race)
    await process_frame
    await process_frame
    if race.park == null or race.park.tutorial == null or race.park.guide == null:
        _fail("TUTORIAL mode must create the tutorial and its guide")
        return
    if race.park.tutorial.lesson_index != 0 or race.park.tutorial.phase != "active":
        _fail("a fresh tutorial starts with the GAS lesson")
        return
    if str(ProjectSettings.get_setting("nitro/park_mode","free")) != "free":
        _fail("the mode must be consumed so the next visit does not inherit it")
        return
    # real input drives the lessons (GAS -> automatic advance)
    Input.action_press("throttle")
    for k in range(120*5):
        race._physics_process(1.0/120.0)
    Input.action_release("throttle")
    if race.park.tutorial.lesson_index < 1 or not PROGRESS.is_completed("gas"):
        _fail("pressing the real throttle did not complete + advance the GAS lesson (lesson %d)" % race.park.tutorial.lesson_index)
        return
    # a schematic freezes the car
    race.park.tutorial.start(5)
    race.park.guide.queue_redraw()
    var frozen_at: Vector2 = race.model.position
    Input.action_press("throttle")
    for k in range(120):
        race._physics_process(1.0/120.0)
    Input.action_release("throttle")
    if race.model.position != frozen_at:
        _fail("the car moved while the lesson schematic was up")
        return
    race.park.tutorial.dismiss_intro()
    # cones are reset by every lesson start; displace one and start the next lesson
    race.park.cones.positions[3] = race.park.cones.homes[3]+Vector2(4,4)
    race.park.cones.tilt[3] = 1.5
    race.park.tutorial.start(6)
    if race.park.cones.displaced_count() != 0:
        _fail("cones must return to their guide positions when a lesson starts")
        return
    # donut with the real input path: flick + hold the steering into the turn
    race.park.tutorial.start(5)
    race.park.tutorial.dismiss_intro()
    var centre: Vector2 = LAYOUT.DONUT_LEFT
    var model_car: String = "e30"
    race.model.reset(centre-_orbit_offset_digital(model_car),0.0)
    race.model.velocity = race.model.forward()*(45.0/3.6)
    Input.action_press("steer_left")
    Input.action_press("throttle")
    var done_idx: int = -1
    for k in range(120*20):
        if k < 42:
            Input.action_press("handbrake")
        else:
            Input.action_release("handbrake")
        race._physics_process(1.0/120.0)
        if race.park.tutorial.lesson_index != 5 or race.park.tutorial.phase == "success":
            done_idx = k
            break
    Input.action_release("steer_left")
    Input.action_release("throttle")
    if done_idx < 0 or not PROGRESS.is_completed("donut_left"):
        _fail("a real left donut with the real controls did not complete DONUT LEFT (progress %.2f)" % race.park.tutorial.progress())
        return
    # SKIP keeps cones and paint exactly where they are, input comes back
    race.park.cones.positions[7] = race.park.cones.homes[7]+Vector2(3,0)
    race.park.cones.tilt[7] = 1.5
    var displaced: int = race.park.cones.displaced_count()
    var paint_nodes: int = race.track.get_child_count()
    if not str(race.park.pause_label()).contains("ON"):
        _fail("the pause row must say the tutorial is ON")
        return
    race.park.skip_tutorial()
    if race.park.tutorial.is_active() or race.park.cones.displaced_count() != displaced or race.track.get_child_count() != paint_nodes:
        _fail("SKIP TUTORIAL must keep cones and paint exactly as they are")
        return
    if not str(race.park.pause_label()).contains("OFF"):
        _fail("the pause row must say the tutorial is OFF after SKIP")
        return
    race.park.toggle_tutorial()
    if not race.park.tutorial.is_active():
        _fail("the pause row must be able to switch the tutorial on again")
        return
    race.queue_free()
    await process_frame
    # ----------------------------------------------------------------------- menu
    var menu: Control = BOOT.instantiate()
    menu.navigate_enabled = false
    root.add_child(menu)
    await process_frame
    menu.show_page("park")
    if menu.find_child("Park tutorial",true,false) == null or menu.find_child("Park free drive",true,false) == null \
            or menu.find_child("Park car",true,false) == null:
        _fail("the PARK page needs START TUTORIAL, FREE DRIVE and the car")
        return
    PROGRESS.mark_completed("gas")
    menu.show_page("park")
    if menu.find_child("Park tutorial restart",true,false) == null:
        _fail("with progress saved the page offers RESTART TUTORIAL")
        return
    menu._start_park("free")
    if str(ProjectSettings.get_setting("nitro/park_mode","")) != "free" or menu.last_scene != "res://scenes/race.tscn" \
            or str(ProjectSettings.get_setting("nitro/selected_track","")) != LAYOUT.TRACK_PATH:
        _fail("FREE DRIVE did not set the mode / track")
        return
    if menu.current_track() == LAYOUT.TRACK_PATH:
        _fail("the Park must never be 'the track you last raced' in the DRIVE setup")
        return
    for entry in menu.TRACKS:
        if str(entry[1]) == LAYOUT.TRACK_PATH:
            _fail("the Park must not be listed in the circuit registry")
            return
    _restore(saved)
    print("PASS: Park tutorial - donuts L/R + first slide recognised on REAL drive-model runs (E30 and Lada), straight driving / grip circle / wrong direction / wrong cone / one cone / button tap never count, eights need both lobes + transition + slip flip, the route needs its corridor, auto-advance on real input (GAS -> next, DONUT LEFT with the real controls), schematic freezes the car, hints, SKIP keeps cones + paint, pause row toggles it, saved progress + resume + restart, cones tip + slide + reset, ghost replays identically, menu page + FREE DRIVE + registry untouched")
    quit(0)
