extends Control
class_name NitroRaceHUD
## Responsive, high-contrast mobile HUD. Size is based on the real viewport,
## not small font defaults inherited from the desktop starter.

var race_time: float = 0.0
var lap: int = 1
var lap_limit: int = 3
var score: int = 0
var speed: float = 0.0
var reversing: bool = false
var drift_degrees: float = 0.0
var combo: float = 1.0
var mode: String = "TOP-DOWN"
var paused: bool = false
var finished: bool = false
var road_status: String = "ON TRACK"

const LIGHT := Color(0.99,0.99,0.99)
const ORANGE := Color(1.0,0.69,0.27)
const MUTED := Color(0.79,0.83,0.88)

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
    queue_redraw()

func _font_scale() -> float:
    var view: Vector2 = get_viewport_rect().size
    if view.y > view.x:
        return clampf(view.x/700.0,1.0,2.25)
    return clampf(view.y/700.0,0.95,1.6)

func _panel(rect: Rect2) -> void:
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.04,0.05,0.09,0.73)
    style.set_corner_radius_all(int(18.0*_font_scale()))
    style.border_color = Color(0.94,0.85,0.78,0.12)
    style.set_border_width_all(1)
    draw_style_box(style,rect)

func _print(rect: Rect2,text: String,rel_y: float,point_size: int,
        tint: Color=LIGHT,center: bool=false) -> void:
    var font: Font = get_theme_default_font()
    var sz: int = int(float(point_size)*_font_scale())
    var baseline: float = rect.position.y + rect.size.y*rel_y + font.get_ascent(sz)*0.28
    var x: float = rect.position.x if center else rect.position.x+16.0*_font_scale()
    var width: float = rect.size.x if center else rect.size.x-24.0*_font_scale()
    draw_string(font,Vector2(x,baseline),text,
        HORIZONTAL_ALIGNMENT_CENTER if center else HORIZONTAL_ALIGNMENT_LEFT,
        width,sz,tint)

func _draw() -> void:
    var s: Vector2 = get_viewport_rect().size
    var portrait: bool = s.y>s.x
    var margin: float = s.x*(0.023 if portrait else 0.016)
    var top: float = s.y*(0.015 if portrait else 0.026)
    var left: Rect2 = Rect2(margin,top,s.x*(0.52 if portrait else 0.32),
        s.y*(0.124 if portrait else 0.20))
    var right: Rect2 = Rect2(s.x*(0.78 if portrait else 0.81),top,
        s.x*(0.20 if portrait else 0.17),left.size.y)
    _panel(left)
    _panel(right)

    _print(left,"SHIN-KAWA  •  LAP %d/%d" % [lap,lap_limit],
        0.23,19,MUTED)
    _print(left,_time_string(race_time),0.61,43,LIGHT)
    _print(left,"JAPAN DRIFT NIGHTS",0.88,15,ORANGE)

    _print(right,"SCORE",0.23,19,MUTED,true)
    _print(right,str(score),0.59,39,LIGHT,true)
    _print(right,"x%.1f" % combo,0.88,18,ORANGE,true)

    var speedbox: Rect2 = Rect2(margin,s.y*(0.601 if portrait else 0.755),
        s.x*(0.32 if portrait else 0.18),
        s.y*(0.089 if portrait else 0.16))
    _panel(speedbox)
    _print(speedbox,("%s%d KM/H" % ["R ",int(speed)]) if reversing else "%d KM/H" % int(speed),0.43,31,LIGHT)
    _print(speedbox,"%d°  %s" % [int(absf(drift_degrees)),road_status],
        0.79,15,ORANGE)

    if not portrait:
        var tag: Rect2 = Rect2(s.x*0.39,s.y*0.915,s.x*0.21,s.y*0.06)
        _panel(tag)
        _print(tag,mode,0.58,17,MUTED,true)

    if paused or finished:
        draw_rect(Rect2(Vector2.ZERO,s),Color(0.015,0.018,0.03,0.60))
        var popup: Rect2 = Rect2(s.x*0.19,s.y*0.38,s.x*0.62,s.y*0.16)
        _panel(popup)
        _print(popup,"FINISHED" if finished else "PAUSED",0.38,41,ORANGE,true)
        _print(popup,"Tap RESTART or GARAGE / MENU",0.74,21,LIGHT,true)

func _time_string(seconds: float) -> String:
    return "%02d:%05.2f" % [int(seconds/60.0),fmod(seconds,60.0)]
