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
    if s.y > s.x:
        return {
            "joystick_center": Vector2(s.x*0.215,s.y*0.853),
            "joystick_radius": s.x*0.175,
            "drift": Rect2(s.x*0.790,s.y*0.405,s.x*0.188,s.y*0.332),
            "brake": Rect2(s.x*0.490,s.y*0.772,s.x*0.225,s.y*0.208),
            "gas": Rect2(s.x*0.748,s.y*0.772,s.x*0.230,s.y*0.208),
            "pause": Rect2(s.x*0.690,s.y*0.206,s.x*0.126,s.y*0.057),
            "camera": Rect2(s.x*0.842,s.y*0.206,s.x*0.136,s.y*0.057),
            "restart": Rect2(s.x*0.265,s.y*0.43,s.x*0.470,s.y*0.095),
            "menu": Rect2(s.x*0.265,s.y*0.55,s.x*0.470,s.y*0.095)
        }
    return {
        "joystick_center": Vector2(s.x*0.142,s.y*0.810),
        "joystick_radius": s.y*0.177,
        "drift": Rect2(s.x*0.850,s.y*0.350,s.x*0.128,s.y*0.340),
        "brake": Rect2(s.x*0.675,s.y*0.740,s.x*0.143,s.y*0.238),
        "gas": Rect2(s.x*0.834,s.y*0.740,s.x*0.144,s.y*0.238),
        "pause": Rect2(s.x*0.921,s.y*0.180,s.x*0.057,s.y*0.125),
        "camera": Rect2(s.x*0.846,s.y*0.180,s.x*0.062,s.y*0.125),
        "restart": Rect2(s.x*0.33,s.y*0.49,s.x*0.34,s.y*0.12),
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
    var centre: Vector2 = Vector2(geo["joystick_center"])
    var radius: float = float(geo["joystick_radius"])
    var scale: float = _ui_scale()
    # Minimal transparent steering pad; the physical hit zone is identical.
    draw_circle(centre,radius,Color(0.025,0.029,0.037,0.32))
    draw_arc(centre,radius,0.0,TAU,80,Color(0.87,0.89,0.94,0.78),2.1*scale,true)
    draw_circle(centre+Vector2(steer*radius*0.57,0),
        radius*0.34,Color(0.70,0.73,0.76,0.90))
    draw_arc(centre+Vector2(steer*radius*0.57,0),
        radius*0.34,0.0,TAU,48,Color(1,1,1,0.66),1.4*scale,true)
    _handbrake(Rect2(geo["drift"]),handbrake>0.0)
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
    style.bg_color = Color(0.25,0.07,0.18,0.80) if pushed else Color(0.020,0.025,0.035,0.76)
    style.border_color = Color(1.0,0.12,0.56,0.87) if pushed else Color(0.83,0.84,0.89,0.63)
    style.set_border_width_all(int(maxf(1.8,1.8*scale)))
    style.set_corner_radius_all(int(minf(rect.size.y*0.28,16.0*scale)))
    draw_style_box(style,rect)
    var font: Font = get_theme_default_font()
    var font_size: int = int((17.0 if small else 27.0)*scale)
    var col: Color = Color(1.0,0.17,0.57) if highlight else Color(1,1,1)
    var baseline: float = rect.position.y+rect.size.y*0.5+font.get_ascent(font_size)*0.37
    draw_string(font,Vector2(rect.position.x,baseline),label,
        HORIZONTAL_ALIGNMENT_CENTER,rect.size.x,font_size,col)

func _handbrake(rect: Rect2, pressed: bool) -> void:
    # The entire drawn lever rectangle is the functional touch target.
    var scale: float = _ui_scale()
    var x: float = rect.position.x
    var y: float = rect.position.y
    var w: float = rect.size.x
    var h: float = rect.size.y
    var pink := Color(1.0,0.035,0.49,0.95)
    var cx: float = x+w*0.50
    var bottom: float = y+h*0.77
    var shaft_bottom := Vector2(cx,bottom)
    var shaft_top := Vector2(cx,y+h*(0.24 if pressed else 0.14))
    draw_line(shaft_bottom,shaft_top,Color(0.85,0.88,0.91),w*0.110,true)
    draw_line(shaft_bottom+Vector2(w*0.032,0),shaft_top+Vector2(w*0.032,0),
        Color(0.33,0.36,0.40),w*0.026,true)
    var grip := Rect2(x+w*0.31,y+h*0.015,w*0.38,h*(0.34 if pressed else 0.42))
    var rubber := StyleBoxFlat.new()
    rubber.bg_color = Color(0.065,0.065,0.080)
    rubber.border_color = pink
    rubber.set_border_width_all(int(maxf(1.4,1.5*scale)))
    rubber.set_corner_radius_all(int(w*0.14))
    draw_style_box(rubber,grip)
    for rib in range(9):
        var ry: float = grip.position.y+grip.size.y*(0.19+float(rib)*0.069)
        draw_line(Vector2(grip.position.x+w*0.055,ry),
            Vector2(grip.end.x-w*0.055,ry),Color(0.65,0.67,0.69,0.46),1.2*scale,true)
    var base := Rect2(x+w*0.10,y+h*0.75,w*0.80,h*0.235)
    var metal := StyleBoxFlat.new()
    metal.bg_color = Color(0.09,0.075,0.095,0.92)
    metal.border_color = pink if pressed else Color(0.92,0.91,0.95,0.80)
    metal.set_border_width_all(int(2.2*scale))
    metal.set_corner_radius_all(int(w*0.17))
    draw_style_box(metal,base)
    var font: Font = get_theme_default_font()
    var symbol_size: int = int(34.0*scale)
    draw_string(font,Vector2(base.position.x,base.position.y+base.size.y*0.56+
        font.get_ascent(symbol_size)*0.28),"Ⅲ",HORIZONTAL_ALIGNMENT_CENTER,
        base.size.x,symbol_size,pink)
    draw_circle(Vector2(base.position.x+base.size.x*0.16,base.position.y+base.size.y*0.15),
        w*0.025,Color(0.86,0.88,0.93))
    draw_circle(Vector2(base.end.x-base.size.x*0.16,base.position.y+base.size.y*0.15),
        w*0.025,Color(0.86,0.88,0.93))

func _pedal(rect: Rect2, label: String, pressed: bool) -> void:
    var x: float = rect.position.x
    var y: float = rect.position.y
    var w: float = rect.size.x
    var h: float = rect.size.y
    var scale: float = _ui_scale()
    var poly := PackedVector2Array([
        Vector2(x+w*0.22,y+h*0.015),Vector2(x+w*0.83,y+h*0.015),
        Vector2(x+w*0.97,y+h*0.87),Vector2(x+w*0.87,y+h*0.98),
        Vector2(x+w*0.07,y+h*0.98),Vector2(x+w*0.015,y+h*0.88)
    ])
    draw_colored_polygon(poly,Color(0.99,0.58,0.74,0.94) if pressed else Color(0.74,0.76,0.79,0.95))
    draw_polyline(PackedVector2Array([
        poly[0],poly[1],poly[2],poly[3],poly[4],poly[5],poly[0]
    ]),Color(0.98,0.98,1.0,0.97),2.5*scale,true)
    for row in range(3):
        for col in range(2):
            draw_circle(Vector2(x+w*(0.35+0.31*float(col)),
                y+h*(0.20+0.24*float(row))),w*0.079,Color(0.045,0.045,0.055,0.96))
    var font: Font = get_theme_default_font()
    var font_size: int = int(15.0*scale)
    draw_string(font,Vector2(x,y+h*0.91),label,
        HORIZONTAL_ALIGNMENT_CENTER,w,font_size,Color(0.055,0.055,0.070))
    if pressed:
        draw_line(Vector2(x+w*0.12,y+h*0.99),Vector2(x+w*0.89,y+h*0.99),
            Color(1.0,0.08,0.51,0.9),3.0*scale,true)
