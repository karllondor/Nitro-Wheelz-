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
            "drift": Rect2(s.x*0.790,s.y*0.470,s.x*0.188,s.y*0.300),
            "brake": Rect2(s.x*0.515,s.y*0.846,s.x*0.160,s.y*0.132),
            "gas": Rect2(s.x*0.788,s.y*0.788,s.x*0.158,s.y*0.190),
            "pause": Rect2(s.x*0.690,s.y*0.206,s.x*0.126,s.y*0.057),
            "camera": Rect2(s.x*0.842,s.y*0.206,s.x*0.136,s.y*0.057),
            "restart": Rect2(s.x*0.265,s.y*0.43,s.x*0.470,s.y*0.095),
            "menu": Rect2(s.x*0.265,s.y*0.55,s.x*0.470,s.y*0.095)
        }
    return {
        "joystick_center": Vector2(s.x*0.142,s.y*0.810),
        "joystick_radius": s.y*0.177,
        "drift": Rect2(s.x*0.850,s.y*0.390,s.x*0.128,s.y*0.340),
        "brake": Rect2(s.x*0.698,s.y*0.817,s.x*0.096,s.y*0.161),
        "gas": Rect2(s.x*0.856,s.y*0.754,s.x*0.098,s.y*0.224),
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
    # PAUSE and FINISH have exclusive modal menus in their own CanvasLayers.

func _button(rect: Rect2, label: String, pushed: bool,
        highlight: bool=false, small: bool=false) -> void:
    var scale: float = _ui_scale()
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.25,0.07,0.18,0.80) if pushed else Color(0.020,0.025,0.035,0.76)
    style.border_color = Color(0.57,0.30,0.98,0.87) if pushed else Color(0.83,0.84,0.89,0.63)
    style.set_border_width_all(int(maxf(1.8,1.8*scale)))
    style.set_corner_radius_all(int(minf(rect.size.y*0.28,16.0*scale)))
    draw_style_box(style,rect)
    var font: Font = get_theme_default_font()
    var font_size: int = int((17.0 if small else 27.0)*scale)
    var col: Color = Color(0.71,0.55,1.0) if highlight else Color(1,1,1)
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
    var pink := Color(0.57,0.30,0.98,0.95)
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
    # Enlarge only the lower handbrake BUTTON by 10%; keep lever grip.
    var base := Rect2(x+w*0.06,y+h*0.7265,w*0.88,h*0.2585)
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
    # Separate brake and throttle silhouettes based on the approved
    # perforated aluminium pedal reference. Visual shape and touch Rect2 match.
    var x: float = rect.position.x
    var y: float = rect.position.y
    var w: float = rect.size.x
    var h: float = rect.size.y
    var scale: float = _ui_scale()
    var gas_pedal: bool = label == "GAS"
    var poly := PackedVector2Array()
    if gas_pedal:
        poly = PackedVector2Array([
            Vector2(x+w*0.14,y+h*0.012),Vector2(x+w*0.84,y+h*0.012),
            Vector2(x+w*0.96,y+h*0.087),Vector2(x+w*0.95,y+h*0.92),
            Vector2(x+w*0.84,y+h*0.987),Vector2(x+w*0.12,y+h*0.987),
            Vector2(x+w*0.045,y+h*0.91),Vector2(x+w*0.045,y+h*0.082)
        ])
    else:
        poly = PackedVector2Array([
            Vector2(x+w*0.18,y+h*0.008),Vector2(x+w*0.88,y+h*0.008),
            Vector2(x+w*0.972,y+h*0.090),Vector2(x+w*0.91,y+h*0.92),
            Vector2(x+w*0.80,y+h*0.989),Vector2(x+w*0.06,y+h*0.989),
            Vector2(x+w*0.012,y+h*0.90),Vector2(x+w*0.10,y+h*0.087)
        ])
    draw_colored_polygon(poly,Color(0.92,0.62,0.75) if pressed else Color(0.68,0.70,0.73))
    var outline: PackedVector2Array = poly.duplicate()
    outline.append(poly[0])
    draw_polyline(outline,Color(0.99,0.99,1.0,0.95),2.4*scale,true)
    # Matte holes: staggered rows. The gas pedal is taller than the brake.
    var rows: int = 6 if gas_pedal else 4
    for row in range(rows):
        var hole_y: float = y+h*(0.15+(0.70*float(row)/float(rows-1)))
        var positions: Array[float] = [0.31,0.69] if row%2==0 else [0.5]
        for hole_x in positions:
            var centre: Vector2 = Vector2(x+w*hole_x,hole_y)
            draw_circle(centre,w*0.101,Color(0.93,0.94,0.95,0.80))
            draw_circle(centre,w*0.083,Color(0.028,0.031,0.040,1.0))
    draw_line(Vector2(x+w*0.12,y+h*0.97),Vector2(x+w*0.86,y+h*0.97),
        Color(0.57,0.30,0.98,0.94) if pressed else Color(0.43,0.45,0.50,0.7),2.4*scale,true)
