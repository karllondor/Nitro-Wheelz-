extends SceneTree
## v0.1.32 mobile QA ("CHASING 27,226" on different tracks): records and
## star targets belong to the right track.
##  * the Terrain Builder's DRIVE slot gives two different layouts two ids
##    (the old fixed "player_terrain_track" pooled every layout's runs) and
##    the same layout the same id; a run stored on layout A is not the best
##    of layout B;
##  * named saves: same name + different shape = different record id;
##  * the HUD pill shows the next star of this track (same tiers as the
##    finish screen), then the personal best, then ALL STARS.
const BUILDER = preload("res://scenes/terrain_builder.tscn")
const TT = preload("res://scripts/world/terrain/terrain_track.gd")
const RESULTS = preload("res://scripts/ui/race_results.gd")
const HUD = preload("res://scripts/ui/race_hud.gd")
const PATH_A: String = "user://nitro_track_qa_records_a.json"
const PATH_B: String = "user://nitro_track_qa_records_b.json"

func _initialize() -> void:
    call_deferred("_run")

func _id_of(path: String) -> String:
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return str((raw as Dictionary).get("id","")) if raw is Dictionary else ""

func _run() -> void:
    var err: String = await _checks()
    for p in [PATH_A,PATH_B]:
        DirAccess.remove_absolute(p)
    DirAccess.remove_absolute("user://nitro_terrain_builder_draft.json")
    if not err.is_empty():
        printerr("FAIL: "+err)
        quit(1)
        return
    print("PASS: records per track layout - Terrain Builder DRIVE / named saves fingerprint the geometry (different layouts never share a best, the same layout keeps its records), HUD pill = next star of this track -> personal best -> ALL STARS, RESTART / GARAGE need a second tap")
    for _f in range(3):
        await process_frame
    quit(0)

func _checks() -> String:
    DirAccess.remove_absolute("user://nitro_terrain_builder_draft.json")
    var b: Node3D = BUILDER.instantiate()
    root.add_child(b)
    await process_frame
    b._pick_country("japan")
    b._pick_landscape(str(b.CAT.of_country("japan")[0]))
    b.terrain_seed = 2
    b.generate_terrain(false)
    b._enter_build()
    TT.generate_loop(b.grid,b.world.field,b.descriptor(),5)
    b.route_start = TT.route_order(b.grid)["order"][0]
    b._after_edit()
    if not b._write(PATH_A,"MY DRIVE","player_terrain_track"):
        return "Layout A could not be written"
    var id_a: String = _id_of(PATH_A)
    if not b._write(PATH_B,"MY DRIVE","player_terrain_track"):
        return "Layout A (again) could not be written"
    if _id_of(PATH_B) != id_a:
        return "The same layout must keep its record id (%s vs %s)" % [id_a,_id_of(PATH_B)]
    b.grid = TT.new_grid()
    TT.generate_loop(b.grid,b.world.field,b.descriptor(),9)
    b.route_start = TT.route_order(b.grid)["order"][0]
    b._after_edit()
    if not b._write(PATH_B,"MY DRIVE","player_terrain_track"):
        return "Layout B could not be written"
    var id_b: String = _id_of(PATH_B)
    root.remove_child(b)
    b.free()
    if id_a == id_b or not id_a.begins_with("player_terrain_track_") or not id_b.begins_with("player_terrain_track_"):
        return "Two layouts driven from the builder share one record id: %s / %s" % [id_a,id_b]
    # A stored run on A is not B's best.
    RESULTS.save_run(id_a,61.0,27226,3,[],"qa")
    for run in RESULTS.track_runs(id_b):
        if int((run as Dictionary).get("score",0)) == 27226:
            return "A run of layout A appears in layout B's records"
    _purge(id_a)
    # Named saves: the fingerprint follows the shape, not the name.
    var shape1: Dictionary = {"knots":[[0,0],[100,0],[100,80]],"closed":true}
    var shape2: Dictionary = {"knots":[[0,0],[120,0],[100,90]],"closed":true}
    var n1: String = RESULTS.layout_id("custom_my_circuit",shape1)
    if n1 == RESULTS.layout_id("custom_my_circuit",shape2) or n1 != RESULTS.layout_id("custom_my_circuit",shape1):
        return "Named saves must fingerprint the shape"
    if RESULTS.layout_id(n1,shape2) != RESULTS.layout_id("custom_my_circuit",shape2):
        return "Re-saving must replace the old fingerprint, not stack another one"
    # HUD pill: next star of this track, then the best, then ALL STARS.
    var hud: NitroRaceHUD = HUD.new()
    hud.star_tiers = RESULTS.star_tiers(1000.0)
    var tiers: Array[int] = hud.star_tiers
    hud.best_score = 99999
    hud.score = 0
    if not str(hud.chase_label()["text"]).begins_with("NEXT ★1"):
        return "Pill must show the first star target: "+str(hud.chase_label())
    hud.score = tiers[0]+10
    if not str(hud.chase_label()["text"]).begins_with("NEXT ★2"):
        return "Pill must move on to the second star: "+str(hud.chase_label())
    hud.score = tiers[2]+10
    if not str(hud.chase_label()["text"]).begins_with("CHASING"):
        return "With every star, the pill chases this track's best: "+str(hud.chase_label())
    hud.best_score = tiers[2]
    if not bool(hud.chase_label()["beating"]):
        return "Beyond every star and the best the pill must celebrate"
    hud.free()
    # Pause menu: RESTART / GARAGE need a second tap (they end the run).
    var layer := CanvasLayer.new()
    root.add_child(layer)
    var pause: Control = load("res://scripts/ui/race_pause.gd").new()
    layer.add_child(pause)
    var hits: Array = [0,0]
    pause.show_pause(func(): pass,func(): hits[0] += 1,func(): hits[1] += 1)
    await process_frame
    var rb: Button = pause.find_child("RESTART",true,false)
    var gb: Button = pause.find_child("GARAGE*",true,false)   # "/" is not allowed in node names
    rb.pressed.emit()
    gb.pressed.emit()
    if hits != [0,0] or not rb.text.begins_with("TAP AGAIN") or not gb.text.begins_with("TAP AGAIN"):
        return "RESTART / GARAGE must ask for a second tap first (%s, %s / %s)" % [str(hits),rb.text,gb.text]
    rb.pressed.emit()
    gb.pressed.emit()
    if hits != [1,1]:
        return "The second tap must restart / leave (%s)" % str(hits)
    layer.queue_free()
    await process_frame
    return ""

func _purge(id: String) -> void:
    var runs: Array = RESULTS.read_runs()
    var keep: Array = []
    for r in runs:
        if not (r is Dictionary and str((r as Dictionary).get("track_id","")) == id):
            keep.append(r)
    var f := FileAccess.open(RESULTS.STORAGE,FileAccess.WRITE)
    if f != null:
        f.store_string(JSON.stringify(keep))
        f.close()
