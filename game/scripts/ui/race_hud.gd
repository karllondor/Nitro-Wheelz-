extends Control
class_name NitroRaceHUD
## Adaptive HUD: wide desktop and portrait mobile. Decorative only (touch uses
## a separate independent multitouch layer for reliable simultaneous controls).

var race_time: float = 0.0
var lap: int = 1
var lap_limit: int = 3
var score: int = 0
var speed: float = 0.0
var drift_degrees: float = 0.0
var combo: float = 1.0
var mode: String = "TOP-DOWN"
var paused: bool = false
var finished: bool = false
var road_status: String = "ON TRACK"

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
    queue_redraw()

func _draw() -> void:
    var area: Vector2 = get_viewport_rect().size
    var portrait: bool = area.y > area.x
    var scale_factor: float = clampf(area.x / (720.0 if portrait else 1280.0), 0.75, 1.25)
    var font: Font = get_theme_default_font()
    var white := Color(0.94,0.94,0.95)
    var amber := Color(1.0,0.67,0.24)
    var panel := Color(0.05,0.07,0.11,0.76)
    var pad: float = 16.0 * scale_factor
    var top_y: float = 16.0 * scale_factor
    var left_w: float = minf(area.x*0.57, 410.0*scale_factor)
    var panel_h: float = 128.0*scale_factor
    draw_rect(Rect2(Vector2(pad,top_y),Vector2(left_w,panel_h)),panel)
    var size_small: int = int(18.0 * scale_factor)
    var size_big: int = int(39.0 * scale_factor)
    var location: String = "SHIN-KAWA   •   LAP " + str(lap) + "/" + str(lap_limit)
    draw_string(font,Vector2(pad*1.6,top_y+28.0*scale_factor),location,
        HORIZONTAL_ALIGNMENT_LEFT,-1,size_small,white)
    draw_string(font,Vector2(pad*1.6,top_y+83.0*scale_factor),
        _time_string(race_time),HORIZONTAL_ALIGNMENT_LEFT,-1,size_big,white)
    draw_string(font,Vector2(pad*1.6,top_y+111.0*scale_factor),
        "JAPAN DRIFT NIGHTS",HORIZONTAL_ALIGNMENT_LEFT,-1,int(15*scale_factor),amber)

    var right_width: float = minf(area.x*0.30,210.0*scale_factor)
    var score_x: float = area.x - right_width - pad
    draw_rect(Rect2(Vector2(score_x,top_y),Vector2(right_width,panel_h)),panel)
    draw_string(font,Vector2(score_x+14*scale_factor,top_y+28*scale_factor),
        "DRIFT SCORE",HORIZONTAL_ALIGNMENT_LEFT,-1,size_small,white)
    draw_string(font,Vector2(score_x+14*scale_factor,top_y+78*scale_factor),
        str(score),HORIZONTAL_ALIGNMENT_LEFT,-1,size_big,amber)
    draw_string(font,Vector2(score_x+14*scale_factor,top_y+111*scale_factor),
        "COMBO  x" + str(snappedf(combo,0.1)),HORIZONTAL_ALIGNMENT_LEFT,-1,
        int(16*scale_factor),white)

    var bottom_y: float = area.y * (0.62 if portrait else 0.78)
    draw_rect(Rect2(Vector2(pad,bottom_y),Vector2(182*scale_factor,84*scale_factor)),panel)
    draw_string(font,Vector2(pad+14*scale_factor,bottom_y+35*scale_factor),
        str(int(speed)) + " KM/H",HORIZONTAL_ALIGNMENT_LEFT,-1,int(27*scale_factor),white)
    draw_string(font,Vector2(pad+14*scale_factor,bottom_y+66*scale_factor),
        str(int(absf(drift_degrees))) + "°  " + road_status,
        HORIZONTAL_ALIGNMENT_LEFT,-1,int(14*scale_factor),amber)

    draw_rect(Rect2(Vector2(area.x*0.35,area.y-38*scale_factor),
        Vector2(area.x*0.30,29*scale_factor)),Color(0.05,0.07,0.11,0.70))
    draw_string(font,Vector2(area.x*0.37,area.y-17*scale_factor),
        mode + "  •  C / Xbox Y",HORIZONTAL_ALIGNMENT_LEFT,-1,
        int(15*scale_factor),white)

    if finished or paused:
        draw_rect(Rect2(Vector2.ZERO,area),Color(0.02,0.03,0.05,0.62))
        var heading: String = "FINISH — 3 LAPS" if finished else "PAUSED"
        draw_string(font,Vector2(area.x*0.26,area.y*0.43),heading,
            HORIZONTAL_ALIGNMENT_LEFT,-1,int(36*scale_factor),white)
        draw_string(font,Vector2(area.x*0.26,area.y*0.49),
            "Press R to restart · Esc / Menu to resume or exit",
            HORIZONTAL_ALIGNMENT_LEFT,-1,int(18*scale_factor),amber)

func _time_string(seconds: float) -> String:
    var minutes: int = int(seconds / 60.0)
    var rest: float = fmod(seconds,60.0)
    return "%02d:%05.2f" % [minutes,rest]

