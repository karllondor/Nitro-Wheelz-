extends Node
signal complete(ok: bool)

const STORE = preload("res://scripts/world/player_track_store.gd")
const BOOT = preload("res://scenes/boot.tscn")
const TERRAIN = preload("res://scenes/terrain_builder.tscn")
const NODE_EDITOR = preload("res://scenes/track_editor.tscn")
const RESULTS = preload("res://scripts/ui/race_results.gd")
const PROFILE = preload("res://scripts/player/driver_profile.gd")
const PROGRESS = preload("res://scripts/player/player_progress.gd")
const NODE_SOURCE = "res://tracks/shin_kawa_v2.json"
const ROUTE_SOURCE = "res://tracks/event_workshop_29.json"
const DRAFT = "user://nitro_terrain_builder_draft.json"

var failures: Array[String] = []
var candidates: Array[String] = []
var previous: Dictionary = {}
var tag := "QA "+Crypto.new().generate_random_bytes(4).hex_encode()

func _ready() -> void:
    _run.call_deferred()

func _check(ok: bool, message: String) -> void:
    if not ok:
        failures.append(message)

func _fixture(path: String) -> Dictionary:
    return JSON.parse_string(FileAccess.get_file_as_string(path))

func _write(path: String, text: String) -> void:
    var file := FileAccess.open(path,FileAccess.WRITE)
    file.store_string(text)
    file.close()

func _remember(path: String) -> String:
    if path != "":
        candidates.append(path)
    return path

func _button(parent: Node, caption: String) -> Button:
    for node in parent.find_children("*","Button",true,false):
        if node.text == caption:
            return node
    return null

func _press(parent: Node, caption: String) -> void:
    var button := _button(parent,caption)
    _check(button != null,"Missing "+caption)
    if button != null:
        button.pressed.emit()
    await get_tree().process_frame

func _popup(parent: Node) -> ConfirmationDialog:
    var popup := parent.get_node_or_null("Track file dialog") as ConfirmationDialog
    _check(popup != null,"Missing track file confirmation")
    return popup

func _confirm(parent: Node, title: Variant = null) -> void:
    var popup := _popup(parent)
    if popup != null:
        if title != null:
            popup.get_node("Track name").text = title
        popup.get_ok_button().pressed.emit()
    await get_tree().process_frame

func _run() -> void:
    for path in [STORE.LAST_EDIT,DRAFT,RESULTS.STORAGE,PROFILE.PATH]:
        previous[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
    var selection: Variant = ProjectSettings.get_setting("nitro/selected_track",null)
    var edit_path: Variant = ProjectSettings.get_setting("nitro/terrain_edit_track",null)
    var boot := get_tree().current_scene
    var own_boot := boot == null
    if own_boot:
        boot = BOOT.instantiate()
        add_child(boot)
    await _exercise(boot)
    if own_boot:
        boot.free()
    else:
        boot.show_page("main")
    for path in candidates:
        for file in [path,STORE.TRASH.path_join(path.get_file())]:
            if FileAccess.file_exists(file):
                DirAccess.remove_absolute(file)
    for path in previous:
        if previous[path] == null:
            if FileAccess.file_exists(path):
                DirAccess.remove_absolute(path)
        else:
            var file := FileAccess.open(path,FileAccess.WRITE)
            file.store_buffer(previous[path])
            file.close()
    ProjectSettings.set_setting("nitro/selected_track",selection)
    ProjectSettings.set_setting("nitro/terrain_edit_track",edit_path)
    var verdict := "PASS: My Tracks duplicate protection, rename, undoable deletion, identity and both editor workflows"
    if not failures.is_empty():
        verdict = "FAIL: "+str(failures)
    print(verdict)
    if OS.has_feature("android"):
        _write("user://tracks-verdict.txt",verdict)
    complete.emit(failures.is_empty())
    queue_free()

func _exercise(boot: Node) -> void:
    var raw := _fixture(NODE_SOURCE)
    var legacy := _remember("user://nitro_track_"+tag.replace(" ","_")+".json")
    raw.id = "old_"+tag
    raw.name = tag
    _write(legacy,JSON.stringify(raw))
    var original_hash := FileAccess.get_sha256(legacy)
    for i in range(2):
        var result := STORE.create(raw,tag)
        _check(not result.has("error"),"SAVE AS duplicate "+str(i))
        _remember(str(result.get("path","")))
    _check(candidates.size() == 3 and candidates[1] != candidates[2]
        and FileAccess.get_sha256(legacy) == original_hash,"Same-name quick saves overwrote a file")
    for path in [NODE_SOURCE,"user://nitro_track_terrain_drive.json","user://nitro_track_built.json",DRAFT,
            "user://folder/../nitro_track_test.json"]:
        _check(not STORE.owned_path(path) and STORE.trash(path,"fake") != "","Protected path "+path)
    var corrupt := _remember("user://nitro_track_"+tag.replace(" ","_")+"_corrupt.json")
    _write(corrupt,'{"control_points":[["bad",null]]}')
    _check(STORE.read(corrupt).is_empty() and STORE.trash(corrupt,FileAccess.get_sha256(corrupt)) != "",
        "Malformed file accepted")
    var id: String = raw.id
    _check(RESULTS.save_run(id,91.0,12345,3),"Record setup")
    var runs_hash := FileAccess.get_sha256(RESULTS.STORAGE)
    var stars := PROGRESS.total_stars(PROGRESS.rows(boot._known_tracks(true)))
    boot.show_page("drive")
    await get_tree().process_frame
    var card: Node = boot.find_child("My track "+id,true,false)
    _check(card != null,"Legacy track missing from Drive")
    if card == null:
        return
    await _press(card,"RENAME")
    await _confirm(boot,tag+" Renamed")
    var renamed := STORE.read(legacy)
    _check(renamed.get("name") == tag+" Renamed" and renamed.get("id") == id
        and STORE.same_layout(raw,renamed),"Rename changed path, geometry or ID")
    _check(STORE.rename(legacy,"Stale",original_hash).has("error"),"Stale rename was accepted")
    card = boot.find_child("My track "+id,true,false)
    await _press(card,"DELETE")
    var cancel := _popup(boot)
    if cancel != null:
        _check(cancel.dialog_text.contains(tag+" Renamed"),"Delete warning omits exact name")
        cancel.get_cancel_button().pressed.emit()
        # Simulate the cancel signal emitted by the Window for embedded subwindows.
        if is_instance_valid(cancel) and not cancel.is_queued_for_deletion():
            cancel.canceled.emit()
    await get_tree().process_frame
    _check(FileAccess.file_exists(legacy),"Cancel removed the track")
    ProjectSettings.set_setting("nitro/selected_track",legacy)
    ProjectSettings.set_setting("nitro/terrain_edit_track",legacy)
    PROFILE.set_last_track(legacy)
    STORE.mark_recent(legacy)
    await _press(card,"DELETE")
    await _confirm(boot)
    _check(not FileAccess.file_exists(legacy) and not STORE.entries(true).is_empty()
        and FileAccess.file_exists(candidates[1]) and FileAccess.file_exists(candidates[2]),"Delete affected wrong copies")
    _check(boot.current_track() == STORE.FALLBACK and PROFILE.last_track() == STORE.FALLBACK
        and ProjectSettings.get_setting("nitro/terrain_edit_track","") == ""
        and not FileAccess.file_exists(STORE.LAST_EDIT),"Stale selection references")
    _check(PROGRESS.total_stars(PROGRESS.rows(boot._known_tracks(true))) == stars,
        "Moving a track to trash reduced profile stars")
    await _press(boot,"TRACK TRASH")
    await _press(boot,"RESTORE  ▸  "+tag+" Renamed")
    _check(STORE.read(legacy).get("id") == id and RESULTS.track_runs(id).size() == 1
        and FileAccess.get_sha256(RESULTS.STORAGE) == runs_hash,"Restore or rename lost stars/PB")
    _check(STORE.replace(legacy,{"control_points":[]},FileAccess.get_sha256(legacy)).has("error"),
        "Invalid save replaced track")

    boot.hide()
    var node = NODE_EDITOR.instantiate()
    add_child(node)
    node._close_dialog()
    await _press(node,"OPEN...")
    _check(node.dialog_overlay != null,"Node Editor OPEN picker")
    node._load_path(legacy)
    _check(node.last_saved_path == legacy and node.last_saved_name == tag+" Renamed","Node Editor OPEN wrong track")
    var before := FileAccess.get_sha256(legacy)
    await _press(node,"SAVE")
    _check(before == FileAccess.get_sha256(legacy),"Node Editor SAVE before confirm")
    await _confirm(node)
    _check(STORE.read(legacy).get("id") == id,"Unchanged Node Editor SAVE changed ID")
    node._reverse()
    await _press(node,"SAVE")
    await _confirm(node)
    _check(STORE.read(legacy).get("id",id) != id and FileAccess.get_sha256(RESULTS.STORAGE) == runs_hash,
        "Edited layout did not update identity independently of historical records")
    await _press(node,"SAVE AS...")
    if node.dialog_overlay != null:
        node.name_input.text = tag
        await _press(node.dialog_overlay,"SAVE")
    _check(node.last_saved_path != legacy and STORE.owned_path(node.last_saved_path),"Node Editor SAVE AS reused source")
    _remember(node.last_saved_path)
    node.free()

    var route := STORE.create(_fixture(ROUTE_SOURCE),tag+" Route","terrain_")
    if route.has("error"):
        _check(false,"Terrain route fixture: "+route.error)
        boot.show()
        return
    var path := _remember(str(route.path))
    ProjectSettings.set_setting("nitro/terrain_edit_track",path)
    var terrain = TERRAIN.instantiate()
    add_child(terrain)
    while terrain.busy_running:
        await get_tree().process_frame
    _check(terrain.loaded_path == path and terrain.loaded_name == tag+" Route","Terrain Builder OPEN legacy route")
    await _press(terrain,"OPEN")
    _check(terrain.dialog != null,"Terrain Builder OPEN picker")
    terrain._close_dialog()
    await get_tree().process_frame
    await _press(terrain,"SAVE")
    await _confirm(terrain)
    _check(terrain.loaded_path == path and STORE.read(path).get("id") == route.data.id,
        "Unchanged Terrain Builder SAVE changed identity")
    await _press(terrain,"RENAME")
    await _confirm(terrain,tag+" Road")
    _check(STORE.read(path).get("name") == tag+" Road","Terrain rename")
    await _press(terrain,"SAVE AS")
    await _confirm(terrain,tag+" Road")
    _check(terrain.loaded_path != path and STORE.owned_path(terrain.loaded_path),"Terrain Builder SAVE AS reused source")
    _remember(terrain.loaded_path)
    terrain.free()
    boot.show()
