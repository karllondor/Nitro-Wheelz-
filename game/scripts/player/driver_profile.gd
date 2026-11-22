extends RefCounted
class_name NitroDriverProfile
## Local display identity; no network account or online leaderboard.
## NOTE: the accessors are get_driver_name / set_driver_name on purpose: a static
## `get_name` / `set_name` on a preloaded script is shadowed by the built-in
## Resource.get_name / set_name and silently returns null (found by
## tests/driver_profile_test.gd in the PR #15 version).
const PATH: String = "user://nitro_driver.cfg"
const DEFAULT_NAME: String = "DRIVER"
const MAX_LENGTH: int = 16

static func clean(value: String) -> String:
    var out: String = value.strip_edges().replace("\n"," ").replace("\r"," ").replace("\t"," ")
    while out.contains("  "):
        out = out.replace("  "," ")
    out = out.substr(0,MAX_LENGTH).strip_edges()
    return out if not out.is_empty() else DEFAULT_NAME

static func get_driver_name() -> String:
    var cfg := ConfigFile.new()
    if cfg.load(PATH) != OK:
        return DEFAULT_NAME
    return clean(str(cfg.get_value("player","driver_name",DEFAULT_NAME)))

static func set_driver_name(value: String) -> String:
    var chosen: String = clean(value)
    var cfg := ConfigFile.new()
    cfg.load(PATH)
    cfg.set_value("player","driver_name",chosen)
    cfg.save(PATH)
    return chosen
