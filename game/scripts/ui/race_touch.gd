extends Control
class_name NitroRaceTouch
## Mobile-first controls: DRIFTIT-like proportions, large labels, rounded
## buttons. Every visible control shares its exact Rect2 with touch detection.
## Independent pointer IDs support steering, gas and handbrake simultaneously.

const STYLE = preload("res://scripts/ui/hud_style.gd")
const NW_MASK = preload("res://assets/brand/nw_initials_mask.png")

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
## Optional gate set by a game mode (the Park tutorial): while it returns true a NEW press is ignored
## (a full-screen card is up and the car is frozen), releases are always processed. Independent of the
## order in which nodes receive input, so a tap that dismisses a card can never become a pedal press.
var press_blocker: Callable = Callable()

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_process_input(true)

func _process(_delta: float) -> void:
    queue_redraw()

func _layout(size_override: Vector2 = Vector2.ZERO) -> Dictionary:
    var s: Vector2 = get_viewport_rect().size if size_override == Vector2.ZERO else size_override
    # PAUSE / CAM share their rectangles with the HUD style metrics so the
    # drawn buttons and touch targets are always identical.
    var hud: Dictionary = STYLE.metrics(s)
    if s.y > s.x:
        return {
            "joystick_center": Vector2(s.x*0.215,s.y*0.853),
            "joystick_radius": s.x*0.175,
            "drift": Rect2(s.x*0.790,s.y*0.470,s.x*0.188,s.y*0.300),
            "brake": Rect2(s.x*0.515,s.y*0.846,s.x*0.160,s.y*0.132),
            "gas": Rect2(s.x*0.788,s.y*0.788,s.x*0.158,s.y*0.190),
            "gas_shape": _gas_shape(Rect2(s.x*0.788,s.y*0.788,s.x*0.158,s.y*0.190),
                Rect2(s.x*0.515,s.y*0.846,s.x*0.160,s.y*0.132)),
            "pause": hud["pause"],
            "camera": hud["camera"],
            "restart": Rect2(s.x*0.265,s.y*0.43,s.x*0.470,s.y*0.095),
            "menu": Rect2(s.x*0.265,s.y*0.55,s.x*0.470,s.y*0.095)
        }
    return {
        "joystick_center": Vector2(s.x*0.142,s.y*0.810),
        "joystick_radius": s.y*0.177,
        "drift": Rect2(s.x*0.850,s.y*0.390,s.x*0.128,s.y*0.340),
        "brake": Rect2(s.x*0.698,s.y*0.817,s.x*0.096,s.y*0.161),
        "gas": Rect2(s.x*0.856,s.y*0.754,s.x*0.098,s.y*0.224),
        "gas_shape": _gas_shape(Rect2(s.x*0.856,s.y*0.754,s.x*0.098,s.y*0.224),
            Rect2(s.x*0.698,s.y*0.817,s.x*0.096,s.y*0.161)),
        "pause": hud["pause"],
        "camera": hud["camera"],
        "restart": Rect2(s.x*0.33,s.y*0.49,s.x*0.34,s.y*0.12),
        "menu": Rect2(s.x*0.33,s.y*0.65,s.x*0.34,s.y*0.12)
    }

func _zone_at(pos: Vector2, size_override: Vector2 = Vector2.ZERO) -> String:
    var geo: Dictionary = _layout(size_override)
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
    # v0.1.36: the gas pedal has a "wing" above the brake (owner's request:
    # the thumb slid off the top-left of the pedal). Drawn and touched as one.
    if Geometry2D.is_point_in_polygon(pos,PackedVector2Array(geo["gas_shape"])):
        return "gas"
    return ""

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        var touch: InputEventScreenTouch = event
        if touch.pressed and press_blocker.is_valid() and bool(press_blocker.call()):
            return
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

## ---------------------------------------------------------------- gas pedal
## The pedal face rectangle (shared by the drawing and the shape maths).
static func pedal_face(rect: Rect2, gas_pedal: bool, press: float = 0.0) -> Rect2:
    return Rect2(rect.position.x+rect.size.x*0.05,rect.position.y+rect.size.y*0.01+press,
        rect.size.x*0.90,rect.size.y*(0.88 if gas_pedal else 0.86))

const PEDAL_SKEW: float = 0.10

## Outline (screen pixels, italic skew applied) of the L-shaped GAS pedal: the
## normal pedal plus a wing that reaches left over the top of the brake and
## tapers back to the pedal along a diagonal (the owner's sketch, 2026-11-22:
## "add surface so it nests with the brake"). The drawing and the touch
## detection use this one polygon; the brake rectangle stays untouched.
static func _gas_shape(gas: Rect2, brake_rect: Rect2) -> PackedVector2Array:
    var face: Rect2 = pedal_face(gas,true)
    var radius: float = gas.size.x*0.14
    var margin: float = brake_rect.size.x*0.12
    var x0: float = brake_rect.end.x+margin
    var y_top: float = face.position.y
    var y_left: float = brake_rect.position.y-gas.size.y*0.012
    var y_end: float = face.position.y+face.size.y*0.62
    var wing := PackedVector2Array([
        Vector2(x0,y_top),Vector2(face.position.x+face.size.x*0.40,y_top),
        Vector2(face.position.x+face.size.x*0.40,y_end),Vector2(face.position.x+face.size.x*0.02,y_end),
        Vector2(x0,y_left)])
    var union: Array = Geometry2D.merge_polygons(STYLE.shape(face,radius,0.0),wing)
    if union.is_empty():
        return STYLE.shape(face,radius,PEDAL_SKEW)
    var poly: PackedVector2Array = union[0]
    # Round the corners: close (concave), then open (convex).
    var r: float = radius*0.85
    for delta in [r,-r,-r,r]:
        var grown: Array = Geometry2D.offset_polygon(poly,float(delta),Geometry2D.JOIN_ROUND)
        if grown.is_empty():
            break
        poly = grown[0]
    var out := PackedVector2Array()
    for p in poly:
        out.append(STYLE.skew_point(p,face,PEDAL_SKEW))
    return out

## Face polygon of the (rectangular) brake pedal, for overlap checks.
static func brake_shape(brake_rect: Rect2) -> PackedVector2Array:
    return STYLE.shape(pedal_face(brake_rect,false),brake_rect.size.x*0.14,PEDAL_SKEW)

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
    var u: float = _ui_scale()
    _joystick(Vector2(geo["joystick_center"]),float(geo["joystick_radius"]),u)
    _handbrake(Rect2(geo["drift"]),handbrake > 0.0)
    _pedal(Rect2(geo["brake"]),"BRAKE",brake > 0.0)
    _pedal(Rect2(geo["gas"]),"GAS",throttle > 0.0,PackedVector2Array(geo["gas_shape"]))
    _button(Rect2(geo["pause"]),"pause",u)
    _button(Rect2(geo["camera"]),"camera",u)
    # PAUSE and FINISH have exclusive modal menus in their own CanvasLayers.

func _joystick(centre: Vector2, radius: float, u: float) -> void:
    # Thin ring + metal knob; the hit zone is the same circle (x1.17).
    draw_circle(centre,radius,Color(0.02,0.02,0.035,0.30))
    draw_arc(centre,radius,0.0,TAU,96,Color(0.92,0.93,0.97,0.80),2.2*u,true)
    # Accent neon on the lower-right edge, like the pedals and panels.
    STYLE.glow_arc(self,centre,radius,-PI*0.12,PI*0.62,STYLE.PINK,2.2*u,1.0)
    draw_arc(centre,radius*0.965,0.0,TAU,96,Color(1,1,1,0.10),1.2*u,true)
    var knob: Vector2 = centre+Vector2(steer*radius*0.57,0.0)
    var rk: float = radius*0.36
    draw_circle(knob+Vector2(rk*0.05,rk*0.12),rk*1.04,Color(0,0,0,0.38))
    var steps: int = 16
    for k in range(steps):
        var t: float = float(k)/float(steps-1)
        var c: Color = Color(0.34,0.35,0.39).lerp(Color(0.95,0.95,0.97),pow(t,0.75))
        draw_circle(knob+Vector2(-0.30,-0.34)*rk*t,rk*(1.0-t*0.80),c)
    draw_arc(knob,rk,0.0,TAU,48,Color(1,1,1,0.55),1.3*u,true)
    draw_circle(knob+Vector2(-0.42,-0.46)*rk,rk*0.10,Color(1,1,1,0.55))

func _button(rect: Rect2, icon: String, u: float) -> void:
    var pts: PackedVector2Array = STYLE.shape(rect,13.0*u,STYLE.SKEW*0.85)
    var cols := PackedColorArray()
    for p in pts:
        cols.append(STYLE.GLASS_TOP.lerp(STYLE.GLASS_BOTTOM,clampf((p.y-rect.position.y)/rect.size.y,0.0,1.0)))
    draw_polygon(pts,cols)
    var outline: PackedVector2Array = pts.duplicate()
    outline.append(pts[0])
    draw_polyline(outline,Color(1,1,1,0.14),6.0*u,true)
    draw_polyline(outline,Color(0.93,0.94,0.98,0.85),2.0*u,true)
    var c: Vector2 = rect.get_center()
    var h: float = rect.size.y
    if icon == "pause":
        for side in [-1.0,1.0]:
            var bar := Rect2(c.x+side*h*0.13-h*0.065,c.y-h*0.24,h*0.13,h*0.48)
            draw_rect(bar,STYLE.WHITE,true)
    else:
        var body := Rect2(c.x-h*0.36,c.y-h*0.20,h*0.48,h*0.40)
        var box := StyleBoxFlat.new()
        box.bg_color = STYLE.WHITE
        box.set_corner_radius_all(int(h*0.08))
        draw_style_box(box,body)
        draw_colored_polygon(PackedVector2Array([
            Vector2(body.end.x+h*0.02,c.y-h*0.03),Vector2(body.end.x+h*0.24,c.y-h*0.17),
            Vector2(body.end.x+h*0.24,c.y+h*0.17),Vector2(body.end.x+h*0.02,c.y+h*0.03)]),STYLE.WHITE)

func _handbrake(rect: Rect2, pressed: bool) -> void:
    # Lever reference: black ribbed grip with pink cap, chrome shaft and a
    # black base with pink neon. The WHOLE drawn rectangle is the target.
    var u: float = _ui_scale()
    var x: float = rect.position.x
    var y: float = rect.position.y
    var w: float = rect.size.x
    var h: float = rect.size.y
    var cx: float = x+w*0.5
    var pull: float = h*0.06 if pressed else 0.0
    # Base plate.
    var base := Rect2(x+w*0.05,y+h*0.705,w*0.90,h*0.285)
    var base_pts: PackedVector2Array = STYLE.shape(base,w*0.17,0.0)
    var base_cols := PackedColorArray()
    for p in base_pts:
        base_cols.append(Color(0.16,0.16,0.19).lerp(Color(0.035,0.035,0.045),
            clampf((p.y-base.position.y)/base.size.y,0.0,1.0)))
    var outline: PackedVector2Array = base_pts.duplicate()
    outline.append(base_pts[0])
    draw_polygon(base_pts,base_cols)
    # Same frame as every other control (owner): thin edge all round, neon
    # only along the lower-right corner.
    draw_polyline(outline,STYLE.EDGE,maxf(1.0,1.5*u),true)
    STYLE.glow_line(self,STYLE.glow_path(base,w*0.17,0.0),STYLE.PINK,2.2*u,1.6 if pressed else 1.0)
    for side in [-1.0,1.0]:
        var bolt := Vector2(cx+side*base.size.x*0.32,base.position.y+base.size.y*0.17)
        draw_circle(bolt,w*0.045,Color(0.55,0.56,0.60))
        draw_circle(bolt+Vector2(-1,-1)*w*0.012,w*0.026,Color(0.92,0.93,0.96))
    # Owner's NW initials as a small, delicate engraving in the base plate:
    # a shade lighter than the plate, hairline dark lip above-left and a
    # faint light catch below-right.
    var logo_h: float = base.size.y*0.30
    var logo_w: float = logo_h*float(NW_MASK.get_width())/float(NW_MASK.get_height())
    # Centred in the box (owner), between the two bolts' row and the bottom.
    var logo := Rect2(Vector2(cx,base.get_center().y)-Vector2(logo_w,logo_h)*0.5,Vector2(logo_w,logo_h))
    var lip: float = maxf(0.75,0.8*u)
    draw_texture_rect(NW_MASK,Rect2(logo.position+Vector2(lip,lip),logo.size),false,Color(1,1,1,0.10))
    draw_texture_rect(NW_MASK,Rect2(logo.position-Vector2(lip,lip),logo.size),false,Color(0,0,0,0.55))
    draw_texture_rect(NW_MASK,logo,false,Color(0.24,0.245,0.27) if not pressed else Color(0.30,0.305,0.33))
    # Chrome shaft (three vertical strips fake a cylinder).
    var shaft_top: float = y+h*0.34+pull
    var shaft_bottom: float = base.position.y+base.size.y*0.06
    var sw: float = w*0.15
    var strips: Array = [[-0.5,-0.15,Color(0.45,0.47,0.52),Color(0.88,0.89,0.93)],
        [-0.15,0.18,Color(0.97,0.98,1.0),Color(0.97,0.98,1.0)],
        [0.18,0.5,Color(0.82,0.83,0.88),Color(0.30,0.31,0.36)]]
    for strip in strips:
        var a: float = cx+sw*float(strip[0])
        var b: float = cx+sw*float(strip[1])
        draw_polygon(PackedVector2Array([Vector2(a,shaft_top),Vector2(b,shaft_top),
            Vector2(b,shaft_bottom),Vector2(a,shaft_bottom)]),
            PackedColorArray([strip[2],strip[3],strip[3],strip[2]]))
    draw_rect(Rect2(cx-sw*0.75,shaft_top-h*0.012,sw*1.5,h*0.03),Color(0.08,0.08,0.10),true)
    # Ribbed rubber grip.
    var grip := Rect2(cx-w*0.17,y+h*0.045+pull,w*0.34,h*0.30)
    var grip_box := StyleBoxFlat.new()
    grip_box.bg_color = Color(0.07,0.07,0.085)
    grip_box.set_corner_radius_all(int(w*0.12))
    grip_box.border_color = Color(0.25,0.25,0.29)
    grip_box.set_border_width_all(int(maxf(1.0,1.2*u)))
    draw_style_box(grip_box,grip)
    var ribs: int = 12
    for k in range(ribs):
        var ry: float = grip.position.y+grip.size.y*(0.10+0.82*float(k)/float(ribs-1))
        draw_line(Vector2(grip.position.x+w*0.035,ry),Vector2(grip.end.x-w*0.035,ry),
            Color(0.20,0.20,0.24,0.95),2.2*u,true)
        draw_line(Vector2(grip.position.x+w*0.035,ry+1.6*u),Vector2(grip.end.x-w*0.035,ry+1.6*u),
            Color(0.0,0.0,0.0,0.6),1.2*u,true)
    draw_line(Vector2(grip.position.x+w*0.06,grip.position.y+grip.size.y*0.12),
        Vector2(grip.position.x+w*0.06,grip.end.y-grip.size.y*0.10),Color(1,1,1,0.16),2.0*u,true)
    # Pink cap.
    var cap := Rect2(cx-w*0.19,grip.position.y-h*0.03,w*0.38,h*0.055)
    var cap_box := StyleBoxFlat.new()
    cap_box.bg_color = STYLE.PINK
    cap_box.set_corner_radius_all(int(w*0.10))
    cap_box.shadow_color = Color(STYLE.PINK.r,STYLE.PINK.g,STYLE.PINK.b,0.55 if pressed else 0.35)
    cap_box.shadow_size = int(10.0*u)
    draw_style_box(cap_box,cap)
    draw_line(Vector2(cap.position.x+w*0.06,cap.position.y+cap.size.y*0.32),
        Vector2(cap.end.x-w*0.06,cap.position.y+cap.size.y*0.32),Color(1,0.75,0.88,0.9),2.0*u,true)

func _pedal(rect: Rect2, label: String, pressed: bool, shape: PackedVector2Array = PackedVector2Array()) -> void:
    # Perforated brushed-aluminium pedals with a pink-lit lower edge.
    # Visual footprint = the touch area (v0.1.36: the GAS pedal is an L-shape
    # with a wing above the brake, passed in as `shape`).
    var u: float = _ui_scale()
    var gas_pedal: bool = label == "GAS"
    var press: float = rect.size.y*0.025 if pressed else 0.0
    var face: Rect2 = pedal_face(rect,gas_pedal,press)
    var skew: float = PEDAL_SKEW
    var radius: float = rect.size.x*0.14
    var depth: float = rect.size.y*(0.055 if gas_pedal else 0.075)
    var side_rect := Rect2(face.position+Vector2(0,depth),face.size)
    var face_pts: PackedVector2Array = STYLE.shape(face,radius,skew)
    var side_pts: PackedVector2Array = STYLE.shape(side_rect,radius,skew)
    if gas_pedal and shape.size() >= 3:
        face_pts = _shifted(shape,Vector2(0,press))
        side_pts = _shifted(shape,Vector2(0,press+depth))
    STYLE.glow_line(self,STYLE.glow_path(side_rect,radius,skew,0.02,0.75),STYLE.PINK,
        2.6*u,1.8 if pressed else 1.0)
    draw_colored_polygon(side_pts,Color(0.30,0.31,0.35))
    var box: Rect2 = _bounds(face_pts)
    var cols := PackedColorArray()
    for p in face_pts:
        var t: float = clampf((p.y-box.position.y)/box.size.y,0.0,1.0)
        var d: float = clampf((p.x-box.position.x)/box.size.x,0.0,1.0)
        cols.append(Color(0.93,0.94,0.96).lerp(Color(0.55,0.57,0.62),t*0.75+d*0.25))
    draw_polygon(face_pts,cols)
    # Brushed grain (clipped to the outline row by row).
    for k in range(22):
        var gy: float = box.position.y+box.size.y*(0.04+0.92*float(k)/21.0)
        var span: Vector2 = _row_span(face_pts,gy)
        if span.y-span.x < radius*1.2:
            continue
        draw_line(Vector2(span.x+radius*0.4,gy),Vector2(span.y-radius*0.4,gy),
            Color(1,1,1,0.07) if k%2 == 0 else Color(0,0,0,0.05),1.0*u)
    var outline: PackedVector2Array = face_pts.duplicate()
    outline.append(face_pts[0])
    draw_polyline(outline,Color(1,1,1,0.85),1.6*u,true)
    # Holes: gas 2x5 grid (+ 2 in the wing), brake 2-1-2.
    var holes: Array[Vector2] = []
    if gas_pedal:
        for row in range(5):
            for col in [0.30,0.70]:
                holes.append(Vector2(col,0.13+0.74*float(row)/4.0))
        if shape.size() >= 3:
            holes.append(Vector2(-0.36,0.13))
            holes.append(Vector2(-0.36,0.30))
    else:
        holes = [Vector2(0.28,0.20),Vector2(0.72,0.20),Vector2(0.5,0.50),
            Vector2(0.28,0.80),Vector2(0.72,0.80)]
    var hole_r: float = face.size.x*(0.105 if gas_pedal else 0.12)
    for rel in holes:
        var c: Vector2 = STYLE.skew_point(face.position+face.size*rel,face,skew)
        if rel.x < 0.0 and not Geometry2D.is_point_in_polygon(c,face_pts):
            continue
        draw_circle(c+Vector2(hole_r*0.10,hole_r*0.14),hole_r*1.08,Color(1,1,1,0.55))
        draw_circle(c,hole_r,Color(0.05,0.05,0.07))
        draw_circle(c-Vector2(hole_r*0.18,hole_r*0.20),hole_r*0.72,Color(0.015,0.015,0.02))
    if pressed:
        draw_polyline(outline,Color(1.0,0.35,0.70,0.9),2.4*u,true)

static func _shifted(pts: PackedVector2Array, by: Vector2) -> PackedVector2Array:
    var out := PackedVector2Array()
    for p in pts:
        out.append(p+by)
    return out

static func _bounds(pts: PackedVector2Array) -> Rect2:
    var lo := Vector2(INF,INF)
    var hi := Vector2(-INF,-INF)
    for p in pts:
        lo = Vector2(minf(lo.x,p.x),minf(lo.y,p.y))
        hi = Vector2(maxf(hi.x,p.x),maxf(hi.y,p.y))
    return Rect2(lo,hi-lo)

## Left / right x of a polygon on the horizontal line y (INF / -INF when the
## line misses it).
static func _row_span(pts: PackedVector2Array, y: float) -> Vector2:
    var lo: float = INF
    var hi: float = -INF
    var n: int = pts.size()
    for i in range(n):
        var a: Vector2 = pts[i]
        var b: Vector2 = pts[(i+1)%n]
        if (a.y <= y and b.y > y) or (b.y <= y and a.y > y):
            var x: float = a.x+(y-a.y)/(b.y-a.y)*(b.x-a.x)
            lo = minf(lo,x)
            hi = maxf(hi,x)
    return Vector2(lo,hi)
