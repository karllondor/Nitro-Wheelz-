extends RefCounted
class_name NitroPhysicsDev
## Developer Mode elevation physics (local setting, never saved in tracks).
##
## The arcade drive model stays planar (2D) and its handling is unchanged;
## a terrain road adds:
##   grade_force  0 / 25 / 50 / 75 / 100 % of the gravity component along
##                the road (g * sin(atan(grade))) as a planar acceleration.
##                Default 0 % = exactly the flat handling.
##   camera_pitch cameras follow the road grade (visual).
##   banking      visual body roll from lateral acceleration + road cross-
##                fall (roads are level across, so cross-fall reads 0).
##   grounding    "snap": car height = road height every tick;
##                "smooth": damped follow (visual).
##   suspension   visual heave / pitch from longitudinal acceleration.
##   telemetry    on-screen readout of all of the above + traction values.
## Switchable at any time, no terrain regeneration.
const SETTINGS_PATH: String = "user://nitro_settings.cfg"
const SECTION: String = "physics_dev"
const GRADE_STEPS: Array[int] = [0,25,50,75,100]
const G: float = 9.81
const DEFAULTS: Dictionary = {"grade_force":0,"camera_pitch":true,"banking":false,"grounding":"snap",
    "suspension":false,"telemetry":false}

static func load_settings() -> Dictionary:
    var out: Dictionary = DEFAULTS.duplicate()
    var cfg := ConfigFile.new()
    if cfg.load(SETTINGS_PATH) != OK:
        return out
    for k in DEFAULTS.keys():
        out[k] = cfg.get_value(SECTION,k,DEFAULTS[k])
    out["grade_force"] = clampi(int(out["grade_force"]),0,100)
    if str(out["grounding"]) not in ["snap","smooth"]:
        out["grounding"] = "snap"
    return out

static func save_settings(s: Dictionary) -> void:
    var cfg := ConfigFile.new()
    cfg.load(SETTINGS_PATH)  # keep the other sections
    for k in DEFAULTS.keys():
        cfg.set_value(SECTION,k,s.get(k,DEFAULTS[k]))
    cfg.save(SETTINGS_PATH)

static func set_value(key: String, value: Variant) -> Dictionary:
    var s: Dictionary = load_settings()
    s[key] = value
    save_settings(s)
    return s

static func next_grade(current: int) -> int:
    var i: int = GRADE_STEPS.find(current)
    return GRADE_STEPS[(i+1)%GRADE_STEPS.size()]

## Planar acceleration from the road grade (rise / run along the tangent).
static func grade_acceleration(tangent: Vector2, grade: float, percent: int) -> Vector2:
    if percent <= 0 or grade == 0.0:
        return Vector2.ZERO
    return -tangent.normalized()*G*sin(atan(grade))*float(percent)/100.0
