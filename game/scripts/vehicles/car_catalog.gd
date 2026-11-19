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

const ORDER: Array[String] = ["red","white","blue"]
const CARS: Dictionary = {
    "red":{"name":"LADA 2106 DRIFT SPEC","paint":"RACING RED","short":"LADA • RED",
        "length":4.166,"wheelbase":2.424,"width":1.91,"note":"EXPOSED ENGINE",
        "profile":"res://cars/lada_baseline.json"},
    "white":{"name":"LADA 2106 DRIFT SPEC","paint":"PEARL WHITE","short":"LADA • WHITE",
        "length":4.166,"wheelbase":2.424,"width":1.91,"note":"CLEAN HOOD",
        "profile":"res://cars/lada_baseline.json"},
    "blue":{"name":"RYU-32 COUPE","paint":"DEEP BLUE","short":"RYU-32 • BLUE",
        "length":4.545,"wheelbase":2.615,"width":1.90,"note":"4.0 V8 ITB • 350 HP • 400 NM",
        "profile":"res://cars/ryu32_v8.json"},
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
    var cfg := ConfigFile.new()
    if cfg.load(SETTINGS_PATH) != OK:
        return false
    return bool(cfg.get_value("developer","baseline_physics",false))

static func set_baseline_physics_forced(on: bool) -> void:
    var cfg := ConfigFile.new()
    cfg.load(SETTINGS_PATH)
    cfg.set_value("developer","baseline_physics",on)
    cfg.save(SETTINGS_PATH)

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

## New car node for a variant (Lada red/white or the RYU-32 coupe).
static func make(variant: String) -> Node3D:
    var v: String = valid(variant)
    if v == "blue":
        return COUPE.new()
    var lada: NitroLadaLowPoly = LADA.new()
    lada.paint_variant = v
    return lada
