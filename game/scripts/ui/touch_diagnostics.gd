extends CanvasLayer
class_name NitroTouchDiag
## DEVELOPER > TOUCH DIAGNOSTICS (v0.1.32 mobile QA). An overlay on top of
## the Track Builder and the race that shows, live on the phone:
##  * every touch: its ID, position and WHO takes it - the top-most UI
##    control that stops it (button / panel name) or "SCENE" when it passes
##    through to the map / game;
##  * the hitboxes of every visible input-stopping control (red outlines)
##    and the scene's input area (green, e.g. the builder map rectangle);
##  * the order of events (press / drag / release per ID, then what the
##    scene did with it, from the scene's own diag log);
##  * FPS, frame time (process / physics ms), draw calls, plus the scene's
##    own lines (builder: terrain adapts and whether one ever ran during a
##    camera move; race: the visual angle of every wheel).
## Off by default; never part of the player HUD. Input passes through.
const DEV = preload("res://scripts/dev_settings.gd")
const STYLE = preload("res://scripts/ui/hud_style.gd")

var source: Node
var _view: Control
var _touches: Dictionary = {}
var _log: PackedStringArray = []
var _hitboxes: Array = []
var _hit_t: float = 0.0

static func enabled() -> bool:
    return bool(DEV.get_value("developer","touch_diagnostics",false))

static func set_enabled(on: bool) -> void:
    DEV.set_value("developer","touch_diagnostics",on)

## Adds the overlay to a scene when the developer switch is on.
static func attach(parent: Node) -> NitroTouchDiag:
    if not enabled():
        return null
    var d: NitroTouchDiag = load("res://scripts/ui/touch_diagnostics.gd").new()
    d.source = parent
    d.layer = 120
    d.name = "Touch diagnostics"
    parent.add_child(d)
    return d

func _ready() -> void:
    _view = Control.new()
    _view.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _view.draw.connect(_draw_view)
    add_child(_view)
    # v0.1.52 (issue #65): the overlay can always be switched off where it is seen (the DEVELOPER switch was out of
    # reach on a phone). Same setting as DEVELOPER > TOUCH DIAGNOSTICS; only this small button takes touches.
    var s: Vector2 = get_viewport().get_visible_rect().size
    var u: float = clampf(minf(s.x,s.y)/700.0,0.8,1.8)
    var off := Button.new()
    off.name = "Diagnostics off"
    off.text = "DIAG OFF ✕"
    off.focus_mode = Control.FOCUS_NONE
    off.add_theme_font_size_override("font_size",int(18*u))
    STYLE.style_button(off,u,true)
    off.size = Vector2(190,58)*u
    off.position = Vector2(s.x-off.size.x-10.0*u,s.y*0.16+6.0*u)
    off.pressed.connect(turn_off)
    add_child(off)

## Switches the overlay off for good (DEVELOPER > TOUCH DIAGNOSTICS: OFF) and removes it from this screen.
func turn_off() -> void:
    set_enabled(false)
    queue_free()

func _process(delta: float) -> void:
    _hit_t -= delta
    if _hit_t <= 0.0:
        _hit_t = 0.5
        _hitboxes = []
        _collect(get_tree().root,_hitboxes)
    _view.queue_redraw()

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        var t: InputEventScreenTouch = event
        var who: String = who_takes(t.position)
        if t.pressed:
            _touches[t.index] = {"pos":t.position,"who":who}
        else:
            _touches.erase(t.index)
        _add("%s #%d (%d,%d) -> %s" % ["DOWN" if t.pressed else "UP",t.index,int(t.position.x),int(t.position.y),who])
    elif event is InputEventScreenDrag:
        var d: InputEventScreenDrag = event
        if _touches.has(d.index):
            _touches[d.index]["pos"] = d.position

func _add(line: String) -> void:
    _log.append("%05d %s" % [Time.get_ticks_msec()%100000,line])
    if _log.size() > 8:
        _log.remove_at(0)

## Name of the top-most visible control that stops a touch at p, or SCENE
## (tree order = draw order inside a canvas layer; higher layers win).
func who_takes(p: Vector2) -> String:
    var best: Array = [null,-1000]
    _who(get_tree().root,0,p,best)
    var c: Control = best[0]
    if c == null:
        return "SCENE"
    var label: String = str(c.name)
    if c is Button and (c as Button).text != "":
        label += " [%s]" % (c as Button).text.replace("\n"," ")
    return label

func _who(n: Node, lay: int, p: Vector2, best: Array) -> void:
    if n == self:
        return
    if n is CanvasLayer:
        lay = (n as CanvasLayer).layer
    if n is Control:
        var c := n as Control
        if not c.is_visible_in_tree():
            return
        if c.mouse_filter == Control.MOUSE_FILTER_STOP and c.get_global_rect().has_point(p) and lay >= int(best[1]):
            best[0] = c
            best[1] = lay
    for ch in n.get_children():
        _who(ch,lay,p,best)

func _collect(n: Node, out: Array) -> void:
    if n == self:
        return
    if n is Control:
        var c := n as Control
        if not c.is_visible_in_tree():
            return
        if c.mouse_filter == Control.MOUSE_FILTER_STOP:
            out.append(c.get_global_rect())
    for ch in n.get_children():
        _collect(ch,out)

func _draw_view() -> void:
    var s: Vector2 = _view.size
    var u: float = clampf(minf(s.x,s.y)/700.0,0.8,1.8)
    var font: Font = ThemeDB.fallback_font
    for r in _hitboxes:
        _view.draw_rect(r,Color(1.0,0.2,0.25,0.55),false,1.5)
    if source != null and source.get("map_rect") is Rect2:
        _view.draw_rect(source.get("map_rect"),Color(0.2,1.0,0.4,0.8),false,3.0)
    for k in _touches.keys():
        var t: Dictionary = _touches[k]
        var p: Vector2 = t["pos"]
        _view.draw_circle(p,26.0*u,Color(1.0,0.85,0.1,0.35))
        _view.draw_arc(p,26.0*u,0.0,TAU,32,Color(1.0,0.85,0.1,0.95),2.0)
        _view.draw_string(font,p+Vector2(30,-10)*u,"#%d %s" % [int(k),str(t["who"])],HORIZONTAL_ALIGNMENT_LEFT,-1,int(15*u),Color.WHITE)
    var lines: PackedStringArray = []
    lines.append("FPS %d  frame %.1f ms  physics %.1f ms  draw calls %d" % [Engine.get_frames_per_second(),
        Performance.get_monitor(Performance.TIME_PROCESS)*1000.0,Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0,
        int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))])
    if source != null and source.has_method("diag_text"):
        for l in str(source.call("diag_text")).split("\n"):
            lines.append(l)
    lines.append("-- input events (who takes them) --")
    for l in _log:
        lines.append(l)
    var fs: int = int(13*u)
    var h: float = float(lines.size())*(fs+3)+10
    var top: float = s.y*0.16
    _view.draw_rect(Rect2(6,top,s.x*0.94,h),Color(0,0,0,0.62))
    for i in range(lines.size()):
        _view.draw_string(font,Vector2(12,top+8+fs+i*(fs+3)),lines[i],HORIZONTAL_ALIGNMENT_LEFT,s.x*0.92,fs,Color(0.9,1.0,0.9))
