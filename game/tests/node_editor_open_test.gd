extends SceneTree
## v0.1.42 (owner request 2026-11-23): circuits of the Terrain Builder / 3D tile builder open in the NODE EDITOR to be shaped
## further, and the START can be set.
##  * a terrain circuit opens in the node editor with its landscape (no bounce back to the Terrain Builder),
##  * OPEN lists terrain / tile / node circuits and copies of the built-in ones,
##  * SET START (the selected node becomes knot 0, the car drives towards the next node), REVERSE,
##  * a node moved over water / sea is red and cannot be saved or driven, UNDO brings it back,
##  * SAVE AS re-solves the road heights on the landscape, keeps the world, marks the circuit node-shaped; the race
##    builds it with the start on knot 0 heading to knot 1,
##  * the Terrain Builder never reloads old tiles over a node-shaped circuit; the menu routes it to the node editor,
##  * the editor layout (four button rows) has no overlaps.
## NOT proven here: finger feel, the layout on the owner's phone.
const TOOLS = preload("res://scripts/world/track_edit_tools.gd")
const TT = preload("res://scripts/world/terrain/terrain_track.gd")
const FIELD = preload("res://scripts/world/terrain/terrain_field.gd")
const CAT = preload("res://scripts/world/terrain/terrain_catalog.gd")
const DNA = preload("res://scripts/world/track_dna.gd")
const EDITOR_SCENE = preload("res://scenes/track_editor.tscn")
const BOOT = preload("res://scenes/boot.tscn")
const RACE = preload("res://scenes/race.tscn")
const SRC: String = "user://nitro_track_qa_terrain_source.json"
const LAST: String = "user://nitro_editor_last_path.txt"

var _marker_before: String = ""
var _had_marker: bool = false

func _initialize() -> void:
    if FileAccess.file_exists(LAST):
        _had_marker = true
        _marker_before = FileAccess.get_file_as_string(LAST)
    call_deferred("_run")

func _fail(message: String) -> void:
    _restore_marker()
    printerr("FAIL: "+message)
    quit(1)

func _restore_marker() -> void:
    ProjectSettings.set_setting("nitro/editor_open_latest",false)
    if _had_marker:
        var f := FileAccess.open(LAST,FileAccess.WRITE)
        if f != null:
            f.store_string(_marker_before)
            f.close()
    elif FileAccess.file_exists(LAST):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(LAST))

func _mark(path: String) -> void:
    var f := FileAccess.open(LAST,FileAccess.WRITE)
    f.store_string(path)
    f.close()

func _read(path: String) -> Dictionary:
    return JSON.parse_string(FileAccess.get_file_as_string(path))

func _pts(d: Dictionary) -> Array:
    var out: Array = []
    for p in d["control_points"]:
        out.append(Vector2(float(p[0]),float(p[1])))
    return out

func _run() -> void:
    # ---- a terrain circuit on a coast (sea = something to build over)
    var field: NitroTerrainField = FIELD.new("ie_coast",7)
    var grid = TT.new_grid()
    var gen: Dictionary = TT.generate_loop(grid,field,CAT.descriptor("ie_coast",7),5)
    if not bool(gen.get("ok",false)):
        _fail("could not generate a terrain loop for the test")
        return
    var src: Dictionary = gen["data"]
    src["name"] = "QA TERRAIN SOURCE"
    src["id"] = "qa_terrain_source"
    var sf := FileAccess.open(SRC,FileAccess.WRITE)
    sf.store_string(JSON.stringify(src,"  ",false,true))
    sf.close()
    var n: int = (src["control_points"] as Array).size()
    if TOOLS.kind_of(src) != "terrain" or TOOLS.node_shaped(src) or TOOLS.is_open_route(src):
        _fail("kind detection of a Terrain Builder circuit")
        return
    # ---- the list
    var listed: Array = TOOLS.list_tracks()
    var found_src: bool = false
    var builtins: int = 0
    for t in listed:
        if str(t["path"]) == SRC:
            found_src = str(t["kind"]) == "terrain" and not bool(t["open"]) and not bool(t["builtin"])
        if bool(t["builtin"]):
            builtins += 1
    if not found_src or builtins != 4:
        _fail("OPEN list: terrain circuit listed = %s, built-in copies = %d" % [str(found_src),builtins])
        return
    # ---- opening it in the node editor (EDIT NODES with this circuit being the last one touched)
    _mark(SRC)
    var editor: Control = EDITOR_SCENE.instantiate()
    root.add_child(editor)
    await process_frame
    var ed: Dictionary = editor.get("data")
    if ed.is_empty() or TT.world_of(ed).is_empty() or (ed["control_points"] as Array).size() != n:
        _fail("a terrain circuit must open in the node editor with its world (it was bounced to the Terrain Builder)")
        return
    if editor.get("terrain_field") == null or editor.get("terrain_tex") == null or not bool(editor.get("ready_to_play")):
        _fail("terrain context missing after opening (field / picture / valid)")
        return
    var tex: ImageTexture = editor.get("terrain_tex")
    if tex.get_width() != int((editor.get("terrain_field") as NitroTerrainField).nx):
        _fail("terrain picture size")
        return
    if not str(editor.get("message_label").text).contains("TERRAIN OK"):
        _fail("status must say TERRAIN OK: "+str(editor.get("message_label").text))
        return
    # ---- SET START
    var before: Array = _pts(ed)
    var heights_before: Array = (ed["elevation"]["knot_heights"] as Array).duplicate()
    var comp_before: Dictionary = DNA.compile(ed)
    editor.call("_set_start")
    if int(editor.get("selected")) != -1 or before != _pts(editor.get("data")):
        _fail("SET START without a selected node must change nothing")
        return
    var k: int = 17
    editor.set("selected",k)
    editor.call("_set_start")
    var after: Dictionary = editor.get("data")
    var pa: Array = _pts(after)
    if pa.size() != n or pa[0] != before[k] or pa[1] != before[(k+1)%n] or int(editor.get("selected")) != 0:
        _fail("SET START: the selected node must become knot 0, the next node knot 1")
        return
    if (after["elevation"]["knot_heights"] as Array)[0] != heights_before[k]:
        _fail("heights must follow the start rotation")
        return
    if not bool(editor.get("ready_to_play")):
        _fail("rotating the start must keep the circuit valid")
        return
    var comp_after: Dictionary = DNA.compile(after)
    var sub: int = DNA.SUBDIVISIONS
    if (comp_after["centerline"] as Array)[0] != (comp_before["centerline"] as Array)[k*sub] or absf(float(comp_after["length_metres"])-float(comp_before["length_metres"])) > 0.01:
        _fail("SET START must not change the road")
        return
    var pose: Dictionary = TOOLS.start_pose(after)
    var want: Vector2 = (before[(k+1)%n]-before[k]).normalized()
    var fwd := Vector2(sin(float(pose["heading"])),-cos(float(pose["heading"])))
    if fwd.dot(want) < 0.9:
        _fail("the car must start driving towards the next node")
        return
    # ---- REVERSE
    editor.set("selected",3)
    editor.call("_reverse")
    var rv: Array = _pts(editor.get("data"))
    if rv[0] != pa[0] or rv[1] != pa[n-1] or rv[n-1] != pa[1] or int(editor.get("selected")) != n-3:
        _fail("REVERSE: knot 0 stays, the order runs the other way (selected follows its node)")
        return
    var pose2: Dictionary = TOOLS.start_pose(editor.get("data"))
    var fwd2 := Vector2(sin(float(pose2["heading"])),-cos(float(pose2["heading"])))
    if fwd2.dot(fwd) > -0.5:
        _fail("REVERSE must turn the driving direction round")
        return
    if absf(float(DNA.compile(editor.get("data"))["length_metres"])-float(comp_before["length_metres"])) > 0.5:
        _fail("REVERSE must not change the road length")
        return
    editor.call("_undo")
    editor.call("_undo")
    editor.call("_undo")
    if _pts(editor.get("data")) != before:
        _fail("UNDO x3 must bring back the opened circuit")
        return
    # ---- a road over the sea is red and blocks SAVE / DRIVE; UNDO fixes it (the whole loop is slid until it is in the water)
    var original: Array = (editor.get("data")["control_points"] as Array).duplicate(true)
    var wet: bool = false
    editor.call("_save_undo_snapshot")
    for shift in [Vector2(120,0),Vector2(-120,0),Vector2(0,120),Vector2(0,-120),Vector2(240,0),Vector2(-240,0),Vector2(0,240),Vector2(0,-240),
            Vector2(200,200),Vector2(-200,-200),Vector2(200,-200),Vector2(-200,200),Vector2(360,0),Vector2(-360,0)]:
        var slid: Array = []
        for q in original:
            slid.append([float(q[0])+shift.x,float(q[1])+shift.y])
        (editor.get("data") as Dictionary)["control_points"] = slid
        editor.call("_validate")
        if not (editor.get("terrain_flagged") as Dictionary).is_empty():
            wet = true
            break
    if not wet:
        _fail("could not put the test road over the sea")
        return
    if bool(editor.get("ready_to_play")) or not str(editor.get("message_label").text).begins_with("TERRAIN"):
        _fail("a road over the sea must be refused with a terrain message: "+str(editor.get("message_label").text))
        return
    if (editor.get("invalid_nodes") as Dictionary).is_empty():
        _fail("the nodes over the sea must be red")
        return
    if bool(editor.call("_persist_track","QA Sea Road")):
        _fail("a road over the sea must not be saved")
        return
    editor.call("_undo")
    if not bool(editor.get("ready_to_play")) or not (editor.get("terrain_flagged") as Dictionary).is_empty():
        _fail("UNDO must bring back a drivable circuit")
        return
    # ---- shape it a little, SAVE AS (find a small move that keeps the circuit valid)
    var moved: Vector2 = Vector2.INF
    var moved_index: int = -1
    editor.call("_save_undo_snapshot")
    var base_pts: Array = (editor.get("data")["control_points"] as Array).duplicate(true)
    for idx in [9,13,21,30,40]:
        for off in [Vector2(1.5,0.0),Vector2(0.0,1.5),Vector2(-1.5,0.0),Vector2(0.0,-1.5),Vector2(2.5,2.5),Vector2(-2.5,-2.5)]:
            var cand: Array = base_pts.duplicate(true)
            var np: Vector2 = Vector2(float(cand[idx][0]),float(cand[idx][1]))+off
            cand[idx] = [np.x,np.y]
            (editor.get("data") as Dictionary)["control_points"] = cand
            editor.call("_validate")
            if bool(editor.get("ready_to_play")):
                moved = np
                moved_index = idx
                break
        if moved_index >= 0:
            break
    if moved_index < 0:
        _fail("no small shaping move keeps the circuit valid: "+str(editor.get("message_label").text))
        return
    if not bool(editor.call("_persist_track","QA Node Shaped Terrain")):
        _fail("SAVE AS of a shaped terrain circuit failed: "+str(editor.get("message_label").text))
        return
    var saved_path: String = str(editor.get("last_saved_path"))
    var saved: Dictionary = _read(saved_path)
    if not TOOLS.node_shaped(saved) or TT.world_of(saved).is_empty() or (saved["elevation"]["knot_heights"] as Array).size() != n:
        _fail("saved circuit: node-shaped flag, world and one height per node expected")
        return
    var comp_saved: Dictionary = DNA.compile(saved)
    if not bool(comp_saved.get("ok",false)) or (comp_saved["heights"] as PackedFloat32Array).size() != (comp_saved["centerline"] as Array).size():
        _fail("saved circuit must compile with its road heights")
        return
    if not bool(TT.evaluate(field,saved).get("ok",false)):
        _fail("saved circuit must be buildable on its landscape")
        return
    if _pts(saved)[moved_index].distance_to(moved) > 0.02:
        _fail("the shaped node must be saved where it was put")
        return
    # ---- the Terrain Builder never loads old tiles over it; the menu routes it to the node editor
    var tb = load("res://scripts/ui/terrain_builder.gd").new()
    if tb.call("load_track_file",saved_path):
        _fail("the Terrain Builder must refuse a node-shaped circuit")
        return
    tb.free()
    var menu: Control = BOOT.instantiate()
    menu.set("navigate_enabled",false)
    root.add_child(menu)
    await process_frame
    menu.call("_edit_track",saved_path)
    if str(menu.get("last_scene")) != "res://scenes/track_editor.tscn":
        _fail("a node-shaped terrain circuit must open in the node editor (got %s)" % str(menu.get("last_scene")))
        return
    # TRACK BUILDER > EDIT NODES asks for the circuit touched last
    menu.call("show_page","build")
    var edit_nodes: Button = menu.find_child("Editor nodes",true,false) as Button
    if edit_nodes == null:
        _fail("TRACK BUILDER page needs EDIT NODES")
        return
    edit_nodes.pressed.emit()
    if str(menu.get("last_scene")) != "res://scenes/track_editor.tscn" or not bool(ProjectSettings.get_setting("nitro/editor_open_latest",false)):
        _fail("EDIT NODES must open the node editor and ask for the circuit touched last")
        return
    ProjectSettings.set_setting("nitro/editor_open_latest",false)
    var latest_path: String = TOOLS.default_track_path()
    if latest_path == "" or latest_path.begins_with("res://") or TOOLS.is_open_route(_read(latest_path)):
        _fail("the latest-circuit rule must name a saved closed circuit (got '%s')" % latest_path)
        return
    menu.call("_edit_track",SRC)
    if str(menu.get("last_scene")) != "res://scenes/terrain_builder.tscn":
        _fail("an untouched terrain circuit still opens in the Terrain Builder (got %s)" % str(menu.get("last_scene")))
        return
    menu.queue_free()
    # ---- the race builds it: terrain, start on knot 0 heading to knot 1
    ProjectSettings.set_setting("nitro/selected_track",saved_path)
    var race: Node3D = RACE.instantiate()
    root.add_child(race)
    await process_frame
    var tr = race.get("track")
    if tr.terrain == null or not tr.track_valid:
        _fail("the race must build the terrain of a node-shaped circuit")
        return
    var sp: Array = _pts(saved)
    var h: float = tr.start_heading()
    if tr.start_position().distance_to(sp[0]) > 0.01 or Vector2(sin(h),-cos(h)).dot((sp[1]-sp[0]).normalized()) < 0.8:
        _fail("the race must start on knot 0 driving towards knot 1")
        return
    race.queue_free()
    await process_frame
    # ---- OPEN: a built-in circuit opens as a copy; UNDO brings the terrain circuit back with its landscape
    editor.call("_request_open")
    var list: Node = editor.find_child("Open list",true,false)
    if editor.get("dialog_overlay") == null or list == null or list.get_child(0).get_child_count() < 6:
        _fail("OPEN must show the saved circuits and the built-in copies")
        return
    var builtin_button: Button = editor.find_child("Open shin_kawa_v2",true,false) as Button
    var terrain_button: Button = editor.find_child("Open "+saved_path.get_file().get_basename(),true,false) as Button
    if builtin_button == null or terrain_button == null:
        _fail("OPEN rows for a built-in circuit and for the saved terrain circuit")
        return
    builtin_button.pressed.emit()
    var copy: Dictionary = editor.get("data")
    if not str(copy["name"]).begins_with("COPY OF") or str(editor.get("last_saved_path")) != "" or editor.get("terrain_field") != null \
            or editor.get("dialog_overlay") != null or not bool(editor.get("ready_to_play")):
        _fail("a built-in circuit opens as an unsaved copy without terrain")
        return
    editor.set("selected",4)
    editor.call("_set_start")
    editor.call("_persist_track","QA Flat Start Copy")
    var flat: Dictionary = _read(str(editor.get("last_saved_path")))
    var sf0: Dictionary = TOOLS.start_pose(flat)
    if sf0.is_empty() or Vector2(sf0["position"]).distance_to(_pts(flat)[0]) > 0.01:
        _fail("a flat circuit saves with its start on knot 0 too")
        return
    editor.call("_undo")
    editor.call("_undo")
    editor.call("_request_open")
    (editor.find_child("Open "+saved_path.get_file().get_basename(),true,false) as Button).pressed.emit()
    if editor.get("terrain_field") == null or TT.world_of(editor.get("data")).is_empty():
        _fail("opening the saved terrain circuit again restores its landscape")
        return
    # ---- layout: four rows of buttons, no overlap, finger sized
    var view: Vector2 = editor.get_viewport_rect().size
    var canvas: Rect2 = editor.get("canvas")
    var label: Label = editor.get("message_label")
    var rects: Array = []
    for b in editor.find_children("*","Button",true,false):
        var bb: Button = b
        if bb.get_parent() != editor:
            continue
        var r := Rect2(bb.position,bb.size)
        if canvas.encloses(r) or canvas.intersects(r) and r.position.y < canvas.end.y-4.0:
            continue          # zoom strip floats inside the map on purpose
        rects.append([bb.text,r])
    if rects.size() < 11:
        _fail("expected the bottom button rows, got %d" % rects.size())
        return
    for i in range(rects.size()):
        var ri: Rect2 = rects[i][1]
        if ri.position.x < 0.0 or ri.end.x > view.x or ri.end.y > view.y or ri.size.y < view.y*0.045:
            _fail("button '%s' off screen or too small" % str(rects[i][0]))
            return
        if ri.intersects(Rect2(label.position,label.size)) or ri.intersects(canvas):
            _fail("button '%s' overlaps the validation line or the map" % str(rects[i][0]))
            return
        for j in range(i+1,rects.size()):
            if ri.intersects(rects[j][1]):
                _fail("buttons '%s' and '%s' overlap" % [str(rects[i][0]),str(rects[j][0])])
                return
    for caption in ["SET START","REVERSE","OPEN...","SAVE AS...","START NEW","BACK","DRIVE","ADD NODE","DELETE NODE","AUTO-SMOOTH"]:
        var seen: bool = false
        for r2 in rects:
            if str(r2[0]).ends_with(caption):
                seen = true
        if not seen:
            _fail("missing button "+caption)
            return
    editor.queue_free()
    await process_frame
    _restore_marker()
    print("PASS: node editor v0.1.42 - a Terrain Builder circuit opens with its landscape (water shown, TERRAIN OK), OPEN lists terrain / tile / node circuits + 4 built-in copies, SET START makes the selected node knot 0 driving to the next node (road, length and heights unchanged), REVERSE, UNDO, a node over the sea is red and cannot be saved, SAVE AS re-solves heights + keeps the world + marks it node-shaped, the race starts on knot 0 towards knot 1, the Terrain Builder refuses node-shaped tiles and the menu routes them to the node editor, built-in circuits open as copies, four button rows without overlap")
    print("NOT RUN: finger feel and the layout on a real phone, open point-to-point routes (still edited in the Terrain Builder)")
    quit(0)
