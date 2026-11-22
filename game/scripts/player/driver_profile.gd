extends RefCounted
class_name NitroDriverProfile
## The local player card (v0.1.35, owner request 2026-11-22): nickname, avatar
## (skin / hair / t-shirt colours + hair style) and the last chosen track.
## Local device only, no account, no network.
## NOTE: the accessors are get_driver_name / set_driver_name on purpose: a static
## `get_name` / `set_name` on a preloaded script is shadowed by the built-in
## Resource.get_name / set_name and silently returns null (found by
## tests/driver_profile_test.gd in the PR #15 version).
const PATH: String = "user://nitro_driver.cfg"
const DEFAULT_NAME: String = "DRIVER"
## Length rules (the results table, the profile card and the menus are designed
## for them): a player name has 2 .. 14 characters, a car label (catalog "short")
## at most 14. tests/player_profile_test.gd checks every catalog car.
const MIN_LENGTH: int = 2
const MAX_LENGTH: int = 14
const CAR_LABEL_MAX: int = 14
## Characters a name may contain (anything else is dropped): letters, digits,
## space and - _ . '
const ALLOWED_PUNCTUATION: String = " -_.'"

## Avatar palettes (index = saved choice).
const SKIN: Array[Color] = [Color("f6d3b3"),Color("e9b98f"),Color("d09a6c"),Color("a8714a"),Color("7a4b2e"),Color("4f2f1d")]
const HAIR: Array[Color] = [Color("17130f"),Color("4a2e1b"),Color("8a5a2b"),Color("d9b45a"),Color("c8451d"),Color("8e8e96"),Color("7b3fe4"),Color("e13f93")]
const SHIRT: Array[Color] = [Color("e13f93"),Color("7b3fe4"),Color("2f7de1"),Color("23b5a0"),Color("39c26b"),Color("f2c230"),Color("f08a2c"),Color("d6342c"),Color("eeeef2"),Color("22222a")]
const HAIR_STYLES: Array[String] = ["SHORT","LONG","BUZZ","CAP"]

static func _cfg() -> ConfigFile:
    var cfg := ConfigFile.new()
    cfg.load(PATH)
    return cfg

## The typed name reduced to what is allowed: allowed characters only (Latin
## letters incl. Polish ones, digits, space - _ . '), collapsed spaces, trimmed,
## <= MAX_LENGTH. May be empty.
static func _filter(value: String) -> String:
    var kept: String = ""
    for i in range(value.length()):
        var ch: String = value.substr(i,1)
        var code: int = ch.unicode_at(0)
        var letter: bool = (code >= 48 and code <= 57) or (code >= 65 and code <= 90) \
            or (code >= 97 and code <= 122) or (code >= 192 and code <= 591)
        if letter or ALLOWED_PUNCTUATION.contains(ch):
            kept += ch
    kept = kept.strip_edges()
    while kept.contains("  "):
        kept = kept.replace("  "," ")
    return kept.substr(0,MAX_LENGTH).strip_edges()

## Cleaned player name, DEFAULT_NAME when nothing usable is left.
static func clean(value: String) -> String:
    var kept: String = _filter(value)
    return kept if not kept.is_empty() else DEFAULT_NAME

## A name the player may confirm: at least MIN_LENGTH usable characters typed.
static func is_valid_input(value: String) -> bool:
    return _filter(value).length() >= MIN_LENGTH

## True once the player has told us their name (first-launch question answered).
static func has_profile() -> bool:
    var cfg := ConfigFile.new()
    return cfg.load(PATH) == OK and cfg.has_section_key("player","driver_name")

static func get_driver_name() -> String:
    var cfg := ConfigFile.new()
    if cfg.load(PATH) != OK:
        return DEFAULT_NAME
    return clean(str(cfg.get_value("player","driver_name",DEFAULT_NAME)))

static func set_driver_name(value: String) -> String:
    var chosen: String = clean(value)
    var cfg := _cfg()
    cfg.set_value("player","driver_name",chosen)
    cfg.save(PATH)
    return chosen

# ----------------------------------------------------------------- avatar

static func palette(part: String) -> Array[Color]:
    match part:
        "skin":
            return SKIN
        "hair":
            return HAIR
        _:
            return SHIRT

## {"skin": i, "hair": i, "shirt": i, "style": i} (indexes, always in range).
static func avatar() -> Dictionary:
    var cfg := _cfg()
    return {
        "skin":clampi(int(cfg.get_value("avatar","skin",1)),0,SKIN.size()-1),
        "hair":clampi(int(cfg.get_value("avatar","hair",1)),0,HAIR.size()-1),
        "shirt":clampi(int(cfg.get_value("avatar","shirt",0)),0,SHIRT.size()-1),
        "style":clampi(int(cfg.get_value("avatar","style",0)),0,HAIR_STYLES.size()-1)}

## Next choice of one avatar part (skin / hair / shirt / style), saved.
static func cycle_avatar(part: String) -> Dictionary:
    var a: Dictionary = avatar()
    var size: int = HAIR_STYLES.size() if part == "style" else palette(part).size()
    a[part] = (int(a[part])+1) % size
    var cfg := _cfg()
    for key in a.keys():
        cfg.set_value("avatar",key,int(a[key]))
    cfg.save(PATH)
    return a

# ------------------------------------------------------------- last track

static func last_track() -> String:
    return str(_cfg().get_value("player","last_track",""))

static func set_last_track(path: String) -> void:
    var cfg := _cfg()
    cfg.set_value("player","last_track",path)
    cfg.save(PATH)
