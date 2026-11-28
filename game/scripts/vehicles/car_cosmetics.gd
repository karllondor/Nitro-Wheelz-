extends RefCounted
class_name NitroCarCosmetics
## Cosmetic choices of a Car Factory car (paint colour + finish, wheels,
## livery), saved per car in the garage file and kept apart from physics:
## nothing here is ever read by the drive model or the handling profile.
##
## Every car profile with a "cosmetics" block has an immutable SIGNATURE
## preset (the authentic look of the reference car). The player's choice is
## stored separately; SIGNATURE always resets to the original.

const GARAGE_PATH: String = "user://nitro_garage.cfg"
const WHEELS_PATH: String = "res://assets/cars/wheels/wheels.json"
const SAVE_FIELDS: Array[String] = ["paint_color_hex","paint_finish","wheel_asset_id","wheel_finish","livery_id"]
const FINISHES: Dictionary = {
    # roughness, metallic, gloss (studio reflection), clear-coat rim
    "solid":{"roughness":0.22,"metallic":0.05,"gloss":0.74,"rim":0.45},
    "metallic":{"roughness":0.20,"metallic":0.55,"gloss":0.85,"rim":0.50},
    "pearl":{"roughness":0.18,"metallic":0.30,"gloss":0.95,"rim":0.70},
}
static var _wheels: Dictionary = {}

static func wheels() -> Dictionary:
    if _wheels.is_empty():
        var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(WHEELS_PATH))
        _wheels = raw.get("wheels",{}) if raw is Dictionary else {}
    return _wheels

static func block(profile: Dictionary) -> Dictionary:
    return profile.get("cosmetics",{})

static func supported(profile: Dictionary) -> bool:
    return not block(profile).is_empty()

static func signature(profile: Dictionary) -> Dictionary:
    return (block(profile).get("signature",{}) as Dictionary).duplicate()

## The look the player chose for this car (falls back to SIGNATURE).
static func current(variant: String, profile: Dictionary) -> Dictionary:
    var choice: Dictionary = signature(profile)
    if choice.is_empty():
        return choice
    var cfg := ConfigFile.new()
    if cfg.load(GARAGE_PATH) == OK:
        var section: String = "cosmetics_"+variant
        for key in SAVE_FIELDS:
            if cfg.has_section_key(section,key):
                choice[key] = str(cfg.get_value(section,key))
    return sanitize(choice,profile)

## Unknown wheels / finishes / colours fall back to the signature values.
static func sanitize(choice: Dictionary, profile: Dictionary) -> Dictionary:
    var sig: Dictionary = signature(profile)
    var out: Dictionary = choice.duplicate()
    if not (block(profile).get("wheels",[]) as Array).has(str(out.get("wheel_asset_id",""))) \
            or not wheels().has(str(out.get("wheel_asset_id",""))):
        out["wheel_asset_id"] = sig.get("wheel_asset_id","")
    if not FINISHES.has(str(out.get("paint_finish",""))):
        out["paint_finish"] = sig.get("paint_finish","solid")
    if not Color.html_is_valid(str(out.get("paint_color_hex",""))):
        out["paint_color_hex"] = sig.get("paint_color_hex","#ffffff")
    # Retuned palette colours (e.g. E30 v0.2 Blessed Yellow) keep their name.
    var aliases: Dictionary = block(profile).get("paint_aliases",{})
    var hex: String = str(out.get("paint_color_hex","")).to_upper()
    for old in aliases.keys():
        if str(old).to_upper() == hex:
            out["paint_color_hex"] = str(aliases[old])
    var allowed_liveries: Array[String] = ["clean"]
    for p in paints(profile):
        if p is Dictionary:
            var lid: String = str(p.get("livery_id","clean"))
            if not allowed_liveries.has(lid):
                allowed_liveries.append(lid)
    if not allowed_liveries.has(str(out.get("livery_id","clean"))):
        out["livery_id"] = sig.get("livery_id","clean")
    return out

static func save(variant: String, choice: Dictionary) -> void:
    var cfg := ConfigFile.new()
    cfg.load(GARAGE_PATH)
    var section: String = "cosmetics_"+variant
    for key in SAVE_FIELDS:
        if choice.has(key):
            cfg.set_value(section,key,str(choice[key]))
    cfg.save(GARAGE_PATH)

static func reset_to_signature(variant: String, profile: Dictionary) -> Dictionary:
    var cfg := ConfigFile.new()
    if cfg.load(GARAGE_PATH) == OK and cfg.has_section("cosmetics_"+variant):
        cfg.erase_section("cosmetics_"+variant)
        cfg.save(GARAGE_PATH)
    return signature(profile)

static func is_signature(choice: Dictionary, profile: Dictionary) -> bool:
    var sig: Dictionary = signature(profile)
    for key in SAVE_FIELDS:
        if str(choice.get(key,"")).to_lower() != str(sig.get(key,"")).to_lower():
            return false
    return true

static func paints(profile: Dictionary) -> Array:
    return block(profile).get("paints",[])

static func paint_index(choice: Dictionary, profile: Dictionary) -> int:
    var list: Array = paints(profile)
    for i in range(list.size()):
        var p: Dictionary = list[i]
        if str(p["hex"]).to_lower() == str(choice.get("paint_color_hex","")).to_lower() \
                and str(p["finish"]) == str(choice.get("paint_finish","")) \
                and str(p.get("livery_id","clean")) == str(choice.get("livery_id","clean")):
            return i
    return -1

static func paint_name(choice: Dictionary, profile: Dictionary) -> String:
    var i: int = paint_index(choice,profile)
    return str(paints(profile)[i]["name"]) if i >= 0 else "CUSTOM"

## Next paint preset (cycles through the profile's palette) and saves it.
static func next_paint(variant: String, profile: Dictionary) -> Dictionary:
    var choice: Dictionary = current(variant,profile)
    var list: Array = paints(profile)
    if list.is_empty():
        return choice
    var p: Dictionary = list[(paint_index(choice,profile)+1)%list.size()]
    choice["paint_color_hex"] = str(p["hex"])
    choice["paint_finish"] = str(p["finish"])
    choice["livery_id"] = str(p.get("livery_id","clean"))
    save(variant,choice)
    return choice

## A specific paint preset (garage swatch row, v0.1.52) and saves it; same fields as next_paint.
static func choose_paint(variant: String, profile: Dictionary, index: int) -> Dictionary:
    var choice: Dictionary = current(variant,profile)
    var list: Array = paints(profile)
    if index < 0 or index >= list.size():
        return choice
    var p: Dictionary = list[index]
    choice["paint_color_hex"] = str(p["hex"])
    choice["paint_finish"] = str(p["finish"])
    choice["livery_id"] = str(p.get("livery_id","clean"))
    save(variant,choice)
    return choice

static func next_wheel(variant: String, profile: Dictionary) -> Dictionary:
    var choice: Dictionary = current(variant,profile)
    var list: Array = block(profile).get("wheels",[])
    if list.is_empty():
        return choice
    var i: int = list.find(str(choice.get("wheel_asset_id","")))
    choice["wheel_asset_id"] = str(list[(i+1)%list.size()])
    save(variant,choice)
    return choice

static func wheel_name(choice: Dictionary) -> String:
    var w: Dictionary = wheels().get(str(choice.get("wheel_asset_id","")),{})
    return str(w.get("name","?"))

## Paint material parameters for a choice (colour + finish preset).
static func paint_params(choice: Dictionary) -> Dictionary:
    var p: Dictionary = (FINISHES.get(str(choice.get("paint_finish","solid")),FINISHES["solid"]) as Dictionary).duplicate()
    p["paint"] = Color.html(str(choice.get("paint_color_hex","#ffffff")))
    return p
