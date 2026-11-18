extends SceneTree
## Verify actual editable control points, safe validation, and local-only result board.
const EDITOR = preload("res://scripts/ui/track_editor.gd")
const RESULTS = preload("res://scripts/ui/race_results.gd")
const DNA = preload("res://scripts/world/track_dna.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var editor: Control = EDITOR.new()
    root.add_child(editor)
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
    editor.call("_reset_shape")
    editor.call("_validate")
    if not bool(editor.get("ready_to_play")):
        _fail("Reset track does not validate")
        return
    editor.call("_save")
    var saved: Dictionary = DNA.read_track("user://nitro_custom_track.json")
    if not bool(saved.get("ok",false)):
        _fail("Saved track cannot be played by Track DNA")
        return
    editor.queue_free()
    await process_frame

    if RESULTS.star_count("benchmark_oval",46.77,75.0) != 3:
        _fail("Reference Oval 3-star threshold incorrect")
        return
    if RESULTS.star_count("benchmark_oval",52.0,75.0) != 1:
        _fail("Reference Oval 1-star threshold incorrect")
        return
    if RESULTS.clock(46.77)!="0:46.77":
        _fail("Finish clock formatting incorrect")
        return
    if not RESULTS.save_run("qa_local_only",55.2,1100,1) or not RESULTS.save_run("qa_local_only",52.4,1400,2):
        _fail("Local result persistence failed")
        return
    var ranked: Array = RESULTS.sorted_local("qa_local_only")
    if ranked.size()!=2 or float(ranked[0]["seconds"]) >= float(ranked[1]["seconds"]):
        _fail("Local leaderboard sorting incorrect")
        return
    print("PASS: track editor drag/add/delete/reset/save; local stars, clock, ranked persistent history")
    print("NOT RUN: real phone touch interaction, full 3-lap UI screenshot and online leaderboard")
    quit(0)

func _fail(msg: String) -> void:
    printerr("FAIL: "+msg)
    quit(1)
