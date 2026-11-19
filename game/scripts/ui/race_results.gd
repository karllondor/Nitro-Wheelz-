extends Control
class_name NitroRaceResults
## Full-screen finish screen + local-only history (no network leaderboard,
## no fabricated ranks). Redesigned v0.1.16 for owner feedback ("hard to
## read, you don't know where to look"): one clear hierarchy, top to bottom
##   1. track + FINISHED / NEW BEST + stars
##   2. hero card: DRIFT POINTS (biggest number) and the change vs your best,
##      then TIME / RANK / BEST CHAIN
##   3. LAPS: time + points per lap with bars, best lap marked
##   4. drift stat chips
##   5. YOUR TOP RUNS on this track (by points), this run highlighted
##   6. RESTART / GARAGE buttons
## Everything is drawn with the HUD style (glass panels, accent neon).
const STORAGE: String = "user://nitro_local_runs.json"
const STYLE = preload("res://scripts/ui/hud_style.gd")
const GOOD := Color(0.36,0.95,0.58)
const BAD := Color(1.0,0.45,0.45)
const SILVER := Color(0.80,0.83,0.90)
const BRONZE := Color(0.86,0.55,0.30)

var replay: Callable
var garage: Callable
var data: Dictionary = {}
var canvas: Control
var buttons: Array[Button] = []

## Stars reward DRIFT QUALITY, not lap time (v0.1.17, owner audit): the
## thresholds scale with the distance driven (3 laps x track length), so a
## longer circuit needs proportionally more points. Provisional rates in
## points per metre, calibrated on the owner's first local runs
## (Sweepers best 7,259 pts -> 3 stars; 1,407 pts -> no star).
const STAR_RATES: Array[float] = [2.0,4.5,7.5]
const LAPS: int = 3

static func star_tiers(length_m: float) -> Array[int]:
    var tiers: Array[int] = []
    for rate in STAR_RATES:
        tiers.append(int(round(maxf(length_m,50.0)*float(LAPS)*rate/50.0))*50)
    return tiers

static func star_count(score: int, length_m: float) -> int:
    var count: int = 0
    for tier in star_tiers(length_m):
        if score >= tier:
            count += 1
    return count

static func read_runs() -> Array:
    if not FileAccess.file_exists(STORAGE):
        return []
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(STORAGE))
    if raw is Array:
        return raw
    return []

static func save_run(track_id: String,seconds: float,score: int,stars: int,
        laps: Array = [],date: String = "") -> bool:
    var runs: Array = read_runs()
    var record: Dictionary = {
        "track_id":track_id,
        "seconds":snappedf(seconds,0.01),
        "score":score,
        "stars":stars,
        "date":date if not date.is_empty() else Time.get_datetime_string_from_system()
    }
    if not laps.is_empty():
        record["laps"] = laps
    runs.append(record)
    if runs.size() > 250:
        runs.pop_front()
    var f: FileAccess = FileAccess.open(STORAGE,FileAccess.WRITE)
    if f == null:
        return false
    f.store_string(JSON.stringify(runs,"  "))
    f.close()
    return true

static func track_runs(track_id: String) -> Array:
    var matches: Array = []
    for item in read_runs():
        if item is Dictionary and str(item.get("track_id","")) == track_id and float(item.get("seconds",-1.0)) > 0.0:
            matches.append(item)
    return matches

## Fastest first (kept for the time-based stars and older tests).
static func sorted_local(track_id: String) -> Array:
    var entries: Array = track_runs(track_id)
    entries.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
        return float(a["seconds"]) < float(b["seconds"]))
    return entries

## Drift ranking: most points first, faster time breaks ties.
static func sorted_by_score(track_id: String) -> Array:
    var entries: Array = track_runs(track_id)
    entries.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
        if int(a["score"]) != int(b["score"]):
            return int(a["score"]) > int(b["score"])
        return float(a["seconds"]) < float(b["seconds"]))
    return entries

static func short_date(timestamp: String) -> String:
    # Stored ISO timestamp is preserved for history; display only day + time.
    if timestamp.length() < 16:
        return timestamp
    var month_names: Array[String] = ["Jan","Feb","Mar","Apr","May","Jun",
        "Jul","Aug","Sep","Oct","Nov","Dec"]
    var month_index: int = int(timestamp.substr(5,2))-1
    if month_index < 0 or month_index >= 12:
        return timestamp.substr(0,16)
    return "%d %s  %s" % [int(timestamp.substr(8,2)),month_names[month_index],
        timestamp.substr(11,5)]

static func clock(seconds: float) -> String:
    var mins: int = int(seconds/60.0)
    return "%d:%05.2f" % [mins,fmod(seconds,60.0)]

## Compact star threshold label: 6,650 -> "6.6K".
static func _short_points(value: int) -> String:
    if value >= 1000:
        return "%.1fK" % (float(value)/1000.0)
    return str(value)

static func points(value: int) -> String:
    var digits: String = str(absi(value))
    var out: String = ""
    while digits.length() > 3:
        out = ","+digits.substr(digits.length()-3,3)+out
        digits = digits.substr(0,digits.length()-3)
    return ("-" if value < 0 else "")+digits+out

## Everything the screen shows, computed once (also used by tests).
static func summarize(track_id: String,track_name: String,seconds: float,score: int,
        stars: int,previous: Array,current: Array,stamp: String,stats: Dictionary) -> Dictionary:
    var prior_best_score: int = -1
    var prior_best_time: float = INF
    for run in previous:
        prior_best_score = maxi(prior_best_score,int(run["score"]))
        prior_best_time = minf(prior_best_time,float(run["seconds"]))
    var ranked: Array = current.duplicate()
    ranked.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
        if int(a["score"]) != int(b["score"]):
            return int(a["score"]) > int(b["score"])
        return float(a["seconds"]) < float(b["seconds"]))
    var rank: int = -1
    for i in range(ranked.size()):
        var r: Dictionary = ranked[i]
        if str(r.get("date","")) == stamp and int(r["score"]) == score \
                and absf(float(r["seconds"])-snappedf(seconds,0.01)) < 0.005:
            rank = i+1
            break
    var laps: Array = stats.get("laps",[])
    var best_lap: int = -1
    for i in range(laps.size()):
        if best_lap < 0 or float(laps[i]["time"]) < float(laps[best_lap]["time"]):
            best_lap = i
    return {
        "track_id":track_id,"track_name":track_name,"seconds":seconds,"score":score,
        "stars":stars,"first_run":previous.is_empty(),
        "prior_best_score":prior_best_score,"prior_best_time":prior_best_time,
        "new_best":previous.is_empty() or score > prior_best_score,
        "faster":seconds < prior_best_time,
        "rank":rank,"runs":ranked.size(),"top":ranked.slice(0,5),
        "this_run":{"seconds":snappedf(seconds,0.01),"score":score,"stars":stars,"date":stamp},
        "laps":laps,"best_lap":best_lap,"stats":stats
    }

func show_race(track_id: String,track_name: String,seconds: float,score: int,
        target: float,on_replay: Callable,on_garage: Callable,stats: Dictionary = {}) -> void:
    replay = on_replay
    garage = on_garage
    STYLE.ensure_settings()
    mouse_filter = Control.MOUSE_FILTER_STOP
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var length_m: float = float(stats.get("length_m",0.0))
    if length_m <= 0.0:
        length_m = maxf(target*14.0/3.0,100.0)  # legacy callers: time target
    var stars: int = star_count(score,length_m)
    var previous: Array = track_runs(track_id)
    var stamp: String = Time.get_datetime_string_from_system()
    var stored: bool = save_run(track_id,seconds,score,stars,stats.get("laps",[]),stamp)
    data = summarize(track_id,track_name,seconds,score,stars,previous,track_runs(track_id),stamp,stats)
    data["tiers"] = star_tiers(length_m)
    # Older stored runs were starred by time: re-star every row by points.
    for run in data["top"]:
        run["stars"] = star_count(int(run["score"]),length_m)
    data["stored"] = stored
    var s: Vector2 = get_viewport_rect().size
    var sc: float = clampf(s.x/720.0,0.85,1.85)
    theme = STYLE.screen_theme(sc)
    var shade := ColorRect.new()
    shade.color = Color(0.008,0.010,0.018,0.96)
    shade.mouse_filter = Control.MOUSE_FILTER_STOP
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(shade)
    canvas = Control.new()
    canvas.name = "Results board"
    canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
    canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    canvas.draw.connect(_draw_board)
    add_child(canvas)
    var lay: Dictionary = layout(s)
    var on_edit: Callable = stats.get("on_edit",Callable())
    if on_edit.is_valid():
        # Player track: RESTART | EDIT TRACK | GARAGE / MENU (editor loop).
        var rr: Rect2 = lay["restart"]
        var gap: float = rr.size.x*0.035
        var w1: float = rr.size.x*0.60
        _action("RESTART",Rect2(rr.position,Vector2(w1,rr.size.y)),replay,float(lay["u"]),true)
        _action("EDIT TRACK",Rect2(rr.position+Vector2(w1+gap,0.0),Vector2(rr.size.x-w1-gap,rr.size.y)),
            on_edit,float(lay["u"]),false,0.68)
    else:
        _action("RESTART",Rect2(lay["restart"]),replay,float(lay["u"]),true)
    _action("GARAGE / MENU",Rect2(lay["menu"]),garage,float(lay["u"]),false)

func _action(label: String,rect: Rect2,callback: Callable,u: float,primary: bool,font_scale: float = 1.0) -> void:
    var button := Button.new()
    button.text = label
    button.name = label
    button.position = rect.position
    button.size = rect.size
    button.add_theme_font_size_override("font_size",int(26.0*u*font_scale))
    STYLE.style_button(button,u,primary)
    button.pressed.connect(callback)
    add_child(button)
    button.size = rect.size
    buttons.append(button)

# --------------------------------------------------------------- layout

## Section rectangles. Portrait: one column, scaled down uniformly when the
## screen is short. Landscape: summary left, laps + top runs right.
func layout(s: Vector2) -> Dictionary:
    var portrait: bool = s.y >= s.x
    var lay: Dictionary = {}
    if portrait:
        # Designed on a 1000-unit wide column, 2140 units tall.
        var k: float = minf(s.x*0.94/1000.0,s.y*0.97/2140.0)
        var x0: float = (s.x-1000.0*k)*0.5
        var y0: float = maxf((s.y-2140.0*k)*0.5,s.y*0.02)
        var R := func(x: float,y: float,w: float,h: float) -> Rect2:
            return Rect2(x0+x*k,y0+y*k,w*k,h*k)
        lay = {"title":R.call(0,40,1000,150),"hero":R.call(0,215,1000,470),
            "laps":R.call(0,725,1000,420),"chips":R.call(0,1175,1000,130),
            "top":R.call(0,1345,1000,570),"restart":R.call(0,1950,580,150),
            "menu":R.call(610,1950,390,150),"u":k*1000.0/700.0,"k":k}
    else:
        var k2: float = minf(s.x*0.46/1000.0,s.y*0.93/1080.0)
        var col: float = 1000.0*k2
        var gap: float = s.x*0.03
        var xl: float = (s.x-2.0*col-gap)*0.5
        var xr: float = xl+col+gap
        var yt: float = (s.y-1080.0*k2)*0.5
        var L := func(x: float,y: float,w: float,h: float) -> Rect2:
            return Rect2(xl+x*k2,yt+y*k2,w*k2,h*k2)
        var Rr := func(x: float,y: float,w: float,h: float) -> Rect2:
            return Rect2(xr+x*k2,yt+y*k2,w*k2,h*k2)
        lay = {"title":L.call(0,0,1000,150),"hero":L.call(0,175,1000,470),
            "chips":L.call(0,680,1000,130),"restart":L.call(0,860,580,150),
            "menu":L.call(610,860,390,150),
            "laps":Rr.call(0,0,1000,420),"top":Rr.call(0,450,1000,570),
            "u":k2*1000.0/700.0,"k":k2}
    return lay

# ---------------------------------------------------------------- drawing

func _draw_board() -> void:
    if data.is_empty():
        return
    var s: Vector2 = get_viewport_rect().size
    var lay: Dictionary = layout(s)
    var k: float = float(lay["k"])
    var u: float = float(lay["u"])
    _title(Rect2(lay["title"]),k,u)
    _hero(Rect2(lay["hero"]),k,u)
    _laps(Rect2(lay["laps"]),k,u)
    _chips(Rect2(lay["chips"]),k,u)
    _top_runs(Rect2(lay["top"]),k,u)
    var foot: String = "SAVED ON THIS DEVICE ONLY  •  STARS = DRIFT POINTS  •  v"+str(
        ProjectSettings.get_setting("application/config/version","?"))
    if not bool(data.get("stored",true)):
        foot = "WARNING: THIS RUN COULD NOT BE SAVED ON THIS DEVICE"
    var menu: Rect2 = lay["menu"]
    STYLE.text(canvas,Vector2(Rect2(lay["restart"]).position.x,menu.end.y+34.0*k),foot,22.0*k,
        STYLE.DIM if bool(data.get("stored",true)) else BAD,HORIZONTAL_ALIGNMENT_CENTER,
        menu.end.x-Rect2(lay["restart"]).position.x,false)

func _title(r: Rect2, k: float, u: float) -> void:
    var c: Control = canvas
    STYLE.text(c,Vector2(r.position.x,r.position.y+38.0*k),
        str(data["track_name"]).to_upper()+"  •  3 LAPS",30.0*k,STYLE.MUTED,HORIZONTAL_ALIGNMENT_LEFT,r.size.x*0.62,false)
    var headline: String = "NEW BEST!" if bool(data["new_best"]) and not bool(data["first_run"]) else (
        "FIRST RUN" if bool(data["first_run"]) else "FINISHED")
    STYLE.text(c,Vector2(r.position.x,r.position.y+122.0*k),headline,78.0*k,
        STYLE.GOLD if headline == "NEW BEST!" else STYLE.WHITE)
    var stars: int = int(data["stars"])
    var tiers: Array = data.get("tiers",[])
    for i in range(3):
        var sc := Vector2(r.end.x-(3-i)*92.0*k+40.0*k,r.position.y+72.0*k)
        STYLE.star(c,sc,38.0*k,i < stars,u)
        if i < tiers.size():
            STYLE.text(c,Vector2(sc.x-46.0*k,sc.y+68.0*k),_short_points(int(tiers[i])),19.0*k,
                STYLE.GOLD if i < stars else STYLE.DIM,HORIZONTAL_ALIGNMENT_CENTER,92.0*k,false)

func _hero(r: Rect2, k: float, u: float) -> void:
    var c: Control = canvas
    STYLE.panel(c,r,u,22.0,0.0,true,1.4)
    var score: int = int(data["score"])
    STYLE.text(c,Vector2(r.position.x,r.position.y+62.0*k),"DRIFT POINTS",30.0*k,STYLE.MUTED,
        HORIZONTAL_ALIGNMENT_CENTER,r.size.x,false)
    var big: String = points(score)
    var size: float = STYLE.fit_size(big,190.0*k,r.size.x*0.9)
    # Soft accent glow behind the main number.
    var glow := Color(STYLE.PINK.r,STYLE.PINK.g,STYLE.PINK.b,0.028)
    for g in range(4):
        c.draw_circle(Vector2(r.get_center().x,r.position.y+175.0*k),(190.0-40.0*float(g))*k,glow)
    STYLE.text(c,Vector2(r.position.x,r.position.y+238.0*k),big,size,STYLE.WHITE,
        HORIZONTAL_ALIGNMENT_CENTER,r.size.x)
    var delta_txt: String
    var delta_col: Color
    if bool(data["first_run"]):
        delta_txt = "FIRST RUN ON THIS TRACK  •  SET THE BENCHMARK"
        delta_col = STYLE.PINK_SOFT
    elif bool(data["new_best"]):
        delta_txt = "▲ +%s PTS  •  NEW PERSONAL BEST" % points(score-int(data["prior_best_score"]))
        delta_col = STYLE.GOLD
    else:
        delta_txt = "%s PTS TO YOUR BEST (%s)" % [points(int(data["prior_best_score"])-score),
            points(int(data["prior_best_score"]))]
        delta_col = BAD
    STYLE.text(c,Vector2(r.position.x,r.position.y+300.0*k),delta_txt,
        STYLE.fit_size(delta_txt,32.0*k,r.size.x*0.9),delta_col,HORIZONTAL_ALIGNMENT_CENTER,r.size.x,true)
    # Divider + three facts.
    var yl: float = r.position.y+335.0*k
    c.draw_line(Vector2(r.position.x+40.0*k,yl),Vector2(r.end.x-40.0*k,yl),Color(1,1,1,0.10),2.0*k)
    var cols: float = r.size.x/3.0
    var secs: float = float(data["seconds"])
    var time_sub: String = ""
    var time_col: Color = STYLE.MUTED
    if not bool(data["first_run"]):
        var d: float = secs-float(data["prior_best_time"])
        time_sub = ("-%.2f s BEST" % absf(d)) if d < 0.0 else ("+%.2f s" % d)
        time_col = GOOD if d < 0.0 else STYLE.MUTED
    var rank: int = int(data["rank"])
    var facts: Array = [
        ["TIME",clock(secs),time_sub,time_col],
        ["RANK","#%d" % rank if rank > 0 else "-","OF %d RUNS" % int(data["runs"]),STYLE.MUTED],
        ["BEST CHAIN",points(int((data["stats"] as Dictionary).get("best_chain",0))),"PTS",STYLE.MUTED]]
    for i in range(3):
        var f: Array = facts[i]
        var x: float = r.position.x+cols*float(i)
        STYLE.text(c,Vector2(x,yl+38.0*k),str(f[0]),22.0*k,STYLE.DIM,HORIZONTAL_ALIGNMENT_CENTER,cols,false)
        # Our race time in yellow (owner v0.1.21); rank #1 gold as before.
        STYLE.text(c,Vector2(x,yl+92.0*k),str(f[1]),STYLE.fit_size(str(f[1]),50.0*k,cols*0.9),
            STYLE.GOLD if i == 0 or (i == 1 and rank == 1) else STYLE.WHITE,HORIZONTAL_ALIGNMENT_CENTER,cols)
        STYLE.text(c,Vector2(x,yl+124.0*k),str(f[2]),21.0*k,f[3],HORIZONTAL_ALIGNMENT_CENTER,cols,false)
        if i > 0:
            c.draw_line(Vector2(x,yl+18.0*k),Vector2(x,yl+122.0*k),Color(1,1,1,0.08),2.0*k)

func _section(r: Rect2, title: String, note: String, k: float) -> float:
    var c: Control = canvas
    c.draw_rect(Rect2(r.position.x,r.position.y+8.0*k,8.0*k,34.0*k),STYLE.PINK)
    STYLE.text(c,Vector2(r.position.x+24.0*k,r.position.y+38.0*k),title,36.0*k,STYLE.WHITE)
    if not note.is_empty():
        STYLE.text(c,Vector2(r.position.x,r.position.y+38.0*k),note,22.0*k,STYLE.DIM,
            HORIZONTAL_ALIGNMENT_RIGHT,r.size.x,false)
    return r.position.y+64.0*k

func _laps(r: Rect2, k: float, u: float) -> void:
    var c: Control = canvas
    var laps: Array = data["laps"]
    var y: float = _section(r,"LAPS","TIME  •  POINTS",k)
    var box := Rect2(r.position.x,y,r.size.x,r.end.y-y)
    STYLE.panel(c,box,u,18.0,0.0,false,0.0)
    if laps.is_empty():
        STYLE.text(c,Vector2(box.position.x,box.get_center().y+12.0*k),"LAP SPLITS NOT RECORDED FOR THIS RUN",
            26.0*k,STYLE.MUTED,HORIZONTAL_ALIGNMENT_CENTER,box.size.x,false)
        return
    var max_pts: int = 1
    for l in laps:
        max_pts = maxi(max_pts,int(l["score"]))
    var row_h: float = box.size.y/float(maxi(laps.size(),3))
    var best: int = int(data["best_lap"])
    for i in range(laps.size()):
        var l: Dictionary = laps[i]
        var ry: float = box.position.y+row_h*float(i)
        var cy: float = ry+row_h*0.5
        if i > 0:
            c.draw_line(Vector2(box.position.x+24.0*k,ry),Vector2(box.end.x-24.0*k,ry),Color(1,1,1,0.07),2.0*k)
        STYLE.text(c,Vector2(box.position.x+30.0*k,cy+14.0*k),"LAP %d" % (i+1),36.0*k,STYLE.WHITE)
        var is_best: bool = i == best and laps.size() > 1
        STYLE.text(c,Vector2(box.position.x+210.0*k,cy+14.0*k),clock(float(l["time"])),36.0*k,
            STYLE.GOLD if is_best else STYLE.MUTED,HORIZONTAL_ALIGNMENT_LEFT,-1.0,is_best)
        if is_best:
            STYLE.text(c,Vector2(box.position.x+210.0*k,cy+42.0*k),"FASTEST LAP",17.0*k,STYLE.GOLD,
                HORIZONTAL_ALIGNMENT_LEFT,-1.0,false)
        # Points bar.
        var bx: float = box.position.x+440.0*k
        var bw: float = box.end.x-bx-200.0*k
        var bh: float = 18.0*k
        var bar := Rect2(bx,cy-bh*0.5,bw,bh)
        c.draw_rect(bar,Color(1,1,1,0.07))
        var f: float = clampf(float(l["score"])/float(max_pts),0.0,1.0)
        if f > 0.0:
            c.draw_rect(Rect2(bar.position,Vector2(bw*f,bh)),STYLE.PINK)
            c.draw_rect(Rect2(bar.position,Vector2(bw*f,bh*0.35)),Color(1,1,1,0.22))
        STYLE.text(c,Vector2(box.end.x-190.0*k,cy+14.0*k),points(int(l["score"])),36.0*k,STYLE.WHITE,
            HORIZONTAL_ALIGNMENT_RIGHT,170.0*k)

func _chips(r: Rect2, k: float, u: float) -> void:
    var c: Control = canvas
    var st: Dictionary = data["stats"]
    var chips: Array = [["TRANSITIONS",int(st.get("transitions",0)),STYLE.WHITE],
        ["KERB CLIPS",int(st.get("kerb_clips",0)),STYLE.WHITE],
        ["CHAINS LOST",int(st.get("chains_lost",0)),BAD if int(st.get("chains_lost",0)) > 0 else STYLE.WHITE]]
    var gap: float = 22.0*k
    var w: float = (r.size.x-gap*2.0)/3.0
    for i in range(3):
        var chip := Rect2(r.position.x+(w+gap)*float(i),r.position.y,w,r.size.y)
        STYLE.panel(c,chip,u,16.0,STYLE.SKEW,i == 0,0.5)
        var ch: Array = chips[i]
        STYLE.text(c,Vector2(chip.position.x,chip.position.y+66.0*k),str(ch[1]),54.0*k,ch[2],
            HORIZONTAL_ALIGNMENT_CENTER,chip.size.x)
        STYLE.text(c,Vector2(chip.position.x,chip.position.y+106.0*k),str(ch[0]),21.0*k,STYLE.MUTED,
            HORIZONTAL_ALIGNMENT_CENTER,chip.size.x,false)

func _top_runs(r: Rect2, k: float, u: float) -> void:
    var c: Control = canvas
    var y: float = _section(r,"YOUR TOP RUNS","THIS TRACK  •  BY POINTS",k)
    var box := Rect2(r.position.x,y,r.size.x,r.end.y-y)
    STYLE.panel(c,box,u,18.0,0.0,false,0.0)
    # Column positions (units of the 1000-wide design).
    var cx: Array[float] = [30.0,150.0,480.0,700.0,810.0]
    var hy: float = box.position.y+40.0*k
    var heads: Array[String] = ["#","POINTS","TIME","","DATE"]
    for i in range(heads.size()):
        STYLE.text(c,Vector2(box.position.x+cx[i]*k,hy),heads[i],20.0*k,STYLE.DIM,HORIZONTAL_ALIGNMENT_LEFT,-1.0,false)
    var rows: Array = (data["top"] as Array).duplicate()
    var rank: int = int(data["rank"])
    var extra: bool = rank > rows.size()
    if extra:
        rows.append(data["this_run"])
    var row_h: float = (box.end.y-hy-14.0*k)/6.0
    for i in range(rows.size()):
        var run: Dictionary = rows[i]
        var ry: float = hy+14.0*k+row_h*float(i)
        var place: int = rank if (extra and i == rows.size()-1) else i+1
        var mine: bool = place == rank
        var row := Rect2(box.position.x+12.0*k,ry+4.0*k,box.size.x-24.0*k,row_h-8.0*k)
        if mine:
            # This run highlighted in yellow (owner v0.1.21).
            c.draw_rect(row,Color(STYLE.GOLD.r,STYLE.GOLD.g,STYLE.GOLD.b,0.16))
            c.draw_rect(Rect2(row.position,Vector2(6.0*k,row.size.y)),STYLE.GOLD)
        if extra and i == rows.size()-1:
            STYLE.text(c,Vector2(box.position.x,ry-2.0*k),"• • •",18.0*k,STYLE.DIM,HORIZONTAL_ALIGNMENT_CENTER,box.size.x,false)
        var ty: float = row.get_center().y+13.0*k
        var medal: Color = STYLE.GOLD if place == 1 else (SILVER if place == 2 else (BRONZE if place == 3 else STYLE.MUTED))
        if place <= 3:
            c.draw_circle(Vector2(box.position.x+52.0*k,row.get_center().y),24.0*k,Color(medal.r,medal.g,medal.b,0.22))
        STYLE.text(c,Vector2(box.position.x+cx[0]*k,ty),str(place),32.0*k,medal,HORIZONTAL_ALIGNMENT_CENTER,46.0*k)
        STYLE.text(c,Vector2(box.position.x+cx[1]*k,ty),points(int(run["score"])),38.0*k,
            STYLE.GOLD if mine else (STYLE.WHITE if place == 1 else Color(0.90,0.90,0.94)))
        STYLE.text(c,Vector2(box.position.x+cx[2]*k,ty),clock(float(run["seconds"])),30.0*k,
            STYLE.GOLD if mine else STYLE.MUTED,HORIZONTAL_ALIGNMENT_LEFT,-1.0,mine)
        var n_st: int = int(run.get("stars",0))
        for si in range(3):
            STYLE.star(c,Vector2(box.position.x+(cx[3]+14.0+30.0*si)*k,row.get_center().y),12.0*k,si < n_st,u*0.6)
        var when: String = "THIS RUN" if mine else short_date(str(run.get("date","")))
        STYLE.text(c,Vector2(box.position.x+cx[4]*k,ty),when,22.0*k,STYLE.GOLD if mine else STYLE.DIM,
            HORIZONTAL_ALIGNMENT_LEFT,-1.0,mine)
