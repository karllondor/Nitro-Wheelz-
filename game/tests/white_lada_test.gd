extends SceneTree
## WHITE Lada 2106 = lightly tuned BMW N20B20 single-turbo inline-four from the first moment
## (owner decision 2026-11-22, #25 c7081083460 / #26 c7081085893): its own profile, sound, card text and
## acceleration, independent of the RED Lada's Mazda 13B rotary. Not a progression gate, no second turbo.
const DRIVE = preload("res://scripts/driving/drive_model.gd")
const CARS = preload("res://scripts/vehicles/car_catalog.gd")
const SYNTH = preload("res://scripts/audio/engine_synth.gd")
const DT: float = 1.0/240.0

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

func _t100(m) -> float:
    var t: float = 0.0
    while m.speed_kmh() < 100.0 and t < 40.0:
        m.step(DT,0.0,1.0,0.0,0.0)
        t += DT
    return t

func _t_between(m, a: float, b: float) -> float:
    var t: float = 0.0
    var ta: float = -1.0
    while m.speed_kmh() < b and t < 60.0:
        m.step(DT,0.0,1.0,0.0,0.0)
        t += DT
        if ta < 0.0 and m.speed_kmh() >= a:
            ta = t
    return t-ta

func _rms(a: PackedVector2Array) -> float:
    var acc: float = 0.0
    for v in a:
        acc += v.x*v.x
    return sqrt(acc/maxf(float(a.size()),1.0))

func _render(engine: Dictionary, speed: float, gas: float, seconds: float, lift_after: float = -1.0) -> Dictionary:
    var s = SYNTH.new()
    s.apply_profile(engine)
    var out := PackedVector2Array()
    var t: float = 0.0
    while t < seconds:
        var g: float = gas if (lift_after < 0.0 or t < lift_after) else 0.0
        s.set_state(speed,g,0.0,1.0/60.0)
        out.append_array(s.render(368))
        t += 1.0/60.0
    return {"synth":s,"audio":out}

func _run() -> void:
    # 1) The profile: own file, N20B20 facts vs estimates, the owner's constraints.
    var info: Dictionary = CARS.info("white")
    var prof: Dictionary = CARS.profile("white")
    var red: Dictionary = CARS.profile("red")
    if str(prof.get("id","")) != "lada_n20" or not str(info["note"]).contains("N20B20") or not str(info["note"]).contains("TURBO"):
        _fail("white must be the N20B20 TURBO car (profile lada_n20, card text)")
        return
    if str(red.get("id","")) != "lada_13b" or str(CARS.profile("red")["engine"]["layout"]).contains("TURBO"):
        _fail("the RED Lada must stay the 13B rotary")
        return
    var perf: Dictionary = prof["performance"]
    if int(perf["power_ps"]) != 275 or int(perf["stock_power_ps"]) != 245 or int(perf["mass_kg"]) != 1150:
        _fail("white performance block: 275 PS tuned (245 PS stock), 1,150 kg estimate")
        return
    var prov: Dictionary = prof["provenance"]
    for key in ["confirmed","estimates","missing"]:
        if not prov.has(key) or (prov[key] as Array).is_empty():
            _fail("white provenance must list what is "+key)
            return
    var role: String = str(prof["role"])
    var text: String = JSON.stringify(prof)
    if not role.contains("NOT stock") or not role.contains("NO second turbo") or not role.contains("NOT gated by stars"):
        _fail("white role must say: tuned from the start (not stock), no second turbo, not gated by stars")
        return
    if not text.contains("245 PS") or not text.contains("350 Nm"):
        _fail("white profile must state the stock N20B20 figures (245 PS / 350 Nm)")
        return
    var eng: Dictionary = prof["engine"]
    if int(eng["cylinders"]) != 4 or not str(eng["layout"]).contains("N20") or not eng.has("turbo"):
        _fail("white engine block: four cylinders, N20 layout, turbo layer")
        return
    for variant in ["red","e30","blue","flame"]:
        if CARS.engine(variant).has("turbo"):
            _fail("only the white Lada has the turbo sound layer (%s must not)" % variant)
            return
    # The tuned engine is a genuine step up from the donor (stock 350 Nm plateau, 245 PS).
    var rp = _model("white",CARS.MODE_REAL_POWER).real
    if rp.torque_at(3000.0) < 400.0 or rp.peak_power_ps() < 265.0 or rp.peak_power_ps() > 285.0:
        _fail("white tuned curve: 400+ Nm plateau and 265-285 PS (Stage 1, not a wild build)")
        return
    # Gear table of the physics = the one of the sound (single source).
    if (CARS.real_power("white")["gear_top_kmh"] as Array) != (eng["gear_top_kmh"] as Array):
        _fail("physics and sound must share one gear table")
        return

    # 2) Performance: different from the red 13B in both modes (the same chassis, other power).
    var plus_white: float = _t100(_model("white",CARS.MODE_ARCADE_PLUS))
    var plus_red: float = _t100(_model("red",CARS.MODE_ARCADE_PLUS))
    var a_white: float = _t100(_model("white",CARS.MODE_REAL_POWER))
    var a_red: float = _t100(_model("red",CARS.MODE_REAL_POWER))
    if absf(plus_white-2.76) > 0.03 or plus_red < plus_white+0.4:
        _fail("ARCADE_PLUS 0-100: white must be 2.76 s and clearly quicker than red (%.2f / %.2f)" % [plus_white,plus_red])
        return
    if a_red < a_white+0.15:
        _fail("REAL_POWER_TEST 0-100: white must beat red by 0.15 s or more (%.2f / %.2f)" % [a_white,a_red])
        return
    var mid_w: float = _t_between(_model("white",CARS.MODE_REAL_POWER),60.0,120.0)
    var mid_r: float = _t_between(_model("red",CARS.MODE_REAL_POWER),60.0,120.0)
    if mid_r < mid_w+0.35:
        _fail("REAL_POWER_TEST 60-120 km/h: the torquey N20 must pull clearly harder than the 13B (%.2f / %.2f s)" % [mid_w,mid_r])
        return

    # 3) Sound: a compressor whistle that rises with boost, silent when the throttle is closed, a flutter
    # on lift-off; the layer is the ONLY difference to the same engine without it.
    var with_t: Dictionary = _render(eng,90.0,1.0,3.0)
    var plain: Dictionary = eng.duplicate(true)
    plain.erase("turbo")
    var no_t: Dictionary = _render(plain,90.0,1.0,3.0)
    var s: SYNTH = with_t["synth"]
    if s.boost < 0.6:
        _fail("boost must build up on full throttle at 90 km/h (got %.2f)" % s.boost)
        return
    var a_with: PackedVector2Array = with_t["audio"]
    var a_no: PackedVector2Array = no_t["audio"]
    var tail: int = a_with.size()-22050
    var diff: PackedVector2Array = PackedVector2Array()
    for i in range(tail,a_with.size()):
        diff.append(a_with[i]-a_no[i])
    var ratio: float = _rms(diff)/maxf(_rms(a_with.slice(tail)),1.0e-9)
    if ratio < 0.02 or ratio > 0.40:
        _fail("the turbo whistle must be audible but not dominant (RMS share %.3f, want 0.02-0.40)" % ratio)
        return
    var cold: Dictionary = _render(eng,90.0,0.0,1.0)
    var cold_plain: Dictionary = _render(plain,90.0,0.0,1.0)
    var quiet: float = 0.0
    for i in range(cold["audio"].size()):
        quiet = maxf(quiet,absf((cold["audio"][i]-cold_plain["audio"][i]).x))
    if quiet > 1.0e-9:
        _fail("no boost, no whistle: the layer must be silent on a closed throttle (max difference %.3e)" % quiet)
        return
    var early: Dictionary = _render(eng,90.0,1.0,0.15)
    if (early["synth"] as SYNTH).boost > s.boost*0.6:
        _fail("boost must spool up over time, not appear at once (%.2f after 0.15 s vs %.2f)" % [(early["synth"] as SYNTH).boost,s.boost])
        return
    var lifted: Dictionary = _render(eng,90.0,1.0,3.05,3.0)
    if (lifted["synth"] as SYNTH)._flutter < 0.3:
        _fail("lifting off from boost must trigger the flutter / blow-off (flutter %.2f)" % (lifted["synth"] as SYNTH)._flutter)
        return
    var settled: Dictionary = _render(eng,90.0,1.0,3.0,1.5)
    if (settled["synth"] as SYNTH)._flutter > 0.02:
        _fail("the flutter must die away within 1.5 s (%.3f left)" % (settled["synth"] as SYNTH)._flutter)
        return
    var red_s = SYNTH.new()
    red_s.apply_profile(CARS.engine("red"))
    if red_s.turbo_level != 0.0:
        _fail("the rotary must have no turbo layer")
        return
    CARS.set_physics_mode(_mode_before)
    CARS.set_baseline_physics_forced(_forced_before)
    print("PASS: white Lada = N20B20 turbo (own profile, 275 PS / 410 Nm estimate vs 245 PS / 350 Nm stock, provenance, no second turbo, not star-gated), red stays the 13B; ARCADE_PLUS 0-100 %.2f s vs red %.2f s, REAL_POWER_TEST 0-100 %.2f s vs red %.2f s, 60-120 %.2f s vs %.2f s; turbo sound layer (whistle share %.2f of the signal, spools up, silent off boost, flutter on lift-off, only the white car has it)" % [plus_white,plus_red,a_white,a_red,mid_w,mid_r,ratio])
    print("NOT RUN: listening test on the owner's phone (sound quality is not approved by this test)")
    quit(0)
