extends SceneTree
## #33 integration (v0.1.43): the features of both lines working TOGETHER, not just side by side.
##  * a #29 ROAD (12 m) CLUB EVENT circuit on Ojców seed 621727 opens in the v0.1.42 node editor without losing its width,
##    surface, event mode or landscape; SET START + a shaping move + SAVE AS keep all of it,
##  * the race of the shaped circuit judges it as a Club event (zones regenerated from the edited road, narrow surface),
##  * the #19 water fix still holds under the shaped road (Astra's own footprint measure: stream >= 2.19 m below the deck),
##  * multiplayer (v0.1.41) stays on unjudged circuits (no judged event can be shared yet: gated, not removed),
##  * a judged event run writes no record / star (same rule as multiplayer and the diagnostic physics mode).
## NOT proven here: anything on a phone (owner QA).
const TOOLS = preload("res://scripts/world/track_edit_tools.gd")
const TT = preload("res://scripts/world/terrain/terrain_track.gd")
const CAT = preload("res://scripts/world/terrain/terrain_catalog.gd")
const WORLD = preload("res://scripts/world/terrain/terrain_world.gd")
const DNA = preload("res://scripts/world/track_dna.gd")
const P = preload("res://scripts/net/net_protocol.gd")
const RESULTS = preload("res://scripts/ui/race_results.gd")
const FOOTPRINT = preload("res://tests/terrain_water_footprint_test.gd")
const EDITOR_SCENE = preload("res://scenes/track_editor.tscn")
const BOOT = preload("res://scenes/boot.tscn")
const RACE = preload("res://scenes/race.tscn")
const SRC: String = "user://nitro_track_qa_integration_club_road.json"
const LAST: String = "user://nitro_editor_last_path.txt"
const RUNS: String = "user://nitro_local_runs.json"

var _marker_before: String = ""
var _had_marker: bool = false
var _track_before: Variant = null

func _initialize() -> void:
    _had_marker = FileAccess.file_exists(LAST)
    if _had_marker:
        _marker_before = FileAccess.get_file_as_string(LAST)
    _track_before = ProjectSettings.get_setting("nitro/selected_track","")
    call_deferred("_run")

func _restore() -> void:
    ProjectSettings.set_setting("nitro/selected_track",_track_before)
    if _had_marker:
        var f := FileAccess.open(LAST,FileAccess.WRITE)
        f.store_string(_marker_before)
        f.close()
    elif FileAccess.file_exists(LAST):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(LAST))

func _fail(message: String) -> void:
    _restore()
    printerr("FAIL: "+message)
    quit(1)

func _read(path: String) -> Dictionary:
    return JSON.parse_string(FileAccess.get_file_as_string(path))

func _zones(path: String) -> Dictionary:
    ProjectSettings.set_setting("nitro/selected_track",path)
    var race: Node3D = RACE.instantiate()
    root.add_child(race)
    await process_frame
    var tr = race.get("track")
    var out: Dictionary = {"mode":str(tr.event_mode),"style":str(tr.road_style),"zones":(tr.event_layout["zones"] as Array).duplicate(true),
        "half":float(tr.halfwidths[0]),"length":float(tr.length_metres),"terrain":tr.terrain != null,"start":tr.start_position(),"race":race}
    return out

func _run() -> void:
    # ---- a #29 ROAD Club Event circuit on Astra's Ojców seed, built by the Terrain Builder's own code
    var w = WORLD.new()
    var desc: Dictionary = CAT.descriptor("pl_ojcow",621727,-1,"club")
    desc["road_style"] = "road"
    w.with_lighting = false
    w.setup(desc)
    root.add_child(w)
    w.build()
    var src: Dictionary = {}
    var crossing: bool = false
    for seed_value in [3,4,5,6,7,8,9,10,11,12]:
        var gen: Dictionary = TT.generate_loop(TT.new_grid(),w.field,desc,seed_value)
        if not bool(gen.get("ok",false)):
            continue
        var c0: Dictionary = DNA.compile(gen["data"])
        w.set_road(c0.centerline,c0.halfwidths,c0.heights,c0.closed)
        if int(FOOTPRINT.measure(w,c0)["sections"]) > 0:
            src = gen["data"]
            crossing = true
            break
    if not crossing:
        _fail("no Ojców 621727 Club ROAD loop crossing the stream could be generated")
        return
    if int(src.get("event_version",0)) != 1 or str(src.get("road_style","")) != "road" or absf(float(src["width_m"])-12.0) > 0.01 \
            or str(TT.world_of(src).get("event_mode","")) != "club":
        _fail("the Terrain Builder data must be a 12 m ROAD Club event (#29): %s / %s / %s" % [str(src.get("event_version")),str(src.get("road_style")),str(src.get("width_m"))])
        return
    src["name"] = "QA CLUB ROAD OJCOW"
    var sf := FileAccess.open(SRC,FileAccess.WRITE)
    sf.store_string(JSON.stringify(src,"  ",false,true))
    sf.close()
    # ---- open it in the node editor: width, surface, event and landscape survive
    var mf := FileAccess.open(LAST,FileAccess.WRITE)
    mf.store_string(SRC)
    mf.close()
    var editor: Control = EDITOR_SCENE.instantiate()
    root.add_child(editor)
    await process_frame
    var ed: Dictionary = editor.get("data")
    if absf(float(ed.get("width_m",0.0))-12.0) > 0.01:
        _fail("the node editor widened the 12 m ROAD to %.1f m" % float(ed.get("width_m",0.0)))
        return
    if str(ed.get("road_style","")) != "road" or int(ed.get("event_version",0)) != 1 or str(TT.world_of(ed).get("event_mode","")) != "club":
        _fail("the node editor lost the surface / event of the circuit")
        return
    if editor.get("terrain_field") == null or not bool(editor.get("ready_to_play")):
        _fail("the Club ROAD circuit must open valid with its landscape: "+str(editor.get("message_label").text))
        return
    var status: String = str(editor.get("message_label").text)
    if not status.contains("CLUB EVENT • ROAD") or not status.contains("TERRAIN OK"):
        _fail("the status must show the event and the surface: "+status)
        return
    var listed: bool = false
    for t in TOOLS.list_tracks():
        if str(t["path"]) == SRC and str(t["label"]).contains("CLUB EVENT • ROAD"):
            listed = true
    if not listed:
        _fail("OPEN must label the circuit with its event and surface")
        return
    # ---- SET START + a shaping move + SAVE AS
    var n: int = (ed["control_points"] as Array).size()
    editor.set("selected",n/3)
    editor.call("_set_start")
    if not bool(editor.get("ready_to_play")):
        _fail("SET START on the Club ROAD circuit must stay valid")
        return
    editor.call("_save_undo_snapshot")
    var base_pts: Array = (editor.get("data")["control_points"] as Array).duplicate(true)
    var moved: bool = false
    for idx in [5,9,14,20,27]:
        for off in [Vector2(1.5,0),Vector2(0,1.5),Vector2(-1.5,0),Vector2(0,-1.5)]:
            var cand: Array = base_pts.duplicate(true)
            cand[idx] = [float(cand[idx][0])+off.x,float(cand[idx][1])+off.y]
            (editor.get("data") as Dictionary)["control_points"] = cand
            editor.call("_validate")
            if bool(editor.get("ready_to_play")):
                moved = true
                break
        if moved:
            break
    if not moved:
        _fail("no small shaping move keeps the Club ROAD circuit valid")
        return
    if not bool(editor.call("_persist_track","QA Club Road Shaped")):
        _fail("SAVE AS failed: "+str(editor.get("message_label").text))
        return
    var shaped_path: String = str(editor.get("last_saved_path"))
    var shaped: Dictionary = _read(shaped_path)
    if int(shaped.get("event_version",0)) != 1 or str(shaped.get("road_style","")) != "road" or absf(float(shaped["width_m"])-12.0) > 0.01 \
            or str(TT.world_of(shaped).get("event_mode","")) != "club" or not TOOLS.node_shaped(shaped) \
            or (shaped["elevation"]["knot_heights"] as Array).size() != n:
        _fail("SAVE AS must keep event_version, ROAD, 12 m, CLUB, the world, one height per node and mark node-shaped")
        return
    editor.queue_free()
    await process_frame
    # ---- the race judges the shaped circuit as a Club event on the narrow surface, zones from the edited road
    var before: Dictionary = await _zones(SRC)
    (before["race"] as Node).queue_free()
    await process_frame
    var after: Dictionary = await _zones(shaped_path)
    var race_after: Node3D = after["race"]
    if not bool(after["terrain"]) or str(after["mode"]) != "club" or str(after["style"]) != "road" or absf(float(after["half"])-6.0) > 0.01:
        _fail("race of the shaped circuit: terrain %s, mode '%s', style '%s', half width %.2f" % [str(after["terrain"]),str(after["mode"]),str(after["style"]),float(after["half"])])
        return
    var za: Array = after["zones"]
    var zb: Array = before["zones"]
    if za.is_empty() or zb.is_empty():
        _fail("Club zones must exist before (%d) and after (%d) shaping" % [zb.size(),za.size()])
        return
    for z in za:
        if float(z["a"]) < 0.0 or float(z["a"]) > float(after["length"])+0.5:
            _fail("a zone outside the shaped road")
            return
    var same: bool = za.size() == zb.size()
    if same:
        for i in range(za.size()):
            if absf(float(za[i]["a"])-float(zb[i]["a"])) > 0.5:
                same = false
                break
    if same:
        _fail("zones must be regenerated from the edited road (start moved, stations should differ)")
        return
    var sp: Array = shaped["control_points"]
    if Vector2(after["start"]).distance_to(Vector2(float(sp[0][0]),float(sp[0][1]))) > 0.01:
        _fail("the race must start on the node chosen with SET START")
        return
    # ---- a judged event run writes no record / star
    var runs_before: String = FileAccess.get_file_as_string(RUNS) if FileAccess.file_exists(RUNS) else ""
    race_after.set("finished",true)
    race_after.call("_show_results")
    await process_frame
    var runs_after: String = FileAccess.get_file_as_string(RUNS) if FileAccess.file_exists(RUNS) else ""
    if runs_after != runs_before:
        _fail("a judged event run must not be saved as a record")
        return
    if race_after.find_child("*",true,false) == null:
        pass
    var event_panel_found: bool = false
    for b in race_after.find_children("*","Button",true,false):
        if (b as Button).text == "EDIT ROAD":
            event_panel_found = true
    if not event_panel_found:
        _fail("the #29 event result panel (with EDIT ROAD) must be shown")
        return
    race_after.queue_free()
    await process_frame
    # ---- EDIT ROAD / MY TRACKS > EDIT of the shaped event circuit goes to the node editor
    var menu: Control = BOOT.instantiate()
    menu.set("navigate_enabled",false)
    root.add_child(menu)
    await process_frame
    menu.call("_edit_track",shaped_path)
    if str(menu.get("last_scene")) != "res://scenes/track_editor.tscn":
        _fail("a node-shaped event circuit must reopen in the node editor")
        return
    menu.call("_edit_track",SRC)
    if str(menu.get("last_scene")) != "res://scenes/terrain_builder.tscn":
        _fail("the untouched event circuit still opens in the Terrain Builder (event / surface buttons live there)")
        return
    menu.queue_free()
    # ---- #19 water fix under the shaped road (Astra's measure: deck - water over every crossing)
    var cs: Dictionary = DNA.compile(shaped)
    w.set_road(cs.centerline,cs.halfwidths,cs.heights,cs.closed)
    var m: Dictionary = FOOTPRINT.measure(w,cs)
    if int(m["sections"]) == 0 or float(m["min"]) < 2.19:
        _fail("stream clearance under the shaped Club ROAD: %d crossings, minimum %.2f m (needs >= 2.19 m)" % [int(m["sections"]),float(m["min"])])
        return
    var water_min: float = float(m["min"])
    w.queue_free()
    # ---- multiplayer stays on unjudged circuits (gated, not removed)
    for path in P.TRACKS:
        var raw: Dictionary = _read(path)
        if int(raw.get("event_version",0)) == 1:
            _fail("a judged event circuit must not be shareable in multiplayer yet: "+path)
            return
    if P.track_allowed("res://tracks/event_workshop_29.json") or P.track_allowed(shaped_path):
        _fail("multiplayer must refuse judged / player circuits")
        return
    if TOOLS.list_tracks().is_empty():
        _fail("OPEN list empty")
        return
    _restore()
    print("PASS: integration matrix - #29 Club ROAD (12 m) circuit on Ojców 621727 opens in the #42 node editor with width / surface / event / landscape intact (CLUB EVENT • ROAD • TERRAIN OK), SET START + shaping + SAVE AS keep them; the race judges it as a Club event on the narrow road with %d zones regenerated from the edited road (were %d); the #19 water fix holds under the shaped road (%d crossings, minimum %.2f m); a judged run writes no record and shows the event panel; EDIT routes shaped -> node editor, untouched -> Terrain Builder; multiplayer stays on the 4 unjudged circuits" % [za.size(),zb.size(),int(m["sections"]),water_min])
    print("NOT RUN: any of it on a phone; multiplayer on a judged event (not designed yet: gated)")
    quit(0)
