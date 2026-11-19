extends Control
class_name NitroRaceHUD
## Driving HUD drawn to the approved Nitro Wheelz gameplay reference:
## header (minimap / track + lap / clock + lap-progress bar), three score
## tiles (total, active drift + combo, chasing time + stars), drift angle
## and speed. All numbers are live race data; stars are the projected
## result tiers used by the finish screen (not fabricated progression).

const STYLE = preload("res://scripts/ui/hud_style.gd")
const RESULTS = preload("res://scripts/ui/race_results.gd")

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
var track_id: String = ""
var track_points: PackedVector2Array = PackedVector2Array()
var car_world_position: Vector2 = Vector2.ZERO
var track_progress: float = 0.0
var target_time: float = 0.0

var _outline_cache: PackedVector2Array = PackedVector2Array()
var _outline_rect: Rect2 = Rect2()

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
    queue_redraw()

func overall_progress() -> float:
    return clampf((float(lap-1)+track_progress)/float(maxi(lap_limit,1)),0.0,1.0)

func projected_time() -> float:
    var progress: float = overall_progress()
    if progress < 0.06 or race_time <= 0.0:
        return 0.0
    return race_time/progress

## Stars the current pace would earn, and the time to chase for the next one.
func chase_state() -> Dictionary:
    if target_time <= 0.0:
        return {"stars":0,"chase":0.0}
    var tiers: Array[float] = [target_time,target_time*0.82,target_time*0.68]
    if track_id == "benchmark_oval":
        tiers = [75.0,51.0,47.31]
    var projected: float = projected_time()
    var stars: int = 0
    if projected > 0.0:
        stars = RESULTS.star_count(track_id,projected,target_time)
    var chase: float = tiers[mini(stars,2)]
    return {"stars":stars,"chase":chase}

func _draw() -> void:
    var s: Vector2 = get_viewport_rect().size
    var m: Dictionary = STYLE.metrics(s)
    var u: float = float(m["unit"])
    _draw_header(Rect2(m["header"]),u)
    _draw_total(Rect2(m["total"]),u)
    _draw_score(Rect2(m["score"]),u)
    _draw_chase(Rect2(m["chase"]),u)
    _draw_angle(Rect2(m["angle"]),u)
    _draw_speed(Rect2(m["speed"]),u)

func _draw_header(r: Rect2, u: float) -> void:
    STYLE.panel(self,r,u,18.0,0.0,true,1.0)
    var map_rect := Rect2(r.position.x+r.size.x*0.025,r.position.y+r.size.y*0.12,
        r.size.x*0.20,r.size.y*0.76)
    _minimap(map_rect,u)
    STYLE.separator(self,r.position.x+r.size.x*0.255,r.position.y+r.size.y*0.2,
        r.position.y+r.size.y*0.8,u)
    var tx: float = r.position.x+r.size.x*0.30
    var title_size: float = r.size.y*0.30
    STYLE.text(self,Vector2(tx,r.position.y+r.size.y*0.46),track_name.to_upper(),
        title_size,STYLE.WHITE,HORIZONTAL_ALIGNMENT_LEFT,r.size.x*0.32)
    STYLE.text(self,Vector2(tx-r.size.y*0.03,r.position.y+r.size.y*0.80),
        "LAP %d/%d" % [lap,lap_limit],r.size.y*0.22,STYLE.MUTED,
        HORIZONTAL_ALIGNMENT_LEFT,-1.0,false)
    STYLE.separator(self,r.position.x+r.size.x*0.625,r.position.y+r.size.y*0.2,
        r.position.y+r.size.y*0.8,u)
    var clock := Rect2(r.position.x+r.size.x*0.655,r.position.y,r.size.x*0.32,r.size.y)
    STYLE.text(self,Vector2(clock.position.x,clock.position.y+clock.size.y*0.58),
        STYLE.time_string(race_time),r.size.y*0.44,STYLE.WHITE,
        HORIZONTAL_ALIGNMENT_CENTER,clock.size.x)
    # Lap progress bar (live), pink neon like the reference.
    var y: float = clock.position.y+clock.size.y*0.79
    var x0: float = clock.position.x+clock.size.x*0.06
    var x1: float = clock.end.x-clock.size.x*0.04
    var thickness: float = r.size.y*0.075
    draw_line(Vector2(x0,y),Vector2(x1,y),Color(0.16,0.16,0.20,0.95),thickness,true)
    var fill: float = clampf(track_progress,0.0,1.0)
    if fill > 0.002:
        var pts := PackedVector2Array([Vector2(x0,y),Vector2(lerpf(x0,x1,fill),y)])
        STYLE.glow_line(self,pts,STYLE.PINK,thickness*0.55,0.8)

func _minimap(rect: Rect2, u: float) -> void:
    if track_points.size() < 8:
        return
    if _outline_rect != rect or _outline_cache.is_empty():
        _outline_rect = rect
        var lo := Vector2(INF,INF)
        var hi := Vector2(-INF,-INF)
        for p in track_points:
            lo = Vector2(minf(lo.x,p.x),minf(lo.y,p.y))
            hi = Vector2(maxf(hi.x,p.x),maxf(hi.y,p.y))
        var box: Vector2 = hi-lo
        var sf: float = minf(rect.size.x*0.86/maxf(box.x,0.01),rect.size.y*0.86/maxf(box.y,0.01))
        var mid: Vector2 = (lo+hi)*0.5
        _outline_cache = PackedVector2Array()
        var step: int = maxi(1,int(track_points.size()/90))
        for i in range(0,track_points.size(),step):
            _outline_cache.append(rect.get_center()+(track_points[i]-mid)*sf)
        _outline_cache.append(_outline_cache[0])
        set_meta("map_scale",sf)
        set_meta("map_mid",mid)
    draw_polyline(_outline_cache,Color(1,1,1,0.12),7.0*u,true)
    draw_polyline(_outline_cache,STYLE.WHITE,2.6*u,true)
    var sf2: float = float(get_meta("map_scale",1.0))
    var mid2: Vector2 = get_meta("map_mid",Vector2.ZERO)
    var start_dot: Vector2 = rect.get_center()+(track_points[0]-mid2)*sf2
    var tangent: Vector2 = (track_points[1]-track_points[track_points.size()-1]).normalized()
    var across := Vector2(-tangent.y,tangent.x)*5.0*u
    draw_line(start_dot-across,start_dot+across,STYLE.WHITE,3.0*u,true)
    var dot: Vector2 = rect.get_center()+(car_world_position-mid2)*sf2
    draw_circle(dot,7.5*u,Color(1.0,0.16,0.56,0.25))
    draw_circle(dot,4.6*u,STYLE.PINK)
    draw_arc(dot,4.6*u,0.0,TAU,20,STYLE.WHITE,1.2*u,true)

func _label(r: Rect2, txt: String) -> void:
    STYLE.text(self,Vector2(r.position.x+r.size.x*0.13,r.position.y+r.size.y*0.30),txt,
        r.size.y*0.155,STYLE.MUTED,HORIZONTAL_ALIGNMENT_LEFT,-1.0,false)

func _draw_total(r: Rect2, u: float) -> void:
    STYLE.panel(self,r,u)
    _label(r,"TOTAL SCORE")
    STYLE.text(self,Vector2(r.position.x,r.position.y+r.size.y*0.76),_score_string(score),
        r.size.y*0.36,STYLE.WHITE,HORIZONTAL_ALIGNMENT_CENTER,r.size.x)

func _draw_score(r: Rect2, u: float) -> void:
    STYLE.panel(self,r,u)
    _label(r,"SCORE")
    STYLE.text(self,Vector2(r.position.x,r.position.y+r.size.y*0.70),_score_string(drift_score),
        r.size.y*0.34,STYLE.WHITE,HORIZONTAL_ALIGNMENT_CENTER,r.size.x)
    STYLE.text(self,Vector2(r.position.x,r.position.y+r.size.y*0.90),"x%.1f" % combo,
        r.size.y*0.15,STYLE.PINK,HORIZONTAL_ALIGNMENT_RIGHT,r.size.x*0.80,false)

func _draw_chase(r: Rect2, u: float) -> void:
    STYLE.panel(self,r,u)
    _label(r,"CHASING TIME")
    var state: Dictionary = chase_state()
    var stars: int = int(state["stars"])
    var radius: float = r.size.y*0.17
    var cy: float = r.position.y+r.size.y*0.63
    for k in range(3):
        var cx: float = r.position.x+r.size.x*0.17+float(k)*radius*2.35
        STYLE.star(self,Vector2(cx,cy),radius,k < stars,u)
    var chase_time: float = float(state["chase"])
    STYLE.text(self,Vector2(r.position.x,cy+r.size.y*0.09),
        STYLE.short_time(chase_time) if chase_time > 0.0 else "--:--",
        r.size.y*0.19,STYLE.MUTED,HORIZONTAL_ALIGNMENT_RIGHT,r.size.x*0.90,false)

func _draw_angle(r: Rect2, u: float) -> void:
    STYLE.panel(self,r,u,12.0)
    STYLE.text(self,Vector2(r.position.x,r.position.y+r.size.y*0.72),
        "%d°" % int(round(absf(drift_degrees))),r.size.y*0.52,STYLE.WHITE,
        HORIZONTAL_ALIGNMENT_CENTER,r.size.x)

func _draw_speed(r: Rect2, u: float) -> void:
    STYLE.panel(self,r,u,14.0)
    var number: String = ("R " if reversing else "")+str(int(speed))
    var big: float = r.size.y*0.60
    var small: float = r.size.y*0.25
    var unit_txt: String = "KM/H"
    var total_w: float = STYLE.text_width(number,big)+r.size.y*0.12+STYLE.text_width(unit_txt,small,false)
    var x: float = r.get_center().x-total_w*0.5
    var base: float = r.position.y+r.size.y*0.74
    STYLE.text(self,Vector2(x,base),number,big,STYLE.WHITE)
    STYLE.text(self,Vector2(x+STYLE.text_width(number,big)+r.size.y*0.12,base),unit_txt,
        small,STYLE.MUTED,HORIZONTAL_ALIGNMENT_LEFT,-1.0,false)

func _score_string(value: int) -> String:
    var digits: String = str(value)
    var end: String = ""
    while digits.length()>3:
        end = ","+digits.substr(digits.length()-3,3)+end
        digits = digits.substr(0,digits.length()-3)
    return digits+end

func _time_string(seconds: float) -> String:
    return STYLE.time_string(seconds)
