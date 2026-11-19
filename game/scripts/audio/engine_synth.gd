extends RefCounted
class_name NitroEngineSynth
## Procedural car sound: engine, tyre squeal, wall scrape and impacts.
## Engine = a small physical model of a piston engine and its exhaust,
## cheap enough for Android (per-sample maths, no samples):
##  * every cylinder firing pushes a blow-down pressure pulse (rounded
##    attack, exponential decay) into its exhaust bank; cylinders differ a
##    little in strength and timing (lumpy idle), and every combustion is
##    slightly different from the last (cycle-to-cycle variation: strength
##    and timing jitter) - a perfectly periodic pulse train is what makes
##    engine synths sound synthetic;
##  * the crank speed wanders a little (more at idle), so the pitch is never
##    a frozen tone;
##  * exhaust acoustics: per-bank header pipe and a main tail pipe are
##    waveguides (delay lines with lossy reflections), so the pipe modes
##    colour the pulses and the timbre sweeps with rpm like a real exhaust;
##    a V8's two banks have their own headers, which is where the uneven
##    cross-plane burble comes from; fixed muffler / body resonances on top;
##  * turbulent flow noise rides on every pulse (rasp under load), ITB
##    induction roar, valvetrain / timing-chain ticking (heard at idle);
##  * overrun: softer pulses, occasional lean misfires (decel burble) and
##    afterfire crackle after lifting off at high revs; ignition cut on
##    upshifts and a bouncing rev limiter;
##  * a short early-reflection "room" (car body, ground) decorrelates left
##    and right so the sound is not bone dry.
## Tyres: squeal = white noise through narrow resonances whose pitch
## wanders, with stick-slip flutter (no fixed siren tone). Impacts: a
## falling-pitch body thud + crunch + rattle. Wall contact: grinding scrape.

const SAMPLE_RATE: float = 22050.0
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
# Speed of sound in hot exhaust gas (m/s): sets the pipe delay lengths.
const GAS_C: float = 480.0
const PIPE_BUF: int = 512        # max pipe round trip ~5.5 m
const ROOM_BUF: int = 1024
const MECH_GAIN: float = 0.3
const JET_GAIN: float = 2.2
# Early reflections (samples at 22.05 kHz) per channel: ~6.5 / 10.6 ms left,
# ~8.4 / 13.1 ms right.
const ROOM_L: Vector2i = Vector2i(143,233)
const ROOM_R: Vector2i = Vector2i(185,289)

# Engine profile (defaults = the Lada's inline-four above). A car profile
# can change the layout, firing pattern, revs, gearing, exhaust geometry and
# resonances through apply_profile(); the synthesis itself is shared.
const SHIFT_FLOOR_RPM: float = 2600.0   # revs right after an upshift
const GEAR_END_RPM: float = 7000.0      # revs at the end of each gear
var layout: String = "I4 ITB"
var cylinders: int = CYLINDERS
var idle_rpm: float = IDLE_RPM
var limit_rpm: float = LIMIT_RPM
var shift_floor_rpm: float = SHIFT_FLOOR_RPM
var gear_end_rpm: float = GEAR_END_RPM
var gear_top: Array[float] = GEAR_TOP.duplicate()
var cyl_gain: Array[float] = CYL_GAIN.duplicate()
var cyl_timing: Array[float] = CYL_TIMING.duplicate()
var f_boom: Vector2 = F_BOOM
var f_pipe: Vector2 = F_PIPE
var f_rasp: Vector2 = F_RASP
var f_intake: Vector2 = F_INTAKE
var boom_gain: float = 1.0
var intake_gain: float = 1.0
var uneven_idle: float = 0.24
var uneven_high: float = 0.06
# Exhaust geometry and engine character (v0.1.21).
var cyl_bank: Array[int] = [0,0,0,0]   # exhaust bank of each firing slot
var header_m: Array[float] = [0.95]    # header length per bank (m)
var bank_lag_m: float = 0.0            # extra pipe run of bank 1 to the collector (m)
var tail_m: float = 3.0                # collector -> tail pipe exit (m)
var header_reflect: float = -0.32      # header loop gain (valve <-> collector)
var tail_reflect: float = 0.34         # tail loop gain (muffler <-> open end)
var pipe_damp_hz: float = 1000.0       # wall/radiation loss per round trip
var jet: float = 1.0                   # turbulent jet noise at the pipe exit
var jitter_idle: float = 0.016         # combustion timing scatter at idle
var jitter_high: float = 0.005         # ... and at high revs
var wander: float = 0.010              # crank speed wander at idle
var misfire: float = 0.10              # overrun lean-misfire probability
var mech_level: float = 1.0            # valvetrain / timing-chain noise
var mech_hz: float = 2900.0
var room: float = 0.20                 # early-reflection level

var rpm: float = IDLE_RPM
var target_rpm: float = IDLE_RPM
var load: float = 0.0          # 0 coast/overrun .. 1 full throttle
var squeal: float = 0.0        # tyre slip loudness 0..1
var scrape: float = 0.0        # body sliding along a wall 0..1
var scrape_target: float = 0.0
var gear: int = 1
var master: float = 0.55
# Player mix (pause / settings sliders): engine, tyres, effects.
var engine_gain: float = 1.0
var tyre_gain: float = 1.0
var fx_gain: float = 1.0
var afterfire: float = 0.0     # overrun crackle window after lifting off
var limiter_hits: int = 0
var shifts: int = 0
var misfires: int = 0

var _rng := RandomNumberGenerator.new()
var _seed: int = 2106
var _seed2: int = 6012
var _cycle: float = 0.0        # 0..1 over one 720 degree engine cycle
var _next_fire: float = 0.0
var _slot: int = 0
var _fire_bank: int = 0
var _jit_prev: float = 0.0
var _mech_kick: float = 0.0
var _e0: float = 0.0           # pulse envelope, bank 0 / bank 1
var _e1: float = 0.0
var _a0: float = 0.0           # rounded (attack-smoothed) pulse
var _a1: float = 0.0
var _mech: float = 0.0
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
var _m1: float = 0.0
var _m2: float = 0.0
var _jh: float = 0.0
var _jh2: float = 0.0
var _jl: float = 0.0
var _hb0 := PackedFloat32Array()   # header waveguides
var _hb1 := PackedFloat32Array()
var _tb := PackedFloat32Array()    # tail pipe waveguide
var _rb := PackedFloat32Array()    # room
var _hl0: float = 0.0
var _hl1: float = 0.0
var _tl: float = 0.0
var _rl: float = 0.0
var _w: int = 0
var _hd0: int = 87
var _hd1: int = 87
var _td: int = 276
var _lag: int = 0
var _banks: int = 1
var _wander: float = 0.0
var _wander_target: float = 0.0
var _wander_t: float = 0.0
var _thump: float = 0.0
var _thump_phase: float = 0.0
var _imp_t: float = 1.0
var _imp_c1: float = 0.0
var _imp_c2: float = 0.0
var _imp_lp: float = 0.0
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
    _hb0.resize(PIPE_BUF)
    _hb1.resize(PIPE_BUF)
    _tb.resize(PIPE_BUF)
    _rb.resize(ROOM_BUF)
    _compute_coefs()

func _compute_coefs() -> void:
    for key in ["boom","pipe","rasp","intake"]:
        var f: Vector2 = {"boom":f_boom,"pipe":f_pipe,"rasp":f_rasp,"intake":f_intake}[key]
        _coef[key] = _reso(f.x,f.y)
    _coef["mech"] = _reso(mech_hz,1400.0)
    _banks = 1
    for b in cyl_bank:
        _banks = maxi(_banks,b+1)
    _banks = mini(_banks,2)
    # Round trip of a pressure wave: 2 L / c, in samples.
    var h0: float = header_m[0] if header_m.size() > 0 else 0.95
    var h1: float = header_m[1] if header_m.size() > 1 else h0
    _hd0 = clampi(int(round(2.0*h0/GAS_C*SAMPLE_RATE)),8,PIPE_BUF-1)
    _hd1 = clampi(int(round(2.0*h1/GAS_C*SAMPLE_RATE)),8,PIPE_BUF-1)
    _td = clampi(int(round(2.0*tail_m/GAS_C*SAMPLE_RATE)),8,PIPE_BUF-1)
    # Bank 1 arrives later at the collector (one-way trip of the extra pipe):
    # the two banks' uneven pulse trains no longer add up to an even one.
    _lag = clampi(int(round(bank_lag_m/GAS_C*SAMPLE_RATE)),0,PIPE_BUF-1)

## Simple automatic gearbox. Slip (wheelspin / drift) lets revs climb above
## road speed, like clutch-kicking in a drift.
static func gear_for(speed_kmh: float) -> int:
    for g in range(GEAR_TOP.size()):
        if speed_kmh < GEAR_TOP[g]:
            return g+1
    return GEAR_TOP.size()

## Engine profile from a car profile's "engine" block (see game/cars/*.json).
func apply_profile(engine: Dictionary) -> void:
    layout = str(engine.get("layout",layout))
    cylinders = int(engine.get("cylinders",cylinders))
    idle_rpm = float(engine.get("idle_rpm",idle_rpm))
    limit_rpm = float(engine.get("limit_rpm",limit_rpm))
    shift_floor_rpm = float(engine.get("shift_floor_rpm",shift_floor_rpm))
    gear_end_rpm = float(engine.get("gear_end_rpm",gear_end_rpm))
    if engine.has("gear_top_kmh"):
        gear_top.assign(engine["gear_top_kmh"])
    if engine.has("cylinder_gain"):
        cyl_gain.assign(engine["cylinder_gain"])
    if engine.has("cylinder_timing"):
        cyl_timing.assign(engine["cylinder_timing"])
    for pair in [["boom_hz","boom_bw","f_boom"],["pipe_hz","pipe_bw","f_pipe"],
            ["rasp_hz","rasp_bw","f_rasp"],["intake_hz","intake_bw","f_intake"]]:
        var cur: Vector2 = get(pair[2])
        set(pair[2],Vector2(float(engine.get(pair[0],cur.x)),float(engine.get(pair[1],cur.y))))
    boom_gain = float(engine.get("boom_gain",boom_gain))
    intake_gain = float(engine.get("intake_gain",intake_gain))
    uneven_idle = float(engine.get("uneven_idle",uneven_idle))
    uneven_high = float(engine.get("uneven_high",uneven_high))
    if engine.has("bank"):
        cyl_bank.assign(engine["bank"])
    if engine.has("header_m"):
        header_m.assign(engine["header_m"])
    for key in [["tail_m","tail_m"],["bank_lag_m","bank_lag_m"],["header_reflect","header_reflect"],["tail_reflect","tail_reflect"],
            ["pipe_damp_hz","pipe_damp_hz"],["jitter_idle","jitter_idle"],["jitter_high","jitter_high"],
            ["wander","wander"],["misfire","misfire"],["jet","jet"],["mech","mech_level"],["mech_hz","mech_hz"],["room","room"]]:
        if engine.has(key[0]):
            set(key[1],float(engine[key[0]]))
    if engine.has("loudness"):
        master = 0.55*float(engine["loudness"])
    # Firing pattern arrays must match the cylinder count.
    while cyl_gain.size() < cylinders:
        cyl_gain.append(1.0)
    while cyl_timing.size() < cylinders:
        cyl_timing.append(0.0)
    while cyl_bank.size() < cylinders:
        cyl_bank.append(0)
    _compute_coefs()
    rpm = idle_rpm
    target_rpm = idle_rpm
    _slot = 0
    _cycle = 0.0
    _jit_prev = 0.0
    _next_fire = cyl_timing[0]/float(cylinders)

## Developer benchmark: CPU milliseconds needed to render one second of
## audio for an engine profile (full load, mid revs, tyre squeal on). Shown
## under DEVELOPER > AUDIO BENCHMARK so it can be read on Android and Web.
static func benchmark(engine: Dictionary, seconds: float = 2.0) -> float:
    var s = load("res://scripts/audio/engine_synth.gd").new()
    s.apply_profile(engine)
    s.rpm = 4500.0
    s.load = 1.0
    s.squeal = 0.5
    var frames: int = int(SAMPLE_RATE*seconds)
    var t0: int = Time.get_ticks_usec()
    var done: int = 0
    while done < frames:
        s.render(512)
        done += 512
    return float(Time.get_ticks_usec()-t0)/1000.0/seconds

func gear_of(speed_kmh: float) -> int:
    for g in range(gear_top.size()):
        if speed_kmh < gear_top[g]:
            return g+1
    return gear_top.size()

func rpm_of(speed_kmh: float, gas: float, slip: float) -> float:
    var g: int = gear_of(speed_kmh)
    var low: float = 0.0 if g == 1 else gear_top[g-2]
    var high: float = gear_top[g-1]
    var t: float = clampf((speed_kmh-low)/maxf(high-low,1.0),0.0,1.0)
    var base: float = lerpf(shift_floor_rpm if g > 1 else idle_rpm,gear_end_rpm,t)
    if speed_kmh < 2.0:
        base = idle_rpm+gas*2200.0
    base += clampf(slip,0.0,1.0)*gas*1600.0
    return clampf(base,idle_rpm,limit_rpm)

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
    var new_gear: int = gear_of(speed_kmh)
    if new_gear > gear and gas > 0.3:
        # Upshift: brief ignition cut while the clutch is in.
        _cut_timer = maxf(_cut_timer,0.11)
        shifts += 1
    gear = new_gear
    target_rpm = rpm_of(speed_kmh,gas,slip)
    _cut_timer = maxf(0.0,_cut_timer-dt)
    if _cut_timer > 0.0:
        rpm = maxf(idle_rpm,rpm-2600.0*dt)
    else:
        # Revs chase the target quickly up, slower down (flywheel inertia).
        var rate: float = 9.0 if target_rpm > rpm else 5.0
        rpm = lerpf(rpm,target_rpm,1.0-exp(-rate*dt))
        if gas > 0.5 and rpm >= limit_rpm-30.0:
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
    return _cut_timer > 0.0 and rpm > limit_rpm-400.0

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
    return rpm/60.0*float(cylinders)*0.5

## One cylinder fires: returns the pulse strength; sets the bank it goes
## to, the valvetrain tick and the time of the next firing.
func _fire() -> float:
    var k: int = _slot
    var rev_t: float = clampf((rpm-idle_rpm)/2500.0,0.0,1.0)
    var uneven: float = lerpf(uneven_idle,uneven_high,rev_t)
    var strength: float = cyl_gain[k]*(1.0+_rng.randf_range(-uneven,uneven))
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
    elif load < 0.3 and rpm > 1800.0 and _rng.randf() < misfire*(1.0-load/0.3):
        # Closed throttle, high vacuum: a lean cylinder barely burns.
        strength *= _rng.randf_range(0.10,0.35)
        misfires += 1
    _fire_bank = cyl_bank[k] if _banks > 1 else 0
    _mech_kick = mech_level*_rng.randf_range(0.45,1.0)
    _slot = (k+1)%cylinders
    # Cycle-to-cycle variation: each combustion lands a little early or
    # late (non-accumulating: the cycle itself stays locked to the crank).
    var jit_amt: float = lerpf(jitter_idle,jitter_high,rev_t)
    var j: float = _rng.randf_range(-jit_amt,jit_amt)
    _next_fire += (1.0+cyl_timing[_slot]-cyl_timing[k]+j-_jit_prev)/float(cylinders)
    _jit_prev = j
    return strength

func render(frames: int) -> PackedVector2Array:
    var out := PackedVector2Array()
    out.resize(frames)
    var span: float = float(frames)/SAMPLE_RATE
    var rev_t: float = clampf((rpm-idle_rpm)/2500.0,0.0,1.0)
    # Crank speed wander: a slow random walk, strongest at idle.
    _wander_t -= span
    if _wander_t <= 0.0:
        _wander_target = _rng.randf_range(-1.0,1.0)
        _wander_t = _rng.randf_range(0.08,0.30)
    _wander += (_wander_target-_wander)*minf(1.0,span/0.15)
    var cyc_inc: float = rpm*(1.0+_wander*wander*lerpf(1.0,0.25,rev_t))/120.0/SAMPLE_RATE
    # Sharper pulses and more rasp under load; softer, hollow on overrun.
    var tau: float = lerpf(0.0019,0.0010,load)
    var env_decay: float = exp(-1.0/(tau*SAMPLE_RATE))
    var k_att: float = 1.0-exp(-1.0/(lerpf(0.00010,0.00004,load)*SAMPLE_RATE))
    var pop_decay: float = exp(-1.0/(0.009*SAMPLE_RATE))
    var mech_decay: float = exp(-1.0/(0.0006*SAMPLE_RATE))
    var rasp: float = lerpf(0.12,0.55,load)
    var body_k: float = lerpf(0.10,0.22,load)
    var rev: float = clampf(rpm/limit_rpm,0.0,1.0)
    var g_body: float = 0.55
    var g_boom: float = lerpf(1.0,0.55,rev)*boom_gain
    var g_pipe: float = lerpf(0.55,0.95,load)
    var g_rasp: float = lerpf(0.12,0.60,load)*lerpf(0.6,1.4,rev)
    var g_intake: float = lerpf(0.0,0.75,load)*rev*intake_gain
    var g_mech: float = MECH_GAIN*lerpf(1.0,0.55,load)*lerpf(0.8,1.6,rev)
    var g_jet: float = JET_GAIN*jet*lerpf(0.12,1.0,load*load)*lerpf(0.55,1.25,rev)
    var k_jlp: float = 1.0-exp(-TAU*2400.0/SAMPLE_RATE)
    var k_jhp: float = 1.0-exp(-TAU*500.0/SAMPLE_RATE)
    var amp: float = master*0.66*lerpf(0.85,1.0,load)*lerpf(0.85,1.35,rev)
    # Soft saturation of the exhaust note, harder under load.
    var drive: float = lerpf(0.35,0.9,load)
    var make_up: float = 1.0+drive*0.25
    var cb: Vector3 = _coef["boom"]
    var cp: Vector3 = _coef["pipe"]
    var cr: Vector3 = _coef["rasp"]
    var ci: Vector3 = _coef["intake"]
    var cm: Vector3 = _coef["mech"]
    var k_damp: float = 1.0-exp(-TAU*pipe_damp_hz/SAMPLE_RATE)
    var hr: float = header_reflect
    var tr: float = tail_reflect
    var two_banks: bool = _banks > 1
    var room_g: float = room
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
    # Hot state in locals (much faster than member access in GDScript).
    # The delay-line arrays are taken out of the members while rendering so
    # writes do not trigger a copy-on-write of the whole buffer.
    var hb0: PackedFloat32Array = _hb0
    var hb1: PackedFloat32Array = _hb1
    var tb: PackedFloat32Array = _tb
    var rb: PackedFloat32Array = _rb
    _hb0 = PackedFloat32Array()
    _hb1 = PackedFloat32Array()
    _tb = PackedFloat32Array()
    _rb = PackedFloat32Array()
    var cyc: float = _cycle
    var next_fire: float = _next_fire
    var e0: float = _e0
    var e1: float = _e1
    var a0: float = _a0
    var a1: float = _a1
    var mech: float = _mech
    var pop: float = _pop
    var body: float = _body
    var b1: float = _b1
    var b2: float = _b2
    var p1: float = _p1
    var p2: float = _p2
    var r1: float = _r1
    var r2: float = _r2
    var i1: float = _i1
    var i2: float = _i2
    var m1: float = _m1
    var m2: float = _m2
    var jh: float = _jh
    var jh2: float = _jh2
    var jl: float = _jl
    var hl0: float = _hl0
    var hl1: float = _hl1
    var tl: float = _tl
    var rl: float = _rl
    var dc_x: float = _dc_x
    var dc_y: float = _dc_y
    var seed: int = _seed
    var seed2: int = _seed2
    var w: int = _w
    var hd0: int = _hd0
    var hd1: int = _hd1
    var td: int = _td
    var lag: int = _lag
    var squealing: bool = sq_amp > 0.002
    var sq_scale: float = sq_amp*tyre_gain
    var sq0: float = _sq_state[0]
    var sq1: float = _sq_state[1]
    var sq2: float = _sq_state[2]
    var sq3: float = _sq_state[3]
    var sq4: float = _sq_state[4]
    var sq5: float = _sq_state[5]
    var fl_ph: float = _sq_flutter_ph
    var sq_g: float = _sq_gain
    var sq_g_target: float = _sq_gain_target
    for i in range(frames):
        cyc += cyc_inc
        if cyc >= next_fire:
            _next_fire = next_fire
            _pop = pop
            var st: float = _fire()
            next_fire = _next_fire
            pop = _pop
            if _fire_bank == 0:
                e0 += st
            else:
                e1 += st
            mech += _mech_kick
        if cyc >= 1.0:
            cyc -= 1.0
            next_fire -= 1.0
        seed = (seed*1103515245+12345) & 0x7fffffff
        var noise: float = float(seed)/1073741823.5-1.0
        seed2 = (seed2*1664525+1013904223) & 0x7fffffff
        var noise2: float = float(seed2)/1073741823.5-1.0
        e0 *= env_decay
        a0 += (e0-a0)*k_att
        pop *= pop_decay
        mech *= mech_decay
        # Blow-down pulse with turbulent flow noise, through its header.
        var hp: int = w & 511
        hl0 += (hb0[(w-hd0) & 511]-hl0)*k_damp
        var h: float = a0*(1.0+noise*rasp)+hr*hl0
        hb0[hp] = h
        if two_banks:
            e1 *= env_decay
            a1 += (e1-a1)*k_att
            hl1 += (hb1[(w-hd1) & 511]-hl1)*k_damp
            hb1[hp] = a1*(1.0+noise2*rasp)+hr*hl1
            h += hb1[(w-lag) & 511]
        var x: float = h+noise*pop*1.4
        body += (x-body)*body_k
        var yb: float = cb.z*x+cb.x*b1-cb.y*b2
        b2 = b1
        b1 = yb
        var yp: float = cp.z*x+cp.x*p1-cp.y*p2
        p2 = p1
        p1 = yp
        var yr: float = cr.z*x+cr.x*r1-cr.y*r2
        r2 = r1
        r1 = yr
        var ex: float = body*g_body+yb*g_boom*6.0+yp*g_pipe*3.0+yr*g_rasp*2.0
        # Tail pipe: the whole exhaust note rings through its modes.
        tl += (tb[(w-td) & 511]-tl)*k_damp
        var t_out: float = ex+tr*tl
        tb[hp] = t_out
        var xi: float = noise*(0.25+a0+a1)
        var yi: float = ci.z*xi+ci.x*i1-ci.y*i2
        i2 = i1
        i1 = yi
        var xm: float = noise2*mech
        var ym: float = cm.z*xm+cm.x*m1-cm.y*m2
        m2 = m1
        m1 = ym
        # Turbulent jet at the pipe exit: band-passed noise that breathes
        # with every exhaust pulse (where a real recording's 1-4 kHz is).
        jh += (noise2*(a0+a1+0.02)-jh)*k_jlp
        jh2 += (jh-jh2)*k_jlp
        jl += (jh2-jl)*k_jhp
        var mix: float = t_out+yi*g_intake*1.6+(jh2-jl)*g_jet
        # DC blocker (pulses are one-sided pressure).
        var dc: float = mix-dc_x+0.996*dc_y
        dc_x = mix
        dc_y = dc
        var e: float = dc*amp
        e = e*make_up/(1.0+drive*absf(e))
        var s: float = (e+ym*g_mech*amp)*engine_gain
        if squealing:
            var y0: float = q0.z*noise+q0.x*sq0-q0.y*sq1
            sq1 = sq0
            sq0 = y0
            var y1: float = q1.z*noise+q1.x*sq2-q1.y*sq3
            sq3 = sq2
            sq2 = y1
            var y2: float = q2.z*noise+q2.x*sq4-q2.y*sq5
            sq5 = sq4
            sq4 = y2
            fl_ph += fl_inc
            if fl_ph >= 1.0:
                fl_ph -= 1.0
            var tri: float = absf(fl_ph*2.0-1.0)
            sq_g += (sq_g_target-sq_g)*0.0006
            s += (y0*7.2+y1*3.6+y2*1.8)*(1.0-fl_depth*tri)*sq_g*sq_scale
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
            s += (z1*2.6+z2*3.2)*_grit*sc_amp*fx_gain
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
            s += (thud*0.95+crunch*0.55+rattle*0.9)*a_imp*fx_gain
            _imp_t += 1.0/SAMPLE_RATE
        # Early reflections (darkened): different taps left and right.
        rl += (s-rl)*0.45
        var rp: int = w & 1023
        rb[rp] = rl
        var left: float = s+room_g*(rb[(w-ROOM_L.x) & 1023]-0.5*rb[(w-ROOM_L.y) & 1023])
        var right: float = s+room_g*(rb[(w-ROOM_R.x) & 1023]-0.5*rb[(w-ROOM_R.y) & 1023])
        w = (w+1) & 0xfffff
        # Soft knee limiter: never clips, untouched below 0.8.
        var al: float = absf(left)
        if al > 0.8:
            left = signf(left)*(0.8+0.19*(1.0-exp(-(al-0.8)/0.19)))
        var ar: float = absf(right)
        if ar > 0.8:
            right = signf(right)*(0.8+0.19*(1.0-exp(-(ar-0.8)/0.19)))
        out[i] = Vector2(left,right)
    _hb0 = hb0
    _hb1 = hb1
    _tb = tb
    _rb = rb
    _cycle = cyc
    _next_fire = next_fire
    _e0 = e0
    _e1 = e1
    _a0 = a0
    _a1 = a1
    _mech = mech
    _pop = pop
    _body = body
    _b1 = b1
    _b2 = b2
    _p1 = p1
    _p2 = p2
    _r1 = r1
    _r2 = r2
    _i1 = i1
    _i2 = i2
    _m1 = m1
    _m2 = m2
    _jh = jh
    _jh2 = jh2
    _jl = jl
    _hl0 = hl0
    _hl1 = hl1
    _tl = tl
    _rl = rl
    _dc_x = dc_x
    _dc_y = dc_y
    _seed = seed
    _seed2 = seed2
    _w = w
    _sq_state = PackedFloat32Array([sq0,sq1,sq2,sq3,sq4,sq5])
    _sq_flutter_ph = fl_ph
    _sq_gain = sq_g
    return out
