extends Control
class_name NitroParkGuide
## On-screen guidance of the Park tutorial (issue #27). Drawn only while a tutorial is
## ON: a lesson card in the header area, pulsing highlights on the REAL touch targets
## (GAS / BRAKE / HANDBRAKE / joystick use the same rectangles the touch input uses), a
## big positive / corrective toast and, before a drill, a dimmed schematic of the
## manoeuvre with arrows. With the tutorial OFF (FREE DRIVE or SKIP) it draws nothing
## and leaves the driving view unobstructed.
const STYLE = preload("res://scripts/ui/hud_style.gd")
const LAYOUT = preload("res://scripts/park/park_layout.gd")
const TUTORIAL = preload("res://scripts/park/park_tutorial.gd")
const TOUCH = preload("res://scripts/ui/race_touch.gd")

var tutorial: NitroParkTutorial = null
var touch: NitroRaceTouch = null
var controller: Node = null                 # NitroParkController (skip / ghost callbacks)
var ghost_on: bool = true
## Planar world position the lesson wants the player to drive to (Vector2) or null,
## and the distance to it in metres (set by the controller every tick).
var target: Variant = null
var target_dist: float = 0.0
var toast_text: String = ""
var toast_time: float = 0.0
var toast_kind: String = "info"             # info / good / hint
var _clock: float = 0.0
var _skip_rect: Rect2 = Rect2()
var _ghost_rect: Rect2 = Rect2()
var _repeat_rect: Rect2 = Rect2()

func _ready() -> void:
    name = "Park guide"
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    STYLE.ensure_fonts()

func show_toast(text: String, kind: String = "info", seconds: float = 2.4) -> void:
    toast_text = text
    toast_kind = kind
    toast_time = seconds
    queue_redraw()

func overlay_active() -> bool:
    return tutorial != null and tutorial.phase == "intro"

func card_visible() -> bool:
    return tutorial != null and tutorial.is_active()

func _process(delta: float) -> void:
    _clock += delta
    if toast_time > 0.0:
        toast_time = maxf(0.0,toast_time-delta)
    if card_visible() or toast_time > 0.0 or (tutorial != null and tutorial.phase == "finished"):
        queue_redraw()

# ---------------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
    var pos := Vector2.ZERO
    var pressed: bool = false
    if event is InputEventScreenTouch:
        var te: InputEventScreenTouch = event
        pos = te.position
        pressed = te.pressed
    elif event is InputEventMouseButton:
        var me: InputEventMouseButton = event
        pos = me.position
        pressed = me.pressed and me.button_index == MOUSE_BUTTON_LEFT
    else:
        return
    if not pressed or tutorial == null:
        return
    if overlay_active():
        tutorial.dismiss_intro()
        get_viewport().set_input_as_handled()
        return
    if not card_visible():
        return
    if _skip_rect.has_point(pos):
        if controller != null:
            controller.call("skip_tutorial")
        get_viewport().set_input_as_handled()
    elif _ghost_rect.has_point(pos):
        if controller != null:
            controller.call("toggle_ghost")
        get_viewport().set_input_as_handled()
    elif _repeat_rect.has_point(pos):
        if controller != null:
            controller.call("repeat_lesson")
        get_viewport().set_input_as_handled()

# ----------------------------------------------------------------------- draw

func _draw() -> void:
    if tutorial == null:
        return
    var s: Vector2 = get_viewport_rect().size
    var m: Dictionary = STYLE.metrics(s)
    var u: float = float(m["unit"])
    if tutorial.phase == "intro":
        _draw_overlay(s,u)
        return
    if card_visible():
        _draw_highlight(u)
        _draw_target(s,u)
        _draw_card(m,u)
    _draw_toast(s,u)

func _wrapped(pos: Vector2, txt: String, size: float, width: float, colour: Color, lines: int, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
    var px: int = maxi(8,int(size))
    draw_multiline_string(STYLE.BOLD,pos+Vector2(1.5,2.0)*maxf(1.0,size/30.0),txt,align,width,px,lines,Color(0,0,0,0.5))
    draw_multiline_string(STYLE.BOLD,pos,txt,align,width,px,lines,colour)

## Pick the biggest font size (<= base) at which `txt` fits `lines` lines of `width`.
func _fit_lines(txt: String, base: float, width: float, lines: int) -> float:
    var size: float = base
    while size > base*0.55:
        var w: float = STYLE.text_width(txt,size)
        if w <= width*float(lines)*0.9:
            break
        size -= 1.0
    return size

func _draw_card(m: Dictionary, u: float) -> void:
    var r: Rect2 = m["header"]
    STYLE.panel(self,r,u,18.0,0.0,true,1.0)
    var dead: Rect2 = m["dead"]
    var top: float = r.position.y+r.size.y*0.06
    if bool(m["portrait"]) and dead.intersects(r):
        top = maxf(top,dead.end.y)
    var pad: float = r.size.x*0.035
    var left: float = r.position.x+pad
    var avail: float = r.size.x-pad*2.0
    var l: Dictionary = tutorial.lesson()
    var title: String = "%d/%d  %s" % [tutorial.lesson_index+1,TUTORIAL.LESSONS.size(),tutorial.title_text()]
    var title_px: float = r.size.y*0.2
    STYLE.text(self,Vector2(left,top+title_px),title,STYLE.fit_size(title,title_px,avail),STYLE.PINK,HORIZONTAL_ALIGNMENT_LEFT,-1.0,true)
    var prompt: String = tutorial.success_text() if tutorial.phase == "success" else tutorial.prompt_text()
    var avail_h: float = r.end.y-top-title_px*1.25-r.size.y*0.12
    var base: float = minf(r.size.y*0.22,avail_h*0.5)
    var size: float = _fit_lines(prompt,base,avail,2)
    _wrapped(Vector2(left,top+title_px*1.25+size),prompt,size,avail,STYLE.WHITE if tutorial.phase != "success" else STYLE.GOLD,2)
    # progress bar along the bottom of the card
    var bar := Rect2(r.position.x+pad,r.end.y-r.size.y*0.11,r.size.x-pad*2.0,maxf(3.0,r.size.y*0.035))
    draw_rect(bar,Color(1,1,1,0.12),true)
    var prog: float = 1.0 if tutorial.phase == "success" else tutorial.progress()
    draw_rect(Rect2(bar.position,Vector2(bar.size.x*prog,bar.size.y)),STYLE.PINK.lerp(Color.WHITE,0.25),true)
    _draw_actions(m,u)

## SKIP / GHOST / REPEAT as a row of big touch buttons under the card, left of the
## PAUSE / CAM buttons (a thumb-sized target each, never over the controls).
func _draw_actions(m: Dictionary, u: float) -> void:
    var r: Rect2 = m["header"]
    var pause: Rect2 = m["pause"]
    var gap: float = 10.0*u
    var left: float = r.position.x
    var right: float = (pause.position.x-gap) if pause.position.y >= r.end.y-1.0 else r.end.x
    var h: float = maxf(pause.size.y,58.0*u)
    var y: float = r.end.y+gap
    var w: float = (right-left-gap*2.0)/3.0
    var l: Dictionary = tutorial.lesson()
    var has_ghost: bool = _has_demo(l)
    _skip_rect = Rect2(left,y,w,h)
    _ghost_rect = Rect2(left+(w+gap),y,w,h)
    _repeat_rect = Rect2(left+(w+gap)*2.0,y,w,h)
    _button(_skip_rect,"POMIŃ" if TUTORIAL.LANG == "pl" else "SKIP",true,u)
    _button(_ghost_rect,("DUCH" if TUTORIAL.LANG == "pl" else "GHOST")+(" ●" if ghost_on and has_ghost else ""),has_ghost,u)
    _button(_repeat_rect,"OD NOWA" if TUTORIAL.LANG == "pl" else "REPEAT",true,u)

func _has_demo(l: Dictionary) -> bool:
    return str(l["kind"]) in ["donut","eight","route"]

func _button(rect: Rect2, label: String, enabled: bool, u: float) -> void:
    STYLE.panel(self,rect,u,12.0,0.0,enabled,0.8)
    var size: float = STYLE.fit_size(label,rect.size.y*0.46,rect.size.x*0.86)
    STYLE.text(self,Vector2(rect.position.x,rect.position.y+rect.size.y*0.66),label,size,
        STYLE.WHITE if enabled else STYLE.MUTED,HORIZONTAL_ALIGNMENT_CENTER,rect.size.x,true)

# ------------------------------------------------------------------ highlight

## Pulsing outline on the touch target the lesson is about. Uses the rectangles the
## touch input itself uses, so what glows is exactly what reacts.
func _draw_highlight(u: float) -> void:
    if touch == null:
        return
    var key: String = str(tutorial.lesson()["highlight"])
    if key == "" or tutorial.phase != "active":
        return
    var geo: Dictionary = touch._layout()
    var pulse: float = 0.55+0.45*sin(_clock*5.5)
    var col := Color(1.0,0.92,0.35,0.55+0.45*pulse)
    var w: float = 4.0*u
    match key:
        "gas":
            var pts := PackedVector2Array(geo["gas_shape"])
            _outline(pts,col,w,6.0*u)
        "brake":
            var rect: Rect2 = geo["brake"]
            _outline(TOUCH.brake_shape(rect),col,w,6.0*u)
        "drift":
            var rect2: Rect2 = geo["drift"]
            draw_rect(rect2.grow(5.0*u),col,false,w)
        "joystick":
            var c: Vector2 = geo["joystick_center"]
            var radius: float = float(geo["joystick_radius"])
            draw_arc(c,radius*1.17+6.0*u*pulse,0.0,TAU,64,col,w,true)

func _outline(pts: PackedVector2Array, col: Color, width: float, grow: float) -> void:
    if pts.size() < 3:
        return
    var out := PackedVector2Array()
    var centre := Vector2.ZERO
    for p in pts:
        centre += p
    centre /= float(pts.size())
    for p2 in pts:
        out.append(p2+(p2-centre).normalized()*grow*0.5)
    out.append(out[0])
    draw_polyline(out,col,width,true)

## An arrow at the screen edge towards the exercise when it is off screen (the Park is
## much bigger than the camera view), with the distance. The world also shows a light
## beacon over the target.
func _draw_target(s: Vector2, u: float) -> void:
    if target == null or tutorial.phase != "active":
        return
    var cam: Camera3D = get_viewport().get_camera_3d()
    if cam == null:
        return
    var t2: Vector2 = target
    var p3 := Vector3(t2.x,0.5,t2.y)
    var behind: bool = cam.is_position_behind(p3)
    var sp: Vector2 = cam.unproject_position(p3)
    var inner: Rect2 = Rect2(Vector2.ZERO,s).grow(-s.x*0.09)
    if not behind and inner.has_point(sp):
        return
    var centre: Vector2 = s*0.5
    var dir: Vector2 = (sp-centre)
    if behind:
        dir = -dir
    if dir.length() < 1.0:
        dir = Vector2(0,-1)
    dir = dir.normalized()
    var half: Vector2 = inner.size*0.5
    var k: float = minf(half.x/maxf(absf(dir.x),0.0001),half.y/maxf(absf(dir.y),0.0001))
    var at: Vector2 = centre+dir*k*0.92
    var nrm := Vector2(-dir.y,dir.x)
    var size: float = 26.0*u
    var pulse: float = 0.6+0.4*sin(_clock*5.0)
    var col := Color(0.35,0.95,1.0,0.65+0.35*pulse)
    var tri := PackedVector2Array([at+dir*size,at-dir*size*0.6+nrm*size*0.8,at-dir*size*0.6-nrm*size*0.8])
    draw_colored_polygon(tri,col)
    var label: String = "%d m" % int(round(target_dist))
    STYLE.text(self,at-dir*size*1.9-Vector2(size*1.5,-size*0.3),label,22.0*u,Color(1,1,1,0.95),HORIZONTAL_ALIGNMENT_CENTER,size*3.0,true)

# ---------------------------------------------------------------------- toast

func _draw_toast(s: Vector2, u: float) -> void:
    var txt: String = toast_text
    var kind: String = toast_kind
    if tutorial != null and tutorial.phase == "success" and toast_time <= 0.0:
        txt = tutorial.success_text()
        kind = "good"
    elif toast_time <= 0.0:
        return
    var alpha: float = clampf(toast_time/0.6,0.0,1.0) if tutorial == null or tutorial.phase != "success" else 1.0
    var size: float = (64.0 if kind == "good" else 34.0)*u
    var col: Color = STYLE.GOLD if kind == "good" else (Color(1.0,0.92,0.6) if kind == "hint" else STYLE.WHITE)
    col.a = alpha
    var y: float = s.y*(0.33 if kind == "good" else 0.40)
    var width: float = s.x*0.9
    var fit: float = _fit_lines(txt,size,width,2)
    if kind == "good":
        STYLE.text(self,Vector2(s.x*0.05,y),txt,fit,col,HORIZONTAL_ALIGNMENT_CENTER,width,true)
    else:
        # a soft plate behind the hint so it reads over the pavement
        var plate := Rect2(s.x*0.05,y-fit*1.25,width,fit*(2.5 if STYLE.text_width(txt,fit) > width*0.9 else 1.7))
        draw_rect(plate,Color(0,0,0,0.42*alpha),true)
        _wrapped(Vector2(s.x*0.05+width*0.02,y),txt,fit,width*0.96,col,2,HORIZONTAL_ALIGNMENT_CENTER)

# -------------------------------------------------------------------- overlay

## Dimmed schematic of the manoeuvre before a drill; any tap starts the practice.
func _draw_overlay(s: Vector2, u: float) -> void:
    draw_rect(Rect2(Vector2.ZERO,s),Color(0.004,0.005,0.012,0.82),true)
    var l: Dictionary = tutorial.lesson()
    var title: String = "%d/%d  %s" % [tutorial.lesson_index+1,TUTORIAL.LESSONS.size(),tutorial.title_text()]
    var ts: float = STYLE.fit_size(title,52.0*u,s.x*0.9)
    STYLE.text(self,Vector2(s.x*0.05,s.y*0.12),title,ts,STYLE.PINK,HORIZONTAL_ALIGNMENT_CENTER,s.x*0.9,true)
    var side: float = minf(s.x*0.86,s.y*0.5)
    var box := Rect2((s.x-side)*0.5,s.y*0.17,side,side)
    STYLE.panel(self,box,u,20.0,0.0,true,0.8)
    _schematic(l,box.grow(-side*0.06),u)
    var prompt: String = tutorial.prompt_text()
    var px: float = _fit_lines(prompt,36.0*u,s.x*0.86,3)
    _wrapped(Vector2(s.x*0.07,box.end.y+px*1.9),prompt,px,s.x*0.86,STYLE.WHITE,3,HORIZONTAL_ALIGNMENT_CENTER)
    var tap: String = "DOTKNIJ, ABY ZACZĄĆ" if TUTORIAL.LANG == "pl" else "TAP TO START"
    var blink: float = 0.55+0.45*sin(_clock*4.0)
    STYLE.text(self,Vector2(s.x*0.05,s.y*0.92),tap,STYLE.fit_size(tap,34.0*u,s.x*0.9),
        Color(1,1,1,blink),HORIZONTAL_ALIGNMENT_CENTER,s.x*0.9,true)

func _schematic(l: Dictionary, area: Rect2, u: float) -> void:
    var kind: String = str(l["kind"])
    var e: Dictionary = LAYOUT.exercise(str(l.get("exercise","")))
    if e.is_empty():
        return
    var pts := PackedVector2Array()
    var centre: Vector2 = e["centre"]
    var cones: Array = []
    match kind:
        "donut":
            var r: float = float(e["radius"])
            for k in range(73):
                var a: float = TAU*float(k)/72.0
                pts.append(centre+Vector2(cos(a),sin(a))*r)
            cones.append(centre)
        "eight":
            pts = LAYOUT.eight_path(centre,float(e["radius"]),LAYOUT.EIGHT_SPREAD,1.0)
            for c in e["lobes"]:
                cones.append(c)
        "route":
            pts = LAYOUT.route_path(2.0)
            for c2 in e["lobes"]:
                cones.append(c2)
    var lo := Vector2(INF,INF)
    var hi := Vector2(-INF,-INF)
    for p in pts:
        lo = Vector2(minf(lo.x,p.x),minf(lo.y,p.y))
        hi = Vector2(maxf(hi.x,p.x),maxf(hi.y,p.y))
    var span: Vector2 = hi-lo
    var fit: float = minf(area.size.x/maxf(span.x,1.0),area.size.y/maxf(span.y,1.0))*0.92
    var mid: Vector2 = (lo+hi)*0.5
    var origin: Vector2 = area.get_center()
    var to_s := func(p: Vector2) -> Vector2: return origin+(p-mid)*fit
    var line := PackedVector2Array()
    for p2 in pts:
        line.append(to_s.call(p2))
    line.append(line[0])
    var path_col: Color = Color(1.0,0.84,0.36) if kind == "route" else STYLE.WHITE
    draw_polyline(line,Color(0,0,0,0.5),5.0*u,true)
    draw_polyline(line,path_col,3.0*u,true)
    # arrows along the line (a chevron every ~1/10 of the path)
    var n: int = line.size()
    var step: int = maxi(4,n/9)
    for i in range(step/2,n-1,step):
        var a2: Vector2 = line[i]
        var b2: Vector2 = line[mini(i+2,n-1)]
        var d: Vector2 = (b2-a2).normalized()
        var nr := Vector2(-d.y,d.x)
        var tip: Vector2 = a2+d*9.0*u
        draw_polyline(PackedVector2Array([tip-d*9.0*u+nr*7.0*u,tip,tip-d*9.0*u-nr*7.0*u]),path_col,3.5*u,true)
    # cones
    for c3 in cones:
        var cp: Vector2 = to_s.call(c3)
        draw_circle(cp,9.0*u,Color(1.0,0.42,0.06))
        draw_circle(cp,4.0*u,Color(1,1,1,0.9))
    # the car with its drifting attitude, ahead of the first arrow
    var mid_i: int = n/5
    var ca: Vector2 = line[mid_i]
    var cb: Vector2 = line[mini(mid_i+2,n-1)]
    var dir: Vector2 = (cb-ca).normalized()
    var body: Vector2 = dir.rotated(0.45*signf(dir.x*(line[mini(mid_i+6,n-1)]-cb).y-dir.y*(line[mini(mid_i+6,n-1)]-cb).x))
    var bn := Vector2(-body.y,body.x)
    var quad := PackedVector2Array([ca+body*15.0*u+bn*7.0*u,ca+body*15.0*u-bn*7.0*u,ca-body*15.0*u-bn*7.0*u,ca-body*15.0*u+bn*7.0*u])
    draw_colored_polygon(quad,Color(0.25,0.95,1.0,0.8))
    draw_line(ca+body*15.0*u,ca+body*24.0*u,Color(1,1,1,0.9),3.0*u,true)
