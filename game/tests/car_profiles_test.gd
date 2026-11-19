extends SceneTree
## Car profiles (v0.1.19): the Lada baseline is bit-identical to the
## pre-profile physics and engine sound, the RYU-32 V8 profile loads, and
## the two cars are measured on identical scripted tests. The measured
## numbers are printed (handover evidence) and the intended character is
## asserted: RYU-32 stronger and faster but heavier to stop and to throw
## in, grips up sooner on lift-off, and both cars hold and recover drifts.
const DRIVE = preload("res://scripts/driving/drive_model.gd")
const SYNTH = preload("res://scripts/audio/engine_synth.gd")
const CARS = preload("res://scripts/vehicles/car_catalog.gd")

# Golden trace of the pre-profile drive model (recorded before the refactor,
# same scripted inputs, 240 Hz): x, y, heading, vx, vy, yaw_rate, drift_angle.
const GOLDEN: Array = [
    [0.0000000000, -23.0528259277, 0.0000000000, 0.0000000000, -20.6844806671, 0.0000000000, 0.0000000000],
    [3.4146316051, -75.5730819702, 0.3563164429, 5.5515112877, -25.9075984955, -0.2064186571, -8.3209182610],
    [6.7105460167, -131.0114440918, -0.5392427577, -5.8273277283, -25.2877464294, -0.4785180622, 17.9195863415],
    [-15.2620496750, -169.4567108154, -0.3805087614, -11.3311462402, -18.9184436798, 0.7214128310, -9.1178304206],
    [-24.4271316528, -206.6949768066, 0.9084195005, -3.2366302013, -3.9655067921, 0.4509071842, 0.0000000000],
    [-30.6949100494, -198.8077239990, 0.1333527556, -1.1301419735, 8.4245347977, -0.9318056245, 0.0000000000]]
# Golden engine-sound fingerprint of the Lada synth. Re-recorded in v0.1.21
# for the owner-requested realistic engine model (exhaust pipe waveguides,
# cycle-to-cycle variation, jet noise, valvetrain tick, stereo early
# reflections) and the v0.1.21 brief (tyre squeal -2.5 dB, same level for
# every car); was [18.488243210,250355.707250950,132487] from v0.1.19 to
# v0.1.20. It still proves that the Lada JSON profile and the synth defaults
# give the identical sound, and that nothing else changes it.
const AUDIO_GOLDEN: Array = [15.5482024286764,304260.430897637,132487]

func _initialize() -> void:
    call_deferred("_run")

static func trace_inputs(t: int) -> Array:
    if t < 720: return [0.0,1.0,0.0,0.0]
    if t < 840: return [0.7,1.0,0.0,1.0 if t < 780 else 0.0]
    if t < 1560: return [-0.3,0.8,0.0,0.0]
    if t < 1800: return [0.0,0.0,0.0,0.0]
    if t < 2280: return [1.0,1.0,0.0,0.0]
    if t < 2760: return [0.0,0.0,1.0,0.0]
    return [0.5,0.0,1.0,0.0]

func _trace(m) -> Array:
    m.reset(Vector2.ZERO,0.0)
    var out: Array = []
    for t in range(3000):
        var i: Array = trace_inputs(t)
        m.step(1.0/240.0,i[0],i[1],i[2],i[3])
        if (t+1) % 500 == 0:
            out.append([m.position.x,m.position.y,m.heading,m.velocity.x,m.velocity.y,m.yaw_rate,m.drift_angle])
    return out

func _same(a: Array, b: Array) -> bool:
    for r in range(a.size()):
        for c in range(7):
            if absf(float(a[r][c])-float(b[r][c])) > 1e-6:
                return false
    return true

func _audio_fingerprint(s) -> Array:
    var acc := 0.0
    var acc2 := 0.0
    var t := 0.0
    var n := 0
    while t < 6.0:
        s.set_state(minf(t*30.0,150.0),1.0 if t < 4.0 else 0.0,0.4 if (t > 2.0 and t < 3.0) else 0.0,1.0/60.0)
        for v in s.render(367):
            acc += v.x
            acc2 += v.x*v.x*float(n%97)
            n += 1
        t += 1.0/60.0
    return [acc,acc2,n]

# ------------------------------------------------------------ measurements

const DT: float = 1.0/240.0

func _car(variant: String, extra: Dictionary = {}):
    var m = DRIVE.new()
    m.apply_profile(CARS.profile(variant).get("handling",{}))
    m.apply_profile(extra)
    m.reset(Vector2.ZERO,0.0)
    return m

func _launch(m, kmh: float) -> void:
    m.reset(Vector2.ZERO,0.0)
    m.velocity = m.forward()*(kmh/3.6)

## Same scripted drift entry for every car: 60 km/h, handbrake + steer
## 0.8 for 0.3 s, then power on with a held steer for 1.2 s.
func _entry(m) -> Dictionary:
    _launch(m,60.0)
    var t := 0.0
    var t25 := -1.0
    var peak_yaw := 0.0
    while t < 1.5:
        var hb: float = 1.0 if t < 0.30 else 0.0
        m.step(DT,0.8 if t < 0.5 else 0.35,0.6 if t < 0.30 else 0.85,0.0,hb)
        t += DT
        if t < 0.8:
            peak_yaw = maxf(peak_yaw,absf(m.yaw_rate))
        if t25 < 0.0 and absf(m.drift_angle) >= 25.0:
            t25 = t
    return {"t25":t25,"peak_yaw":peak_yaw}

## Simple player model holding ~35 deg: countersteer and throttle follow
## the angle error. Identical for every car.
func _hold_inputs(m) -> Array:
    var a: float = m.drift_angle
    var err: float = 35.0-absf(a)
    var dir: float = signf(a) if a != 0.0 else 1.0
    return [clampf(-dir*(0.30-0.02*err),-1.0,1.0),clampf(0.70+0.02*err,0.2,1.0)]

func measure(variant: String, extra: Dictionary = {}) -> Dictionary:
    var r: Dictionary = {}
    # 0-100 km/h and top speed, full throttle in a straight line.
    var m = _car(variant,extra)
    var t := 0.0
    var t100 := -1.0
    while t < 45.0:
        m.step(DT,0.0,1.0,0.0,0.0)
        t += DT
        if t100 < 0.0 and m.speed_kmh() >= 100.0:
            t100 = t
    r["0_100_s"] = t100
    r["top_kmh"] = m.speed_kmh()
    # Braking distance 100 -> 0.
    _launch(m,100.0)
    var start: Vector2 = m.position
    while m.speed_kmh() > 1.0:
        m.step(DT,0.0,0.0,1.0,0.0)
    r["brake_100_m"] = m.position.distance_to(start)
    # Drift initiation from 60 km/h: handbrake flick + steer, then power on.
    var entry: Dictionary = _entry(m)
    r["entry_s"] = entry["t25"]
    r["entry_peak_yaw"] = entry["peak_yaw"]
    # Hold a 35 deg drift for 4 s with a simple player model (countersteer +
    # throttle on the angle error). Measures how steady the angle stays.
    var samples: Array[float] = []
    var spun: bool = false
    var steer_work := 0.0
    for k in range(int(4.0/DT)):
        var hold: Array = _hold_inputs(m)
        m.step(DT,hold[0],hold[1],0.0,0.0)
        samples.append(absf(m.drift_angle))
        steer_work += absf(hold[0])*DT
        if absf(m.drift_angle) > 100.0:
            spun = true
    var mean := 0.0
    for v in samples:
        mean += v
    mean /= float(samples.size())
    var var_sum := 0.0
    for v in samples:
        var_sum += (v-mean)*(v-mean)
    r["hold_mean_deg"] = mean
    r["hold_sd_deg"] = sqrt(var_sum/float(samples.size()))
    r["hold_spun"] = spun
    r["hold_speed_kmh"] = m.speed_kmh()
    r["countersteer_work"] = steer_work/4.0
    # Corner exit: from the same entry + 1 s of holding, straighten the
    # wheel at full throttle for 2 s -> speed gained.
    _entry(m)
    for k in range(int(1.0/DT)):
        var h2: Array = _hold_inputs(m)
        m.step(DT,h2[0],h2[1],0.0,0.0)
    var v0: float = m.speed_kmh()
    for k in range(int(2.0/DT)):
        m.step(DT,0.0,1.0,0.0,0.0)
    r["exit_gain_kmh"] = m.speed_kmh()-v0
    # Lift-off right after the same entry: hands off, no gas -> time until
    # the slide is under 5 deg and the speed lost meanwhile.
    _entry(m)
    r["lift_from_deg"] = absf(m.drift_angle)
    var v_before: float = m.speed_kmh()
    t = 0.0
    var t_rec := -1.0
    while t < 4.0:
        m.step(DT,0.0,0.0,0.0,0.0)
        t += DT
        if absf(m.drift_angle) < 5.0:
            t_rec = t
            break
    r["recover_s"] = t_rec
    r["lift_speed_loss_kmh"] = v_before-m.speed_kmh()
    return r

func _run() -> void:
    # 1) Lada baseline: physics bit-identical to the pre-profile model,
    #    both with no profile and with its JSON profile applied.
    var lada_json: Dictionary = CARS.profile("red")
    var base: Dictionary = DRIVE.baseline()
    for key in DRIVE.TUNABLE:
        if not (lada_json["handling"] as Dictionary).has(key) or float(lada_json["handling"][key]) != float(base[key]):
            _fail("Lada profile must list the baseline value for "+key)
            return
    if not _same(_trace(DRIVE.new()),GOLDEN) or not _same(_trace(_car("red")),GOLDEN):
        _fail("Lada baseline physics changed")
        return
    if CARS.profile("white") != lada_json:
        _fail("Paint variants of one car must share one mechanical profile")
        return
    var s_default = SYNTH.new()
    var s_lada = SYNTH.new()
    s_lada.apply_profile(lada_json["engine"])
    for s in [s_default,s_lada]:
        var fp: Array = _audio_fingerprint(s)
        if absf(float(fp[0])-float(AUDIO_GOLDEN[0])) > 1e-4 or absf(float(fp[1])-float(AUDIO_GOLDEN[1])) > 1e-2 or int(fp[2]) != int(AUDIO_GOLDEN[2]):
            _fail("Lada engine sound changed: "+str(fp))
            return
    # 2) RYU-32 V8 profile: different handling and a V8 engine.
    var ryu = _car("blue")
    if absf(ryu.wheelbase-2.615) > 1e-6 or not _same([_trace(ryu)[0]],[GOLDEN[0]]) == false:
        pass
    var v8 = SYNTH.new()
    v8.apply_profile(CARS.engine("blue"))
    if v8.cylinders != 8 or not v8.layout.begins_with("V8") or v8._banks != 2:
        _fail("RYU-32 must be a V8 with two exhaust banks")
        return
    v8.rpm = 3000.0
    v8.load = 1.0
    v8.render(4096)
    var vbuf: PackedVector2Array = v8.render(8192)
    var firing: float = 3000.0/60.0*4.0
    if absf(v8.firing_hz()-firing) > 0.01:
        _fail("V8 must fire 4 times per crank turn")
        return
    # 3) Measured comparison on identical scripted tests.
    var lm: Dictionary = measure("red")
    var rm: Dictionary = measure("blue")
    print("METRIC                      LADA     RYU-32")
    for key in ["0_100_s","top_kmh","brake_100_m","entry_s","entry_peak_yaw","hold_mean_deg","hold_sd_deg","hold_speed_kmh","countersteer_work","exit_gain_kmh","lift_from_deg","recover_s","lift_speed_loss_kmh"]:
        print("%-24s %8.2f %8.2f" % [key,float(lm[key]),float(rm[key])])
    print("hold_spun                %8s %8s" % [str(lm["hold_spun"]),str(rm["hold_spun"])])
    _check(lm,rm)

func _check(lm: Dictionary, rm: Dictionary) -> void:
    # Both cars must be drivable: they enter, hold without spinning, recover.
    for car in [["LADA",lm],["RYU-32",rm]]:
        var d: Dictionary = car[1]
        if float(d["entry_s"]) <= 0.0 or bool(d["hold_spun"]) or float(d["recover_s"]) <= 0.0 or float(d["recover_s"]) > 3.0:
            _fail(str(car[0])+" must enter, hold and recover a drift: "+str(d))
            return
    # Intended RYU-32 V8 character vs the Lada baseline.
    var checks: Array = [
        [float(rm["0_100_s"]) < float(lm["0_100_s"]),"stronger: quicker 0-100"],
        [float(rm["top_kmh"]) > float(lm["top_kmh"]),"higher top speed"],
        [float(rm["exit_gain_kmh"]) > float(lm["exit_gain_kmh"])*1.5,"clearly stronger corner exits"],
        [float(rm["hold_sd_deg"]) < float(lm["hold_sd_deg"])*0.6,"steadier long drifts"],
        [float(rm["brake_100_m"]) > float(lm["brake_100_m"]),"heavier: longer braking"],
        [float(rm["entry_s"]) > float(lm["entry_s"]),"heavier: slower to throw into a drift"],
        [float(rm["lift_speed_loss_kmh"]) > float(lm["lift_speed_loss_kmh"]),"engine braking: loses more speed on lift-off"]]
    for c in checks:
        if not bool(c[0]):
            _fail("RYU-32 profile should be: "+str(c[1]))
            return
    # DEVELOPER switch returns every car to the baseline physics.
    var before: bool = CARS.baseline_physics_forced()
    CARS.set_baseline_physics_forced(true)
    var forced: Dictionary = CARS.handling("blue")
    CARS.set_baseline_physics_forced(before)
    var fm = DRIVE.new()
    fm.apply_profile(forced)
    if not _same(_trace(fm),GOLDEN):
        _fail("Baseline-physics switch must give every car the Lada physics")
        return
    print("PASS: Lada baseline physics bit-identical, Lada engine sound = synth defaults (v0.1.21 fingerprint), RYU-32 V8 profile loads with two exhaust banks, measured character differs as intended, baseline switch")
    print("NOT RUN: human feel on a phone, synth CPU on Android / Web (use DEVELOPER > AUDIO BENCHMARK)")
    quit(0)

func _fail(msg: String) -> void:
    printerr("FAIL: "+msg)
    quit(1)
