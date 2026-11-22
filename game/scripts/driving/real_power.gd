extends RefCounted
class_name NitroRealPower
## REAL_POWER_TEST (diagnostic mode "A", owner decision 2026-11-22, issue #25).
##
## Replaces ONLY the longitudinal force of the arcade drive model with a power
## curve: wheel force = engine power at the current revs / speed, capped by the
## launch traction, with a gearbox that the GAME shifts (the real builds have a
## mechanical manual box; the player has no gear / clutch controls). Steering,
## grip, drift, braking and reverse stay the approved arcade handling.
##
##   a_drive(v) = min(a_launch, gas * eta * P(rpm) / (m * v))        P(rpm) = engine power curve
##   a_drag(v)  = rho * CdA / (2 m) * v^2  +  Crr * g                (the real drag, not the arcade one)
##
## Engine power curve: EITHER a torque table "torque_table": [[rpm, Nm], ...] (linear between the
## points; P = T * omega) - published points and estimated points are told apart in the profile -
## OR the cubic "Heywood" family  P(x) = P_peak * x * (a + b*x - c*x^2),  a + b - c = 1,
## x = rpm / power_rpm.
## Gearing: gear_top_kmh[i] is the road speed at the END of gear i (at shift_up_rpm); the
## same table drives the engine sound (engine block), so sound and physics agree.
## First gear slips the clutch below launch_rpm (the engine does not stall).
##
## Every number comes from the car profile ("real_power" block + the "engine" block); what is a
## published fact and what is an estimate is written beside it in the profile (provenance).
## Nothing here is saved, scored or counted: records / stars ignore this mode (race_results.gd).
const G: float = 9.81
const RHO: float = 1.2

var mass_kg: float = 1150.0
var power_w: float = 170000.0            # engine peak power (W)
var power_rpm: float = 6000.0
var curve_a: float = 1.0
var curve_b: float = 1.0
var curve_c: float = 1.0
var efficiency: float = 0.85             # drivetrain (manual RWD)
var cda: float = 0.85                    # drag area Cd * A (m2)
var crr: float = 0.012                   # rolling resistance coefficient
var launch_accel: float = 5.5            # traction limit of a RWD street-tyre car (m/s2)
var launch_rpm_frac: float = 0.5         # clutch slip below this share of power_rpm in first gear
var idle_rpm: float = 900.0
var limit_rpm: float = 7000.0            # rev limiter
var shift_up_rpm: float = 6500.0
var shift_down_frac: float = 0.55        # downshift below this share of shift_up_rpm
var shift_seconds: float = 0.25          # torque interruption of an upshift under power
var engine_brake: float = 1.0            # m/s2 on lift-off at shift_up_rpm (scaled by revs)
var gear_top_kmh: Array[float] = [48.0,82.0,116.0,150.0,195.0]
var _t_rpm: Array[float] = []            # torque table (empty = the cubic family)
var _t_nm: Array[float] = []

# State.
var gear: int = 0                        # 0-based index
var shift_left: float = 0.0
## Derived (call refresh() after changing the inputs above).
var drag_k: float = 0.0                  # quadratic drag per unit mass (1/m)
var rolling: float = 0.0                 # rolling resistance (m/s2)

func configure(d: Dictionary) -> void:
    mass_kg = float(d.get("mass_kg",mass_kg))
    power_w = float(d.get("power_ps",power_w/735.5))*735.5   # cubic family only; a torque table sets the curve itself
    power_rpm = float(d.get("power_rpm",power_rpm))
    var curve: Array = d.get("torque_curve",[curve_a,curve_b,curve_c])
    if curve.size() == 3:
        curve_a = float(curve[0])
        curve_b = float(curve[1])
        curve_c = float(curve[2])
    efficiency = float(d.get("efficiency",efficiency))
    cda = float(d.get("cda",cda))
    crr = float(d.get("crr",crr))
    launch_accel = float(d.get("launch_accel",launch_accel))
    launch_rpm_frac = float(d.get("launch_rpm_frac",launch_rpm_frac))
    idle_rpm = float(d.get("idle_rpm",idle_rpm))
    limit_rpm = float(d.get("limit_rpm",limit_rpm))
    shift_up_rpm = float(d.get("shift_up_rpm",shift_up_rpm))
    shift_down_frac = float(d.get("shift_down_frac",shift_down_frac))
    shift_seconds = float(d.get("shift_seconds",shift_seconds))
    engine_brake = float(d.get("engine_brake",engine_brake))
    if d.has("gear_top_kmh"):
        gear_top_kmh.assign(d["gear_top_kmh"])
    _t_rpm.clear()
    _t_nm.clear()
    for pt in d.get("torque_table",[]):
        _t_rpm.append(float(pt[0]))
        _t_nm.append(float(pt[1]))
    refresh()
    reset()

func refresh() -> void:
    drag_k = RHO*cda/(2.0*maxf(mass_kg,1.0))
    rolling = crr*G

func reset() -> void:
    gear = 0
    shift_left = 0.0

func gear_number() -> int:
    return gear+1

## Engine torque (Nm) from the table at an engine speed (table mode only).
func torque_at(rpm: float) -> float:
    if rpm <= _t_rpm[0]:
        return _t_nm[0]
    for i in range(1,_t_rpm.size()):
        if rpm <= _t_rpm[i]:
            return lerpf(_t_nm[i-1],_t_nm[i],(rpm-_t_rpm[i-1])/maxf(_t_rpm[i]-_t_rpm[i-1],1.0))
    return _t_nm[_t_nm.size()-1]

## Engine power (W, before the drivetrain loss) at an engine speed.
func engine_power(rpm: float) -> float:
    var r: float = maxf(rpm,idle_rpm)
    if _t_rpm.size() > 1:
        return maxf(0.0,torque_at(r)*r*TAU/60.0)
    var x: float = r/power_rpm
    return maxf(0.0,power_w*x*(curve_a+curve_b*x-curve_c*x*x))

## Engine power at the wheels (W) at an engine speed.
func wheel_power(rpm: float) -> float:
    return engine_power(rpm)*efficiency

## Peak engine power (PS) of the curve between idle and the limiter (documentation / tests).
func peak_power_ps() -> float:
    var best: float = 0.0
    var r: float = idle_rpm
    while r <= limit_rpm:
        best = maxf(best,engine_power(r))
        r += 50.0
    return best/735.5

## Engine speed in the current gear at a road speed (m/s); first gear slips the clutch.
func rpm_at(v: float) -> float:
    var rpm: float = shift_up_rpm*v*3.6/gear_top_kmh[gear]
    if gear == 0:
        rpm = maxf(rpm,launch_rpm_frac*power_rpm)
    return maxf(rpm,idle_rpm)

## Gearbox bookkeeping for one physics tick (also with the throttle closed, so the
## gear always matches the road speed). The game shifts, the player does not.
func update(v: float, dt: float) -> void:
    shift_left = maxf(0.0,shift_left-dt)
    var kmh: float = v*3.6
    var rpm_gear: float = shift_up_rpm*kmh/gear_top_kmh[gear]
    if rpm_gear >= shift_up_rpm and gear < gear_top_kmh.size()-1:
        gear += 1
        shift_left = shift_seconds
    elif gear > 0 and rpm_gear < shift_down_frac*shift_up_rpm:
        gear -= 1

## Forward acceleration from the engine (m/s2, >= 0) at a road speed and throttle.
func drive_accel(v: float, gas: float) -> float:
    if gas <= 0.0 or shift_left > 0.0:
        return 0.0
    var rpm: float = rpm_at(v)
    if gear > 0 and rpm > limit_rpm:
        return 0.0                                  # rev limiter: top speed of the top gear
    var v_eff: float = v
    if gear == 0:
        v_eff = maxf(v,gear_top_kmh[0]*launch_rpm_frac*power_rpm/shift_up_rpm/3.6)
    v_eff = maxf(v_eff,0.5)
    var a_full: float = wheel_power(rpm)/(mass_kg*v_eff)
    return minf(launch_accel,a_full*clampf(gas,0.0,1.0))

## Deceleration of the engine on a closed throttle (m/s2), grows with revs.
func engine_brake_accel(v: float) -> float:
    return engine_brake*clampf(rpm_at(v)/shift_up_rpm,0.25,1.2)

## Top speed of the top gear (km/h) set by the limiter, ignoring drag.
func limiter_speed_kmh() -> float:
    return limit_rpm/shift_up_rpm*gear_top_kmh[gear_top_kmh.size()-1]

## One line for DEVELOPER diagnostics.
func status_text(v: float) -> String:
    return "gear %d  %d rpm%s  P %.0f kW" % [gear+1,int(rpm_at(v)),"  SHIFT" if shift_left > 0.0 else "",wheel_power(rpm_at(v))/1000.0]
