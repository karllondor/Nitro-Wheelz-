extends SceneTree
## Issue #28 (owner v0.1.50): the minimap player marker is a SOLID RED dot with no white stroke, fixed for every HUD accent
## (pink, violet, cyan, lime, orange, red) and every UI scale, visible against the white route line, a black map and the HUD
## glass panel behind the minimap; START / FINISH marks and the white route line are not part of this change.
## NOT proven here: how the dot reads on the owner's phone (owner QA); the dot over a real 3D night / dawn world (it sits on
## the dark glass panel, tested here).
const STYLE = preload("res://scripts/ui/hud_style.gd")
const HUD = preload("res://scripts/ui/race_hud.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    printerr("FAIL: "+message)
    quit(1)

func _lum(c: Color) -> float:
    var l := PackedFloat32Array()
    for v in [c.r,c.g,c.b]:
        l.append(v/12.92 if v <= 0.04045 else pow((v+0.055)/1.055,2.4))
    return 0.2126*l[0]+0.7152*l[1]+0.0722*l[2]

func _contrast(a: Color, b: Color) -> float:
    return (maxf(_lum(a),_lum(b))+0.05)/(minf(_lum(a),_lum(b))+0.05)

func _run() -> void:
    var was: String = STYLE.accent_name
    var err: String = _checks()
    STYLE.set_accent(was)
    if err != "":
        _fail(err)
        return
    print("PASS: minimap player marker (#28) - solid red disc (alpha 1, no white / light stroke) on a dark halo, larger than the old 5.5 dot, identical for six accents and every UI scale, >= 3:1 against the white route line, the black map and the HUD glass; the drawing code uses this spec and no longer strokes the dot; NOT proven: how it reads on the owner's phone")
    quit(0)

func _checks() -> String:
    var base: Array = HUD.map_marker_spec(1.0)
    if base.size() != 2:
        return "the marker is a halo plus one solid disc"
    var halo: Dictionary = base[0]
    var dot: Dictionary = base[1]
    var red: Color = dot["color"]
    if red.a < 0.999 or red.r < 0.9 or red.g > 0.2 or red.b > 0.2:
        return "the marker must be a solid red (%s)" % str(red)
    for primitive in base:
        var c: Color = primitive["color"]
        if c.r > 0.75 and c.g > 0.75 and c.b > 0.75 and c.a > 0.2:
            return "no white / light stroke around the dot"
    if float(dot["radius"]) < 6.5 or float(halo["radius"]) <= float(dot["radius"]):
        return "the dot must be bigger than the old 5.5 and the halo wider than the dot"
    for accent in STYLE.ACCENT_ORDER:
        STYLE.set_accent(accent)
        for u in [0.8,1.0,2.2]:
            var spec: Array = HUD.map_marker_spec(u)
            var c: Color = spec[1]["color"]
            if c != red or absf(float(spec[1]["radius"])-float(dot["radius"])*u) > 0.001:
                return "the marker changes with the accent %s or the scale %.1f" % [accent,u]
    if _contrast(red,STYLE.WHITE) < 3.0 or _contrast(red,Color.BLACK) < 3.0 \
            or _contrast(red,STYLE.GLASS_TOP) < 3.0 or _contrast(red,STYLE.GLASS_BOTTOM) < 3.0:
        return "the red dot is not clearly visible on the white route line, the black map and the glass panel"
    # The real drawing uses the spec and does not stroke the dot any more; start / finish and the white route line remain.
    var source: String = FileAccess.get_file_as_string("res://scripts/ui/race_hud.gd")
    if not source.contains("for primitive in map_marker_spec(u):") or source.contains("draw_arc(dot,"):
        return "_minimap must draw the dot from map_marker_spec and must not stroke it"
    if not source.contains("draw_polyline(_outline_cache,STYLE.WHITE,3.0*u,true)") or not source.contains("_end_marker(rect,u,start_progress,STYLE.WHITE,false)"):
        return "the white route line and the START / FINISH marks must stay"
    # A real HUD with a route draws without errors (a script error would show up as SCRIPT ERROR and fail the suite).
    var hud: Control = HUD.new()
    hud.track_points = PackedVector2Array([Vector2(0,0),Vector2(100,0),Vector2(150,60),Vector2(100,120),Vector2(0,120),Vector2(-50,60),
        Vector2(0,0),Vector2(10,0),Vector2(20,0),Vector2(30,0)])
    root.add_child(hud)
    return ""
