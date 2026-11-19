extends RefCounted
class_name NitroEngineSynth
## Procedural engine for builds without a recorded engine loop.
## Source-filter model of the drift 2106's inline-four on individual
## throttle bodies (the four stacks in the bay):
##  * every cylinder firing injects a pressure pulse into the exhaust; the
##    four cylinders are deliberately a little uneven in strength and timing,
##    which gives the lumpy idle and the "burble" a perfectly even tone lacks;
##  * pulses ring through FIXED exhaust and intake resonances, so the timbre
##    changes as revs sweep through them, like a real car;
##  * throttle load sharpens the pulses and adds combustion rasp + ITB
##    induction roar; lifting off leaves a hollow overrun with crackle/pops;
##  * ignition cut on upshifts and a bouncing rev limiter.
## Tyres: squeal = white noise through narrow resonances whose pitch
## wanders, with stick-slip flutter (no fixed siren tone). Impacts: a
## falling-pitch body thud + crunch + rattle. Wall contact: grinding scrape.
## Cheap per-sample maths only (Android).

const SAMPLE_RATE: float = 22050.0
const TABLE_SIZE: int = 2048
const CYLINDERS: int = 4
const IDLE_RPM: float = 950.0
const LIMIT_RPM: float = 7400.0
# Upper speed (km/h) of gears 1..5 for a short-ratio drift box.
const GEAR_TOP: Array[float] = [48.0,82.0,116.0,150.0,195.0]
# Real engines are never perfectly even: per-cylinder pulse strength and
# timing scatter (fraction of one firing interval).
const CYL_GAIN: Array[float] = [1.0,0.84,0.95,0.79]
const CYL_TIMING: Array[float] = [0.0,0.018,-0.010,0.012]
# Fixed resonances: [Hz, bandwidth Hz]. Muffler boom, pipe body, header rasp,
# ITB intake honk.
const F_BOOM: Vector2 = Vector2(105.0,95.0)
const F_PIPE: Vector2 = Vector2(320.0,120.0)
const F_RASP: Vector2 = Vector2(820.0,300.0)
const F_INTAKE: Vector2 = Vector2(610.0,220.0)

var rpm: float = IDLE_RPM
var target_rpm: float = IDLE_RPM
var load: float = 0.0          # 0 coast/overrun .. 1 full throttle
var squeal: float = 0.0        # tyre slip loudness 0..1
var scrape: float = 0.0        # body sliding along a wall 0..1
var scrape_target: float = 0.0
var gear: int = 1
var master: float = 0.55
var afterfire: float = 0.0     # overrun crackle window after lifting off
var limiter_hits: int = 0
var shifts: int = 0

var _table := PackedFloat32Array()
var _rng := RandomNumberGenerator.new()
var _seed: int = 2106
var _cycle: float = 0.0        # 0..1 over one 720 degree engine cycle
var _next_fire: float = 0.0
var _slot: int = 0
var _env: float = 0.0
var _pop: float = 0.0
var _cut_timer: float = 0.0
var _prev_gas: float = 0.0
var _body: float = 0.0
var _dc_x: float = 0.0
var _dc_y: float = 0.0
var _b1: float = 0.0
var _b2: float = 0.0
var _p1: float = 0.0
var _p2: float = 0.0
var _r1: float = 0.0
var _r2: float = 0.0
var _i1: float = 0.0
var _i2: float = 0.0
var _thump: float = 0.0
var _thump_phase: float = 0.0
var _imp_t: float = 1.0
var _imp_c1: float = 0.0
var _imp_c2: float = 0.0
var _imp_lp: float = 0.0
var _wobble: float = 0.0
var _sq_drift := PackedFloat32Array([0.0,0.0,0.0])
var _sq_state := PackedFloat32Array([0.0,0.0,0.0,0.0,0.0,0.0])
var _sq_flutter_ph: float = 0.0
var _sq_flutter_rate: float = 16.0
var _sq_gain: float = 1.0
var _sq_gain_target: float = 1.0
var _sc1: float = 0.0
var _sc2: float = 0.0
var _sc3: float = 0.0
var _sc4: float = 0.0
var _grit: float = 1.0
var _coef: Dictionary = {}

func _init() -> void:
    _rng.seed = 2106
    _table.resize(TABLE_SIZE)
    for i in range(TABLE_SIZE):
        var x: float = TAU*float(i)/float(TABLE_SIZE)
        var v: float = sin(x)*1.0+sin(2.0*x+0.3)*0.55+sin(3.0*x+0.9)*0.32+sin(4.0*x+1.7)*0.18
        v += sin(6.0*x+0.4)*0.10+sin(9.0*x+2.1)*0.05
        v += 0.35*pow(maxf(sin(x),0.0),6.0)
        _table[i] = v*0.42
    for key in ["boom","pipe","rasp","intake"]:
        var f: Vector2 = {"boom":F_BOOM,"pipe":F_PIPE,"rasp":F_RASP,"intake":F_INTAKE}[key]
        var r: float = exp(-PI*f.y/SAMPLE_RATE)
        var w: float = TAU*f.x/SAMPLE_RATE
        # [a1, a2, input gain normalised to ~unity peak]
        _coef[key] = Vector3(2.0*r*cos(w),r*r,(1.0-r*r)*sin(w))

## Simple automatic gearbox. Slip (wheelspin / drift) lets revs climb above
## road speed, like clutch-kicking in a drift.
static func gear_for(speed_kmh: float) -> int:
    for g in range(GEAR_TOP.size()):
        if speed_kmh < GEAR_TOP[g]:
            return g+1
    return GEAR_TOP.size()

static func rpm_for(speed_kmh: float, gas: float, slip: float) -> float:
    var g: int = gear_for(speed_kmh)
    var low: float = 0.0 if g == 1 else GEAR_TOP[g-2]
    var high: float = GEAR_TOP[g-1]
    var t: float = clampf((speed_kmh-low)/maxf(high-low,1.0),0.0,1.0)
    var base: float = lerpf(2600.0 if g > 1 else IDLE_RPM,7000.0,t)
    if speed_kmh < 2.0:
        base = IDLE_RPM+gas*2200.0
    base += clampf(slip,0.0,1.0)*gas*1600.0
    return clampf(base,IDLE_RPM,LIMIT_RPM)

func set_state(speed_kmh: float, gas: float, slip: float, dt: float) -> void:
    var new_gear: int = gear_for(speed_kmh)
    if new_gear > gear and gas > 0.3:
        # Upshift: brief ignition cut while the clutch is in.
        _cut_timer = maxf(_cut_timer,0.11)
        shifts += 1
    gear = new_gear
    target_rpm = rpm_for(speed_kmh,gas,slip)
    _cut_timer = maxf(0.0,_cut_timer-dt)
    if _cut_timer > 0.0:
        rpm = maxf(IDLE_RPM,rpm-2600.0*dt)
    else:
        # Revs chase the target quickly up, slower down (flywheel inertia).
        var rate: float = 9.0 if target_rpm > rpm else 5.0
        rpm = lerpf(rpm,target_rpm,1.0-exp(-rate*dt))
        if gas > 0.5 and rpm >= LIMIT_RPM-30.0:
            # Bouncing limiter: cut, drop ~200 rpm, fire again.
            _cut_timer = 0.075
            limiter_hits += 1
    # Lifting off from high revs opens a short crackle window.
    if _prev_gas > 0.55 and gas < 0.15 and rpm > 3200.0:
        afterfire = 1.0
    afterfire = maxf(0.0,afterfire-dt*0.85)
    if gas > 0.4:
        afterfire = 0.0
    _prev_gas = gas
    load = lerpf(load,clampf(gas,0.0,1.0),1.0-exp(-10.0*dt))
    var squeal_target: float = clampf(slip,0.0,1.0)*clampf(speed_kmh/60.0,0.0,1.0)
    squeal = lerpf(squeal,squeal_target,1.0-exp(-8.0*dt))

func on_limiter() -> bool:
    return _cut_timer > 0.0 and rpm > LIMIT_RPM-400.0

func impact(strength: float) -> void:
    _thump = maxf(_thump if _imp_t < 0.12 else 0.0,clampf(strength,0.0,1.0))
    _thump_phase = 0.0
    _imp_t = 0.0

## Two-pole resonator coefficients: (a1, a2, input gain).
static func _reso(freq: float, bw: float) -> Vector3:
    var r: float = exp(-PI*bw/SAMPLE_RATE)
    var w: float = TAU*clampf(freq,40.0,SAMPLE_RATE*0.45)/SAMPLE_RATE
    return Vector3(2.0*r*cos(w),r*r,(1.0-r*r)*sin(w))

## Firing frequency: four-stroke fires CYLINDERS/2 times per crank turn.
func firing_hz() -> float:
    return rpm/60.0*float(CYLINDERS)*0.5

func _fire() -> void:
    var k: int = _slot
    var rev_t: float = clampf((rpm-IDLE_RPM)/2500.0,0.0,1.0)
    var uneven: float = lerpf(0.24,0.06,rev_t)
    var strength: float = CYL_GAIN[k]*(1.0+_rng.randf_range(-uneven,uneven))
    strength *= lerpf(0.42,1.0,load)
    if _cut_timer > 0.0:
        strength *= 0.08
        if rpm > 5000.0 and _rng.randf() < 0.35:
            _pop = maxf(_pop,_rng.randf_range(0.4,0.8))
    elif afterfire > 0.0 and load < 0.25:
        var p: float = 0.30*afterfire*clampf((rpm-2200.0)/3000.0,0.0,1.0)
        if _rng.randf() < p:
            _pop = maxf(_pop,_rng.randf_range(0.5,1.0))
            strength += 0.9
    _env += strength
    _slot = (k+1)%CYLINDERS
    _next_fire += (1.0+CYL_TIMING[_slot]-CYL_TIMING[k])/float(CYLINDERS)

func render(frames: int) -> PackedVector2Array:
    var out := PackedVector2Array()
    out.resize(frames)
    var cyc_inc: float = rpm/120.0/SAMPLE_RATE
    # Sharper pulses and more rasp under load; softer, hollow on overrun.
    var tau: float = lerpf(0.0019,0.0010,load)
    var env_decay: float = exp(-1.0/(tau*SAMPLE_RATE))
    var pop_decay: float = exp(-1.0/(0.009*SAMPLE_RATE))
    var rasp: float = lerpf(0.12,0.55,load)
    var body_k: float = lerpf(0.10,0.22,load)
    var rev: float = clampf(rpm/LIMIT_RPM,0.0,1.0)
    var g_body: float = 0.55
    var g_boom: float = lerpf(1.0,0.55,rev)
    var g_pipe: float = lerpf(0.55,0.95,load)
    var g_rasp: float = lerpf(0.12,0.60,load)*lerpf(0.6,1.4,rev)
    var g_intake: float = lerpf(0.0,0.75,load)*rev
    var amp: float = master*0.72*lerpf(0.85,1.0,load)*lerpf(0.85,1.35,rev)
    var cb: Vector3 = _coef["boom"]
    var cp: Vector3 = _coef["pipe"]
    var cr: Vector3 = _coef["rasp"]
    var ci: Vector3 = _coef["intake"]
    var sq_amp: float = master*squeal
    # Squeal pitch wanders (random walk) and rises a little with slip.
    for k in range(3):
        _sq_drift[k] = clampf(_sq_drift[k]*0.94+_rng.randf_range(-0.035,0.035),-0.12,0.12)
    var f0: float = (860.0+340.0*squeal)*(1.0+_sq_drift[0])
    var q0: Vector3 = _reso(f0,38.0)
    var q1: Vector3 = _reso(f0*1.93*(1.0+_sq_drift[1]*0.5),70.0)
    var q2: Vector3 = _reso(520.0*(1.0+_sq_drift[2]),260.0)
    if _rng.randf() < 0.08:
        _sq_flutter_rate = _rng.randf_range(9.0,24.0)
        _sq_gain_target = _rng.randf_range(0.65,1.0)
    var fl_inc: float = _sq_flutter_rate/SAMPLE_RATE
    var fl_depth: float = 0.35
    scrape = lerpf(scrape,scrape_target,0.35)
    var sc_amp: float = master*scrape
    var s1: Vector3 = _reso(1900.0,1300.0)
    var s2: Vector3 = _reso(430.0,260.0)
    var size_f: float = float(TABLE_SIZE)
    for i in range(frames):
        _cycle += cyc_inc
        if _cycle >= _next_fire:
            _fire()
        if _cycle >= 1.0:
            _cycle -= 1.0
            _next_fire -= 1.0
        _seed = (_seed*1103515245+12345) & 0x7fffffff
        var noise: float = float(_seed)/1073741823.5-1.0
        _env *= env_decay
        _pop *= pop_decay
        var x: float = _env*(1.0+noise*rasp)+noise*_pop*1.4
        _body += (x-_body)*body_k
        var yb: float = cb.z*x+cb.x*_b1-cb.y*_b2
        _b2 = _b1
        _b1 = yb
        var yp: float = cp.z*x+cp.x*_p1-cp.y*_p2
        _p2 = _p1
        _p1 = yp
        var yr: float = cr.z*x+cr.x*_r1-cr.y*_r2
        _r2 = _r1
        _r1 = yr
        var xi: float = noise*(0.25+_env)
        var yi: float = ci.z*xi+ci.x*_i1-ci.y*_i2
        _i2 = _i1
        _i1 = yi
        var mix: float = _body*g_body+yb*g_boom*6.0+yp*g_pipe*3.0+yr*g_rasp*2.0+yi*g_intake*1.6
        # DC blocker (pulses are one-sided pressure).
        var dc: float = mix-_dc_x+0.996*_dc_y
        _dc_x = mix
        _dc_y = dc
        var s: float = dc*amp
        if sq_amp > 0.002:
            var y0: float = q0.z*noise+q0.x*_sq_state[0]-q0.y*_sq_state[1]
            _sq_state[1] = _sq_state[0]
            _sq_state[0] = y0
            var y1: float = q1.z*noise+q1.x*_sq_state[2]-q1.y*_sq_state[3]
            _sq_state[3] = _sq_state[2]
            _sq_state[2] = y1
            var y2: float = q2.z*noise+q2.x*_sq_state[4]-q2.y*_sq_state[5]
            _sq_state[5] = _sq_state[4]
            _sq_state[4] = y2
            _sq_flutter_ph = fmod(_sq_flutter_ph+fl_inc,1.0)
            var tri: float = absf(_sq_flutter_ph*2.0-1.0)
            _sq_gain += (_sq_gain_target-_sq_gain)*0.0006
            var am: float = (1.0-fl_depth*tri)*_sq_gain
            s += (y0*7.2+y1*3.6+y2*1.8)*am*sq_amp
        if sc_amp > 0.002:
            # Grinding scrape: bright grit + low body rumble, gritty AM.
            if (i & 63) == 0:
                _grit = _rng.randf_range(0.45,1.0)
            var z1: float = s1.z*noise+s1.x*_sc1-s1.y*_sc2
            _sc2 = _sc1
            _sc1 = z1
            var z2: float = s2.z*noise+s2.x*_sc3-s2.y*_sc4
            _sc4 = _sc3
            _sc3 = z2
            s += (z1*2.6+z2*3.2)*_grit*sc_amp
        if _imp_t < 0.45:
            # Impact: falling-pitch body thud, crunch and panel rattle.
            var a_imp: float = _thump*master*1.25
            var f_thud: float = 42.0+95.0*exp(-_imp_t/0.035)
            _thump_phase = fmod(_thump_phase+f_thud/SAMPLE_RATE,1.0)
            var thud: float = sin(TAU*_thump_phase)*exp(-_imp_t/0.11)
            var yc: float = 0.42*noise+1.55*_imp_c1-0.70*_imp_c2
            _imp_c2 = _imp_c1
            _imp_c1 = yc
            var crunch: float = yc*exp(-_imp_t/0.030)
            _imp_lp += (noise-_imp_lp)*0.12
            var rattle: float = _imp_lp*exp(-_imp_t/0.07)*(0.6+0.4*float((i>>7)&1))
            s += (thud*0.95+crunch*0.55+rattle*0.9)*a_imp
            _imp_t += 1.0/SAMPLE_RATE
        # Soft knee limiter: never clips, untouched below 0.8.
        var a: float = absf(s)
        if a > 0.8:
            s = signf(s)*(0.8+0.19*(1.0-exp(-(a-0.8)/0.19)))
        out[i] = Vector2(s,s)
    _wobble = _rng.randf_range(-1.0,1.0)
    return out
