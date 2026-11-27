extends RefCounted
class_name NitroForestLabSettings
## FOREST LAB (issue #54) - experimental, developer-only settings. They live in the DEVELOPER file (user://nitro_dev.cfg,
## section [forest_lab]) and in user://forest_lab_presets/*.json, NEVER in the player's settings or saves. The default is
## CLASSIC: a build that never touches DEVELOPER > FOREST LAB draws exactly the trees it drew before.
const DEV = preload("res://scripts/dev_settings.gd")
const F = preload("res://scripts/world/forest_lab/nitro_tree_factory.gd")
const SECTION: String = "forest_lab"
const PRESET_DIR: String = "user://forest_lab_presets"
const MODES: Array[String] = ["classic","lab"]
const DENSITY_NAMES: Array[String] = ["LOW","MEDIUM","HIGH"]
## Spacing = 11 m / sqrt(mult): CLASSIC uses 11 m, so LOW ~ CLASSIC, MEDIUM ~ 1.4x, HIGH ~ 2x the trees the filters accept.
const DENSITY_MULT: Array[float] = [0.85,1.4,2.0]
## Touge stand mix (species id -> weight): pine / fir backbone, birch / oak / rowan mixed stands, maple as an accent,
## sakura rare, shrubs as understory. Species ids are NitroTreeFactory.Type.
const DEFAULT_MIX: Dictionary = {0:0.27,1:0.33,5:0.09,2:0.07,3:0.05,6:0.02,7:0.05,4:0.12}

static func defaults() -> Dictionary:
    return {"mode":"classic","density":1,"season":F.Season.SUMMER,"scale":1.0,"near_distance":120.0,"seed_offset":0,
        "preset":"","mix":DEFAULT_MIX.duplicate(),"params":{}}

static func read() -> Dictionary:
    var d: Dictionary = defaults()
    d["mode"] = str(DEV.get_value(SECTION,"mode","classic"))
    if not MODES.has(d["mode"]):
        d["mode"] = "classic"
    d["density"] = clampi(int(DEV.get_value(SECTION,"density",1)),0,2)
    d["season"] = clampi(int(DEV.get_value(SECTION,"season",F.Season.SUMMER)),0,4)
    d["scale"] = clampf(float(DEV.get_value(SECTION,"scale",1.0)),0.7,1.4)
    d["near_distance"] = clampf(float(DEV.get_value(SECTION,"near_distance",120.0)),60.0,240.0)
    d["seed_offset"] = int(DEV.get_value(SECTION,"seed_offset",0))
    d["preset"] = str(DEV.get_value(SECTION,"preset",""))
    if d["preset"] != "":
        var pr: Dictionary = load_preset(d["preset"])
        if not pr.is_empty():
            d = apply_preset(d,pr)
    return d

static func write_value(key: String, value: Variant) -> void:
    DEV.set_value(SECTION,key,value)

static func mode() -> String:
    return str(read()["mode"])

static func set_mode(m: String) -> void:
    write_value("mode",m if MODES.has(m) else "classic")

# ---------------------------------------------------------------------------------------------- presets

## A preset is plain JSON: {"version":1,"name":..,"season":..,"density":..,"scale":..,"mix":{"0":w,..},"species":{"0":{params},..}}
static func apply_preset(cfg: Dictionary, pr: Dictionary) -> Dictionary:
    var d: Dictionary = cfg.duplicate(true)
    if pr.has("season"):
        d["season"] = clampi(int(pr["season"]),0,4)
    if pr.has("density"):
        d["density"] = clampi(int(pr["density"]),0,2)
    if pr.has("scale"):
        d["scale"] = clampf(float(pr["scale"]),0.7,1.4)
    if pr.get("mix",null) is Dictionary:
        var mix: Dictionary = {}
        for k in (pr["mix"] as Dictionary).keys():
            mix[int(k)] = clampf(float(pr["mix"][k]),0.0,1.0)
        d["mix"] = mix
    var params: Dictionary = {}
    if pr.get("species",null) is Dictionary:
        for k in (pr["species"] as Dictionary).keys():
            params[int(k)] = F.clamp_params(pr["species"][k])
    d["params"] = params
    return d

static func safe_name(raw: String) -> String:
    var out: String = ""
    for ch in raw.strip_edges().to_lower():
        if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") or ch == "_" or ch == "-":
            out += ch
        elif ch == " ":
            out += "_"
    return out.substr(0,32)

static func list_presets() -> Array[String]:
    var out: Array[String] = []
    if DirAccess.dir_exists_absolute(PRESET_DIR):
        for f in DirAccess.get_files_at(PRESET_DIR):
            if f.ends_with(".json"):
                out.append(f.get_basename())
    out.sort()
    return out

static func preset_path(name: String) -> String:
    return PRESET_DIR+"/"+safe_name(name)+".json"

## "" = ok. A name that exists is never overwritten silently (overwrite must be asked for).
static func save_preset(name: String, data: Dictionary, overwrite: bool = false) -> String:
    var n: String = safe_name(name)
    if n == "":
        return "NAME THE PRESET (a-z, 0-9, _ or -)"
    if not DirAccess.dir_exists_absolute(PRESET_DIR):
        DirAccess.make_dir_recursive_absolute(PRESET_DIR)
    var path: String = preset_path(n)
    if FileAccess.file_exists(path) and not overwrite:
        return "PRESET '%s' ALREADY EXISTS - choose another name" % n
    var f := FileAccess.open(path,FileAccess.WRITE)
    if f == null:
        return "DEVICE STORAGE UNAVAILABLE"
    var d: Dictionary = data.duplicate(true)
    d["version"] = 1
    d["name"] = n
    f.store_string(JSON.stringify(d,"  "))
    f.close()
    return ""

static func load_preset(name: String) -> Dictionary:
    var path: String = preset_path(name)
    if not FileAccess.file_exists(path):
        return {}
    return _parse(FileAccess.get_file_as_string(path))

static func parse_json_text(text: String) -> Dictionary:
    var d: Dictionary = _parse(text)
    return d if int(d.get("version",0)) == 1 else {}

## JSON.new().parse() reports a broken file as an error CODE; JSON.parse_string() would also print an engine ERROR.
static func _parse(text: String) -> Dictionary:
    var j := JSON.new()
    if j.parse(text) != OK or not (j.data is Dictionary):
        return {}
    return j.data

static func delete_preset(name: String) -> void:
    var path: String = preset_path(name)
    if FileAccess.file_exists(path):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    if str(DEV.get_value(SECTION,"preset","")) == safe_name(name):
        write_value("preset","")

## The mesh knobs of one species in the active config ({} = stock geometry).
static func params_for(cfg: Dictionary, tree_type: int) -> Dictionary:
    var p: Variant = (cfg.get("params",{}) as Dictionary).get(tree_type,{})
    return p if p is Dictionary else {}
