extends SceneTree
## Verify actual editable control points, safe validation, and local-only result board.
const EDITOR = preload("res://scripts/ui/track_editor.gd")
const RESULTS = preload("res://scripts/ui/race_results.gd")
const DNA = preload("res://scripts/world/track_dna.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    EDITOR.set_help_hidden(false)
    var editor: Control = EDITOR.new()
    root.add_child(editor)
    await process_frame
    # Layout per owner sketch: no logo/instruction text, clipped edit window
    # above every bottom button, help shown as a first-open popup.
    if editor.find_child("Nitro Wheelz brand mark",true,false) != null:
        _fail("Editor logo should be removed")
        return
    var view: Control = editor.find_child("Clipped edit window",true,false) as Control
    if view == null or not view.clip_contents:
        _fail("Map must draw inside a clipped edit window")
        return
    var edit_rect: Rect2 = editor.get("canvas")
    var strip: Rect2 = editor.get("zoom_strip")
    for child in editor.get_children():
        if child is Button and not strip.encloses(Rect2(child.position,child.size)):
            var b := Rect2(child.position,child.size)
            if b.intersects(edit_rect):
                _fail("Button "+str(child.text)+" overlaps the edit window")
                return
    var status: Label = editor.find_child("Validation line",true,false) as Label
    if status == null or status.position.y < edit_rect.end.y:
        _fail("Validation line must sit under the edit window")
        return
    var help: CheckBox = editor.find_child("Do not show again",true,false) as CheckBox
    if editor.get("dialog_overlay") == null or help == null:
        _fail("First open must show the help popup with Don't show again")
        return
    help.button_pressed = true
    editor.call("_close_help")
    if not EDITOR.help_hidden():
        _fail("Don't show again was not remembered")
        return
    EDITOR.set_help_hidden(false)
    await process_frame
    var data: Dictionary = editor.get("data")
    var initial_count: int = (data["control_points"] as Array).size()
    if initial_count < 8 or not bool(editor.get("ready_to_play")):
        _fail("Track editor did not load a playable reference track")
        return
    editor.call("_add_point")
    data = editor.get("data")
    if (data["control_points"] as Array).size()!=initial_count+1:
        _fail("Add Node did not insert a real waypoint")
        return
    var selected: int = int(editor.get("selected"))
    var old_position: Vector2 = editor.call("_node_position",selected)
    var dragged: Vector2 = old_position+Vector2(1.0,2.0)
    editor.set("pointer",-2)
    editor.call("_drag_touch",editor.call("_screen_point",dragged),-2)
    data = editor.get("data")
    var edited_position: Vector2 = editor.call("_node_position",selected)
    if edited_position.distance_to(old_position) < 1.5:
        _fail("Editor drag did not change actual knot coordinates")
        return
    editor.call("_delete_point")
    data = editor.get("data")
    if (data["control_points"] as Array).size()!=initial_count:
        _fail("Delete Node did not remove waypoint")
        return
    # Undo a completed touchscreen drag, and verify Start New can be cancelled.
    var selected_before: int = int(editor.get("selected"))
    if selected_before < 0:
        editor.set("selected",0)
        selected_before = 0
    var before_undo: Vector2 = editor.call("_node_position",selected_before)
    editor.call("_start_touch",editor.call("_screen_point",before_undo),-2)
    editor.call("_drag_touch",editor.call("_screen_point",before_undo+Vector2(3.0,1.0)),-2)
    editor.call("_release_touch",-2)
    editor.call("_undo")
    var after_undo: Vector2 = editor.call("_node_position",selected_before)
    if after_undo.distance_to(before_undo) > 0.1:
        _fail("UNDO must restore the last dragged knot")
        return
    editor.call("_request_new")
    if editor.get("dialog_overlay") == null:
        _fail("Start New custom dialog did not appear")
        return
    editor.call("_close_dialog")

    editor.call("_start_new_circle")
    data = editor.get("data")
    if (data["control_points"] as Array).size() != 16 or not bool(editor.get("ready_to_play")):
        _fail("Start New Circle should produce a 16-knot valid loop")
        return
    var before_zoom: float = float(editor.get("pixels_per_metre"))
    editor.call("_zoom",1.25)
    if float(editor.get("pixels_per_metre")) <= before_zoom:
        _fail("Zoom+ did not increase editable view scale")
        return
    # Panning: zoomed edges must be reachable (v0.1.13 owner request).
    var canvas_rect: Rect2 = editor.get("canvas")
    var mid_before: Vector2 = editor.get("world_mid")
    editor.call("_pan_by",Vector2(-120,0))
    if (Vector2(editor.get("world_mid"))-mid_before).x <= 0.0:
        _fail("Dragging the empty map left must move the view right")
        return
    var probe: Vector2 = canvas_rect.position+canvas_rect.size*Vector2(0.2,0.3)
    var world_under: Vector2 = editor.call("_world_point",probe)
    editor.call("_zoom_at",probe,float(editor.get("zoom_level"))*2.0)
    if Vector2(editor.call("_screen_point",world_under)).distance_to(probe) > 0.5:
        _fail("Pinch/wheel zoom must keep the point under the fingers fixed")
        return
    var knot: Vector2 = editor.call("_node_position",0)
    editor.call("_zoom_at",editor.call("_screen_point",knot),6.0)
    editor.call("_pan_by",canvas_rect.get_center()-Vector2(editor.call("_screen_point",knot)))
    if not canvas_rect.has_point(editor.call("_screen_point",knot)):
        _fail("A knot at the edge must be reachable at maximum zoom")
        return
    editor.call("_fit_all")
    if absf(float(editor.get("zoom_level"))-1.0) > 0.001 or Vector2(editor.get("pan_offset")) != Vector2.ZERO:
        _fail("FIT must restore the whole-track view")
        return
    # Duplicate a knot: validator should flag specific offending nodes red.
    data["control_points"][3] = data["control_points"][2].duplicate()
    editor.set("data",data)
    editor.call("_validate")
    var invalid: Dictionary = editor.get("invalid_nodes")
    if bool(editor.get("ready_to_play")) or not invalid.has(2) or not invalid.has(3):
        _fail("Invalid duplicate knots were not identified for red highlighting")
        return

    editor.call("_start_new_blank")
    data = editor.get("data")
    if not (data["control_points"] as Array).is_empty() or not bool(editor.get("add_mode")):
        _fail("Start New Blank must begin with zero nodes and tap placement enabled")
        return
    # Place eight new knots using the same pointer entrypoint as on a phone.
    for i in range(8):
        var angle: float = PI+TAU*float(i)/8.0
        var world: Vector2 = Vector2(cos(angle),sin(angle))*80.0
        editor.call("_start_touch",editor.call("_screen_point",world),i)
        editor.call("_release_touch",i)
    data = editor.get("data")
    if (data["control_points"] as Array).size()!=8:
        _fail("Blank editor cannot place eight points by touching map")
        return
    if not bool(editor.get("ready_to_play")):
        _fail("Eight-point closed loop rejected after touch placement")
        return
    editor.call("_request_save")
    if editor.get("dialog_overlay") == null:
        _fail("Accessible Save dialog did not appear")
        return
    var input: LineEdit = editor.get("name_input")
    if input == null or input.get_theme_font_size("font_size") < 18:
        _fail("Name field font too small on portrait screens")
        return
    editor.call("_close_dialog")
    if not bool(editor.call("_persist_track","QA Oval v010")):
        _fail("Named track could not be saved")
        return
    var path: String = str(editor.get("last_saved_path"))
    var saved: Dictionary = DNA.read_track(path)
    if not bool(saved.get("ok",false)) or str(saved.get("track_name",""))!="QA Oval v010":
        _fail("Named track save did not preserve valid geometry/name")
        return
    editor.queue_free()
    await process_frame

    # AUTO-SMOOTH: a too-tight notch is highlighted and fixed automatically,
    # only nodes near the problem move, and UNDO restores the original.
    var smoother: Control = EDITOR.new()
    root.add_child(smoother)
    await process_frame
    smoother.call("_close_dialog")
    smoother.call("_start_new_circle")
    var circle: Array = (smoother.get("data")["control_points"] as Array).duplicate(true)
    var notched: Array = circle.duplicate(true)
    notched[5] = [float(circle[5][0])*0.42,float(circle[5][1])*0.42]
    var dd: Dictionary = smoother.get("data")
    dd["control_points"] = notched
    smoother.call("_validate")
    if bool(smoother.get("ready_to_play")) or (smoother.get("problem_ranges") as Array).is_empty():
        _fail("Notched circle must be invalid with a highlighted arc")
        return
    smoother.call("_auto_smooth")
    if not bool(smoother.get("ready_to_play")):
        _fail("AUTO-SMOOTH did not fix a tight notch")
        return
    var after: Array = smoother.get("data")["control_points"]
    for k in [0,1,10,11,12,13]:
        if Vector2(float(after[k][0]),float(after[k][1])).distance_to(Vector2(float(notched[k][0]),float(notched[k][1]))) > 0.01:
            _fail("AUTO-SMOOTH moved node %d far from the problem" % k)
            return
    smoother.call("_undo")
    if Vector2(float(smoother.get("data")["control_points"][5][0]),0).distance_to(Vector2(float(notched[5][0]),0)) > 0.01:
        _fail("UNDO must restore the pre-smooth shape")
        return
    smoother.queue_free()
    await process_frame

    # Stars are earned with drift points (scaled by distance), not time.
    var tiers: Array[int] = RESULTS.star_tiers(295.0)
    if tiers.size() != 3 or not (tiers[0] < tiers[1] and tiers[1] < tiers[2]):
        _fail("Star tiers must rise")
        return
    if RESULTS.star_count(7259,295.0) != 3 or RESULTS.star_count(3588,295.0) != 1 \
            or RESULTS.star_count(1407,295.0) != 0 or RESULTS.star_count(tiers[1],295.0) != 2:
        _fail("Points-based star tiers incorrect: "+str(tiers))
        return
    if RESULTS.star_tiers(590.0)[2] <= tiers[2]:
        _fail("A longer track must need more points per star")
        return
    if RESULTS.clock(46.77)!="0:46.77":
        _fail("Finish clock formatting incorrect")
        return
    # Start from a clean QA track (earlier local runs of this suite leave records).
    var kept: Array = RESULTS.read_runs().filter(func(r): return str(r.get("track_id","")) != "qa_local_only")
    var store: FileAccess = FileAccess.open(RESULTS.STORAGE,FileAccess.WRITE)
    store.store_string(JSON.stringify(kept,"  "))
    store.close()
    if not RESULTS.save_run("qa_local_only",55.2,1100,1) or not RESULTS.save_run("qa_local_only",52.4,1400,2):
        _fail("Local result persistence failed")
        return
    var ranked: Array = RESULTS.sorted_local("qa_local_only")
    if ranked.size()!=2 or float(ranked[0]["seconds"]) >= float(ranked[1]["seconds"]):
        _fail("Local leaderboard sorting incorrect")
        return
    print("PASS: clipped edit window + help popup layout, AUTO-SMOOTH of tight corners, drag/add/delete/UNDO, circle/blank, zoom + pan/pinch/FIT, red invalid knots, readable dialogs, named save, local records")
    print("NOT RUN: real phone touch interaction, full 3-lap UI screenshot and online leaderboard")
    quit(0)

func _fail(msg: String) -> void:
    printerr("FAIL: "+msg)
    quit(1)
