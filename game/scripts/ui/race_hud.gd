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

## NITRO WHEELZ PARK (issue #27): no lap, no score, no minimap, no callouts - only the
## speedometer and the drift angle; the lesson card (park_guide.gd) uses the header.
var park_mode: bool = false
var race_time: float = 0.0
var current_lap_time: float = 0.0
var last_lap_time: float = -1.0
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
## Issue #18: false closing segment on open (point-to-point) routes. True =
## circuit (the outline and the arc length wrap from the last point to the
## first); false = open route (no closure, no wrap, START and FINISH markers).
var closed_loop: bool = true
## Open routes: where the start / finish lines sit along the route (0..1 of
## the arc length; same numbers the race uses for `track_progress`).
var start_progress: float = 0.0
var finish_progress: float = 1.0
var car_world_position: Vector2 = Vector2.ZERO
var track_progress: float = 0.0
var target_time: float = 0.0
var event_cue: String=""
var best_score: int = -1        # local best on this track, -1 = none yet
## v0.1.32: this track's star thresholds (points); the pill shows the next
## star to earn, then the personal best once every star is reached.
var star_tiers: Array[int] = []
var car_screen: Vector2 = Vector2(-1,-1)  # car on screen; callouts pop above it
var bank_progress: float = 0.0  # 0..1 while a finished combo waits to bank
var _last_score: int = 0
var _score_pulse: float = 0.0
var _flights: Array[Dictionary] = []   # banked combos flying into the score
var score_events: Array[Dictionary] = []

var chain_alpha: float = 0.0
var _outline_cache: PackedVector2Array = PackedVector2Array()
var _outline_rect: Rect2 = Rect2()
var _outline_sig: Array = []        # what the cached outline was built from
var _map_scale: float = 1.0
var _map_mid: Vector2 = Vector2.ZERO
var _map_rot: float = 0.0
var _cum: PackedFloat32Array = PackedFloat32Array()
var _cum_points: int = -1
var _cum_closed: bool = true
var _shown_chain: int = 0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    STYLE.ensure_settings()

func _process(delta: float) -> void:
    if drift_score > 0:
        _shown_chain = drift_score
    # A combo was banked: fly its points from the COMBO box into the score.
    if score > _last_score:
        _flights.append({"amount":score-_last_score,"t":0.0})
        _score_pulse = 1.0
    _last_score = score
    for f in _flights:
        f["t"] = float(f["t"])+delta/0.75
    _flights = _flights.filter(func(f: Dictionary) -> bool: return float(f["t"]) < 1.0)
    _score_pulse = maxf(0.0,_score_pulse-delta*1.6)
    var target: float = 1.0 if drift_score > 0 else 0.0
    chain_alpha = move_toward(chain_alpha,target,delta*(6.0 if target > chain_alpha else 2.5))
    queue_redraw()

func overall_progress() -> float:
    return clampf((float(lap-1)+track_progress)/float(maxi(lap_limit,1)),0.0,1.0)

## Text of the centred chase pill: who/what the player is chasing.
func chase_label() -> Dictionary:
    if event_cue!="":
        return {"text":event_cue,"beating":false}
    var running: int = score+int(round(float(drift_score)*combo))
    if not star_tiers.is_empty():
        for i in range(star_tiers.size()):
            if running < star_tiers[i]:
                return {"text":"NEXT ★%d  %s" % [i+1,_score_string(star_tiers[i])],"beating":false}
        if best_score > running:
            return {"text":"CHASING  "+_score_string(best_score),"beating":false}
        return {"text":"ALL STARS  "+_score_string(running),"beating":true}
    if best_score <= 0:
        return {"text":"FIRST RUN","beating":false}
    if running > best_score:
        return {"text":"NEW BEST  "+_score_string(running),"beating":true}
    return {"text":"CHASING  "+_score_string(best_score),"beating":false}

## Font size of every HUD text for a layout. Drawing and the layout test
## use the same numbers. v0.1.21: the small labels (BANKED SCORE, COMBO,
## PTS TO BANK, track name) grew ~35-45% so they read on a phone.
static func text_sizes(m: Dictionary, track_title: String = "SHIN-KAWA DRIFT PARK", lap_txt: String = "LAP 3/3",
        score_txt: String = "999,999") -> Dictionary:
    var hh: float = Rect2(m["header"]).size.y
    var sc: float = Rect2(m["score"]).size.y
    var lap_r: Rect2 = m["lap"]
    var lap_split: bool = bool(m.get("portrait",false))
    var lap_value: String = lap_txt.trim_prefix("LAP ") if lap_split else lap_txt
    return {
        # Portrait: "LAP" label over the big "1/3" beside the minimap.
        "lap":STYLE.fit_size(lap_value,hh*0.17,lap_r.size.x),
        "lap_label":STYLE.fit_size("LAP",hh*0.10,lap_r.size.x),
        "banked_label":STYLE.fit_size("BANKED SCORE",hh*0.115,Rect2(m["total_label"]).size.x,false),
        "score":STYLE.fit_size(score_txt,hh*0.31,Rect2(m["total"]).size.x),
        "clock":STYLE.fit_size("00:00.00",hh*0.14,Rect2(m["total"]).size.x,false),
        "name":STYLE.fit_size(track_title.to_upper(),hh*0.15,Rect2(m["name"]).size.x),
        "chase":Rect2(m["chase"]).size.y*0.50,
        "combo_label":sc*0.19,
        "combo_value":sc*0.44,
        "to_bank":sc*0.17}

func _draw() -> void:
    var s: Vector2 = get_viewport_rect().size
    var profile: String = STYLE.platform_profile()
    var m: Dictionary = STYLE.metrics(s,profile)
    var u: float = float(m["unit"])
    if profile != "mobile":
        _draw_desktop(m,s,u)
        return
    if park_mode:
        _draw_gauge(Vector2(m["gauge_centre"]),float(m["gauge_radius"]),u)
        _draw_angle(Rect2(m["angle"]),u)
        return
    _draw_header(m,u)
    _draw_chain(Rect2(m["score"]),u)
    _draw_gauge(Vector2(m["gauge_centre"]),float(m["gauge_radius"]),u)
    _draw_angle(Rect2(m["angle"]),u)
    _draw_callouts(callout_anchor(m,s),s,u)
    _draw_flights(m,u)

## Desktop/Web: three restrained, translucent instruments, no full-width
## mobile strip and no big circular dial. Scoring, route and banked data still
## come from the unmodified HUD state and scoring pipeline.
func _draw_desktop(m: Dictionary, s: Vector2, u: float) -> void:
    if not park_mode:
        var h: Rect2 = m["header"]
        var map_r: Rect2 = m["map"]
        var nm: Rect2 = m["name"]
        var lp: Rect2 = m["lap"]
        var chase_r: Rect2 = m["chase"]
        var times_r: Rect2 = m["lap_times"]
        _desktop_glass(h,u)
        _minimap(map_r,u*0.80)
        var track_txt: String = track_name.to_upper()
        STYLE.text(self,Vector2(nm.position.x,nm.end.y-2.0),track_txt,
            STYLE.fit_size(track_txt,15.0*u,nm.size.x),STYLE.WHITE,
            HORIZONTAL_ALIGNMENT_LEFT,nm.size.x)
        var lap_txt: String = "LAP %d/%d" % [lap,lap_limit]
        STYLE.text(self,Vector2(lp.position.x,lp.end.y-1.0),lap_txt,
            STYLE.fit_size(lap_txt,17.0*u,lp.size.x),STYLE.WHITE,
            HORIZONTAL_ALIGNMENT_LEFT,lp.size.x)
        var times := STYLE.time_string(current_lap_time)
        if last_lap_time >= 0.0:
            times += "  /  LAST " + STYLE.time_string(last_lap_time)
        STYLE.text(self,Vector2(times_r.position.x,times_r.end.y-1.0),times,
            STYLE.fit_size(times,11.0*u,times_r.size.x),STYLE.MUTED,
            HORIZONTAL_ALIGNMENT_LEFT,times_r.size.x,false)
        var chase_txt: String = str(chase_label()["text"])
        STYLE.text(self,Vector2(chase_r.position.x,chase_r.end.y-1.0),chase_txt,
            STYLE.fit_size(chase_txt,11.5*u,chase_r.size.x),STYLE.GOLD,
            HORIZONTAL_ALIGNMENT_LEFT,chase_r.size.x,false)
        _draw_lap_line(h)
        var bank_r: Rect2 = m["bank_panel"]
        var lab: Rect2 = m["total_label"]
        var val: Rect2 = m["total"]
        _desktop_glass(bank_r,u)
        STYLE.text(self,Vector2(lab.position.x,lab.end.y-1.0),"BANKED SCORE",
            12.5*u,STYLE.MUTED,HORIZONTAL_ALIGNMENT_LEFT,lab.size.x,false)
        var bank_txt: String = _score_string(score)
        STYLE.text(self,Vector2(val.position.x,val.position.y+val.size.y*0.56),bank_txt,
            STYLE.fit_size(bank_txt,31.0*u,val.size.x),STYLE.WHITE.lerp(STYLE.GOLD,_score_pulse),
            HORIZONTAL_ALIGNMENT_LEFT,val.size.x)
        STYLE.text(self,Vector2(val.position.x,val.end.y-2.0),STYLE.time_string(race_time),
            11.5*u,STYLE.MUTED,HORIZONTAL_ALIGNMENT_LEFT,val.size.x,false)
        _draw_chain(Rect2(m["score"]),u)
        _draw_callouts(callout_anchor(m,s),s,u)
        _draw_flights(m,u)
    _draw_desktop_telemetry(Rect2(m["speed"]),u)

## Keep the approved Exo 2 / dark-glass / accent design, with reduced desktop
## opacity and a hairline edge instead of mobile-sized chrome and glow.
func _desktop_glass(r: Rect2, u: float) -> void:
    var pts: PackedVector2Array = STYLE.shape(r,9.0*u,STYLE.SKEW*0.45)
    draw_colored_polygon(pts,Color(0.018,0.020,0.032,0.61))
    var edge: PackedVector2Array = pts.duplicate()
    edge.append(pts[0])
    draw_polyline(edge,Color(0.88,0.89,0.95,0.27),maxf(1.0,u),true)
    draw_line(Vector2(r.position.x+10.0,r.end.y-2.0),
        Vector2(r.end.x-10.0,r.end.y-2.0),
        Color(STYLE.PINK.r,STYLE.PINK.g,STYLE.PINK.b,0.55),maxf(1.0,1.3*u),true)

func _draw_desktop_telemetry(r: Rect2, u: float) -> void:
    _desktop_glass(r,u)
    var inset: float = 11.0
    var number: String = ("R " if reversing else "")+str(int(speed))
    STYLE.text(self,Vector2(r.position.x+inset,r.position.y+r.size.y*0.62),number,
        STYLE.fit_size(number,30.0*u,r.size.x*0.60),STYLE.WHITE)
    STYLE.text(self,Vector2(r.position.x+inset,r.end.y-9.0),"KM/H",
        11.0*u,STYLE.MUTED,HORIZONTAL_ALIGNMENT_LEFT,-1.0,false)
    var angle_txt: String = "%d°" % roundi(absf(drift_degrees))
    STYLE.text(self,Vector2(r.position.x+r.size.x*0.62,r.position.y+r.size.y*0.63),
        angle_txt,STYLE.fit_size(angle_txt,20.0*u,r.size.x*0.33),
        STYLE.PINK_SOFT,HORIZONTAL_ALIGNMENT_LEFT,r.size.x*0.35)
    STYLE.text(self,Vector2(r.position.x+r.size.x*0.62,r.end.y-9.0),"DRIFT",
        9.5*u,STYLE.MUTED,HORIZONTAL_ALIGNMENT_LEFT,-1.0,false)

# ------------------------------------------------------------------ header

func _draw_header(m: Dictionary, u: float) -> void:
    var r: Rect2 = m["header"]
    var hh: float = r.size.y
    STYLE.panel(self,r,u,18.0,0.0,true,1.0)
    _minimap(Rect2(m["map"]),u)
    # Top band, beside the camera keep-out: LAP (left) and the score label.
    var lp: Rect2 = m["lap"]
    var lap_txt: String = "LAP %d/%d" % [lap,lap_limit]
    var sizes: Dictionary = text_sizes(m,track_name,lap_txt,_score_string(score))
    if bool(m["portrait"]):
        # Beside the minimap: small "LAP" over the big "1/3".
        STYLE.text(self,Vector2(lp.position.x,lp.position.y+lp.size.y*0.34),"LAP",float(sizes["lap_label"]),
            STYLE.MUTED,HORIZONTAL_ALIGNMENT_CENTER,lp.size.x,false)
        STYLE.text(self,Vector2(lp.position.x,lp.end.y-lp.size.y*0.04),"%d/%d" % [lap,lap_limit],
            float(sizes["lap"]),STYLE.WHITE,HORIZONTAL_ALIGNMENT_CENTER,lp.size.x,true)
    else:
        STYLE.text(self,Vector2(lp.position.x,lp.end.y-lp.size.y*0.16),lap_txt,
            float(sizes["lap"]),STYLE.WHITE,HORIZONTAL_ALIGNMENT_LEFT,-1.0,true)
    var tl: Rect2 = m["total_label"]
    STYLE.text(self,Vector2(tl.position.x,tl.end.y-tl.size.y*0.18),"BANKED SCORE",float(sizes["banked_label"]),STYLE.MUTED,
        HORIZONTAL_ALIGNMENT_RIGHT,tl.size.x,false)
    # Right: the most important number, clock under it.
    var st: Rect2 = m["total"]
    var score_txt: String = _score_string(score)
    var pulse: float = _score_pulse*_score_pulse
    STYLE.text(self,Vector2(st.position.x,st.position.y+st.size.y*0.56),score_txt,
        STYLE.fit_size(score_txt,float(sizes["score"])*(1.0+0.10*pulse),st.size.x),STYLE.WHITE.lerp(STYLE.GOLD,pulse),
        HORIZONTAL_ALIGNMENT_RIGHT,st.size.x)
    STYLE.text(self,Vector2(st.position.x,st.end.y-st.size.y*0.02),STYLE.time_string(race_time),float(sizes["clock"]),
        STYLE.MUTED,HORIZONTAL_ALIGNMENT_RIGHT,st.size.x,false)
    # Centre, under the keep-out: track name (light) and the chase pill.
    var nm: Rect2 = m["name"]
    var name_txt: String = track_name.to_upper()
    STYLE.text(self,Vector2(nm.position.x,nm.end.y-nm.size.y*0.16),name_txt,
        float(sizes["name"]),STYLE.WHITE.lerp(STYLE.MUTED,0.35),HORIZONTAL_ALIGNMENT_CENTER,nm.size.x,true)
    _draw_chase(Rect2(m["chase"]),u)
    _draw_lap_line(r)

## Thin line across the whole panel, split into one segment per lap:
## completed laps full, the current lap fills with progress.
func _draw_lap_line(r: Rect2) -> void:
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

## Track outline turned so its long side runs horizontally (largest fit in
## the wide map box); the car dot is placed ON the white line from the
## lap progress, so it never wanders off it.
func _minimap(rect: Rect2, u: float) -> void:
    if track_points.size() < 8:
        return
    if _outline_rect != rect or _outline_cache.is_empty() or _outline_sig != _signature():
        _rebuild_outline(rect)
    draw_polyline(_outline_cache,Color(1,1,1,0.10),9.0*u,true)
    draw_polyline(_outline_cache,STYLE.WHITE,3.0*u,true)
    if closed_loop:
        # Circuit: the start line sits on the first point; the tangent is the
        # neighbour on either side (the route wraps).
        var start_dot: Vector2 = _map_point(track_points[0],rect)
        var tangent: Vector2 = (_map_point(track_points[1],rect)-_map_point(track_points[track_points.size()-1],rect)).normalized()
        var across := Vector2(-tangent.y,tangent.x)*6.0*u
        draw_line(start_dot-across,start_dot+across,STYLE.WHITE,3.5*u,true)
    else:
        # Open route: a white START tick and a gold FINISH tick + ring on the
        # start / finish lines (never a wrapped tangent).
        _end_marker(rect,u,start_progress,STYLE.WHITE,false)
        _end_marker(rect,u,finish_progress,STYLE.GOLD,true)
    var dot: Vector2 = _map_point(point_at_progress(track_progress),rect)
    draw_circle(dot,9.0*u,Color(STYLE.PINK.r,STYLE.PINK.g,STYLE.PINK.b,0.28))
    draw_circle(dot,5.5*u,STYLE.PINK)
    draw_arc(dot,5.5*u,0.0,TAU,20,STYLE.WHITE,1.4*u,true)

func _map_point(p: Vector2, rect: Rect2) -> Vector2:
    return rect.get_center()+(p.rotated(-_map_rot)-_map_mid)*_map_scale

func _rebuild_outline(rect: Rect2) -> void:
    _outline_rect = rect
    var step: int = maxi(1,int(track_points.size()/140))
    var sub := PackedVector2Array()
    for i in range(0,track_points.size(),step):
        sub.append(track_points[i])
    # Open route: the sampling step may skip the real last point; the outline
    # (and the box it is fitted into) must end exactly on it.
    if not closed_loop and (track_points.size()-1) % step != 0:
        sub.append(track_points[track_points.size()-1])
    var best: float = -1.0
    for k in range(36):
        var ang: float = PI*float(k)/36.0
        var lo := Vector2(INF,INF)
        var hi := Vector2(-INF,-INF)
        for p in sub:
            var q: Vector2 = p.rotated(-ang)
            lo = Vector2(minf(lo.x,q.x),minf(lo.y,q.y))
            hi = Vector2(maxf(hi.x,q.x),maxf(hi.y,q.y))
        var box: Vector2 = hi-lo
        var sc: float = minf(rect.size.x*0.90/maxf(box.x,0.01),rect.size.y*0.88/maxf(box.y,0.01))
        # Keep the authored orientation unless turning is clearly bigger.
        if sc > best*1.04:
            best = sc
            _map_rot = ang
            _map_scale = sc
            _map_mid = (lo+hi)*0.5
    _outline_sig = _signature()
    _outline_cache = PackedVector2Array()
    for p in sub:
        _outline_cache.append(_map_point(p,rect))
    if closed_loop:
        _outline_cache.append(_outline_cache[0])   # open routes never close

## What the cached outline depends on: a new track, a changed number of points
## or a change of topology rebuilds it (not only a new map rectangle).
func _signature() -> Array:
    var n: int = track_points.size()
    return [n,closed_loop,track_points[0] if n > 0 else Vector2.ZERO,
        track_points[n-1] if n > 0 else Vector2.ZERO]

## START / FINISH tick of an open route at a fraction of its length.
func _end_marker(rect: Rect2, u: float, f: float, col: Color, ring: bool) -> void:
    var at: Vector2 = _map_point(point_at_progress(f),rect)
    var a: Vector2 = _map_point(point_at_progress(clampf(f-0.01,0.0,1.0)),rect)
    var b: Vector2 = _map_point(point_at_progress(clampf(f+0.01,0.0,1.0)),rect)
    var tangent: Vector2 = (b-a)
    tangent = tangent.normalized() if tangent.length() > 0.001 else Vector2.RIGHT
    var across := Vector2(-tangent.y,tangent.x)*6.0*u
    draw_line(at-across,at+across,col,3.5*u,true)
    if ring:
        draw_arc(at,7.5*u,0.0,TAU,20,col,1.6*u,true)

## Centreline point at a lap fraction (same arc length as the race uses).
## Circuit: wraps from the last point back to the first. Open route: only the
## real segments 0..n-2 count and the fraction is clamped to 0..1 (no wrap, no
## made-up last -> first distance).
func point_at_progress(f: float) -> Vector2:
    var n: int = track_points.size()
    if n == 0:
        return car_world_position
    if n == 1:
        return track_points[0]
    var segs: int = n if closed_loop else n-1
    if _cum_points != n or _cum_closed != closed_loop:
        _cum_points = n
        _cum_closed = closed_loop
        _cum = PackedFloat32Array()
        _cum.resize(segs+1)
        _cum[0] = 0.0
        for i in range(segs):
            _cum[i+1] = _cum[i]+track_points[i].distance_to(track_points[(i+1)%n])
    var total: float = _cum[segs]
    var target: float = (fposmod(f,1.0) if closed_loop else clampf(f,0.0,1.0))*total
    var i: int = clampi(_cum.bsearch(target)-1,0,segs-1)
    var seg: float = maxf(_cum[i+1]-_cum[i],0.0001)
    return track_points[i].lerp(track_points[(i+1)%n],clampf((target-_cum[i])/seg,0.0,1.0))

# ------------------------------------------------------- chase + live chain

## Chase line straight on the header glass (owner: no frame inside the
## header frame): star + FIRST RUN / CHASING best / BEATING best, centred.
func _draw_chase(r: Rect2, u: float) -> void:
    var state: Dictionary = chase_label()
    var beating: bool = bool(state["beating"])
    var col: Color = STYLE.GOLD if beating else STYLE.WHITE
    var star_r: float = r.size.y*0.26
    var txt: String = str(state["text"])
    var size: float = STYLE.fit_size(txt,r.size.y*0.50,r.size.x-star_r*3.0)
    var tw: float = STYLE.text_width(txt,size)
    var x0: float = r.get_center().x-(tw+star_r*2.6)*0.5
    if event_cue=="":
        STYLE.star(self,Vector2(x0+star_r,r.get_center().y),star_r,beating or best_score > 0,u)
    STYLE.text(self,Vector2(x0+star_r*2.6,r.position.y+r.size.y*0.70),txt,size,col,HORIZONTAL_ALIGNMENT_LEFT,-1.0,true)

## COMBO box: the running chain (raw points x multiplier) and what it will
## add to the BANKED SCORE. Banks when you straighten up; the bar shows the
## grace time before it banks. Only visible while a combo is running.
func _draw_chain(r: Rect2, u: float) -> void:
    if chain_alpha <= 0.01:
        return
    var a: float = chain_alpha
    var sz: Dictionary = text_sizes({"header":Rect2(),"score":r,"lap":Rect2(),"total_label":Rect2(),
        "total":Rect2(),"name":Rect2(),"chase":Rect2()})
    var big: float = float(sz["combo_value"])
    var txt: String = "+"+_score_string(_shown_chain)
    var mult: String = "×%.1f" % combo
    var to_bank: int = int(round(float(_shown_chain)*combo))
    var w_txt: float = STYLE.text_width(txt,big)
    var w_mult: float = STYLE.text_width(mult,big*0.55)
    var content: float = w_txt+w_mult+r.size.y*0.12
    var fw: float = clampf(content+r.size.y*0.9,r.size.x*0.55,r.size.x)
    var frame := Rect2(r.get_center().x-fw*0.5,r.position.y,fw,r.size.y)
    var pts: PackedVector2Array = STYLE.shape(frame,14.0*u,STYLE.SKEW)
    var cols := PackedColorArray()
    for p in pts:
        var t: float = clampf((p.y-frame.position.y)/frame.size.y,0.0,1.0)
        var g: Color = STYLE.GLASS_TOP.lerp(STYLE.GLASS_BOTTOM,t)
        g.a *= 0.66*a
        cols.append(g)
    draw_polygon(pts,cols)
    var outline: PackedVector2Array = pts.duplicate()
    outline.append(pts[0])
    draw_polyline(outline,Color(1,1,1,0.16*a),maxf(1.0,1.2*u),true)
    STYLE.glow_line(self,STYLE.glow_path(frame,14.0*u,STYLE.SKEW),
        Color(STYLE.PINK.r,STYLE.PINK.g,STYLE.PINK.b,0.75*a),1.8*u,0.8)
    var banking: bool = bank_progress > 0.001
    STYLE.text(self,Vector2(frame.position.x,frame.position.y+frame.size.y*0.20),
        "BANKING…" if banking else "COMBO",float(sz["combo_label"]),
        Color(STYLE.GOLD.r,STYLE.GOLD.g,STYLE.GOLD.b,a) if banking else Color(STYLE.MUTED.r,STYLE.MUTED.g,STYLE.MUTED.b,a),
        HORIZONTAL_ALIGNMENT_CENTER,frame.size.x,false)
    var x: float = frame.get_center().x-content*0.5
    var base: float = frame.position.y+frame.size.y*0.62
    STYLE.text(self,Vector2(x,base),txt,big,Color(1,1,1,a))
    var mc: Color = STYLE.PINK_SOFT
    mc.a = a
    STYLE.text(self,Vector2(x+w_txt+r.size.y*0.12,base),mult,big*0.55,mc)
    var gold := Color(STYLE.GOLD.r,STYLE.GOLD.g,STYLE.GOLD.b,a)
    STYLE.text(self,Vector2(frame.position.x,frame.position.y+frame.size.y*0.84),
        "= %s PTS TO BANK" % _score_string(to_bank),float(sz["to_bank"]),gold,HORIZONTAL_ALIGNMENT_CENTER,frame.size.x,false)
    if banking:
        var bar := Rect2(frame.position.x+frame.size.x*0.12,frame.end.y-r.size.y*0.09,frame.size.x*0.76,maxf(2.0,r.size.y*0.035))
        draw_rect(bar,Color(1,1,1,0.12*a))
        draw_rect(Rect2(bar.position,Vector2(bar.size.x*clampf(bank_progress,0.0,1.0),bar.size.y)),gold)

## Banked points travel from the COMBO box into the BANKED SCORE.
func _draw_flights(m: Dictionary, u: float) -> void:
    if _flights.is_empty():
        return
    var from: Vector2 = Rect2(m["score"]).get_center()
    var st: Rect2 = m["total"]
    var to: Vector2 = Vector2(st.end.x-st.size.x*0.35,st.position.y+st.size.y*0.35)
    var hh: float = Rect2(m["header"]).size.y
    for f in _flights:
        var t: float = float(f["t"])
        var e: float = 1.0-pow(1.0-t,3.0)
        var p: Vector2 = from.lerp(to,e)+Vector2(0,-sin(t*PI)*hh*0.25)
        var col: Color = STYLE.GOLD
        col.a = 1.0-pow(t,4.0)
        var txt: String = "+"+_score_string(int(f["amount"]))
        var size: float = hh*lerpf(0.26,0.14,e)
        STYLE.text(self,p-Vector2(STYLE.text_width(txt,size)*0.5,-size*0.35),txt,size,col)

# --------------------------------------------------------------- callouts

## Callouts sit just above the car so they can be read without looking away;
## clamped below the chain readout and above the controls.
func callout_anchor(m: Dictionary, s: Vector2) -> Vector2:
    if car_screen.x < 0.0:
        return Vector2(m["callout"])
    var lo: float = Rect2(m["score"]).end.y+minf(s.x,s.y)*0.12
    # Keep the newest line clear of the speedometer on the left.
    var hi: float = Vector2(m["gauge_centre"]).y-float(m["gauge_radius"])-minf(s.x,s.y)*0.02
    # Owner: about 20% higher on screen than just above the roof.
    var y: float = (car_screen.y-minf(s.x,s.y)*0.13)*0.80
    y = clampf(y,lo,maxf(lo,hi))
    return Vector2(s.x*0.5,y)

func _draw_callouts(anchor: Vector2, s: Vector2, u: float) -> void:
    var size: float = minf(s.x,s.y)*0.062
    if STYLE.platform_profile() != "mobile":
        size = clampf(size,19.0,30.0)
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
    # Accent neon on the lower-right edge, like every other panel.
    STYLE.glow_arc(self,c,r,-PI*0.12,PI*0.62,STYLE.PINK,2.2*u,1.0)
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
