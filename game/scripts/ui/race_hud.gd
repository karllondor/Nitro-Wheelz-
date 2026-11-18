extends Control
class_name NitroRaceHUD
## P5 visual prototype from the approved Nitro Wheelz reference. All score
## readouts use the real race model; stars are outlined until progression P4.

var race_time: float = 0.0
var lap: int = 1
var lap_limit: int = 3
var score: int = 0
var drift_score: int = 0
var speed: float = 0.0
var reversing: bool = false
var drift_degrees: float = 0.0
var combo: float = 1.0
var mode: String = "TOP-DOWN"
var paused: bool = false
var finished: bool = false
var road_status: String = "ON TRACK"
var track_name: String = "SHIN-KAWA"
var track_points: PackedVector2Array = PackedVector2Array()
var target_time: float = 0.0

const WHITE := Color(0.98,0.98,1.0)
const MUTED := Color(0.78,0.79,0.83)
const PINK := Color(1.0,0.025,0.48)
const GOLD := Color(1.0,0.77,0.24)

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
    queue_redraw()

func _scale() -> float:
    var s: Vector2 = get_viewport_rect().size
    return clampf((s.x if s.y>s.x else s.y)/700.0,0.78,2.1)

func _panel(rect: Rect2,rounding: float=18.0) -> void:
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.018,0.023,0.033,0.85)
    style.border_color = Color(0.73,0.76,0.80,0.56)
    style.set_border_width_all(int(maxf(1.0,1.4*_scale())))
    style.set_corner_radius_all(int(rounding*_scale()))
    draw_style_box(style,rect)
    draw_line(Vector2(rect.end.x-rect.size.x*0.13,rect.end.y-2.0),
        Vector2(rect.end.x-rect.size.x*0.02,rect.end.y-2.0),
        PINK,2.3*_scale(),true)

func _label(rect: Rect2,txt: String,y: float,size: int,
        col: Color=WHITE,align: HorizontalAlignment=HORIZONTAL_ALIGNMENT_LEFT) -> void:
    var f: Font = get_theme_default_font()
    var pt: int = int(size*_scale())
    var px: float = rect.position.x+12.0*_scale()
    var extent: float = rect.size.x-24.0*_scale()
    var baseline: float = rect.position.y+rect.size.y*y+f.get_ascent(pt)*0.25
    draw_string(f,Vector2(px,baseline),txt,align,extent,pt,col)

func _minimap(rect: Rect2) -> void:
    if track_points.size()<8:
        return
    var smallest := Vector2(INF,INF)
    var largest := Vector2(-INF,-INF)
    for p in track_points:
        smallest.x = minf(smallest.x,p.x)
        smallest.y = minf(smallest.y,p.y)
        largest.x = maxf(largest.x,p.x)
        largest.y = maxf(largest.y,p.y)
    var box: Vector2 = largest-smallest
    var sf: float = minf(rect.size.x*0.76/maxf(box.x,0.01),
        rect.size.y*0.70/maxf(box.y,0.01))
    var mid: Vector2 = (smallest+largest)*0.5
    var outline := PackedVector2Array()
    var step: int = maxi(1,int(track_points.size()/80))
    for i in range(0,track_points.size(),step):
        outline.append(rect.get_center()+(track_points[i]-mid)*sf)
    outline.append(outline[0])
    draw_polyline(outline,WHITE,2.5*_scale(),true)
    draw_circle(outline[0],2.8*_scale(),PINK)

func _draw() -> void:
    var s: Vector2 = get_viewport_rect().size
    var portrait: bool = s.y>s.x
    var mx: float = s.x*(0.022 if portrait else 0.016)
    var top: float = s.y*0.016
    var header_height: float = s.y*(0.080 if portrait else 0.160)
    var header := Rect2(mx,top,s.x-2.0*mx,header_height)
    _panel(header,20.0)
    var map_area := Rect2(mx+6.0*_scale(),top+4.0*_scale(),
        header.size.x*0.22,header_height-8.0*_scale())
    _minimap(map_area)
    draw_line(Vector2(header.position.x+header.size.x*0.255,top+header_height*0.19),
        Vector2(header.position.x+header.size.x*0.255,top+header_height*0.81),
        MUTED,1.2*_scale(),true)
    var centre := Rect2(header.position.x+header.size.x*0.276,top,
        header.size.x*0.31,header_height)
    _label(centre,track_name.to_upper(),0.33,27,WHITE)
    _label(centre,"LAP %d/%d" % [lap,lap_limit],0.72,18,MUTED)
    draw_line(Vector2(header.position.x+header.size.x*0.610,top+header_height*0.17),
        Vector2(header.position.x+header.size.x*0.610,top+header_height*0.81),
        MUTED,1.2*_scale(),true)
    var clock := Rect2(header.position.x+header.size.x*0.642,top,
        header.size.x*0.338,header_height)
    _label(clock,_time_string(race_time),0.41,36,WHITE,HORIZONTAL_ALIGNMENT_CENTER)
    var bar_top := clock.position.y+clock.size.y*0.77
    draw_line(Vector2(clock.position.x+clock.size.x*0.12,bar_top),
        Vector2(clock.end.x-clock.size.x*0.12,bar_top),
        PINK,5.0*_scale(),true)

    var stats_y: float = s.y*(0.109 if portrait else 0.192)
    var stats_h: float = s.y*(0.083 if portrait else 0.149)
    var gap: float = s.x*0.012
    var score_w: float = (s.x-2.0*mx-2.0*gap)*0.300
    var active_w: float = (s.x-2.0*mx-2.0*gap)*0.260
    var time_w: float = (s.x-2.0*mx-2.0*gap)-score_w-active_w
    var total_rect := Rect2(mx,stats_y,score_w,stats_h)
    var active_rect := Rect2(total_rect.end.x+gap,stats_y,active_w,stats_h)
    var chase_rect := Rect2(active_rect.end.x+gap,stats_y,time_w,stats_h)
    _panel(total_rect);_panel(active_rect);_panel(chase_rect)
    _label(total_rect,"TOTAL SCORE",0.22,14,MUTED)
    _label(total_rect,_score_string(score),0.64,32,WHITE,HORIZONTAL_ALIGNMENT_CENTER)
    _label(active_rect,"SCORE",0.22,14,MUTED)
    _label(active_rect,_score_string(drift_score),0.57,29,WHITE,HORIZONTAL_ALIGNMENT_CENTER)
    _label(active_rect,"x%.1f" % combo,0.85,17,PINK,HORIZONTAL_ALIGNMENT_RIGHT)
    _label(chase_rect,"CHASING TIME",0.22,14,MUTED)
    _label(chase_rect,"☆ ☆ ☆",0.67,29,GOLD)
    _label(chase_rect,_time_string(target_time) if target_time>0.0 else "--:--",
        0.67,17,MUTED,HORIZONTAL_ALIGNMENT_RIGHT)

    var angle_box := Rect2(mx,s.y*(0.588 if portrait else 0.545),
        s.x*(0.145 if portrait else 0.125),s.y*(0.047 if portrait else 0.095))
    var speed_box := Rect2(mx,s.y*(0.649 if portrait else 0.645),
        s.x*(0.335 if portrait else 0.210),s.y*(0.071 if portrait else 0.118))
    _panel(angle_box,12.0);_panel(speed_box,14.0)
    _label(angle_box,"%d°" % int(round(absf(drift_degrees))),0.52,24,WHITE,
        HORIZONTAL_ALIGNMENT_CENTER)
    _label(speed_box,("R " if reversing else "")+str(int(speed))+" KM/H",
        0.55,31,WHITE,HORIZONTAL_ALIGNMENT_CENTER)
    if paused or finished:
        draw_rect(Rect2(Vector2.ZERO,s),Color(0.012,0.015,0.025,0.65))
        var popup := Rect2(s.x*0.19,s.y*0.37,s.x*0.62,s.y*0.16)
        _panel(popup)
        _label(popup,"FINISHED" if finished else "PAUSED",0.40,36,PINK,
            HORIZONTAL_ALIGNMENT_CENTER)
        _label(popup,"Tap RESTART or GARAGE / MENU",0.75,18,WHITE,
            HORIZONTAL_ALIGNMENT_CENTER)

func _score_string(value: int) -> String:
    var digits: String = str(value)
    var end: String = ""
    while digits.length()>3:
        end = ","+digits.substr(digits.length()-3,3)+end
        digits = digits.substr(0,digits.length()-3)
    return digits+end

func _time_string(seconds: float) -> String:
    return "%02d:%05.2f" % [int(seconds/60.0),fmod(seconds,60.0)]
