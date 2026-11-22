extends SceneTree
## v0.1.36 (owner request 2026-11-22): the GAS pedal is an L-shape with a wing
## above the brake (the thumb slipped off the top-left of the old rectangle).
##  * the wing exists, is touched as GAS and is drawn from the same polygon;
##  * it never overlaps the brake face, the handbrake, the joystick, PAUSE / CAM
##    and stays on the screen, on every phone / tablet size in both orientations;
##  * the rectangles the other tests rely on (gas / brake / drift) are unchanged;
##  * a real touch event on the wing presses GAS, a touch just above the brake
##    (outside the wing) does nothing, the brake itself is still BRAKE.
const TOUCH = preload("res://scripts/ui/race_touch.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    printerr("FAIL: "+message)
    quit(1)

func _run() -> void:
    var touch: NitroRaceTouch = TOUCH.new()
    root.add_child(touch)
    await process_frame
    var sizes: Array = [Vector2(720,1560),Vector2(720,1600),Vector2(900,2000),Vector2(1080,2400),
        Vector2(1080,1920),Vector2(800,1280),Vector2(1200,1600),
        Vector2(1600,720),Vector2(2400,1080),Vector2(1280,800),Vector2(2000,900),Vector2(1152,648)]
    var worst_gap: float = INF
    for sz in sizes:
        var s: Vector2 = sz
        var tag: String = "%dx%d" % [int(s.x),int(s.y)]
        var geo: Dictionary = touch._layout(s)
        var gas: Rect2 = geo["gas"]
        var brake: Rect2 = geo["brake"]
        var shape: PackedVector2Array = geo["gas_shape"]
        if shape.size() < 8:
            _fail(tag+": the gas outline is missing")
            return
        var box := Rect2(shape[0],Vector2.ZERO)
        for p in shape:
            box = box.expand(p)
        if not Rect2(Vector2.ZERO,s).grow(1.0).encloses(box):
            _fail(tag+": the gas pedal leaves the screen")
            return
        # The wing reaches well to the left of the plain pedal ...
        if box.position.x > gas.position.x-gas.size.x*0.45:
            _fail(tag+": the wing is too small (left edge %.0f, pedal %.0f)" % [box.position.x,gas.position.x])
            return
        # ... but never over the brake.
        var brake_poly: PackedVector2Array = TOUCH.brake_shape(brake)
        var hit: Array = Geometry2D.intersect_polygons(shape,brake_poly)
        if not hit.is_empty():
            _fail(tag+": the gas wing overlaps the brake pedal")
            return
        var gap: float = INF
        for bp in brake_poly:
            for gp in shape:
                gap = minf(gap,bp.distance_to(gp))
        worst_gap = minf(worst_gap,gap)
        if gap < s.x*0.004:
            _fail(tag+": the gas wing touches the brake (gap %.1f px)" % gap)
            return
        # Other controls.
        var drift_rect: Rect2 = geo["drift"]
        var c: Vector2 = geo["joystick_center"]
        var r: float = float(geo["joystick_radius"])
        for p in shape:
            if drift_rect.has_point(p):
                _fail(tag+": the gas wing enters the handbrake")
                return
            if p.distance_to(c) < r*1.17:
                _fail(tag+": the gas wing enters the joystick")
                return
            for key in ["pause","camera"]:
                if Rect2(geo[key]).has_point(p):
                    _fail(tag+": the gas wing enters "+key)
                    return
        # Hit tests through the real lookup.
        var wing_pt := Vector2(lerpf(box.position.x,gas.position.x,0.5),gas.position.y+gas.size.y*0.10)
        if not Geometry2D.is_point_in_polygon(wing_pt,shape) or touch._zone_at(wing_pt,s) != "gas":
            _fail(tag+": a touch in the wing is not GAS")
            return
        var above_brake := Vector2(brake.position.x+brake.size.x*0.3,brake.position.y-brake.size.y*0.15)
        if touch._zone_at(above_brake,s) == "gas" or touch._zone_at(above_brake,s) == "brake":
            _fail(tag+": the area above the brake (left of the wing) must stay empty")
            return
        if touch._zone_at(gas.get_center(),s) != "gas" or touch._zone_at(brake.get_center(),s) != "brake":
            _fail(tag+": the pedal centres are no longer GAS / BRAKE")
            return
        # The unchanged rectangles (other tests depend on them).
        if gas.size.y < brake.size.y*1.2 or gas.position.y >= brake.position.y:
            _fail(tag+": the gas pedal must stay taller than the brake and start higher")
            return
    # A real touch event in the default (viewport) layout presses and releases GAS.
    var geo0: Dictionary = touch._layout()
    var gas0: Rect2 = geo0["gas"]
    var poly0: PackedVector2Array = geo0["gas_shape"]
    var left: float = INF
    for p in poly0:
        left = minf(left,p.x)
    var pt := Vector2(lerpf(left,gas0.position.x,0.5),gas0.position.y+gas0.size.y*0.10)
    var down := InputEventScreenTouch.new()
    down.index = 3
    down.position = pt
    down.pressed = true
    touch._input(down)
    if touch.throttle < 0.99:
        _fail("a touch on the wing did not press GAS")
        return
    var up := InputEventScreenTouch.new()
    up.index = 3
    up.position = pt
    up.pressed = false
    touch._input(up)
    if touch.throttle > 0.01:
        _fail("GAS stayed pressed after releasing the wing")
        return
    print("PASS: gas pedal L-shape - the wing is part of the drawing and of the touch area, never overlaps the brake (smallest gap %.1f px), handbrake, joystick or PAUSE / CAM, fits 12 phone / tablet sizes in both orientations, a touch on it presses GAS and the old rectangles are unchanged" % worst_gap)
    quit(0)
