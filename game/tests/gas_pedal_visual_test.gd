extends SceneTree
## Issue #28 (owner v0.1.50 polish): the GAS pedal gets its slanted mechanical face and a visible press back, while the
## full-height hit area accepted on the phone stays exactly as it was.
##  * INPUT UNCHANGED: the layout's "gas" rectangle, "gas_shape" polygon, brake, drift and joystick of eight screen sizes hash to
##    the value computed on the base (9c827cd, v0.1.53) before this patch; a visual press never alters them;
##  * the visible face is a parallelogram leaning like the BRAKE (same sign, about PEDAL_SKEW * height), large (>= 72 % of the
##    hit width, >= 85 % of its height, face + plate >= 90 %), and lies strictly INSIDE the hit polygon at rest and fully pressed, so the picture
##    never promises more than the touch area gives;
##  * a press pushes the face down onto the depth plate by a visible amount, the plate and the hit polygon do not move;
##  * the press follows the input: touching GAS sets throttle at once, the face sinks over a few frames, releasing lifts it;
##    steering + GAS + handbrake still work with three pointers.
## NOT proven here: how the pedal looks and feels on the owner's phone (owner QA).
const TOUCH = preload("res://scripts/ui/race_touch.gd")
const SIZES: Array[Vector2] = [Vector2(720,1600),Vector2(1080,2400),Vector2(800,1280),Vector2(1200,1600),
    Vector2(1600,720),Vector2(2400,1080),Vector2(1280,800),Vector2(1152,648)]
## sha256 of the str() of gas, gas_shape, brake, drift, joystick centre and radius for SIZES, computed on the base 9c827cd.
const LAYOUT_HASH: String = "0d99d50115b6ea95b2f1fec6a94fbbfd96785caf8261d0e48c2ef16b4ab7d725"

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    printerr("FAIL: "+message)
    quit(1)

func _inside(point: Vector2, polygon: PackedVector2Array) -> bool:
    return Geometry2D.is_point_in_polygon(point,polygon)

func _run() -> void:
    var touch: NitroRaceTouch = TOUCH.new()
    root.add_child(touch)
    await process_frame
    # ------------------------------------------------------------------------------ input geometry unchanged
    var text := ""
    for s in SIZES:
        var g: Dictionary = touch._layout(s)
        text += str(s)+str(g.gas)+str(g.gas_shape)+str(g.brake)+str(g.drift)+str(g.joystick_center)+str(g.joystick_radius)
    if text.sha256_text() != LAYOUT_HASH:
        _fail("the touch layout (GAS hit polygon, brake, handbrake, joystick) differs from the accepted v0.1.50 / v0.1.53 geometry")
        return
    for s in SIZES:
        var geo: Dictionary = touch._layout(s)
        var gas: Rect2 = geo.gas
        var hit: PackedVector2Array = geo.gas_shape
        var tag: String = "%dx%d" % [int(s.x),int(s.y)]
        var rest: Dictionary = TOUCH.gas_visual(gas,hit,0.0)
        var pushed: Dictionary = TOUCH.gas_visual(gas,hit,1.0)
        # ------------------------------------------------------------------------ inside the hit polygon
        for label in ["face","plate"]:
            for state in [rest,pushed]:
                for p in (state[label] as PackedVector2Array):
                    if not _inside(p,hit):
                        _fail("%s: a %s point %s of the GAS visual is outside the hit polygon" % [tag,label,str(p)])
                        return
        # ------------------------------------------------------------------------------- slanted like BRAKE
        var face: PackedVector2Array = rest["face"]
        var frect: Rect2 = rest["face_rect"]
        var top_x: float = 0.0
        var bottom_x: float = 0.0
        var top_n: int = 0
        var bottom_n: int = 0
        for p in face:
            if p.y <= frect.position.y+frect.size.y*0.10:
                top_x += p.x
                top_n += 1
            elif p.y >= frect.end.y-frect.size.y*0.10:
                bottom_x += p.x
                bottom_n += 1
        var lean: float = top_x/float(top_n)-bottom_x/float(bottom_n)
        var brake_face: PackedVector2Array = TOUCH.brake_shape(Rect2(geo.brake))
        var brect: Rect2 = TOUCH._bounds(brake_face)
        var b_top: float = 0.0
        var b_bottom: float = 0.0
        var bt: int = 0
        var bb: int = 0
        for p in brake_face:
            if p.y <= brect.position.y+brect.size.y*0.10:
                b_top += p.x
                bt += 1
            elif p.y >= brect.end.y-brect.size.y*0.10:
                b_bottom += p.x
                bb += 1
        var brake_lean: float = b_top/float(bt)-b_bottom/float(bb)
        if lean <= frect.size.y*TOUCH.PEDAL_SKEW*0.6 or lean*brake_lean <= 0.0:
            _fail("%s: the GAS face must lean like the BRAKE (GAS %.1f px, BRAKE %.1f px)" % [tag,lean,brake_lean])
            return
        # ------------------------------------------------------------------------------ large, not shrunk
        var total_h: float = float(rest["plate_rect"].end.y)-frect.position.y
        if frect.size.x < gas.size.x*0.72 or frect.size.y < gas.size.y*0.85 or total_h < gas.size.y*0.90:
            _fail("%s: the GAS pedal must stay large (face %.2f x %.2f, face + plate %.2f of the hit area)" % [tag,frect.size.x/gas.size.x,frect.size.y/gas.size.y,total_h/gas.size.y])
            return
        # ------------------------------------------------------------------------------- a visible press
        var sink: float = float(pushed["face_rect"].position.y)-float(rest["face_rect"].position.y)
        if sink < gas.size.y*0.025:
            _fail("%s: a pressed GAS must sink visibly (%.1f px of %.0f)" % [tag,sink,gas.size.y])
            return
        if pushed["plate"] != rest["plate"] or float(pushed["face_rect"].end.y) > float(rest["plate_rect"].end.y)+0.01:
            _fail("%s: the plate stays put and the pushed face never leaves it" % tag)
            return
        if TOUCH.gas_visual(gas,hit,0.5)["face_rect"].position.y <= rest["face_rect"].position.y \
                or TOUCH.gas_visual(gas,hit,0.5)["face_rect"].position.y >= pushed["face_rect"].position.y:
            _fail("%s: the press must be gradual" % tag)
            return
        # ---------------------------------------------------- the hit polygon is untouched by any press value
        if touch._layout(s)["gas_shape"] != hit or touch._layout(s)["gas"] != gas:
            _fail("%s: a visual press changed the GAS hit area" % tag)
            return
    # ------------------------------------------------------------------ the press follows the input state
    var geo0: Dictionary = touch._layout()
    var box: Rect2 = geo0.gas
    var press_at := Vector2(box.position.x+box.size.x*0.16,box.position.y+box.size.y*0.84)   # lower-left, outside the visual face
    _touch(touch,0,Vector2(geo0.joystick_center)+Vector2(float(geo0.joystick_radius)*0.5,0),true)
    _touch(touch,1,press_at,true)
    _touch(touch,2,Rect2(geo0.drift).get_center(),true)
    if touch.throttle != 1.0 or touch.handbrake != 1.0 or touch.steer < 0.2:
        _fail("three simultaneous contacts must work: steer %.2f, GAS %.1f, handbrake %.1f" % [touch.steer,touch.throttle,touch.handbrake])
        return
    if touch.gas_press != 0.0:
        _fail("the animation must never gate the input (the face starts moving after the touch, not before)")
        return
    var previous: float = 0.0
    for _i in range(3):
        touch._process(1.0/60.0)
        if touch.gas_press <= previous:
            _fail("the face must sink while GAS is held")
            return
        previous = touch.gas_press
    for _i in range(20):
        touch._process(1.0/60.0)
    if touch.gas_press < 0.999:
        _fail("a held GAS must end fully pressed (%.2f)" % touch.gas_press)
        return
    _touch(touch,1,press_at,false)
    if touch.throttle != 0.0 or touch.handbrake != 1.0 or touch.steer < 0.2:
        _fail("releasing GAS changed another pointer")
        return
    for _i in range(20):
        touch._process(1.0/60.0)
    if touch.gas_press > 0.001:
        _fail("the face must lift after GAS is released (%.2f)" % touch.gas_press)
        return
    # The real drawing runs (a script error in the pedal drawing would show up as SCRIPT ERROR and fail the suite).
    touch.size = Vector2(1080,2400)
    for _i in range(3):
        await process_frame
    print("PASS: GAS pedal (#28) - hit area byte-identical to the accepted geometry on eight screen sizes, slanted face leaning like BRAKE, large and strictly inside the hit polygon at rest and pressed, visible gradual press onto a fixed plate, press follows (never gates) the input, three-pointer steer + GAS + handbrake still work; NOT proven: look and feel on the owner's phone")
    quit(0)

func _touch(touch: NitroRaceTouch, index: int, position: Vector2, down: bool) -> void:
    var event := InputEventScreenTouch.new()
    event.index = index
    event.position = position
    event.pressed = down
    touch._input(event)
