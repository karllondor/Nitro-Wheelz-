extends Control
class_name NitroRaceTouch
## Pointer-ID-aware touch input. Three fingers can steer, hold throttle and
## handbrake simultaneously. Deliberately does not synthesize keyboard events.

signal camera_requested
signal pause_requested
signal restart_requested
signal menu_requested

var steer: float = 0.0
var throttle: float = 0.0
var brake: float = 0.0
var handbrake: float = 0.0
var active_joystick: bool = false
var overlay_visible: bool = false

var contacts: Dictionary = {}
var tap_guard: Dictionary = {}

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_process_input(true)

func _process(_delta: float) -> void:
    queue_redraw()

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        var touch: InputEventScreenTouch = event
        if touch.pressed:
            contacts[touch.index] = {"zone":_zone_at(touch.position),"pos":touch.position}
            var zone: String = str(contacts[touch.index]["zone"])
            if zone == "camera":
                camera_requested.emit()
            elif zone == "pause":
                pause_requested.emit()
            elif zone == "restart":
                restart_requested.emit()
            elif zone == "menu":
                menu_requested.emit()
        else:
            contacts.erase(touch.index)
        _recompute()
    elif event is InputEventScreenDrag:
        var drag: InputEventScreenDrag = event
        if contacts.has(drag.index):
            var data: Dictionary = contacts[drag.index]
            data["pos"] = drag.position
            contacts[drag.index] = data
            _recompute()

func _zone_at(pos: Vector2) -> String:
    var screen: Vector2 = get_viewport_rect().size
    var portrait: bool = screen.y > screen.x
    var cx: float = screen.x*(0.22 if portrait else 0.15)
    var cy: float = screen.y*(0.84 if portrait else 0.81)
    var radius: float = minf(screen.x,screen.y)*0.19
    if pos.distance_to(Vector2(cx,cy)) < radius*1.35:
        return "steering"
    if overlay_visible and pos.x > screen.x*0.30 and pos.x < screen.x*0.74:
        if pos.y > screen.y*0.52 and pos.y < screen.y*0.61:
            return "restart"
        if pos.y > screen.y*0.62 and pos.y < screen.y*0.71:
            return "menu"
    if pos.x > screen.x*0.79 and pos.y > screen.y*0.15 and pos.y < screen.y*0.22:
        return "pause"
    if pos.x > screen.x*0.75 and pos.y > screen.y*0.22 and pos.y < screen.y*0.32:
        return "camera"
    if pos.y > screen.y*(0.76 if portrait else 0.71):
        if pos.x > screen.x*0.79:
            return "gas"
        if pos.x > screen.x*0.56:
            return "brake"
    if pos.y > screen.y*(0.65 if portrait else 0.56) and pos.x > screen.x*0.52:
        return "drift"
    return ""

func _recompute() -> void:
    steer = 0.0
    throttle = 0.0
    brake = 0.0
    handbrake = 0.0
    active_joystick = false
    var screen: Vector2 = get_viewport_rect().size
    var portrait: bool = screen.y > screen.x
    var center: Vector2 = Vector2(screen.x*(0.22 if portrait else 0.15),
        screen.y*(0.84 if portrait else 0.81))
    var radius: float = minf(screen.x,screen.y)*0.19
    for data in contacts.values():
        var zone: String = str(data["zone"])
        if zone == "steering":
            active_joystick = true
            steer = clampf((Vector2(data["pos"]).x-center.x)/radius,-1.0,1.0)
        elif zone == "gas":
            throttle = 1.0
        elif zone == "brake":
            brake = 1.0
        elif zone == "drift":
            handbrake = 1.0

func _draw() -> void:
    var screen: Vector2 = get_viewport_rect().size
    var portrait: bool = screen.y > screen.x
    var center: Vector2 = Vector2(screen.x*(0.22 if portrait else 0.15),
        screen.y*(0.84 if portrait else 0.81))
    var radius: float = minf(screen.x,screen.y)*0.19
    draw_circle(center,radius,Color(0.08,0.10,0.14,0.48))
    draw_arc(center,radius,0.0,TAU,64,Color(0.84,0.84,0.86,0.54),2.0)
    draw_circle(center+Vector2(steer*radius*0.6,0),radius*0.37,
        Color(0.86,0.86,0.89,0.72))

    var drift_rect: Rect2 = Rect2(Vector2(screen.x*0.54, screen.y*(0.65 if portrait else 0.56)),
        Vector2(screen.x*0.42,screen.y*0.095))
    var brake_rect: Rect2 = Rect2(Vector2(screen.x*0.55,screen.y*(0.78 if portrait else 0.71)),
        Vector2(screen.x*0.18,screen.y*0.16))
    var gas_rect: Rect2 = Rect2(Vector2(screen.x*0.77,screen.y*(0.78 if portrait else 0.71)),
        Vector2(screen.x*0.20,screen.y*0.16))
    _control(drift_rect,"DRIFT",handbrake>0.0)
    _control(brake_rect,"BRAKE",brake>0.0)
    _control(gas_rect,"GAS",throttle>0.0)
    _control(Rect2(Vector2(screen.x*0.82,screen.y*0.15),
        Vector2(screen.x*0.15,screen.y*0.07)),"II",false)
    _control(Rect2(Vector2(screen.x*0.78,screen.y*0.23),
        Vector2(screen.x*0.19,screen.y*0.085)),"CAM",false)
    if overlay_visible:
        _control(Rect2(Vector2(screen.x*0.30,screen.y*0.52),
            Vector2(screen.x*0.44,screen.y*0.09)),"RESTART",false)
        _control(Rect2(Vector2(screen.x*0.30,screen.y*0.62),
            Vector2(screen.x*0.44,screen.y*0.09)),"MENU",false)

func _control(rect: Rect2,text: String,active: bool) -> void:
    draw_rect(rect,Color(0.65,0.38,0.13,0.72) if active else Color(0.08,0.09,0.12,0.55))
    draw_rect(rect,Color(0.85,0.85,0.85,0.4),false,2.0)
    var font: Font = get_theme_default_font()
    draw_string(font,rect.position+Vector2(rect.size.x*0.22,rect.size.y*0.57),
        text,HORIZONTAL_ALIGNMENT_LEFT,-1,21,Color.WHITE)

