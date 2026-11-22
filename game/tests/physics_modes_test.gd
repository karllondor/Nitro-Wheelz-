extends SceneTree
## Issue #25 (owner decision c7080962400): physics modes.
##  ARCADE_PLUS (default, "C+"): the approved arcade handling, the SAME 0-100 km/h, a documented per-car
##    top speed. Below the knee (100.8 km/h) the model is bit-identical to the calibrated tune.
##  REAL_POWER_TEST ("A", DEVELOPER only): power curve + game-shifted gears + real drag; steering / grip /
##    drift stay arcade; never writes a record, star or score.
## The test pins the mode and restores it (the dev config lives in user:// and is shared with other tests).
const DRIVE = preload("res://scripts/driving/drive_model.gd")
const CARS = preload("res://scripts/vehicles/car_catalog.gd")
const RESULTS = preload("res://scripts/ui/race_results.gd")
const BOOT = preload("res://scenes/boot.tscn")
const DT: float = 1.0/240.0
const ID: String = "qa_physics_modes"

var _mode_before: String = ""
var _forced_before: bool = false

func _initialize() -> void:
    _mode_before = CARS.physics_mode()
    _forced_before = CARS.baseline_physics_forced()
    CARS.set_baseline_physics_forced(false)
    CARS.set_physics_mode(CARS.MODE_ARCADE_PLUS)
    call_deferred("_run")

func _fail(message: String) -> void:
    CARS.set_physics_mode(_mode_before)
    CARS.set_baseline_physics_forced(_forced_before)
    printerr("FAIL: "+message)
    quit(1)

func _model(variant: String, mode: String):
    var m = DRIVE.new()
    CARS.configure_model(m,variant,mode)
    m.reset(Vector2.ZERO,0.0)
    return m

## Drive a model that is already doing `kmh` straight ahead; inputs come from `script(t) -> [steer, gas, brake, hb]`.
func _drive(m, kmh: float, seconds: float, script: Callable) -> Dictionary:
    m.reset(Vector2.ZERO,0.0)
    m.velocity = m.forward()*kmh/3.6
    var t: float = 0.0
    var max_drift: float = 0.0
    var max_yaw: float = 0.0
    var finite: bool = true
    while t < seconds:
        var i: Array = script.call(t)
        m.step(DT,i[0],i[1],i[2],i[3])
        t += DT
        max_drift = maxf(max_drift,absf(m.drift_angle))
        max_yaw = maxf(max_yaw,absf(m.yaw_rate))
        if is_nan(m.position.x) or is_nan(m.velocity.x) or is_nan(m.heading) or is_inf(m.velocity.x):
            finite = false
    return {"drift":max_drift,"yaw":max_yaw,"finite":finite,"end_drift":absf(m.drift_angle),"end_kmh":m.speed_kmh(),"end_yaw":absf(m.yaw_rate)}

func _run() -> void:
    # 1) Default mode and the configuration of each mode.
    if CARS.physics_mode() != CARS.MODE_ARCADE_PLUS:
        _fail("the default physics mode must be ARCADE_PLUS")
        return
    for variant in CARS.ORDER:
        var plus = _model(variant,CARS.MODE_ARCADE_PLUS)
        var real = _model(variant,CARS.MODE_REAL_POWER)
        if plus.real != null or plus.drag_knee_mps > 40.0 or plus.drag_high_scale >= 1.0 or plus.top_speed_mps < 55.0:
            _fail("%s: ARCADE_PLUS must set the drag knee / scale / top speed and no power-curve drivetrain" % variant)
            return
        if real.real == null or real.drag_knee_mps < 1.0e8:
            _fail("%s: REAL_POWER_TEST must attach the power-curve drivetrain and not the C+ drag" % variant)
            return
        var rp: Dictionary = CARS.real_power(variant)
        var peak: float = real.real.peak_power_ps()
        if absf(peak-float(rp["power_ps"]))/float(rp["power_ps"]) > 0.02:
            _fail("%s: the torque table peaks at %.0f PS, the profile says %.0f PS" % [variant,peak,float(rp["power_ps"])])
            return
    # Published torque points (see the provenance in the profiles): the table passes through them.
    var rx = _model("red",CARS.MODE_REAL_POWER).real
    var n20 = _model("white",CARS.MODE_REAL_POWER).real
    var m52 = _model("e30",CARS.MODE_REAL_POWER).real
    var v8 = _model("blue",CARS.MODE_REAL_POWER).real
    if absf(rx.torque_at(5500.0)-211.0) > 1.0 or absf(rx.engine_power(8200.0)/735.5-231.0) > 3.0:
        _fail("13B table must pass through 211 Nm @ 5,500 and 231 PS @ 8,200 rpm")
        return
    if absf(m52.torque_at(3950.0)-280.0) > 1.0 or absf(m52.engine_power(5300.0)/735.5-193.0) > 3.0:
        _fail("M52B28 table must pass through 280 Nm @ 3,950 and 193 PS @ 5,300 rpm")
        return
    if absf(n20.torque_at(3000.0)-410.0) > 1.0 or n20.peak_power_ps() < 270.0 or n20.peak_power_ps() > 280.0 or n20.torque_at(3000.0) <= 350.0:
        _fail("tuned N20 table: 410 Nm plateau (stock 350) and about 275 PS")
        return
    if absf(v8.torque_at(4000.0)-400.0) > 1.0 or absf(v8.peak_power_ps()-350.0) > 5.0:
        _fail("RYU-32 table: 400 Nm and 350 PS (owner reference)")
        return

    # 2) ARCADE_PLUS == the calibrated tune below the knee: identical trace, every car (speed kept < 90 km/h).
    var limited := func(t: float) -> Array:
        return [0.0,1.0,0.0,0.0] if t < 1.5 else ([0.7,1.0,0.0,1.0 if t < 2.0 else 0.0] if t < 3.5 else [-0.5,0.7,0.0,0.0])
    for variant in CARS.ORDER:
        var base = DRIVE.new()
        base.apply_profile(CARS.profile(variant).get("handling",{}))
        var plus = _model(variant,CARS.MODE_ARCADE_PLUS)
        base.reset(Vector2.ZERO,0.0)
        var worst: float = 0.0
        var top: float = 0.0
        for k in range(int(8.0/DT)):
            var i: Array = limited.call(float(k)*DT)
            base.step(DT,i[0],i[1],i[2],i[3])
            plus.step(DT,i[0],i[1],i[2],i[3])
            top = maxf(top,plus.speed_kmh())
            worst = maxf(worst,(base.position-plus.position).length()+absf(base.heading-plus.heading))
        if top > 100.0:
            _fail("%s: the identity run must stay below the knee (reached %.1f km/h)" % [variant,top])
            return
        if worst > 1.0e-9:
            _fail("%s: ARCADE_PLUS differs from the calibrated tune below the knee by %.3e" % [variant,worst])
            return

    # 3) REAL_POWER_TEST: gearbox, launch, limiter, ordering, slower than C+ to 100 km/h.
    var ab: Dictionary = {}
    for variant in ["red","white","e30","blue"]:
        var m = _model(variant,CARS.MODE_REAL_POWER)
        var t: float = 0.0
        var t60: float = -1.0
        var t100: float = -1.0
        var gear_changes: int = 0
        var last_gear: int = m.real.gear
        var top: float = 0.0
        while t < 60.0:
            m.step(DT,0.0,1.0,0.0,0.0)
            t += DT
            top = maxf(top,m.speed_kmh())
            if t60 < 0.0 and m.speed_kmh() >= 60.0:
                t60 = t
            if t100 < 0.0 and m.speed_kmh() >= 100.0:
                t100 = t
            if m.real.gear != last_gear:
                gear_changes += 1
                last_gear = m.real.gear
        var limit: float = m.real.limiter_speed_kmh()
        ab[variant] = [t60,t100,top,limit,gear_changes]
        if gear_changes != 4 or m.real.gear_number() != 5:
            _fail("%s: a full-throttle run must shift up exactly 4 times into 5th, got %d changes, gear %d" % [variant,gear_changes,m.real.gear_number()])
            return
        if t60 < 3.0 or t60 > 4.0:
            _fail("%s: 0-60 km/h in REAL_POWER_TEST is traction limited (about 3.4 s), got %.2f s" % [variant,t60])
            return
        if t100 < 5.3 or t100 > 7.0:
            _fail("%s: REAL_POWER_TEST 0-100 km/h must be credible for the build (5.3-7.0 s), got %.2f s" % [variant,t100])
            return
        if top > limit*1.005 or top < limit*0.97:
            _fail("%s: top speed %.1f km/h must sit at the limiter speed %.1f km/h (power exceeds drag there)" % [variant,top,limit])
            return
        var plus = _model(variant,CARS.MODE_ARCADE_PLUS)
        var tp: float = 0.0
        while plus.speed_kmh() < 100.0 and tp < 30.0:
            plus.step(DT,0.0,1.0,0.0,0.0)
            tp += DT
        if not (t100 > tp+1.5):
            _fail("%s: REAL_POWER_TEST must NOT be quicker to 100 km/h than ARCADE_PLUS (A %.2f s vs C+ %.2f s)" % [variant,t100,tp])
            return
    if not (float(ab["white"][1]) < float(ab["red"][1]) and float(ab["white"][2]) <= float(ab["red"][2]+3.0)):
        _fail("the tuned N20 (275 PS) must be quicker to 100 km/h than the 13B (231 PS) in REAL_POWER_TEST: "+str(ab))
        return
    if not (float(ab["blue"][1]) < float(ab["e30"][1]) and float(ab["red"][1]) < float(ab["e30"][1])):
        _fail("REAL_POWER_TEST ordering by power-to-weight on 0-100 km/h broke: "+str(ab))
        return
    # No gear hunting on a lift, brake and re-accelerate cycle; engine braking slows the car.
    var cyc = _model("red",CARS.MODE_REAL_POWER)
    var changes: int = 0
    var g0: int = cyc.real.gear
    for k in range(int(30.0/DT)):
        var tt: float = float(k)*DT
        var gas: float = 1.0 if tt < 8.0 else (0.0 if tt < 12.0 else 1.0)
        var brk: float = 1.0 if tt >= 12.0 and tt < 14.0 else 0.0
        cyc.step(DT,0.0,gas,brk,0.0)
        if cyc.real.gear != g0:
            changes += 1
            g0 = cyc.real.gear
    if changes > 12:
        _fail("gear hunting: %d gear changes in a lift / brake / re-accelerate cycle" % changes)
        return
    var coast = _model("red",CARS.MODE_REAL_POWER)
    coast.velocity = coast.forward()*(120.0/3.6)
    for k in range(int(2.0/DT)):
        coast.step(DT,0.0,0.0,0.0,0.0)
    if coast.speed_kmh() > 120.0-2.0 or coast.speed_kmh() < 120.0-25.0:
        _fail("engine braking + real drag over 2 s of lift-off should shed 2-25 km/h from 120, got %.1f" % (120.0-coast.speed_kmh()))
        return

    # 4) Handling at high speed stays stable in both modes (the arcade lateral model was tuned below ~130 km/h).
    var coasting := func(_t: float) -> Array: return [0.0,0.0,0.0,0.0]
    var lane := func(t: float) -> Array:
        return [0.5 if t < 0.5 else (-0.5 if t < 1.0 else 0.0),0.6,0.0,0.0]
    var hb := func(t: float) -> Array:
        return [0.5 if t < 0.7 else 0.0,0.0,0.0,1.0 if t < 0.6 else 0.0]
    var report: PackedStringArray = []
    for mode in CARS.MODES:
        for variant in ["red","white","e30","blue"]:
            var top_kmh: float = float((CARS.profile(variant)["arcade_plus"] as Dictionary)["top_kmh"])
            for kmh in [150.0,top_kmh-5.0]:
                var s1: Dictionary = _drive(_model(variant,mode),kmh,3.0,coasting)
                var s2: Dictionary = _drive(_model(variant,mode),kmh,6.0,lane)
                var s3: Dictionary = _drive(_model(variant,mode),kmh,9.0,hb)
                if not (s1["finite"] and s2["finite"] and s3["finite"]):
                    _fail("%s %s at %.0f km/h: the model produced NaN / infinity" % [variant,mode,kmh])
                    return
                if float(s1["drift"]) > 1.0 or float(s1["yaw"]) > 0.02:
                    _fail("%s %s at %.0f km/h: a straight, hands-off car must stay straight (drift %.2f deg, yaw %.3f)" % [variant,mode,kmh,s1["drift"],s1["yaw"]])
                    return
                if float(s2["drift"]) > 30.0 or float(s2["yaw"]) > 2.0 or float(s2["end_drift"]) > 8.0:
                    _fail("%s %s at %.0f km/h: a lane change must not spin the car (max drift %.1f deg, max yaw %.2f rad/s, 5 s later %.1f deg)" % [variant,mode,kmh,s2["drift"],s2["yaw"],s2["end_drift"]])
                    return
                if float(s3["drift"]) < 5.0 or float(s3["drift"]) > 70.0 or float(s3["end_drift"]) > 12.0 or float(s3["end_kmh"]) > kmh+2.0:
                    _fail("%s %s at %.0f km/h: a handbrake tap must slide and recover (max %.1f deg, after 8 s %.1f deg, %.0f km/h)" % [variant,mode,kmh,s3["drift"],s3["end_drift"],s3["end_kmh"]])
                    return
                report.append("%s/%s@%.0f lane %.1f/%.2f hb %.1f/%.1f" % [variant,mode.substr(0,2),kmh,s2["drift"],s2["yaw"],s3["drift"],s3["end_drift"]])

    # 5) Developer switch on the DEVELOPER page; A never saves a record (the run is shown, not stored).
    var menu: Control = BOOT.instantiate()
    root.add_child(menu)
    await process_frame
    menu.call("show_page","dev")
    await process_frame
    var btn: Button = menu.find_child("Physics mode",true,false)
    if btn == null or not btn.text.contains("ARCADE_PLUS") or not btn.text.contains("ACTIVE PHYSICS MODE"):
        _fail("DEVELOPER must show 'ACTIVE PHYSICS MODE: ARCADE_PLUS' (default)")
        return
    btn.pressed.emit()
    await process_frame
    await process_frame
    if CARS.physics_mode() != CARS.MODE_REAL_POWER:
        _fail("the DEVELOPER row must switch to REAL_POWER_TEST")
        return
    var btn2: Button = menu.find_child("Physics mode",true,false)
    if btn2 == null or not btn2.text.contains("REAL_POWER_TEST") or not btn2.text.contains("NOT SAVED"):
        _fail("DEVELOPER must say that REAL_POWER_TEST runs are not saved")
        return
    menu.queue_free()
    await process_frame
    if RESULTS.record_allowed():
        _fail("records must not be allowed in REAL_POWER_TEST")
        return
    var runs_before: int = RESULTS.read_runs().size()
    var view: Control = RESULTS.new()
    root.add_child(view)
    view.show_race(ID,"QA",61.9,7680,90.0,func(): pass,func(): pass,{"length_m":700.0})
    await process_frame
    if RESULTS.read_runs().size() != runs_before or bool(view.data.get("stored",true)) or not bool(view.data.get("diagnostic",false)):
        _fail("a REAL_POWER_TEST run must not be stored (runs %d -> %d)" % [runs_before,RESULTS.read_runs().size()])
        return
    view.queue_free()
    await process_frame
    CARS.set_physics_mode(CARS.MODE_ARCADE_PLUS)
    if not RESULTS.record_allowed():
        _fail("records must be allowed in ARCADE_PLUS")
        return
    # Baseline switch wins over both modes (the way back to the old equal-performance behaviour).
    CARS.set_baseline_physics_forced(true)
    CARS.set_physics_mode(CARS.MODE_REAL_POWER)
    var forced = _model("red",CARS.MODE_REAL_POWER)
    if forced.real != null or CARS.real_power_active():
        _fail("DEVELOPER > BASELINE PHYSICS must switch the power-curve drivetrain off")
        return
    CARS.set_physics_mode(_mode_before)
    CARS.set_baseline_physics_forced(_forced_before)
    print("PASS: ARCADE_PLUS is the default and bit-identical to the calibrated tune below 100 km/h, REAL_POWER_TEST shifts 4 times to 5th, is traction limited at launch (0-60 about 3.4 s), slower than C+ to 100 km/h, peaks at the limiter speed; torque tables pass through the published points; both modes stable at 150 km/h and at top speed (lane change, handbrake, hands off); DEVELOPER switch + not saved: "+" | ".join(report.slice(0,6)))
    print("NOT RUN: the feel of either mode on the owner's phone")
    quit(0)
