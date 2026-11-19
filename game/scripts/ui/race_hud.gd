extends Control
class_name NitroRaceHUD
## Driving HUD v2 (owner sketch, 2026-11-19).
## Header: big minimap | TOTAL score (heavy) / LAP x/3 + time / small track
## name, with a thin full-width progress line split into the three laps.
## Under it: CHASING-score pill (local best) and, only while a drift chain
## is scoring, the live chain points + multiplier in the centre. Scoring
## callouts appear large above the car. Round speedometer with the drift
## angle under it on the left. All values are live race data.

const STYLE = preload("res://scripts/ui/hud_style.gd")

var race_time: float = 0.0
var lap: int = 1
var lap_limit: int = 3
var score: int = 0              # banked total
var drift_score: int = 0        # live chain points
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
var best_score: int = -1        # local best on this track, -1 = none yet
var car_screen: Vector2 = Vector2(-1,-1)  # car on screen; callouts pop above it
var score_events: Array[Dictionary] = []

var chain_alpha: float = 0.0
var _outline_cache: PackedVector2Array = PackedVector2Array()
var _outline_rect: Rect2 = Rect2()
var _map_scale: float = 1.0
var _map_mid: Vector2 = Vector2.ZERO

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    STYLE.ensure_settings()

func _process(delta: float) -> void:
    var target: float = 1.0 if drift_score > 0 else 0.0
    chain_alpha = move_toward(chain_alpha,target,delta*(6.0 if target > chain_alpha else 2.5))
    queue_redraw()

func overall_progress() -> float:
    return clampf((float(lap-1)+track_progress)/float(maxi(lap_limit,1)),0.0,1.0)

## Text of the centred chase pill: who/what the player is chasing.
func chase_label() -> Dictionary:
    var running: int = score+int(round(float(drift_score)*combo))
    if best_score <= 0:
        return {"text":"FIRST RUN  •  SET THE SCORE","beating":false}
    if running > best_score:
        return {"text":"NEW BEST  "+_score_string(running),"beating":true}
    return {"text":"CHASING  "+_score_string(best_score),"beating":false}

func _draw() -> void:
    var s: Vector2 = get_viewport_rect().size
    var m: Dictionary = STYLE.metrics(s)
    var u: float = float(m["unit"])
    _draw_header(m,u)
    _draw_chase(Rect2(m["chase"]),u)
    _draw_chain(Rect2(m["score"]),u)
    _draw_gauge(Vector2(m["gauge_centre"]),float(m["gauge_radius"]),u)
    _draw_angle(Rect2(m["angle"]),u)
    _draw_callouts(callout_anchor(m,s),s,u)

# ------------------------------------------------------------------ header

func _draw_header(m: Dictionary, u: float) -> void:
    var r: Rect2 = m["header"]
    STYLE.panel(self,r,u,18.0,0.0,true,1.0)
    _minimap(Rect2(m["map"]),u)
    var st: Rect2 = m["total"]
    var x: float = st.position.x
    var h: float = r.size.y
    var y0: float = r.position.y
    STYLE.text(self,Vector2(x,y0+h*0.17),"TOTAL SCORE",h*0.080,STYLE.MUTED,
        HORIZONTAL_ALIGNMENT_LEFT,-1.0,false)
    STYLE.text(self,Vector2(x,y0+h*0.50),_score_string(score),h*0.33,STYLE.WHITE,
        HORIZONTAL_ALIGNMENT_LEFT,st.size.x)
    STYLE.text(self,Vector2(x,y0+h*0.73),"LAP %d/%d" % [lap,lap_limit],h*0.15,
        STYLE.WHITE,HORIZONTAL_ALIGNMENT_LEFT,-1.0,true)
    STYLE.text(self,Vector2(x,y0+h*0.73),STYLE.time_string(race_time),h*0.12,
        STYLE.MUTED,HORIZONTAL_ALIGNMENT_RIGHT,st.size.x,false)
    STYLE.text(self,Vector2(x,y0+h*0.865),track_name.to_upper(),h*0.068,STYLE.DIM,
        HORIZONTAL_ALIGNMENT_LEFT,st.size.x,false)
    _draw_lap_line(r,u)

## Thin line across the whole panel, split into one segment per lap:
## completed laps full, the current lap fills with progress.
func _draw_lap_line(r: Rect2, u: float) -> void:
    var pad: float = r.size.x*0.035
    var y: float = r.end.y-r.size.y*0.07
    var gap: float = r.size.x*0.018
    var seg: float = (r.size.x-2.0*pad-gap*float(lap_limit-1))/float(lap_limit)
    var thickness: float = maxf(3.0,r.size.y*0.028)
    for k in range(lap_limit):
        var x0: float = r.position.x+pad+float(k)*(seg+gap)
        draw_line(Vector2(x0,y),Vector2(x0+seg,y),Color(0.22,0.22,0.27,0.95),thickness,true)
        var fill: float = 0.0
        if k < lap-1 or (finished and k <= lap-1):
            fill = 1.0
        elif k == lap-1:
            fill = clampf(track_progress,0.0,1.0)
        if fill > 0.003:
            var pts := PackedVector2Array([Vector2(x0,y),Vector2(x0+seg*fill,y)])
            STYLE.glow_line(self,pts,STYLE.PINK,thickness*0.75,0.7)

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
        _map_scale = minf(rect.size.x*0.90/maxf(box.x,0.01),rect.size.y*0.90/maxf(box.y,0.01))
        _map_mid = (lo+hi)*0.5
        _outline_cache = PackedVector2Array()
        var step: int = maxi(1,int(track_points.size()/140))
        for i in range(0,track_points.size(),step):
            _outline_cache.append(rect.get_center()+(track_points[i]-_map_mid)*_map_scale)
        _outline_cache.append(_outline_cache[0])
    draw_polyline(_outline_cache,Color(1,1,1,0.10),9.0*u,true)
    draw_polyline(_outline_cache,STYLE.WHITE,3.0*u,true)
    var start_dot: Vector2 = rect.get_center()+(track_points[0]-_map_mid)*_map_scale
    var tangent: Vector2 = (track_points[1]-track_points[track_points.size()-1]).normalized()
    var across := Vector2(-tangent.y,tangent.x)*6.0*u
    draw_line(start_dot-across,start_dot+across,STYLE.WHITE,3.5*u,true)
    var dot: Vector2 = rect.get_center()+(car_world_position-_map_mid)*_map_scale
    draw_circle(dot,9.0*u,Color(STYLE.PINK.r,STYLE.PINK.g,STYLE.PINK.b,0.28))
    draw_circle(dot,5.5*u,STYLE.PINK)
    draw_arc(dot,5.5*u,0.0,TAU,20,STYLE.WHITE,1.4*u,true)

# ------------------------------------------------------- chase + live chain

func _draw_chase(r: Rect2, u: float) -> void:
    var state: Dictionary = chase_label()
    var beating: bool = bool(state["beating"])
    STYLE.panel(self,r,u,12.0,STYLE.SKEW,true,1.4 if beating else 0.6)
    var col: Color = STYLE.GOLD if beating else STYLE.WHITE
    var star_r: float = r.size.y*0.24
    STYLE.star(self,Vector2(r.position.x+r.size.x*0.10,r.get_center().y),star_r,beating or best_score > 0,u)
    STYLE.text(self,Vector2(r.position.x+r.size.x*0.17,r.position.y+r.size.y*0.66),str(state["text"]),
        r.size.y*0.36,col,HORIZONTAL_ALIGNMENT_LEFT,r.size.x*0.80,true)

func _draw_chain(r: Rect2, u: float) -> void:
    if chain_alpha <= 0.01:
        return
    var a: float = chain_alpha
    var big: float = r.size.y*0.62
    var txt: String = "+"+_score_string(drift_score)
    var mult: String = "x%.1f" % combo
    var w_txt: float = STYLE.text_width(txt,big)
    var w_mult: float = STYLE.text_width(mult,big*0.45)
    var x: float = r.get_center().x-(w_txt+w_mult+r.size.y*0.15)*0.5
    var base: float = r.position.y+r.size.y*0.70
    STYLE.text(self,Vector2(x,base),txt,big,Color(1,1,1,a))
    var mc: Color = STYLE.PINK_SOFT
    mc.a = a
    STYLE.text(self,Vector2(x+w_txt+r.size.y*0.15,base),mult,big*0.45,mc)
    STYLE.text(self,Vector2(r.position.x,r.position.y+r.size.y*0.02),"DRIFT",r.size.y*0.20,
        Color(STYLE.MUTED.r,STYLE.MUTED.g,STYLE.MUTED.b,a),HORIZONTAL_ALIGNMENT_CENTER,r.size.x,false)

# --------------------------------------------------------------- callouts

## Callouts sit just above the car so they can be read without looking away;
## clamped below the chain readout and above the controls.
func callout_anchor(m: Dictionary, s: Vector2) -> Vector2:
    if car_screen.x < 0.0:
        return Vector2(m["callout"])
    var lo: float = Rect2(m["score"]).end.y+minf(s.x,s.y)*0.20
    # Keep the newest line clear of the speedometer on the left.
    var hi: float = Vector2(m["gauge_centre"]).y-float(m["gauge_radius"])-minf(s.x,s.y)*0.02
    var y: float = clampf(car_screen.y-minf(s.x,s.y)*0.13,lo,maxf(lo,hi))
    return Vector2(s.x*0.5,y)

func _draw_callouts(anchor: Vector2, s: Vector2, u: float) -> void:
    var size: float = minf(s.x,s.y)*0.062
    var y: float = anchor.y
    # Newest nearest the car, at most three stacked upwards.
    for k in range(score_events.size()-1,maxi(-1,score_events.size()-4),-1):
        var e: Dictionary = score_events[k]
        var age: float = float(e.get("age",0.0))
        var alpha: float = clampf(1.6-age,0.0,1.0)
        var pop: float = 1.0+0.25*clampf(1.0-age*6.0,0.0,1.0)
        var txt: String = str(e.get("text",""))
        var bad: bool = txt.contains("LOST")
        var col: Color = Color(1.0,0.42,0.42) if bad else (STYLE.GOLD if txt.begins_with("BANKED") else STYLE.PINK_SOFT)
        col.a = alpha
        var px: float = size*pop
        var pos := Vector2(0.0,y-age*18.0*u)
        # Dark outline for readability over kerbs, sky and grass.
        for o in [Vector2(-2,0),Vector2(2,0),Vector2(0,-2),Vector2(0,2)]:
            draw_string(STYLE.BOLD,pos+o*u,txt,HORIZONTAL_ALIGNMENT_CENTER,s.x,int(px),Color(0,0,0,0.65*alpha))
        draw_string(STYLE.BOLD,pos,txt,HORIZONTAL_ALIGNMENT_CENTER,s.x,int(px),col)
        y -= size*1.35

# ----------------------------------------------------------- speedometer

const GAUGE_MAX_KMH: float = 200.0
const GAUGE_START: float = PI*0.75      # 135 degrees (bottom-left)
const GAUGE_SWEEP: float = PI*1.5       # 270 degree dial

func _draw_gauge(c: Vector2, r: float, u: float) -> void:
    draw_circle(c,r*1.04,Color(0,0,0,0.35))
    var face := PackedVector2Array()
    var cols := PackedColorArray()
    for k in range(48):
        var t: float = TAU*float(k)/48.0
        face.append(c+Vector2(cos(t),sin(t))*r)
        cols.append(STYLE.GLASS_TOP.lerp(STYLE.GLASS_BOTTOM,clampf((sin(t)+1.0)*0.5,0.0,1.0)))
    draw_polygon(face,cols)
    draw_arc(c,r,0.0,TAU,64,STYLE.EDGE,1.6*u,true)
    # Track and live arc.
    draw_arc(c,r*0.86,GAUGE_START,GAUGE_START+GAUGE_SWEEP,72,Color(0.22,0.22,0.27,0.95),r*0.07,true)
    var f: float = clampf(speed/GAUGE_MAX_KMH,0.0,1.0)
    if f > 0.003:
        var col: Color = STYLE.PINK
        draw_arc(c,r*0.86,GAUGE_START,GAUGE_START+GAUGE_SWEEP*f,maxi(4,int(72*f)),
            Color(col.r,col.g,col.b,0.25),r*0.15,true)
        draw_arc(c,r*0.86,GAUGE_START,GAUGE_START+GAUGE_SWEEP*f,maxi(4,int(72*f)),col,r*0.07,true)
    # Ticks every 20 km/h, labels every 40.
    for k in range(11):
        var t2: float = GAUGE_START+GAUGE_SWEEP*float(k)/10.0
        var dir := Vector2(cos(t2),sin(t2))
        var major: bool = k%2 == 0
        draw_line(c+dir*r*(0.68 if major else 0.72),c+dir*r*0.76,
            STYLE.WHITE if major else STYLE.DIM,(2.2 if major else 1.4)*u,true)
        if major and k > 0 and k < 10:
            STYLE.text(self,c+dir*r*0.56+Vector2(-r*0.2,r*0.05),str(k*20),r*0.11,STYLE.DIM,
                HORIZONTAL_ALIGNMENT_CENTER,r*0.4,false)
    # Needle.
    var tn: float = GAUGE_START+GAUGE_SWEEP*f
    var nd := Vector2(cos(tn),sin(tn))
    draw_line(c-nd*r*0.10,c+nd*r*0.80,Color(0,0,0,0.5),5.0*u,true)
    draw_line(c-nd*r*0.10,c+nd*r*0.80,STYLE.WHITE,2.8*u,true)
    draw_circle(c,r*0.07,STYLE.PINK)
    # Digital readout.
    var number: String = ("R " if reversing else "")+str(int(speed))
    STYLE.text(self,Vector2(c.x-r,c.y+r*0.40),number,r*0.36,STYLE.WHITE,HORIZONTAL_ALIGNMENT_CENTER,r*2.0)
    STYLE.text(self,Vector2(c.x-r,c.y+r*0.62),"KM/H",r*0.13,STYLE.MUTED,HORIZONTAL_ALIGNMENT_CENTER,r*2.0,false)

func _draw_angle(r: Rect2, u: float) -> void:
    STYLE.panel(self,r,u,10.0,STYLE.SKEW,true,0.6)
    STYLE.text(self,Vector2(r.position.x,r.position.y+r.size.y*0.70),
        "%d°" % int(round(absf(drift_degrees))),r.size.y*0.55,STYLE.WHITE,
        HORIZONTAL_ALIGNMENT_CENTER,r.size.x)

# --------------------------------------------------------------- helpers

func _score_string(value: int) -> String:
    var digits: String = str(value)
    var end: String = ""
    while digits.length()>3:
        end = ","+digits.substr(digits.length()-3,3)+end
        digits = digits.substr(0,digits.length()-3)
    return digits+end

func _time_string(seconds: float) -> String:
    return STYLE.time_string(seconds)
