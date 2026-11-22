extends SceneTree
## Issue #25 (owner decision c7080962400): side-by-side measurement of the two physics modes on the
## SAME cars. Developer tool, headless, prints JSON + a readable table:
##   godot --headless --path game --script res://tests/physics_ab_audit.gd
## ARCADE_PLUS (default, "C+") and REAL_POWER_TEST ("A") are measured with the real drive model on a
## full-throttle straight (0-60, 0-100, 60-120, 100-150, 100-200, 0-top), a 100-0 km/h brake and the
## held-drift / corner-exit / lift-off numbers of car_profiles_test (drift control, brake behaviour).
const DRIVE = preload("res://scripts/driving/drive_model.gd")
const CARS = preload("res://scripts/vehicles/car_catalog.gd")
const DT: float = 1.0/240.0

func _initialize() -> void:
    call_deferred("_run")

func _model(variant: String, mode: String):
    var m = DRIVE.new()
    CARS.configure_model(m,variant,mode)
    m.reset(Vector2.ZERO,0.0)
    return m

## Time to reach each speed mark (km/h) from standstill, the top speed after `seconds`, gear at the end.
static func straight(m, seconds: float) -> Dictionary:
    var marks: Array = [30,60,100,120,150,180,200]
    var at: Dictionary = {}
    var t: float = 0.0
    var top: float = 0.0
    while t < seconds:
        m.step(DT,0.0,1.0,0.0,0.0)
        t += DT
        var v: float = m.speed_kmh()
        top = maxf(top,v)
        for k in marks:
            if not at.has(k) and v >= float(k):
                at[k] = t
    return {"at":at,"top":top,"final":m.speed_kmh()}

static func between(at: Dictionary, a: int, b: int) -> float:
    return float(at[b])-float(at[a]) if at.has(a) and at.has(b) else -1.0

## 100 -> 0 km/h full brake: distance (m) and time (s).
static func brake100(m) -> Array:
    m.velocity = Vector2(0.0,-100.0/3.6)
    var t: float = 0.0
    var d: float = 0.0
    while m.speed_kmh() > 1.0 and t < 15.0:
        var before: Vector2 = m.position
        m.step(DT,0.0,0.0,1.0,0.0)
        d += (m.position-before).length()
        t += DT
    return [d,t]

func _run() -> void:
    var out: Dictionary = {}
    var lines: PackedStringArray = []
    lines.append("| car | mode | 0-60 | 0-100 | 60-120 | 100-150 | 100-200 | top (60 s) | 100-0 brake |")
    lines.append("|---|---|---|---|---|---|---|---|---|")
    for variant in CARS.ORDER:
        if variant == "flame":
            continue
        for mode in CARS.MODES:
            var r: Dictionary = straight(_model(variant,mode),60.0)
            var br: Array = brake100(_model(variant,mode))
            var at: Dictionary = r["at"]
            out["%s/%s" % [variant,mode]] = {"0-60":at.get(60,-1.0),"0-100":at.get(100,-1.0),"60-120":between(at,60,120),
                "100-150":between(at,100,150),"100-200":between(at,100,200),"top":r["top"],"brake_m":br[0],"brake_s":br[1]}
            lines.append("| %s | %s | %.2f s | %.2f s | %.2f s | %.2f s | %s | %.1f km/h | %.1f m |" % [variant,mode,
                at.get(60,-1.0),at.get(100,-1.0),between(at,60,120),between(at,100,150),
                ("%.2f s" % between(at,100,200)) if at.has(200) else "not reached",r["top"],br[0]])
    print("AB_JSON "+JSON.stringify(out))
    print("\n".join(lines))
    quit(0)
