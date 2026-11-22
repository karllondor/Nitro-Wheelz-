extends SceneTree
## Issue #25 audit tool (developer tool, headless, prints JSON): what the drive model
## ACTUALLY does on a full-throttle straight, per catalog car. Used by
## tools/perf/reference_model.py and docs/CAR_PERFORMANCE_AUDIT_20261122.md.
##   godot --headless --path game --script res://tests/car_performance_audit.gd
const DRIVE = preload("res://scripts/driving/drive_model.gd")
const CARS = preload("res://scripts/vehicles/car_catalog.gd")
const DT: float = 1.0/240.0

func _initialize() -> void:
    var out: Dictionary = {}
    for variant in CARS.ORDER:
        var h: Dictionary = CARS.handling(variant)
        var m = DRIVE.new()
        m.apply_profile(h)
        m.reset(Vector2.ZERO,0.0)
        var t: float = 0.0
        var times: Dictionary = {}
        var marks: Array = [30,50,60,80,100,110,120,130,140]
        var samples: Array = []        # [kmh, accel m/s2]
        var last_v: float = 0.0
        var top: float = 0.0
        while t < 60.0:
            m.step(DT,0.0,1.0,0.0,0.0)
            t += DT
            var v: float = m.speed_kmh()
            for mk in marks:
                if not times.has(mk) and v >= float(mk):
                    times[mk] = snappedf(t,0.01)
            if int(t/DT)%120 == 0:
                samples.append([snappedf(v,0.1),snappedf((m.speed_mps()-last_v)/0.5,0.01)])
                last_v = m.speed_mps()
            top = maxf(top,v)
        var t95: float = 0.0
        # time to 95 % of the top speed (a second run)
        var m2 = DRIVE.new()
        m2.apply_profile(h)
        m2.reset(Vector2.ZERO,0.0)
        var tt: float = 0.0
        while tt < 60.0 and m2.speed_kmh() < top*0.95:
            m2.step(DT,0.0,1.0,0.0,0.0)
            tt += DT
        t95 = tt
        out[variant] = {"drive_accel":h.get("drive_accel",11.8),"drag_coeff":h.get("drag_coeff",0.009),
            "rolling_drag":h.get("rolling_drag",0.45),"top_speed_mps":h.get("top_speed_mps",50.0),
            "times":times,"top_kmh":snappedf(top,0.1),"t95":snappedf(t95,0.01),"samples":samples}
    print("AUDIT_JSON "+JSON.stringify(out))
    quit(0)
