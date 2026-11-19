extends Control
class_name NitroRaceResults
## Local-only three-lap race history. No network leaderboard or fabricated ranks.
const STORAGE: String = "user://nitro_local_runs.json"
const STYLE = preload("res://scripts/ui/hud_style.gd")
const PINK: Color = Color(1.0,0.16,0.56)
const GOLD: Color = Color(1.0,0.78,0.26)
const WHITE: Color = Color(0.97,0.97,0.99)
const MUTED: Color = Color(0.68,0.71,0.78)
var replay: Callable
var garage: Callable

static func star_count(track_id: String,seconds: float,target: float) -> int:
    var times: Array[float] = []
    if track_id == "benchmark_oval":
        # Local tiers matching the three Oval thresholds in supplied reference.
        times = [75.0,51.0,47.31]
    else:
        # Provisional local practice tiers, not official DRIFTIT timings.
        times = [target,target*0.82,target*0.68]
    var count: int = 0
    for threshold in times:
        if seconds <= threshold:
            count += 1
    return count

static func read_runs() -> Array:
    if not FileAccess.file_exists(STORAGE):
        return []
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(STORAGE))
    if raw is Array:
        return raw
    return []

static func save_run(track_id: String,seconds: float,score: int,stars: int) -> bool:
    var runs: Array = read_runs()
    runs.append({
        "track_id":track_id,
        "seconds":snappedf(seconds,0.01),
        "score":score,
        "stars":stars,
        "date":Time.get_datetime_string_from_system()
    })
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

static func sorted_local(track_id: String) -> Array:
    var entries: Array = track_runs(track_id)
    entries.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
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

func show_race(track_id: String,track_name: String,seconds: float,score: int,
        target: float,on_replay: Callable,on_garage: Callable,stats: Dictionary = {}) -> void:
    replay = on_replay
    garage = on_garage
    mouse_filter = Control.MOUSE_FILTER_STOP
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var stars: int = star_count(track_id,seconds,target)
    var previous: Array = sorted_local(track_id)
    var prior_best: float = float(previous[0]["seconds"]) if not previous.is_empty() else INF
    var stored: bool = save_run(track_id,seconds,score,stars)
    var current: Array = sorted_local(track_id)
    var s: Vector2 = get_viewport_rect().size
    var sc: float = clampf(s.x/720.0,0.85,1.85)

    var shade := ColorRect.new()
    shade.color = Color(0.008,0.012,0.020,0.94)
    shade.mouse_filter = Control.MOUSE_FILTER_STOP
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(shade)

    var scroll := ScrollContainer.new()
    scroll.position = Vector2(s.x*0.035,s.y*0.035)
    scroll.size = Vector2(s.x*0.93,s.y*0.93)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    add_child(scroll)
    var panel := PanelContainer.new()
    panel.custom_minimum_size.x = s.x*0.91
    panel.add_theme_stylebox_override("panel",STYLE.modal_box(sc))
    theme = STYLE.screen_theme(sc)
    scroll.add_child(panel)
    var padding := MarginContainer.new()
    for side in ["margin_left","margin_right","margin_top","margin_bottom"]:
        padding.add_theme_constant_override(side,int(23.0*sc))
    panel.add_child(padding)
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation",int(10.0*sc))
    padding.add_child(v)

    _label(v,"NITRO WHEELZ  •  "+track_name.to_upper(),17,MUTED,sc)
    _label(v,("THREE STARS" if stars == 3 else "FINISHED"),35,WHITE,sc)
    var glyph: String = "★".repeat(stars)+"☆".repeat(3-stars)
    _label(v,glyph,33,GOLD,sc)
    _label(v,clock(seconds),64,WHITE,sc)
    var difference: String = "FIRST RECORDED RUN" if previous.is_empty() else (
        "NEW PERSONAL BEST" if seconds < prior_best else "+%.2f s VS BEST" % (seconds-prior_best))
    _label(v,difference,19,MUTED,sc)
    _label(v,"%d DRIFT POINTS  •  THREE LAPS" % score,21,PINK,sc)
    if not stats.is_empty():
        _label(v,"BEST CHAIN %d  •  %d TRANSITIONS  •  %d KERB CLIPS  •  %d CHAINS LOST" % [
            int(stats.get("best_chain",0)),int(stats.get("transitions",0)),
            int(stats.get("kerb_clips",0)),int(stats.get("chains_lost",0))],15,MUTED,sc)
    if track_id != "benchmark_oval":
        _label(v,"Stars: provisional local practice thresholds",15,MUTED,sc)
    if not stored:
        _label(v,"WARNING: run could not be saved on this device",17,Color(1.0,0.43,0.43),sc)
    _label(v,"LOCAL LEADERBOARD  •  THIS DEVICE ONLY",23,WHITE,sc)
    var local_rank: int = -1
    for index in range(current.size()):
        var run: Dictionary = current[index]
        if float(run["seconds"]) == snappedf(seconds,0.01) and int(run["score"]) == score and local_rank == -1:
            local_rank = index+1
    _label(v,("#%d of %d runs" % [local_rank,current.size()]) if local_rank > 0 else "No stored runs",23,GOLD,sc)
    for i in range(mini(5,current.size())):
        var item: Dictionary = current[i]
        _label(v,"%02d   %s   %s   %d PTS" % [i+1,clock(float(item["seconds"])),
            "★".repeat(int(item.get("stars",0))),int(item["score"])],17,WHITE,sc)
    _label(v,"RECENT DRIVES",22,WHITE,sc)
    var latest: Array = track_runs(track_id)
    latest.reverse()
    for i in range(mini(5,latest.size())):
        var item: Dictionary = latest[i]
        _label(v,"%s    %d PTS    %s" % [clock(float(item["seconds"])),
            int(item["score"]),short_date(str(item.get("date","")))],15,MUTED,sc)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation",int(12.0*sc))
    v.add_child(row)
    _action(row,"RESTART",replay,sc)
    _action(row,"GARAGE / MENU",garage,sc)
    _label(v,"LOCAL SAVE • NO ONLINE RANKING • v"+str(ProjectSettings.get_setting("application/config/version","?")),13,MUTED,sc)

func _label(parent: Node,txt: String,size: int,col: Color,scale: float) -> void:
    var l := Label.new()
    l.text = txt
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    l.add_theme_font_size_override("font_size",int(size*scale))
    l.add_theme_color_override("font_color",col)
    parent.add_child(l)

func _action(parent: HBoxContainer,label: String,callback: Callable,scale: float) -> void:
    var button := Button.new()
    button.text = label
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.custom_minimum_size.y = 58.0*scale
    button.add_theme_font_size_override("font_size",int(19.0*scale))
    STYLE.style_button(button,scale)
    button.pressed.connect(callback)
    parent.add_child(button)
