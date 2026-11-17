extends Control
class_name NitroRaceTouch
## Mobile-first controls: DRIFTIT-like proportions, large labels, rounded
## buttons. Every visible control shares its exact Rect2 with touch detection.
## Independent pointer IDs support steering, gas and handbrake simultaneously.

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

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_process_input(true)

func _process(_delta: float) -> void:
    queue_redraw()

func _layout(size_override: Vector2 = Vector2.ZERO) -> Dictionary:
    var s: Vector2 = get_viewport_rect().size if size_override == Vector2.ZERO else size_override
    var portrait: bool = s.y > s.x
    if portrait:
        return {
            "joystick_center": Vector2(s.x*0.205,s.y*0.836),
            "joystick_radius": s.x*0.180,
            "drift": Rect2(s.x*0.510,s.y*0.627,s.x*0.463,s.y*0.117),
            "brake": Rect2(s.x*0.513,s.y*0.759,s.x*0.220,s.y*0.205),
            "gas": Rect2(s.x*0.746,s.y*0.759,s.x*0.227,s.y*0.205),
            "pause": Rect2(s.x*0.87,s.y*0.148,s.x*0.103,s.y*0.064),
            "camera": Rect2(s.x*0.84,s.y*0.22,s.x*0.135,s.y*0.070),
            "restart": Rect2(s.x*0.285,s.y*0.53,s.x*0.43,s.y*0.086),
            "menu": Rect2(s.x*0.285,s.y*0.63,s.x*0.43,s.y*0.086)
        }
    return {
        "joystick_center": Vector2(s.x*0.15,s.y*0.78),
        "joystick_radius": s.y*0.19,
        "drift": Rect2(s.x*0.680,s.y*0.568,s.x*0.292,s.y*0.143),
        "brake": Rect2(s.x*0.682,s.y*0.736,s.x*0.138,s.y*0.225),
        "gas": Rect2(s.x*0.833,s.y*0.736,s.x*0.142,s.y*0.225),
        "pause": Rect2(s.x*0.92,s.y*0.16,s.x*0.06,s.y*0.10),
        "camera": Rect2(s.x*0.84,s.y*0.16,s.x*0.065,s.y*0.10),
        "restart": Rect2(s.x*0.33,s.y*0.51,s.x*0.34,s.y*0.12),
        "menu": Rect2(s.x*0.33,s.y*0.65,s.x*0.34,s.y*0.12)
    }

func _zone_at(pos: Vector2) -> String:
    var geo: Dictionary = _layout()
    if overlay_visible:
        if Rect2(geo["restart"]).has_point(pos):
            return "restart"
        if Rect2(geo["menu"]).has_point(pos):
            return "menu"
        if Rect2(geo["pause"]).has_point(pos):
            return "pause"
        return ""
    if Rect2(geo["pause"]).has_point(pos):
        return "pause"
    if Rect2(geo["camera"]).has_point(pos):
        return "camera"
    if pos.distance_to(Vector2(geo["joystick_center"])) <= float(geo["joystick_radius"])*1.17:
        return "steering"
    for key in ["drift","brake","gas"]:
        if Rect2(geo[key]).has_point(pos):
            return key
    return ""

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        var touch: InputEventScreenTouch = event
        if touch.pressed:
            var zone: String = _zone_at(touch.position)
            if zone == "camera":
                camera_requested.emit()
            elif zone == "pause":
                pause_requested.emit()
            elif zone == "restart":
                restart_requested.emit()
            elif zone == "menu":
                menu_requested.emit()
            contacts[touch.index] = {"zone":zone,"pos":touch.position}
        else:
            contacts.erase(touch.index)
        _recompute()
    elif event is InputEventScreenDrag:
        var drag: InputEventScreenDrag = event
        if contacts.has(drag.index):
            var record: Dictionary = contacts[drag.index]
            record["pos"] = drag.position
            contacts[drag.index] = record
            _recompute()

func _recompute() -> void:
    steer = 0.0
    throttle = 0.0
    brake = 0.0
    handbrake = 0.0
    active_joystick = false
    if overlay_visible:
        return
    var geo: Dictionary = _layout()
    var center: Vector2 = Vector2(geo["joystick_center"])
    var radius: float = float(geo["joystick_radius"])
    for record in contacts.values():
        var zone: String = str(record["zone"])
        if zone == "steering":
            active_joystick = true
            var raw: float = clampf(
                (Vector2(record["pos"]).x-center.x)/radius,-1.0,1.0)
            # Short thumb movements should react without needing to drag
            # across the whole joystick radius. Still analog at centre.
            steer = signf(raw)*pow(absf(raw),0.74)
        elif zone == "gas":
            throttle = 1.0
        elif zone == "brake":
            brake = 1.0
        elif zone == "drift":
            handbrake = 1.0

func release_all() -> void:
    contacts.clear()
    _recompute()

func _ui_scale() -> float:
    var s: Vector2 = get_viewport_rect().size
    if s.y > s.x:
        return clampf(s.x/700.0,1.0,2.2)
    return clampf(s.y/700.0,0.95,1.6)

func _draw() -> void:
    var geo: Dictionary = _layout()
    var center: Vector2 = Vector2(geo["joystick_center"])
    var radius: float = float(geo["joystick_radius"])
    var active: Color = Color(0.80,0.48,0.20,0.67)
    draw_circle(center,radius,Color(0.09,0.095,0.13,0.42))
    draw_arc(center,radius,0.0,TAU,72,Color(0.94,0.93,0.95,0.68),3.0*_ui_scale())
    draw_circle(center+Vector2(steer*radius*0.57,0),
        radius*0.38,Color(0.94,0.94,0.96,0.70))
    _button(Rect2(geo["drift"]),"DRIFT",handbrake>0.0,true)
    _pedal(Rect2(geo["brake"]),"BRAKE",brake>0.0)
    _pedal(Rect2(geo["gas"]),"GAS",throttle>0.0)
    _button(Rect2(geo["pause"]),"Ⅱ",false,false,true)
    _button(Rect2(geo["camera"]),"CAM",false,false,true)
    if overlay_visible:
        _button(Rect2(geo["restart"]),"RESTART",false)
        _button(Rect2(geo["menu"]),"GARAGE / MENU",false)

func _button(rect: Rect2, label: String, pushed: bool,
        highlight: bool=false, small: bool=false) -> void:
    var scale: float = _ui_scale()
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.70,0.37,0.13,0.76) if pushed else Color(0.11,0.10,0.13,0.52)
    style.border_color = Color(0.98,0.90,0.79,0.72)
    style.set_border_width_all(int(maxf(2.0,2.0*scale)))
    style.set_corner_radius_all(int(minf(rect.size.y*0.22,18.0*scale)))
    draw_style_box(style,rect)
    var font: Font = get_theme_default_font()
    var font_size: int = int((21.0 if small else 31.0)*scale)
    var text_color: Color = Color(1.0,0.72,0.32) if highlight else Color(0.97,0.97,0.97)
    var baseline: float = rect.position.y + rect.size.y*0.5 + font.get_ascent(font_size)*0.37
    draw_string(font,Vector2(rect.position.x,baseline),
        label,HORIZONTAL_ALIGNMENT_CENTER,rect.size.x,font_size,text_color)

func _pedal(rect: Rect2, label: String, pressed: bool) -> void:
    # A wide-bottomed metal pedal silhouette. No icon asset and no hidden
    # click rectangle: _zone_at uses this same Rect2.
    var w: float = rect.size.x
    var h: float = rect.size.y
    var x: float = rect.position.x
    var y: float = rect.position.y
    var outline := PackedVector2Array([
        Vector2(x+w*0.18,y+h*0.01),
        Vector2(x+w*0.82,y+h*0.01),
        Vector2(x+w*0.98,y+h*0.99),
        Vector2(x+w*0.02,y+h*0.99),
        Vector2(x+w*0.18,y+h*0.01)
    ])
    var main_color := Color(0.89,0.47,0.19,0.78) if pressed else Color(0.14,0.15,0.18,0.72)
    draw_colored_polygon(PackedVector2Array([
        outline[0],outline[1],outline[2],outline[3]
    ]),main_color)
    draw_polyline(outline,Color(0.94,0.92,0.90,0.79),
        maxf(2.0,2.5*_ui_scale()),true)
    # Recessed anti-slip ribs at the upper half echo a real pedal surface.
    for rib in range(3):
        var yy: float = y+h*(0.18+float(rib)*0.095)
        draw_line(Vector2(x+w*0.27,yy),Vector2(x+w*0.73,yy),
            Color(0.85,0.86,0.88,0.44),maxf(2.0,2.0*_ui_scale()),true)
    var font: Font = get_theme_default_font()
    var font_size: int = int(32.0*_ui_scale())
    draw_string(font,Vector2(x,y+h*0.73+font.get_ascent(font_size)*0.26),
        label,HORIZONTAL_ALIGNMENT_CENTER,w,font_size,
        Color(1,1,1,1))
