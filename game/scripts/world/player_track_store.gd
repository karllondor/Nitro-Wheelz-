extends RefCounted
## Player-owned files, independent of temporary drive slots and editor drafts.
const DNA = preload("res://scripts/world/track_dna.gd")
const PROFILE = preload("res://scripts/player/driver_profile.gd")
const PREFIX = "user://nitro_track_"
const LAST_EDIT = "user://nitro_editor_last_path.txt"
const FALLBACK = "res://tracks/shin_kawa_v2.json"
const TRASH = "user://nitro_track_trash"
const RESERVED = ["nitro_track_terrain_drive.json","nitro_track_built.json"]

static func owned_path(path: String) -> bool:
    var file := path.get_file()
    if path != "user://"+file or not path.begins_with(PREFIX) or not file.ends_with(".json") or file.contains("\\"):
        return false
    return file not in RESERVED and not DirAccess.open("user://").is_link(file)

static func _number(value: Variant) -> bool:
    return (value is float or value is int) and is_finite(float(value))

static func _compile(raw: Dictionary) -> Dictionary:
    # Check types before passing persisted data to the geometry compiler.
    for key in ["schema_version","width_m","seed","start_index","event_version"]:
        if raw.has(key) and not _number(raw[key]):
            return {}
    var points: Variant = raw.get("control_points",[])
    if not points is Array:
        return {}
    for point in points:
        if not point is Array or point.size() != 2 or not _number(point[0]) or not _number(point[1]):
            return {}
    var widths: Variant = raw.get("widths_m",[])
    if not widths is Array or widths.any(func(w): return not _number(w)):
        return {}
    for key in ["world","builder","elevation"]:
        if raw.has(key) and not raw[key] is Dictionary:
            return {}
    var builder: Dictionary = raw.get("builder",{})
    var tiles: Variant = builder.get("tiles",[])
    if not tiles is Array:
        return {}
    for tile in tiles:
        if not tile is Array or tile.size() != 2 or not _number(tile[0]) or not _number(tile[1]):
            return {}
    var heights: Variant = raw.get("elevation",{}).get("knot_heights",[])
    if not heights is Array or heights.any(func(h): return not _number(h)):
        return {}
    return DNA.compile(raw)

static func _read(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var json := JSON.new()
    if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
        return {}
    return json.data

static func read(path: String) -> Dictionary:
    var raw := _read(path) if owned_path(path) else {}
    return raw if _compile(raw).get("ok",false) else {}

static func entries(deleted: bool = false) -> Array[Dictionary]:
    var out: Array[Dictionary] = []
    var folder := TRASH if deleted else "user://"
    var directory := DirAccess.open(folder)
    if directory == null or (deleted and DirAccess.open("user://").is_link(TRASH.get_file())):
        return out
    for file in directory.get_files():
        var original := "user://"+file
        if not owned_path(original) or directory.is_link(file):
            continue
        var path := folder.path_join(file)
        var raw := _read(path)
        var compiled := _compile(raw)
        if compiled.get("ok",false):
            out.append({"path":original,"id":compiled.track_id,"name":compiled.track_name,
                "length":compiled.length_metres,"time":FileAccess.get_modified_time(path),"raw":raw})
    out.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
        return a.time > b.time if a.time != b.time else a.path < b.path)
    return out

static func _slug(title: String) -> String:
    var out := ""
    for ch in title.to_lower():
        if ch in "abcdefghijklmnopqrstuvwxyz0123456789":
            out += ch
        elif not out.ends_with("_"):
            out += "_"
    return out.left(40).trim_prefix("_").trim_suffix("_")

static func _title(title: String) -> String:
    var clean := title.strip_edges()
    if clean.is_empty() or clean.length() > 42:
        return ""
    for ch in clean:
        if ch.unicode_at(0) < 32 or ch.unicode_at(0) == 127:
            return ""
    return clean

static func _trash_available() -> bool:
    return not DirAccess.open("user://").is_link(TRASH.get_file())

static func _occupied(path: String) -> bool:
    return FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path) or not owned_path(path) \
        or FileAccess.file_exists(TRASH.path_join(path.get_file()))

static func create(data: Dictionary, title: String, prefix: String = "") -> Dictionary:
    var clean := _title(title)
    if clean == "":
        return {"error":"ENTER A TRACK NAME (1–42 CHARACTERS)"}
    var stem := prefix+_slug(clean)
    if stem == prefix:
        stem += "track"
    var file := stem
    var suffix := 2
    while _occupied(PREFIX+file+".json"):
        file = "%s_%d" % [stem,suffix]
        suffix += 1
    var path := PREFIX+file+".json"
    var copy := data.duplicate(true)
    copy.name = clean
    # The legacy helper treats a trailing eight hex digits as an old hash.
    copy.id = _layout_id(("custom_" if prefix == "" else "")+file+"_track",copy)
    return _commit(path,copy,"")

static func _layout_id(base: String, data: Dictionary) -> String:
    return load("res://scripts/ui/race_results.gd").layout_id(base,data)

static func same_layout(before: Dictionary, after: Dictionary) -> bool:
    var a := _compile(before)
    var b := _compile(after)
    if not a.get("ok",false) or not b.get("ok",false):
        return false
    for key in ["centerline","halfwidths","heights","closed","seed"]:
        if a[key] != b[key]:
            return false
    for key in ["world","road_style","event_version","start_index","theme"]:
        if before.get(key) != after.get(key):
            return false
    return true

static func replace(path: String, data: Dictionary, expected: String) -> Dictionary:
    var old := read(path)
    if expected == "" or old.is_empty():
        return {"error":"SAVED TRACK IS UNAVAILABLE • USE SAVE AS"}
    var copy := data.duplicate(true)
    copy.name = str(old.get("name",old.get("id","TRACK")))
    var id := str(old.get("id","unnamed"))
    copy.id = id if same_layout(old,copy) else _layout_id(id,copy)
    return _commit(path,copy,expected)

static func rename(path: String, title: String, expected: String) -> Dictionary:
    var clean := _title(title)
    if clean == "":
        return {"error":"ENTER A TRACK NAME (1–42 CHARACTERS)"}
    var raw := read(path)
    if expected == "" or raw.is_empty():
        return {"error":"SAVED TRACK IS UNAVAILABLE"}
    raw.name = clean
    return _commit(path,raw,expected)

## A synchronous staged write. Validate the exact JSON bytes before publication.
## Recheck the target before replacing it and leave the old file on I/O failure.
static func _commit(path: String, data: Dictionary, expected: String) -> Dictionary:
    var text := JSON.stringify(data,"  ",false,true)
    var raw: Variant = JSON.parse_string(text)
    if not raw is Dictionary or not _compile(raw).get("ok",false):
        return {"error":"TRACK GEOMETRY IS INVALID"}
    var tmp := "user://.nitro_save_"+Crypto.new().generate_random_bytes(16).hex_encode()+".tmp"
    var file := FileAccess.open(tmp,FileAccess.WRITE)
    if file == null:
        return {"error":"STORAGE UNAVAILABLE"}
    var written := file.store_string(text)
    file.flush()
    file.close()
    var error := ""
    if not written or FileAccess.get_file_as_string(tmp) != text:
        error = "COULD NOT WRITE TRACK"
    elif not owned_path(path) or (expected == "" and _occupied(path)) \
            or (expected != "" and FileAccess.get_sha256(path) != expected):
        error = "TRACK CHANGED • REOPEN IT AND TRY AGAIN"
    elif DirAccess.rename_absolute(tmp,path) != OK:
        error = "COULD NOT SAVE TRACK"
    if error != "":
        DirAccess.remove_absolute(tmp)
        return {"error":error}
    return {"path":path,"data":raw}

static func _race_active() -> bool:
    var tree := Engine.get_main_loop() as SceneTree
    return tree != null and tree.current_scene != null and tree.current_scene.scene_file_path == "res://scenes/race.tscn"

static func trash(path: String, expected: String) -> String:
    if _race_active():
        return "FINISH THE ACTIVE RACE FIRST"
    if expected == "" or read(path).is_empty() or FileAccess.get_sha256(path) != expected:
        return "TRACK CHANGED OR IS UNAVAILABLE"
    if not _trash_available() or DirAccess.make_dir_recursive_absolute(TRASH) != OK:
        return "TRACK TRASH IS UNAVAILABLE"
    var target := TRASH.path_join(path.get_file())
    if FileAccess.file_exists(target) or DirAccess.dir_exists_absolute(target) \
            or DirAccess.open(TRASH).is_link(path.get_file()) or DirAccess.rename_absolute(path,target) != OK:
        return "COULD NOT MOVE TRACK TO TRASH"
    if str(ProjectSettings.get_setting("nitro/selected_track","")) == path:
        ProjectSettings.set_setting("nitro/selected_track",FALLBACK)
    if str(ProjectSettings.get_setting("nitro/terrain_edit_track","")) == path:
        ProjectSettings.set_setting("nitro/terrain_edit_track","")
    if PROFILE.last_track() == path:
        PROFILE.set_last_track(FALLBACK)
    if FileAccess.file_exists(LAST_EDIT) and FileAccess.get_file_as_string(LAST_EDIT).strip_edges() == path:
        DirAccess.remove_absolute(LAST_EDIT)
    return ""

static func restore(path: String) -> String:
    if not owned_path(path) or not _trash_available():
        return "TRACK IS UNAVAILABLE"
    var trashed := DirAccess.open(TRASH)
    var source := TRASH.path_join(path.get_file())
    if trashed == null or trashed.is_link(path.get_file()) or not _compile(_read(source)).get("ok",false):
        return "TRACK IS UNAVAILABLE"
    if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path):
        return "A FILE ALREADY USES THIS TRACK SLOT"
    return "" if DirAccess.rename_absolute(source,path) == OK else "COULD NOT RESTORE TRACK"

static func mark_recent(path: String) -> void:
    var recent := FileAccess.open(LAST_EDIT,FileAccess.WRITE)
    if recent != null:
        recent.store_string(path)
        recent.close()
