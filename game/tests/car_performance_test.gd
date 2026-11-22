extends SceneTree
## v0.1.36 (owner decision 2026-11-22: "calibrate the cars by the real
## power-to-weight ratio - that is how it should have been from the start").
##
## The law (docs/CAR_PROFILES.md): the red / white Lada 2106 with its 13B rotary
## is the anchor (231 PS / 1,150 kg = 201 PS/t, 0-100 km/h 3.29 s, 127.8 km/h:
## the approved drive model). Every other car is scaled from it:
##   0-100 km/h time  ~  1 / (power-to-weight)            (first-order physics)
##   top speed        ~  (power-to-weight) ^ (1/3)        (drag-limited speed)
## Each profile lists its power and mass in a "performance" block (facts and
## estimates are named in the profile). The drive model is measured on a scripted
## full-throttle run and must land inside the tolerance of the target.
const DRIVE = preload("res://scripts/driving/drive_model.gd")
const CARS = preload("res://scripts/vehicles/car_catalog.gd")
const DT: float = 1.0/240.0

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    printerr("FAIL: "+message)
    quit(1)

## 0-100 km/h time and top speed of a full-throttle straight with the given handling numbers.
func _measure_h(h: Dictionary, seconds: float = 45.0) -> Array:
    var m = DRIVE.new()
    m.apply_profile(h)
    m.reset(Vector2.ZERO,0.0)
    var t: float = 0.0
    var t100: float = -1.0
    var top: float = 0.0
    while t < seconds:
        m.step(DT,0.0,1.0,0.0,0.0)
        t += DT
        if t100 < 0.0 and m.speed_kmh() >= 100.0:
            t100 = t
        top = maxf(top,m.speed_kmh())
    return [t100,top]

## The v0.1.36 arcade tune of a car (the profile's handling WITHOUT the ARCADE_PLUS additions):
## what the power-to-weight law calibrates.
func _measure(variant: String) -> Array:
    return _measure_h(CARS.profile(variant).get("handling",{}))

func _run() -> void:
    var forced: bool = CARS.baseline_physics_forced()
    CARS.set_baseline_physics_forced(false)
    var ref: Dictionary = (CARS.profile("red")["performance"] as Dictionary)
    var ref_pw: float = float(ref["power_ps"])/(float(ref["mass_kg"])/1000.0)
    var ref_m: Array = _measure("red")
    if absf(float(ref_m[0])-3.29) > 0.01 or absf(float(ref_m[1])-127.8) > 0.1:
        _fail("the anchor moved: Lada 0-100 %.2f s, top %.1f km/h (must stay 3.29 s / 127.8 km/h)" % [ref_m[0],ref_m[1]])
        return
    var tolerance: Dictionary = {"red":0.0,"white":0.03,"e30":0.03,"blue":0.12,"flame":0.12}
    var rows: PackedStringArray = []
    var results: Dictionary = {}
    for variant in CARS.ORDER:
        var prof: Dictionary = CARS.profile(variant)
        if not prof.has("performance"):
            _fail("%s: the profile has no performance block (power, mass)" % variant)
            return
        var perf: Dictionary = prof["performance"]
        var pw: float = float(perf["power_ps"])/(float(perf["mass_kg"])/1000.0)
        if absf(pw-float(perf["power_to_weight_ps_per_t"])) > 1.0:
            _fail("%s: power_to_weight_ps_per_t %.0f does not match power / mass (%.0f)" % [variant,float(perf["power_to_weight_ps_per_t"]),pw])
            return
        var t_target: float = float(ref_m[0])*ref_pw/pw
        var v_target: float = float(ref_m[1])*pow(pw/ref_pw,1.0/3.0)
        var m: Array = _measure(variant)
        results[variant] = m
        var dt_rel: float = float(m[0])/t_target-1.0
        var dv_rel: float = float(m[1])/v_target-1.0
        var tol: float = float(tolerance.get(variant,0.12))
        rows.append("%s %.0f PS/t: 0-100 %.2f s (target %.2f, %+.0f%%), top %.1f km/h (target %.1f, %+.0f%%)" % [variant,pw,m[0],t_target,dt_rel*100.0,m[1],v_target,dv_rel*100.0])
        if absf(dt_rel) > maxf(tol,0.005) or absf(dv_rel) > maxf(tol,0.005):
            _fail("%s is off the power-to-weight target by more than %.0f%%: %s" % [variant,tol*100.0,rows[rows.size()-1]])
            return
    # More power-to-weight must mean quicker and faster, across the catalog.
    # The tuned N20 Lada (275 PS) is quicker than the 13B Lada (231 PS) on the same body.
    if not (float((results["white"] as Array)[0]) < float((results["red"] as Array)[0])):
        _fail("white (N20 275 PS) must beat red (13B 231 PS) on 0-100")
        return
    var order: Array = ["blue","red","e30"]
    for i in range(order.size()-1):
        var a: Array = results[order[i]]
        var b: Array = results[order[i+1]]
        if not (float(a[0]) < float(b[0]) and float(a[1]) > float(b[1])):
            _fail("%s must beat %s on 0-100 and top speed" % [order[i],order[i+1]])
            return
    # v0.1.38 ARCADE_PLUS (default mode): 0-100 km/h is the SAME as the calibrated tune, and the top
    # speed is the documented per-car target (reached within a minute, drag-limited, never beyond).
    var plus_rows: PackedStringArray = []
    if CARS.physics_mode() != CARS.MODE_ARCADE_PLUS:
        _fail("ARCADE_PLUS must be the default physics mode, got "+CARS.physics_mode())
        return
    for variant in CARS.ORDER:
        var target: float = float((CARS.profile(variant).get("arcade_plus",{}) as Dictionary).get("top_kmh",0.0))
        if target <= 0.0:
            _fail("%s: the profile has no ARCADE_PLUS top_kmh target" % variant)
            return
        var plus: Array = _measure_h(CARS.handling(variant),120.0)
        var base_m: Array = results[variant]
        if absf(float(plus[0])-float(base_m[0])) > 0.005:
            _fail("%s: ARCADE_PLUS changed the 0-100 time (%.3f s vs %.3f s); it must only lift the top speed" % [variant,plus[0],base_m[0]])
            return
        if float(plus[1]) < target*0.985 or float(plus[1]) > target*1.003:
            _fail("%s: ARCADE_PLUS top speed %.1f km/h is not the target %.0f km/h (98.5-100.3 %%)" % [variant,plus[1],target])
            return
        if float(plus[1]) < float(base_m[1])+30.0:
            _fail("%s: ARCADE_PLUS must lift the top speed by far more than 30 km/h (was %.1f, now %.1f)" % [variant,base_m[1],plus[1]])
            return
        plus_rows.append("%s %.1f -> %.1f km/h (target %.0f)" % [variant,base_m[1],plus[1],target])
    CARS.set_baseline_physics_forced(forced)
    print("PASS: ARCADE_PLUS top speeds (0-100 unchanged): "+" | ".join(plus_rows))
    print("PASS: car performance follows power-to-weight (anchor Lada 13B 201 PS/t = 3.29 s / 127.8 km/h; 0-100 ~ 1/PW, top ~ PW^(1/3)): "+" | ".join(rows))
    quit(0)
