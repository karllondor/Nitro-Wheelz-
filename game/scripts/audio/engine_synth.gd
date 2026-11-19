extends RefCounted
class_name NitroEngineSynth
## Procedural fallback sound for builds without recorded clips:
## one phase-continuous inline-six voice (3 firing pulses per crank turn)
## so the engine keeps the SAME identity from idle to the limiter, plus a
## tyre-squeal layer and short impact thumps. Wavetable based so it stays
## cheap enough for GDScript on Android (no per-sample sin()).

const SAMPLE_RATE: float = 22050.0
const TABLE_SIZE: int = 2048
const IDLE_RPM: float = 950.0
const LIMIT_RPM: float = 7400.0
# Upper speed (km/h) of gears 1..5 for a short-ratio drift box.
const GEAR_TOP: Array[float] = [48.0,82.0,116.0,150.0,195.0]

var rpm: float = IDLE_RPM
var target_rpm: float = IDLE_RPM
var load: float = 0.0          # 0 coast/overrun .. 1 full throttle
var squeal: float = 0.0        # tyre slip loudness 0..1
var gear: int = 1
var master: float = 0.55

var _table := PackedFloat32Array()
var _phase: float = 0.0
var _sub_phase: float = 0.0
var _squeal_phase_a: float = 0.0
var _squeal_phase_b: float = 0.0
var _lp: float = 0.0
var _noise_lp: float = 0.0
var _noise_bp: float = 0.0
var _thump: float = 0.0
var _thump_phase: float = 0.0
var _rng := RandomNumberGenerator.new()
var _wobble: float = 0.0

func _init() -> void:
    _rng.seed = 2106
    # One crank-synchronous cycle: firing fundamental + harmonics, slightly
    # asymmetric so it reads as combustion pulses rather than a pure tone.
    _table.resize(TABLE_SIZE)
    for i in range(TABLE_SIZE):
        var x: float = TAU*float(i)/float(TABLE_SIZE)
        var v: float = sin(x)*1.0+sin(2.0*x+0.3)*0.55+sin(3.0*x+0.9)*0.32+sin(4.0*x+1.7)*0.18
        v += sin(6.0*x+0.4)*0.10+sin(9.0*x+2.1)*0.05
        v += 0.35*pow(maxf(sin(x),0.0),6.0)
        _table[i] = v*0.42

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
    gear = gear_for(speed_kmh)
    target_rpm = rpm_for(speed_kmh,gas,slip)
    # Revs chase the target quickly up, slower down (flywheel inertia).
    var rate: float = 9.0 if target_rpm > rpm else 5.0
    rpm = lerpf(rpm,target_rpm,1.0-exp(-rate*dt))
    load = lerpf(load,clampf(gas,0.0,1.0),1.0-exp(-10.0*dt))
    var squeal_target: float = clampf(slip,0.0,1.0)*clampf(speed_kmh/60.0,0.0,1.0)
    squeal = lerpf(squeal,squeal_target,1.0-exp(-8.0*dt))

func impact(strength: float) -> void:
    _thump = maxf(_thump,clampf(strength,0.0,1.0))
    _thump_phase = 0.0

func firing_hz() -> float:
    return rpm/60.0*3.0

func render(frames: int) -> PackedVector2Array:
    var out := PackedVector2Array()
    out.resize(frames)
    var inc: float = firing_hz()/SAMPLE_RATE
    var sub_inc: float = inc*0.5
    var bright: float = lerpf(0.10,0.45,load)
    var amp: float = master*lerpf(0.30,0.85,load)*lerpf(0.75,1.0,rpm/LIMIT_RPM)
    var rasp: float = lerpf(0.05,0.22,load)
    var sq_amp: float = master*0.55*squeal
    var sq_a: float = (1150.0+squeal*180.0)/SAMPLE_RATE
    var sq_b: float = (1720.0+squeal*240.0)/SAMPLE_RATE
    var size_f: float = float(TABLE_SIZE)
    for i in range(frames):
        _phase += inc
        if _phase >= 1.0:
            _phase -= 1.0
        _sub_phase += sub_inc
        if _sub_phase >= 1.0:
            _sub_phase -= 1.0
        var main: float = _table[int(_phase*size_f)%TABLE_SIZE]
        var sub: float = _table[int(_sub_phase*size_f)%TABLE_SIZE]
        var noise: float = _rng.randf()*2.0-1.0
        # Combustion rasp gated by the firing pulse.
        var pulse: float = maxf(main,0.0)
        var raw: float = main*0.78+sub*0.30+noise*pulse*rasp
        _lp += (raw-_lp)*bright
        var s: float = _lp*amp
        if sq_amp > 0.002:
            _squeal_phase_a = fmod(_squeal_phase_a+sq_a*(1.0+_wobble*0.02),1.0)
            _squeal_phase_b = fmod(_squeal_phase_b+sq_b,1.0)
            _noise_lp += (noise-_noise_lp)*0.22
            _noise_bp = _noise_lp-_noise_bp*0.6
            var tone: float = _table[int(_squeal_phase_a*size_f)%TABLE_SIZE]*0.45+_table[int(_squeal_phase_b*size_f)%TABLE_SIZE]*0.25
            s += (tone+_noise_bp*0.6)*sq_amp
        if _thump > 0.001:
            _thump_phase += 70.0/SAMPLE_RATE
            s += (_table[int(fmod(_thump_phase,1.0)*size_f)%TABLE_SIZE]+noise*0.5)*_thump*master*1.4
            _thump *= 0.9993
        out[i] = Vector2(s,s)
    _wobble = _rng.randf_range(-1.0,1.0)
    return out
