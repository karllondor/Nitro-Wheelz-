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
        return deg_to_rad(lerpf(35.5, 22.0, clampf(mps/20.0, 0.0, 1.0)))
    return deg_to_rad(lerpf(22.0, 8.5, clampf((mps-20.0)/25.0, 0.0, 1.0)))

func _power_grip_factor(gas: float, speed_mps_now: float) -> float:
    # DRIFTIT documents up to 60% grip reduction at 36 km/h and
    # about 37% at 72 km/h. Power effects weaken as road speed rises.
    # Nonlinear gas response lets partial Xbox throttle hold a slide.
    var full_power_loss: float = clampf(0.83 - speed_mps_now*0.023, 0.10, 0.60)
    return 1.0 - full_power_loss*pow(gas, 1.6)

func _yaw_rate_limit(speed_now: float, slide: float) -> float:
    # Maximum sustainable turn rate follows a_y / v, not a constant
    # rad/s across all speeds. The previous ±2.8 rad/s at 80 km/h
    # allowed an implausible sub-10 m turn and sudden sideways travel.
    return clampf(
        (YAW_LATERAL_BUDGET + SLIDE_YAW_BONUS*slide)/maxf(speed_now, 3.0),
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
        rear_traction = move_toward(rear_traction,1.0,dt/REATTACH_SECONDS)
        steering_angle = move_toward(steering_angle,steer*max_steer,18.0*dt)
        var reverse_speed: float = signed_speed
        if brake > 0.01 and gas < 0.01:
            reverse_speed = maxf(reverse_speed-REVERSE_ACCEL*brake*dt,-REVERSE_LIMIT)
        elif gas > 0.01:
            reverse_speed = minf(reverse_speed+BRAKE_ACCEL*gas*dt,0.0)
        else:
            reverse_speed = minf(0.0,reverse_speed+ROLLING_DRAG*dt)
        if handbrake > 0.10:
            reverse_speed = minf(0.0,reverse_speed+HANDBRAKE_DECEL*handbrake*dt)
        var reverse_yaw: float = clampf(reverse_speed*tan(steering_angle)/WHEELBASE,-1.5,1.5)
        yaw_rate = move_toward(yaw_rate,reverse_yaw,6.0*dt)
        heading = wrapf(heading+yaw_rate*dt,-PI,PI)
        velocity = forward()*reverse_speed
        position += velocity*dt
        drift_angle = 0.0
        return
    var demanded_steer: float = steer*max_steer
    var front_side: float = local_side + yaw_rate*HALF_WHEELBASE
    var rear_side: float = local_side - yaw_rate*HALF_WHEELBASE
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
    var target_traction: float = REAR_SLIDE_GRIP if sliding else 1.0
    if handbrake > 0.1 and speed > 1.5:
        target_traction = HANDBRAKE_GRIP
    # Hard rear lock on the same physics tick as touch, no grip lerp delay.
    if handbrake > 0.35 and speed > 1.5:
        rear_traction = HANDBRAKE_GRIP
    else:
        var response_seconds: float = 0.025 if target_traction < rear_traction else REATTACH_SECONDS
        rear_traction = move_toward(rear_traction,target_traction,dt/response_seconds)

    var travel_direction: float = atan2(local_side,slip_forward)
    var slide_fraction: float = clampf((1.0-rear_traction)/(1.0-REAR_SLIDE_GRIP),0.0,1.0)
    var assist_strength: float = COUNTERSTEER_ASSIST*slide_fraction
    var assisted_steer: float = clampf(
        travel_direction + demanded_steer*0.32,-max_steer,max_steer
    )
    var steer_goal: float = lerpf(demanded_steer,assisted_steer,assist_strength)
    # Smooth stick/key motion. Letting go returns the wheel faster.
    var steer_rate: float = 23.0 if absf(steer_goal)<absf(steering_angle) else 18.0
    steering_angle = move_toward(steering_angle,steer_goal,steer_rate*dt)

    var front_slip: float = atan2(front_side,slip_forward)-steering_angle
    var front_lateral: float = -FRONT_GRIP*_tyre_response(front_slip,deg_to_rad(8.0))
    var power_factor: float = _power_grip_factor(gas,speed)
    # During an established slide, soften stacked rear-grip reductions,
    # while still allowing heavy throttle to increase oversteer.
    power_factor = lerpf(power_factor,1.0,slide_fraction*0.22)
    var brake_factor: float = 1.0-0.30*brake if signed_speed > 1.0 else 1.0
    var rear_cap: float = REAR_GRIP*rear_traction*power_factor*brake_factor
    var rear_lateral: float = -rear_cap*_tyre_response(rear_slip,deg_to_rad(10.0))

    # No artificial steering in place, including while selecting reverse.
    var moving_grip: float = clampf(speed/LOW_SPEED_GRIP_START,0.0,1.0)
    front_lateral *= moving_grip
    rear_lateral *= moving_grip

    # The axle force difference generates yaw, but at road speed the
    # sustainable rotation is bounded by available lateral acceleration.
    # Preserve strong low-speed drift entries without letting a 90 km/h
    # car whirl as if it were stationary.
    var yaw_accel: float = (front_lateral-rear_lateral)*YAW_TORQUE_GAIN
    # Small progressive power-oversteer kicker only after slide starts.
    # Straight driving with GAS is not subject to a forced yaw impulse.
    if powered_entry and handbrake < 0.1:
        yaw_accel += steer*0.252*slide_fraction
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
        yaw_rate += steer*0.56*clampf(speed/14.0,0.0,1.0)
        handbrake_flick_window = 0.0
    yaw_rate *= exp(-(YAW_DAMPING+0.6*hands_off*(1.0-slide_fraction))*dt)
    var yaw_ceiling: float = _yaw_rate_limit(speed,slide_fraction)
    yaw_rate = clampf(yaw_rate,-yaw_ceiling,yaw_ceiling)

    # BRAKE doubles as REVERSE. Forward speed must be nearly zero before
    # negative motor torque engages; holding BRAKE then backs up to a limit.
    var longitudinal_accel: float = 0.0
    if brake > 0.01:
        if signed_speed > 0.40:
            longitudinal_accel = -minf(BRAKE_ACCEL*brake,signed_speed/dt)
        elif gas < 0.01:
            longitudinal_accel = -REVERSE_ACCEL*brake if signed_speed > -REVERSE_LIMIT else 0.0
        elif signed_speed > 0.0:
            longitudinal_accel = -minf(BRAKE_ACCEL*brake,signed_speed/dt)
        else:
            longitudinal_accel = 0.0
    elif gas > 0.01:
        if signed_speed < -0.40:
            longitudinal_accel = minf(BRAKE_ACCEL*gas,-signed_speed/dt)
        else:
            longitudinal_accel = DRIVE_ACCEL*gas
            if speed > 45.0:
                longitudinal_accel *= clampf(1.0-(speed-45.0)/5.0,0.0,1.0)
            if sliding:
                longitudinal_accel *= 0.76

    if absf(signed_speed) > 0.02:
        longitudinal_accel -= ROLLING_DRAG*signf(signed_speed)
    var acceleration: Vector2 = f*longitudinal_accel
    acceleration += r*(front_lateral+rear_lateral)
    acceleration -= velocity*speed*DRAG_COEFF
    if handbrake > 0.10:
        acceleration -= velocity*(HANDBRAKE_DECEL*handbrake/maxf(speed,1.0))

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
