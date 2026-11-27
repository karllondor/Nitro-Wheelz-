extends SceneTree

const TOUCH = preload("res://scripts/ui/race_touch.gd")

func _initialize() -> void:
    _run.call_deferred()

func _run() -> void:
    var touch: NitroRaceTouch = TOUCH.new()
    root.add_child(touch)
    await process_frame
    for size in [Vector2(720,1600),Vector2(1080,2400),Vector2(800,1280),Vector2(1200,1600),
            Vector2(1600,720),Vector2(2400,1080),Vector2(1280,800),Vector2(1152,648)]:
        var geo := touch._layout(size)
        var gas: Rect2 = geo.gas
        var brake: Rect2 = geo.brake
        var shape: PackedVector2Array = geo.gas_shape
        var left := brake.end.x+brake.size.x*0.12
        if absf(gas.position.x-left)>0.1 or gas.intersects(brake) or gas.intersects(geo.drift):
            _fail("GAS must extend to the previous upper left edge with clearance: "+str(size))
            return
        for height in [0.16,0.4,0.64,0.84]:
            var y: float = gas.position.y+gas.size.y*height
            for x in [gas.position.x+gas.size.x*0.05,gas.end.x-gas.size.x*0.05]:
                if touch._zone_at(Vector2(x,y),size) != "gas":
                    _fail("a visible upper/lower GAS edge does not trigger GAS: "+str(size))
                    return
        for point in [gas.position,gas.end,Vector2(gas.get_center().x,gas.end.y+1)]:
            if Geometry2D.is_point_in_polygon(point,shape) or touch._zone_at(point,size) == "gas":
                _fail("invisible GAS target outside the rounded face: "+str(size))
                return
    var geo0 := touch._layout()
    var box: Rect2 = geo0.gas
    var gas_press := Vector2(box.position.x+box.size.x*0.16,box.position.y+box.size.y*0.84)
    _touch(touch,0,Vector2(geo0.joystick_center)+Vector2(float(geo0.joystick_radius)*0.5,0),true)
    _touch(touch,1,gas_press,true)
    _touch(touch,2,Rect2(geo0.drift).get_center(),true)
    if touch.throttle != 1.0 or touch.handbrake != 1.0 or touch.steer < 0.2:
        _fail("three simultaneous touch contacts lost steering, GAS or handbrake")
        return
    _touch(touch,1,gas_press,false)
    if touch.throttle != 0.0 or touch.handbrake != 1.0 or touch.steer < 0.2:
        _fail("releasing GAS changed another pointer")
        return
    print("PASS: uniform visible GAS hit polygon on eight viewport sizes and real three-pointer touch input")
    quit(0)

func _touch(touch: NitroRaceTouch, index: int, position: Vector2, down: bool) -> void:
    var event := InputEventScreenTouch.new()
    event.index = index
    event.position = position
    event.pressed = down
    touch._input(event)

func _fail(message: String) -> void:
    printerr("FAIL: "+message)
    quit(1)
