extends RefCounted
class_name NitroCarCatalog
## The selectable cars. A "variant" id is what the garage stores
## (user://nitro_garage.cfg) and passes to the race (nitro/car_variant).
## Each variant points at a car PROFILE (game/cars/*.json): handling numbers
## for the shared drive model and an engine/sound block for the synth. Paint
## variants of one car share one mechanical profile (Lada red/white ->
## lada_baseline). Profiles are data, so cars can be tuned without touching
## the driving code; the Lada baseline stays the 1:1 reference.
const LADA = preload("res://scripts/vehicles/lada_lowpoly.gd")
const COUPE = preload("res://scripts/vehicles/coupe_lowpoly.gd")
const FACTORY_CAR = preload("res://scripts/vehicles/glb_car.gd")
const COSMETICS = preload("res://scripts/vehicles/car_cosmetics.gd")
const DEV = preload("res://scripts/dev_settings.gd")
const COSMETIC_DATA_PATH: String = "res://cars/car_factory_cosmetics.json"

const ORDER: Array[String] = ["red","white","blue","e30"]
const CARS: Dictionary = {
    "red":{"name":"LADA 2106 DRIFT SPEC","paint":"RACING RED","short":"LADA • RED",
        "length":4.166,"wheelbase":2.424,"width":1.91,"note":"EXPOSED ENGINE",
        "profile":"res://cars/lada_baseline.json","factory_model":"res://cars/models/lada_2106.json"},
    "white":{"name":"LADA 2106 DRIFT SPEC","paint":"PEARL WHITE","short":"LADA • WHITE",
        "length":4.166,"wheelbase":2.424,"width":1.91,"note":"CLEAN HOOD",
        "profile":"res://cars/lada_baseline.json","factory_model":"res://cars/models/lada_2106.json"},
    "blue":{"name":"RYU-32 COUPE","paint":"DEEP BLUE","short":"RYU-32 • BLUE",
        "length":4.545,"wheelbase":2.615,"width":1.90,"note":"4.0 V8 ITB • 350 HP • 400 NM",
        "profile":"res://cars/ryu32_v8.json","factory_model":"res://cars/models/ryu32.json"},
    # Car Factory prototype (Blender -> GLB). Cosmetics (paint, wheels) are
    # chosen in the garage and stored apart from the handling profile.
    "e30":{"name":"E30 BLESSED","paint":"BLESSED YELLOW","short":"E30 • BLESSED",
        "length":4.325,"wheelbase":2.570,"width":1.645,"note":"M52B28 2.8 R6 • NA",
        "body":"4-DOOR SEDAN","factory":true,
        "profile":"res://cars/e30_blessed.json"},
}

const SETTINGS_PATH: String = "user://nitro_settings.cfg"
static var _profiles: Dictionary = {}

## Car profile (handling + engine) for a variant, read once from JSON.
static func profile(variant: String) -> Dictionary:
    var path: String = str(info(variant)["profile"])
    if not _profiles.has(path):
        var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
        _profiles[path] = raw if raw is Dictionary else {}
    return _profiles[path]

## DEVELOPER switch: drive every car on the Lada baseline physics (the way
## back to the old behaviour). Sound and looks still follow the car.
static func baseline_physics_forced() -> bool:
    return bool(DEV.get_value("developer","baseline_physics",false))

static func set_baseline_physics_forced(on: bool) -> void:
    DEV.set_value("developer","baseline_physics",on)

## DEVELOPER switch (v0.1.30): show the Car Factory TEST models (Blender ->
## GLB) of cars that still have an approved procedural model. OFF by
## default: the old model stays until the owner accepts the new one. Looks
## only: handling, sound, collisions and saves never change.
static func factory_test_models() -> bool:
    return not bool(DEV.get_value("developer","legacy_procedural_cars",false))

static func set_factory_test_models(on: bool) -> void:
    DEV.set_value("developer","legacy_procedural_cars",not on)

## DEVELOPER: which look a factory test model with several looks wears
## (RYU-32: "clean" or "livery"). Looks only.
static func factory_test_look() -> String:
    return str(DEV.get_value("developer","factory_test_look","clean"))

static func set_factory_test_look(look: String) -> void:
    DEV.set_value("developer","factory_test_look",look)

static var _models: Dictionary = {}
static var _cosmetics_data: Dictionary = {}

## Cosmetic presets are independent of the physics profile and of the
## Blender-generated model JSON (a model rebuild must not erase choices).
static func cosmetic_profile(variant: String) -> Dictionary:
    var v: String = valid(variant)
    var original: Dictionary = profile(v)
    if COSMETICS.supported(original):
        return original
    if _cosmetics_data.is_empty():
        var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(COSMETIC_DATA_PATH))
        _cosmetics_data = raw if raw is Dictionary else {}
    return {"cosmetics":_cosmetics_data.get(v,{})}

## One appearance pipeline for the garage and race. On RYU-32 the stripes
## are a selectable PAINT preset; both versions share the exact same GLB.
static func visual_choice(variant: String, choice: Dictionary) -> Dictionary:
    var out: Dictionary = choice.duplicate(true)
    var fm: Dictionary = factory_model(variant)
    if not fm.is_empty():
        out["paint_shader"] = (fm["look"] as Dictionary).get("paint_shader",{})
    if valid(variant) == "blue":
        out["livery_texture"] = "res://assets/cars/ryu32/ryu32_livery_provisional.png" \
            if str(out.get("livery_id","clean")) == "stripes" else ""
    return out

## {"model": <model block for NitroGlbCar>, "look": <paint + wheels>} of a
## variant's Car Factory test model, or {} when it has none.
static func factory_model(variant: String) -> Dictionary:
    var path: String = str(info(variant).get("factory_model",""))
    if path == "" or not FileAccess.file_exists(path):
        return {}
    if not _models.has(path):
        var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
        _models[path] = raw if raw is Dictionary else {}
    var data: Dictionary = _models[path]
    var v: Dictionary = (data.get("variants",{}) as Dictionary).get(valid(variant),{})
    if v.is_empty():
        return {}
    var model: Dictionary = data.duplicate()
    model.erase("variants")
    model["variant_slot"] = int(v.get("variant_slot",0))
    var look: Dictionary = {}
    for key in ["paint_color_hex","paint_finish","wheel_asset_id"]:
        look[key] = str(v.get(key,""))
    look["paint_shader"] = v.get("paint_shader",{})
    var looks: Dictionary = v.get("looks",{})
    if not looks.is_empty():
        var chosen: String = factory_test_look() if looks.has(factory_test_look()) else str(looks.keys()[0])
        look["look"] = chosen
        look["livery_texture"] = str((looks[chosen] as Dictionary).get("livery_texture",""))
    return {"model":model,"look":look}

## True when this variant is shown with its Car Factory test model.
static func uses_factory_test_model(variant: String) -> bool:
    return factory_test_models() and not factory_model(variant).is_empty()

static func handling(variant: String) -> Dictionary:
    if baseline_physics_forced():
        return {}
    return profile(variant).get("handling",{})

static func engine(variant: String) -> Dictionary:
    return profile(variant).get("engine",{})

static func valid(variant: String) -> String:
    return variant if CARS.has(variant) else "red"

static func info(variant: String) -> Dictionary:
    return CARS[valid(variant)]

## New car node for a variant (Lada red/white, the RYU-32 coupe or a Car
## Factory GLB car wearing its saved cosmetics: same node in garage + race).
static func make(variant: String) -> Node3D:
    var v: String = valid(variant)
    if uses_factory_test_model(v):
        var fm: Dictionary = factory_model(v)
        return FACTORY_CAR.new().setup(v,{"model":fm["model"]},
            visual_choice(v,COSMETICS.current(v,cosmetic_profile(v))))
    if v == "blue":
        return COUPE.new()
    if bool(info(v).get("factory",false)):
        var prof: Dictionary = profile(v)
        return FACTORY_CAR.new().setup(v,prof,COSMETICS.current(v,prof))
    var lada: NitroLadaLowPoly = LADA.new()
    lada.paint_variant = v
    return lada

const GARAGE_PATH: String = "user://nitro_garage.cfg"

## The car the player drives: this session's garage choice, else the one
## saved by the garage (survives app restarts even when the player goes
## straight to DRIVE without opening the garage), else the red Lada.
static func selected() -> String:
    if ProjectSettings.has_setting("nitro/car_variant"):
        return valid(str(ProjectSettings.get_setting("nitro/car_variant")))
    var chosen: String = "red"
    var cfg := ConfigFile.new()
    if cfg.load(GARAGE_PATH) == OK:
        chosen = str(cfg.get_value("garage","paint","red"))
    chosen = valid(chosen)
    ProjectSettings.set_setting("nitro/car_variant",chosen)
    return chosen

## Garage choice: used by the next race and saved for the next app start.
static func select(variant: String) -> String:
    var chosen: String = valid(variant)
    ProjectSettings.set_setting("nitro/car_variant",chosen)
    var cfg := ConfigFile.new()
    cfg.load(GARAGE_PATH)   # keep other sections (per-car cosmetics)
    cfg.set_value("garage","paint",chosen)
    cfg.save(GARAGE_PATH)
    return chosen
