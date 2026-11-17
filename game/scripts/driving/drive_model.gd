extends RefCounted
class_name NitroDriveModel
## Original planar arcade model. Two virtual tyre contact patches, rear slip hysteresis,
## countersteer assistance and fixed-step integration. Inspired by public DRIFTIT notes;
## no DRIFTIT code is imported.

const FRONT_GRIP: float = 5.6
const REAR_GRIP: float = 6.4
const REAR_SLIDE_GRIP: float = 0.62
const HANDBRAKE_GRIP: float = 0.10
const REATTACH_SECONDS: float = 0.45
const COUNTERSTEER_ASSIST: float = 0.82
const WHEELBASE: float = 2.55
const HALF_WHEELBASE: float = WHEELBASE * 0.5
const DRIVE_ACCEL: float = 10.5
const BRAKE_ACCEL: float = 17.0
const HANDBRAKE_DECEL: float = 2.0
const DRAG_COEFF: float = 0.009
const ROLLING_DRAG: float = 0.45

var position: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO
var heading: float = 0.0
var yaw_rate: float = 0.0
var rear_traction: float = 1.0
var slide_hold: float = 0.0
var drift_angle: float = 0.0
var steering_angle: float = 0.0

func reset(p: Vector2, radians: float) -> void:
    position = p
    velocity = Vector2.ZERO
    heading = radians
    yaw_rate = 0.0
    rear_traction = 1.0
    slide_hold = 0.0
    drift_angle = 0.0
    steering_angle = 0.0

func speed_mps() -> float:
    return velocity.length()

func speed_kmh() -> float:
    return speed_mps() * 3.6

func forward() -> Vector2:
    return Vector2(sin(heading), -cos(heading))

func right() -> Vector2:
    return Vector2(cos(heading), sin(heading))

func is_drifting() -> bool:
    return absf(drift_angle) >= 10.0 and speed_mps() > 4.0

func _tyre_response(slip: float, peak_angle: float) -> float:
    # Smooth saturation at the published front/rear slip-angle scale.
    return slip / sqrt(slip * slip + peak_angle * peak_angle)

func step(dt: float, steer: float, gas: float, brake: float, handbrake: float) -> void:
    if dt <= 0.0:
        return
    steer = clampf(steer, -1.0, 1.0)
    gas = clampf(gas, 0.0, 1.0)
    brake = clampf(brake, 0.0, 1.0)
    handbrake = clampf(handbrake, 0.0, 1.0)

    var f: Vector2 = forward()
    var r: Vector2 = right()
    var local_forward: float = velocity.dot(f)
    var local_side: float = velocity.dot(r)
    var speed: float = velocity.length()
    var speed_ratio: float = clampf(speed / 45.0, 0.0, 1.0)
    var max_steer: float = deg_to_rad(35.5 - 28.5 * pow(speed_ratio, 0.68))
    var demanded_steer: float = steer * max_steer

    # Axle contact velocities include yaw motion, rather than turning the
    # entire velocity vector to face the car.
    var front_side: float = local_side + yaw_rate * HALF_WHEELBASE
    var rear_side: float = local_side - yaw_rate * HALF_WHEELBASE
    var speed_for_slip: float = maxf(absf(local_forward), 2.0)
    var rear_slip: float = atan2(rear_side, speed_for_slip)

    var breakaway: bool = handbrake > 0.10 or (
        speed > 4.0 and absf(rear_slip) > deg_to_rad(10.0)
    )
    if breakaway:
        slide_hold = REATTACH_SECONDS
    else:
        slide_hold = maxf(0.0, slide_hold - dt)

    var sliding: bool = slide_hold > 0.0
    var target_traction: float = 1.0
    if sliding:
        target_traction = REAR_SLIDE_GRIP
    if handbrake > 0.10:
        target_traction = HANDBRAKE_GRIP

    var response: float = 0.04 if handbrake > 0.10 or target_traction < rear_traction else REATTACH_SECONDS
    rear_traction = move_toward(rear_traction, target_traction, dt / response)

    var travel_direction: float = atan2(local_side, speed_for_slip)
    var assist_strength: float = COUNTERSTEER_ASSIST * clampf(
        (1.0 - rear_traction) / (1.0 - REAR_SLIDE_GRIP), 0.0, 1.0
    )
    var assisted_steer: float = clampf(
        travel_direction + demanded_steer * 0.32, -max_steer, max_steer
    )
    steering_angle = lerpf(demanded_steer, assisted_steer, assist_strength)

    var front_slip: float = atan2(front_side, speed_for_slip) - steering_angle
    var front_lateral_accel: float = -FRONT_GRIP * _tyre_response(
        front_slip, deg_to_rad(8.0)
    )
    var traction_from_power: float = 1.0 - 0.60 * gas
    var traction_from_braking: float = 1.0 - 0.30 * brake
    var rear_cap: float = REAR_GRIP * rear_traction * traction_from_power * traction_from_braking
    var rear_lateral_accel: float = -rear_cap * _tyre_response(
        rear_slip, deg_to_rad(10.0)
    )

    # No tyre turning force while stationary: prevent steering in place.
    var low_speed_grip: float = clampf(speed / 3.0, 0.0, 1.0)
    front_lateral_accel *= low_speed_grip
    rear_lateral_accel *= low_speed_grip

    # Differential lateral forces generate yaw. Damping limits endless spins.
    var yaw_accel: float = (front_lateral_accel - rear_lateral_accel) * 0.65
    yaw_rate += yaw_accel * dt
    yaw_rate *= exp(-0.62 * dt)
    yaw_rate = clampf(yaw_rate, -3.2, 3.2)

    var engine: float = DRIVE_ACCEL * gas
    if speed > 45.0:
        engine *= clampf(1.0 - (speed - 45.0) / 5.0, 0.0, 1.0)
    if sliding:
        engine *= 0.60
    # Apply brakes only against existing velocity; never drive backwards from rest.
    var effective_brake: float = 0.0
    if absf(local_forward) > 0.001:
        effective_brake = minf(BRAKE_ACCEL * brake, absf(local_forward) / dt) * signf(local_forward)
    var longitudinal_accel: float = engine - effective_brake - ROLLING_DRAG * signf(local_forward)
    var acceleration: Vector2 = f * longitudinal_accel
    acceleration += r * (front_lateral_accel + rear_lateral_accel)
    acceleration -= velocity * speed * DRAG_COEFF
    if handbrake > 0.10:
        acceleration -= velocity * HANDBRAKE_DECEL * handbrake / maxf(speed, 1.0)

    velocity += acceleration * dt
    if gas < 0.01 and brake < 0.01 and speed < 0.13:
        velocity = Vector2.ZERO
    heading = wrapf(heading + yaw_rate * dt, -PI, PI)
    position += velocity * dt

    var travel_f: Vector2 = forward()
    var travel_r: Vector2 = right()
    drift_angle = rad_to_deg(atan2(
        velocity.dot(travel_r), maxf(absf(velocity.dot(travel_f)), 0.25)
    ))

