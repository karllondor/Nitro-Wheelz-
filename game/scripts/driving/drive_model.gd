extends RefCounted
class_name NitroDriveModel
## Original deterministic two-axle Nitro Wheelz driving model.
## Tuned against publicly described DRIFTIT behaviours, not copied source:
## stable grip on straights; handbrake initiates drift; throttle sustains it;
## steering/countersteer and lift-off let the driver recover.
## BRAKE decelerates forward motion and becomes REVERSE near standstill.

const FRONT_GRIP: float = 6.15
const REAR_GRIP: float = 5.95
const REAR_SLIDE_GRIP: float = 0.60
const HANDBRAKE_GRIP: float = 0.10
const REATTACH_SECONDS: float = 0.45
const COUNTERSTEER_ASSIST: float = 0.66
const WHEELBASE: float = 2.424
const HALF_WHEELBASE: float = WHEELBASE * 0.5
const DRIVE_ACCEL: float = 11.8
const BRAKE_ACCEL: float = 17.0
const REVERSE_ACCEL: float = 4.8
const REVERSE_LIMIT: float = 8.5
const HANDBRAKE_DECEL: float = 2.0
const DRAG_COEFF: float = 0.009
const ROLLING_DRAG: float = 0.45
const YAW_DAMPING: float = 1.22
const YAW_TORQUE_GAIN: float = 0.522
const YAW_LATERAL_BUDGET: float = 13.5
const SLIDE_YAW_BONUS: float = 2.4
const LOW_SPEED_GRIP_START: float = 2.7

# Profile-tunable parameters. Defaults are the constants above (the Lada
# baseline tune, unchanged since v0.1.12); a car profile may override any of
# them through apply_profile(). Nothing else in the model differs per car.
const TOP_SPEED_MPS: float = 50.0          # drive force fades over the last 5 m/s
const STEER_LOCK_REST_DEG: float = 35.5
const STEER_LOCK_MID_DEG: float = 22.0     # at 72 km/h
const STEER_LOCK_HIGH_DEG: float = 8.5     # at 162 km/h
const POWER_LOSS_BASE: float = 0.83        # rear grip lost to full throttle...
const POWER_LOSS_PER_MPS: float = 0.023    # ...shrinking with speed...
const POWER_LOSS_MAX: float = 0.60         # ...capped here
const POWER_ENTRY_KICK: float = 0.252
const FLICK_YAW_IMPULSE: float = 0.56
const SLIDE_DRIVE_FACTOR: float = 0.76
const ENGINE_BRAKE_DECEL: float = 0.0      # extra decel on lift-off (0 = baseline)
var front_grip: float = FRONT_GRIP
var rear_grip: float = REAR_GRIP
var rear_slide_grip: float = REAR_SLIDE_GRIP
var handbrake_grip: float = HANDBRAKE_GRIP
var reattach_seconds: float = REATTACH_SECONDS
var countersteer_assist: float = COUNTERSTEER_ASSIST
var wheelbase: float = WHEELBASE
var half_wheelbase: float = HALF_WHEELBASE
var drive_accel: float = DRIVE_ACCEL
var brake_accel: float = BRAKE_ACCEL
var reverse_accel: float = REVERSE_ACCEL
var reverse_limit: float = REVERSE_LIMIT
var handbrake_decel: float = HANDBRAKE_DECEL
var drag_coeff: float = DRAG_COEFF
var rolling_drag: float = ROLLING_DRAG
var yaw_damping: float = YAW_DAMPING
var yaw_torque_gain: float = YAW_TORQUE_GAIN
var yaw_lateral_budget: float = YAW_LATERAL_BUDGET
var slide_yaw_bonus: float = SLIDE_YAW_BONUS
var low_speed_grip_start: float = LOW_SPEED_GRIP_START
var top_speed_mps: float = TOP_SPEED_MPS
var steer_lock_rest_deg: float = STEER_LOCK_REST_DEG
var steer_lock_mid_deg: float = STEER_LOCK_MID_DEG
var steer_lock_high_deg: float = STEER_LOCK_HIGH_DEG
var power_loss_base: float = POWER_LOSS_BASE
var power_loss_per_mps: float = POWER_LOSS_PER_MPS
var power_loss_max: float = POWER_LOSS_MAX
var power_entry_kick: float = POWER_ENTRY_KICK
var flick_yaw_impulse: float = FLICK_YAW_IMPULSE
var slide_drive_factor: float = SLIDE_DRIVE_FACTOR
var engine_brake_decel: float = ENGINE_BRAKE_DECEL

## The tunable parameter names, all of which a car profile may set.
const TUNABLE: Array[String] = ["front_grip","rear_grip","rear_slide_grip","handbrake_grip",
    "reattach_seconds","countersteer_assist","wheelbase","drive_accel","brake_accel",
    "reverse_accel","reverse_limit","handbrake_decel","drag_coeff","rolling_drag",
    "yaw_damping","yaw_torque_gain","yaw_lateral_budget","slide_yaw_bonus",
    "low_speed_grip_start","top_speed_mps","steer_lock_rest_deg","steer_lock_mid_deg",
    "steer_lock_high_deg","power_loss_base","power_loss_per_mps","power_loss_max",
    "power_entry_kick","flick_yaw_impulse","slide_drive_factor","engine_brake_decel"]

## Baseline (Lada) values of every tunable parameter.
static func baseline() -> Dictionary:
    return {"front_grip":FRONT_GRIP,"rear_grip":REAR_GRIP,"rear_slide_grip":REAR_SLIDE_GRIP,
        "handbrake_grip":HANDBRAKE_GRIP,"reattach_seconds":REATTACH_SECONDS,
        "countersteer_assist":COUNTERSTEER_ASSIST,"wheelbase":WHEELBASE,"drive_accel":DRIVE_ACCEL,
        "brake_accel":BRAKE_ACCEL,"reverse_accel":REVERSE_ACCEL,"reverse_limit":REVERSE_LIMIT,
        "handbrake_decel":HANDBRAKE_DECEL,"drag_coeff":DRAG_COEFF,"rolling_drag":ROLLING_DRAG,
        "yaw_damping":YAW_DAMPING,"yaw_torque_gain":YAW_TORQUE_GAIN,
        "yaw_lateral_budget":YAW_LATERAL_BUDGET,"slide_yaw_bonus":SLIDE_YAW_BONUS,
        "low_speed_grip_start":LOW_SPEED_GRIP_START,"top_speed_mps":TOP_SPEED_MPS,
        "steer_lock_rest_deg":STEER_LOCK_REST_DEG,"steer_lock_mid_deg":STEER_LOCK_MID_DEG,
        "steer_lock_high_deg":STEER_LOCK_HIGH_DEG,"power_loss_base":POWER_LOSS_BASE,
        "power_loss_per_mps":POWER_LOSS_PER_MPS,"power_loss_max":POWER_LOSS_MAX,
        "power_entry_kick":POWER_ENTRY_KICK,"flick_yaw_impulse":FLICK_YAW_IMPULSE,
        "slide_drive_factor":SLIDE_DRIVE_FACTOR,"engine_brake_decel":ENGINE_BRAKE_DECEL}

## Apply a handling profile: unknown keys are ignored, missing keys keep the
## baseline. Returns the keys that were actually changed.
func apply_profile(handling: Dictionary) -> Array[String]:
    var changed: Array[String] = []
    for key in handling.keys():
        if TUNABLE.has(str(key)):
            var v: float = float(handling[key])
            if v != float(get(str(key))):
                changed.append(str(key))
            set(str(key),v)
    half_wheelbase = wheelbase*0.5
    return changed

var position: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO
var heading: float = 0.0
var yaw_rate: float = 0.0
var rear_traction: float = 1.0
var slide_hold: float = 0.0
var drift_angle: float = 0.0
var steering_angle: float = 0.0
var handbrake_previously_held: bool = false
var handbrake_flick_window: float = 0.0

func reset(p: Vector2, radians: float) -> void:
    position = p
    velocity = Vector2.ZERO
    heading = radians
    yaw_rate = 0.0
    rear_traction = 1.0
    slide_hold = 0.0
    drift_angle = 0.0
    steering_angle = 0.0
    handbrake_previously_held = false
    handbrake_flick_window = 0.0

func speed_mps() -> float:
    return velocity.length()

func speed_kmh() -> float:
    return speed_mps() * 3.6

func forward() -> Vector2:
    return Vector2(sin(heading), -cos(heading))

func right() -> Vector2:
    return Vector2(cos(heading), sin(heading))

func signed_forward_speed_mps() -> float:
    return velocity.dot(forward())

func is_reversing() -> bool:
    return signed_forward_speed_mps() < -0.3

func is_drifting() -> bool:
    return signed_forward_speed_mps() > 0.0 and absf(drift_angle) >= 10.0 and speed_mps() > 4.0

func _tyre_response(slip: float, peak_angle: float) -> float:
    return slip / sqrt(slip*slip + peak_angle*peak_angle)

func _max_steer_for_speed(mps: float) -> float:
    # Balanced mobile arcade tune: 35.5 deg at rest, 22 deg at 72 km/h,
    # 8.5 deg at 162 km/h, between stable v0.1.8 and wild v0.1.9.
    if mps < 20.0:
        return deg_to_rad(lerpf(steer_lock_rest_deg, steer_lock_mid_deg, clampf(mps/20.0, 0.0, 1.0)))
    return deg_to_rad(lerpf(steer_lock_mid_deg, steer_lock_high_deg, clampf((mps-20.0)/25.0, 0.0, 1.0)))

func _power_grip_factor(gas: float, speed_mps_now: float) -> float:
    # DRIFTIT documents up to 60% grip reduction at 36 km/h and
    # about 37% at 72 km/h. Power effects weaken as road speed rises.
    # Nonlinear gas response lets partial Xbox throttle hold a slide.
    var full_power_loss: float = clampf(power_loss_base - speed_mps_now*power_loss_per_mps, 0.10, power_loss_max)
    return 1.0 - full_power_loss*pow(gas, 1.6)

func _yaw_rate_limit(speed_now: float, slide: float) -> float:
    # Maximum sustainable turn rate follows a_y / v, not a constant
    # rad/s across all speeds. The previous ±2.8 rad/s at 80 km/h
    # allowed an implausible sub-10 m turn and sudden sideways travel.
    return clampf(
        (yaw_lateral_budget + slide_yaw_bonus*slide)/maxf(speed_now, 3.0),
        0.29, 2.25
    )

func step(dt: float, steer: float, gas: float, brake: float, handbrake: float) -> void:
    if dt <= 0.0:
        return
    steer = clampf(steer,-1.0,1.0)
    gas = clampf(gas,0.0,1.0)
    brake = clampf(brake,0.0,1.0)
    handbrake = clampf(handbrake,0.0,1.0)
    var drift_pressed: bool = handbrake > 0.35 and not handbrake_previously_held
    handbrake_previously_held = handbrake > 0.35
    if drift_pressed:
        # Allow the steer finger to arrive slightly after the DRIFT finger.
        handbrake_flick_window = 0.12
    elif handbrake <= 0.35:
        handbrake_flick_window = 0.0
    else:
        handbrake_flick_window = maxf(0.0,handbrake_flick_window-dt)

    var f: Vector2 = forward()
    var r: Vector2 = right()
    var signed_speed: float = velocity.dot(f)
    var local_side: float = velocity.dot(r)
    var speed: float = velocity.length()
    var max_steer: float = _max_steer_for_speed(speed)
    # Reverse needs SIGNED bicycle kinematics, not forward-slip tyre forces.
    # Right steering while backing rotates the nose left and the rear right.
    if signed_speed < -0.30 and speed < 10.2:
        slide_hold = 0.0
        rear_traction = move_toward(rear_traction,1.0,dt/reattach_seconds)
        steering_angle = move_toward(steering_angle,steer*max_steer,18.0*dt)
        var reverse_speed: float = signed_speed
        if brake > 0.01 and gas < 0.01:
            reverse_speed = maxf(reverse_speed-reverse_accel*brake*dt,-reverse_limit)
        elif gas > 0.01:
            reverse_speed = minf(reverse_speed+brake_accel*gas*dt,0.0)
        else:
            reverse_speed = minf(0.0,reverse_speed+rolling_drag*dt)
        if handbrake > 0.10:
            reverse_speed = minf(0.0,reverse_speed+handbrake_decel*handbrake*dt)
        var reverse_yaw: float = clampf(reverse_speed*tan(steering_angle)/wheelbase,-1.5,1.5)
        yaw_rate = move_toward(yaw_rate,reverse_yaw,6.0*dt)
        heading = wrapf(heading+yaw_rate*dt,-PI,PI)
        velocity = forward()*reverse_speed
        position += velocity*dt
        drift_angle = 0.0
        return
    var demanded_steer: float = steer*max_steer
    var front_side: float = local_side + yaw_rate*half_wheelbase
    var rear_side: float = local_side - yaw_rate*half_wheelbase
    var slip_forward: float = maxf(absf(signed_speed),2.0)
    var rear_slip: float = atan2(rear_side,slip_forward)

    # Throttle alone on a straight retains grip; deliberate steering + full
    # binary GAS may release the rear before large sideways slip develops.
    # Never force a slide simply because the digital GAS key and STEER
    # are down: real lateral slip must develop first. Only deliberately
    # extreme steering can provoke a low-speed donut.
    var rear_angle: float = absf(rear_slip)
    var powered_entry: bool = gas > 0.78 and absf(steer) > 0.55 and (
        signed_speed > 8.0 and rear_angle > deg_to_rad(3.5))
    var powered_donut: bool = gas > 0.95 and absf(steer) > 0.88 and (
        signed_speed > 2.5 and signed_speed < 8.0)
    var slip_entry: bool = gas > 0.55 and signed_speed > 5.2 and (
        rear_angle > deg_to_rad(7.0))
    var breakaway: bool = (handbrake > 0.10 and speed > 1.5) or powered_entry or powered_donut or slip_entry
    if breakaway:
        slide_hold = 0.34 if handbrake > 0.10 else 0.27
    else:
        slide_hold = maxf(0.0, slide_hold-dt)

    var sliding: bool = slide_hold > 0.0
    var target_traction: float = rear_slide_grip if sliding else 1.0
    if handbrake > 0.1 and speed > 1.5:
        target_traction = handbrake_grip
    # Hard rear lock on the same physics tick as touch, no grip lerp delay.
    if handbrake > 0.35 and speed > 1.5:
        rear_traction = handbrake_grip
    else:
        var response_seconds: float = 0.025 if target_traction < rear_traction else reattach_seconds
        rear_traction = move_toward(rear_traction,target_traction,dt/response_seconds)

    var travel_direction: float = atan2(local_side,slip_forward)
    var slide_fraction: float = clampf((1.0-rear_traction)/(1.0-rear_slide_grip),0.0,1.0)
    var assist_strength: float = countersteer_assist*slide_fraction
    var assisted_steer: float = clampf(
        travel_direction + demanded_steer*0.32,-max_steer,max_steer
    )
    var steer_goal: float = lerpf(demanded_steer,assisted_steer,assist_strength)
    # Smooth stick/key motion. Letting go returns the wheel faster.
    var steer_rate: float = 23.0 if absf(steer_goal)<absf(steering_angle) else 18.0
    steering_angle = move_toward(steering_angle,steer_goal,steer_rate*dt)

    var front_slip: float = atan2(front_side,slip_forward)-steering_angle
    var front_lateral: float = -front_grip*_tyre_response(front_slip,deg_to_rad(8.0))
    var power_factor: float = _power_grip_factor(gas,speed)
    # During an established slide, soften stacked rear-grip reductions,
    # while still allowing heavy throttle to increase oversteer.
    power_factor = lerpf(power_factor,1.0,slide_fraction*0.22)
    var brake_factor: float = 1.0-0.30*brake if signed_speed > 1.0 else 1.0
    var rear_cap: float = rear_grip*rear_traction*power_factor*brake_factor
    var rear_lateral: float = -rear_cap*_tyre_response(rear_slip,deg_to_rad(10.0))

    # No artificial steering in place, including while selecting reverse.
    var moving_grip: float = clampf(speed/low_speed_grip_start,0.0,1.0)
    front_lateral *= moving_grip
    rear_lateral *= moving_grip

    # The axle force difference generates yaw, but at road speed the
    # sustainable rotation is bounded by available lateral acceleration.
    # Preserve strong low-speed drift entries without letting a 90 km/h
    # car whirl as if it were stationary.
    var yaw_accel: float = (front_lateral-rear_lateral)*yaw_torque_gain
    # Small progressive power-oversteer kicker only after slide starts.
    # Straight driving with GAS is not subject to a forced yaw impulse.
    if powered_entry and handbrake < 0.1:
        yaw_accel += steer*power_entry_kick*slide_fraction
    if powered_donut and handbrake < 0.1:
        yaw_accel += steer*0.558*clampf((8.0-speed)/5.0,0.0,1.0)
    # A slide with the joystick near centre should be recoverable. Lift-off
    # increases alignment assistance; full throttle suppresses part of it.
    var hands_off: float = clampf(1.0-absf(steer)*2.7,0.0,1.0)
    var recovery: float = slide_fraction*hands_off*clampf(speed/7.0,0.0,1.0)
    yaw_accel += travel_direction*recovery*2.7*(1.0-0.22*gas)
    yaw_rate += yaw_accel*dt
    if handbrake_flick_window > 0.0 and signed_speed > 4.0 and absf(steer) > 0.08:
        # The first valid steer+DRIFT overlap gives a single, immediate
        # entry impulse. Never repeat it while DRIFT remains pressed.
        yaw_rate += steer*flick_yaw_impulse*clampf(speed/14.0,0.0,1.0)
        handbrake_flick_window = 0.0
    yaw_rate *= exp(-(yaw_damping+0.6*hands_off*(1.0-slide_fraction))*dt)
    var yaw_ceiling: float = _yaw_rate_limit(speed,slide_fraction)
    yaw_rate = clampf(yaw_rate,-yaw_ceiling,yaw_ceiling)

    # BRAKE doubles as REVERSE. Forward speed must be nearly zero before
    # negative motor torque engages; holding BRAKE then backs up to a limit.
    var longitudinal_accel: float = 0.0
    if brake > 0.01:
        if signed_speed > 0.40:
            longitudinal_accel = -minf(brake_accel*brake,signed_speed/dt)
        elif gas < 0.01:
            longitudinal_accel = -reverse_accel*brake if signed_speed > -reverse_limit else 0.0
        elif signed_speed > 0.0:
            longitudinal_accel = -minf(brake_accel*brake,signed_speed/dt)
        else:
            longitudinal_accel = 0.0
    elif gas > 0.01:
        if signed_speed < -0.40:
            longitudinal_accel = minf(brake_accel*gas,-signed_speed/dt)
        else:
            longitudinal_accel = drive_accel*gas
            if speed > top_speed_mps-5.0:
                longitudinal_accel *= clampf(1.0-(speed-(top_speed_mps-5.0))/5.0,0.0,1.0)
            if sliding:
                longitudinal_accel *= slide_drive_factor

    if absf(signed_speed) > 0.02:
        longitudinal_accel -= rolling_drag*signf(signed_speed)
    # Engine braking when the throttle is closed (profile; 0 for the Lada).
    if engine_brake_decel > 0.0 and gas < 0.01 and brake < 0.01 and signed_speed > 1.0:
        longitudinal_accel -= engine_brake_decel
    var acceleration: Vector2 = f*longitudinal_accel
    acceleration += r*(front_lateral+rear_lateral)
    acceleration -= velocity*speed*drag_coeff
    if handbrake > 0.10:
        acceleration -= velocity*(handbrake_decel*handbrake/maxf(speed,1.0))

    velocity += acceleration*dt
    if gas < 0.01 and brake < 0.01 and speed < 0.14:
        velocity = Vector2.ZERO
    heading = wrapf(heading+yaw_rate*dt,-PI,PI)
    position += velocity*dt

    # Drift HUD is about lateral movement, not reverse manoeuvring.
    if signed_forward_speed_mps() < -0.1:
        drift_angle = 0.0
    else:
        drift_angle = rad_to_deg(atan2(
            velocity.dot(right()),maxf(absf(velocity.dot(forward())),0.25)
        ))
