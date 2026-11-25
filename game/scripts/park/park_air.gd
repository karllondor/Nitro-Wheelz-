extends RefCounted
## Park-specific vertical motion. The stock planar drive model still handles run-ups and landings.
const SITE = preload("res://scripts/park/park_site.gd")
const GRAVITY := 9.81
const MAX_LIFT := 5.0

var deck := -1
var height := 0.0
var pitch := 0.0
var vertical_speed := 0.0
var airborne := false
var launches := 0
var landings := 0

func reset() -> void:
    deck = -1
    height = 0.0
    pitch = 0.0
    vertical_speed = 0.0
    airborne = false

## Returns true if the normal ground traction step should be skipped this tick.
func advance(model: NitroDriveModel, dt: float) -> bool:
    if not airborne:
        return false
    model.position += model.velocity * dt
    height += vertical_speed * dt - 0.5 * GRAVITY * dt * dt
    vertical_speed -= GRAVITY * dt
    var flight_pitch := atan2(vertical_speed, maxf(model.speed_mps(), 5.0))
    pitch = lerpf(pitch, clampf(flight_pitch * 0.55, -0.24, 0.29), 1.0 - exp(-7.0 * dt))
    if height <= 0.0:
        reset()
        landings += 1
    return true

func ground_step(previous: Vector2, model: NitroDriveModel) -> void:
    if airborne or not SITE.STUNT.grow(5.0).has_point(model.position):
        return
    if deck < 0:
        deck = _approached_deck(previous, model)
        if deck < 0:
            return
    var ramp: Dictionary = SITE.RAMPS[deck]
    var across: float = absf(model.position.x - ramp.start.x)
    var progress: float = ramp.start.y - model.position.y
    if progress < -4.2:
        reset()
        return
    if progress >= ramp.run:
        height = ramp.rise
        var forward_speed := maxf(1.0, -model.velocity.y)
        # At road speed, cap airtime to the measured clear run-out.
        var time_budget: float = (ramp.landing.size.y - 4.0) / forward_speed
        var lift_budget := maxf(0.0, (0.5 * GRAVITY * time_budget * time_budget - height) / time_budget)
        _launch(model, minf(forward_speed * float(ramp.rise) / float(ramp.run) * 0.82, minf(MAX_LIFT, lift_budget)))
        return
    if across > float(ramp.width) * 0.5 - 0.42:
        if height > 0.12:
            _launch(model, 0.0)
        else:
            reset()
        return
    height = clampf(progress / float(ramp.run), 0.0, 1.0) * float(ramp.rise)
    pitch = atan(float(ramp.rise) / float(ramp.run)) * smoothstep(0.0, 1.7, progress)

func _approached_deck(previous: Vector2, model: NitroDriveModel) -> int:
    if model.velocity.y > -0.45 or model.forward().dot(SITE.RAMP_DIR) < 0.72:
        return -1
    for i in SITE.RAMPS.size():
        var ramp: Dictionary = SITE.RAMPS[i]
        var progress: float = ramp.start.y - model.position.y
        if progress >= -4.0 and progress < 0.35 and previous.y >= float(ramp.start.y) - 0.35 and                 absf(model.position.x - ramp.start.x) < float(ramp.width) * 0.5 - 0.85:
            return i
    return -1

func _launch(model: NitroDriveModel, lift: float) -> void:
    vertical_speed = maxf(0.0, lift)
    airborne = true
    model.yaw_rate = 0.0
    model.slide_hold = 0.0
    launches += 1
