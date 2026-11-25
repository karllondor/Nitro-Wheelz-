extends RefCounted
class_name NitroCarCatalog
## The selectable cars. A "variant" id is what the garage stores
## (user://nitro_garage.cfg) and passes to the race (nitro/car_variant).
## Each variant points at a car PROFILE (game/cars/*.json): handling numbers
## for the shared drive model and an engine/sound block for the synth. The RED
## Lada (lada_13b: the handling numbers of lada_baseline + the rotary engine of
## the real build) and the WHITE Lada (lada_n20: the same chassis numbers + the
## tuned BMW N20B20 turbo four, owner decision 2026-11-22) are two different
## mechanical cars on one body. Profiles are data, so cars can be tuned without touching the
## driving code; the Lada handling stays the 1:1 reference (lada_baseline.json
## is kept as the benchmark file for the physics and sound fingerprints).
const LADA = preload("res://scripts/vehicles/lada_lowpoly.gd")
const COUPE = preload("res://scripts/vehicles/coupe_lowpoly.gd")
const FACTORY_CAR = preload("res://scripts/vehicles/glb_car.gd")
const COSMETICS = preload("res://scripts/vehicles/car_cosmetics.gd")
const DEV = preload("res://scripts/dev_settings.gd")
const DRIVE = preload("res://scripts/driving/drive_model.gd")
const COSMETIC_DATA_PATH: String = "res://cars/car_factory_cosmetics.json"

const ORDER: Array[String] = ["red","white","blue","e30","flame"]
const CARS: Dictionary = {
    "red":{"name":"LADA 2106 DRIFT SPEC","paint":"RACING RED","short":"LADA • RED",
        "length":4.166,"wheelbase":2.424,"width":1.91,"note":"13B ROTARY • EXPOSED",
        "profile":"res://cars/lada_13b.json","factory_model":"res://cars/models/lada_2106.json"},
    "white":{"name":"LADA 2106 DRIFT SPEC","paint":"PEARL WHITE","short":"LADA • WHITE",
        "length":4.166,"wheelbase":2.424,"width":1.91,"note":"N20B20 TURBO • STAGE 1 • CLEAN HOOD",
        "profile":"res://cars/lada_n20.json","factory_model":"res://cars/models/lada_2106.json"},
    "blue":{"name":"RYU-32 COUPE","paint":"DEEP BLUE","short":"RYU-32 • BLUE",
        "length":4.545,"wheelbase":2.615,"width":1.90,"note":"4.0 V8 ITB • 350 HP • 400 NM",
        "profile":"res://cars/ryu32_v8.json","factory_model":"res://cars/models/ryu32.json"},
    # Car Factory prototype (Blender -> GLB). Cosmetics (paint, wheels) are
    # chosen in the garage and stored apart from the handling profile.
    "e30":{"name":"E30 BLESSED","paint":"BLESSED YELLOW","short":"E30 • BLESSED",
        "length":4.325,"wheelbase":2.570,"width":1.645,"note":"M52B28 2.8 R6 • NA",
        "body":"4-DOOR SEDAN","factory":true,
        "profile":"res://cars/e30_blessed.json"},
    # AI TEST car (v0.1.33): a separate car wearing a body generated with an
    # image-to-3D service (free plan: NOT FOR RELEASE). It drives exactly like
    # the RYU-32 (same handling, V8 sound, footprint); looks only.
    "flame":{"name":"RYU-32 FLAME (AI TEST)","paint":"FLAME BLUE","short":"R32 • FLAME",
        "length":4.545,"wheelbase":2.615,"width":1.90,"note":"AI TEST BODY • 4.0 V8 ITB",
        "profile":"res://cars/ryu32_v8.json","factory_model":"res://cars/models/ryu32_flame.json","factory_only":true},
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

## v0.1.34 (owner decision 2026-11-22, issue #22): the Car Factory GLB models
## (Blender -> GLB) are the NORMAL player-visible models of Lada RED / WHITE and
## RYU-32. DEVELOPER > CAR FACTORY GLB CARS = OFF shows the earlier procedural
## models for comparison. Stored as "legacy_procedural_cars" (default false): an
## old saved "factory_test_models" value (the previous opt-in switch, default
## OFF) is ignored, so every install gets the GLB cars. Looks only: handling,
## sound, collisions and saves never change.
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

## Cosmetic presets (paint palette, wheels, SIGNATURE) of a car. A profile with
## its own "cosmetics" block (E30) keeps it; the Car Factory cars take theirs
## from game/cars/car_factory_cosmetics.json, apart from the physics profile and
## from the Blender-generated model JSON (a model rebuild must not erase them).
## Cars without presets (the AI test body: paint is baked) return an empty block.
static func cosmetic_profile(variant: String) -> Dictionary:
    var v: String = valid(variant)
    var original: Dictionary = profile(v)
    if COSMETICS.supported(original):
        return original
    if _cosmetics_data.is_empty():
        var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(COSMETIC_DATA_PATH))
        _cosmetics_data = raw if raw is Dictionary else {}
    return {"cosmetics":_cosmetics_data.get(v,{})}

## One appearance pipeline for the garage and the race: the saved choice plus
## what belongs to the model (paint shader tweaks, and for the RYU-32 the stripes
## livery, which is a normal PAINT preset on the same GLB).
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
    var fm: Dictionary = factory_model(variant)
    if fm.is_empty():
        return false
    if bool(info(variant).get("factory_only",false)):
        return ResourceLoader.exists(str((fm["model"] as Dictionary).get("glb","")))   # cars that only exist as a GLB
    return factory_test_models()

## v0.1.38 (owner decision 2026-11-22, issue #25 c7080962400): the physics MODE.
##  ARCADE_PLUS (default, "C+"): the approved arcade handling and the same 0-100 km/h, with the
##    implausibly low top speed of every car lifted to a documented per-car target above 100 km/h.
##  REAL_POWER_TEST (DEVELOPER only, "A"): a power-curve drivetrain with game-shifted gears and real
##    drag replaces the constant drive force (steering / grip / drift stay arcade). Not saved to
##    records or stars (race_results.gd); applies when a race starts.
const MODE_ARCADE_PLUS: String = "ARCADE_PLUS"
const MODE_REAL_POWER: String = "REAL_POWER_TEST"
const MODES: Array[String] = [MODE_ARCADE_PLUS,MODE_REAL_POWER]

static func physics_mode() -> String:
    var m: String = str(DEV.get_value("developer","physics_mode",MODE_ARCADE_PLUS))
    return m if MODES.has(m) else MODE_ARCADE_PLUS

static func set_physics_mode(mode: String) -> void:
    DEV.set_value("developer","physics_mode",mode if MODES.has(mode) else MODE_ARCADE_PLUS)

## True when the A diagnostic drivetrain is on for races (the legacy BASELINE switch wins over it).
static func real_power_active() -> bool:
    return physics_mode() == MODE_REAL_POWER and not baseline_physics_forced()

## Handling numbers of a car in the current mode. BASELINE (developer switch) = none (Lada defaults).
static func handling(variant: String, mode: String = "") -> Dictionary:
    if baseline_physics_forced():
        return {}
    var h: Dictionary = profile(variant).get("handling",{})
    if (mode if mode != "" else physics_mode()) == MODE_ARCADE_PLUS:
        var plus: Dictionary = arcade_plus(variant)
        if not plus.is_empty():
            h = h.duplicate()
            h.merge(plus,true)
    return h

## ARCADE_PLUS additions of a car (top speed target -> drag above the knee), or {} when it has none.
static func arcade_plus(variant: String) -> Dictionary:
    var block: Dictionary = profile(variant).get("arcade_plus",{})
    if block.is_empty():
        return {}
    return DRIVE.arcade_plus_for(profile(variant).get("handling",{}),float(block["top_kmh"]),float(block.get("knee_mps",28.0)))

## Power-curve drivetrain of a car for REAL_POWER_TEST: its "real_power" block + the engine block
## (idle / limiter / gear table, the same numbers the engine sound uses).
static func real_power(variant: String) -> Dictionary:
    var prof: Dictionary = profile(variant)
    if not prof.has("real_power"):
        return {}
    var rp: Dictionary = (prof["real_power"] as Dictionary).duplicate()
    var eng: Dictionary = prof.get("engine",{})
    rp["idle_rpm"] = float(eng.get("idle_rpm",900.0))
    rp["limit_rpm"] = float(eng.get("limit_rpm",7000.0))
    rp["shift_up_rpm"] = float(eng.get("gear_end_rpm",6500.0))
    rp["gear_top_kmh"] = eng.get("gear_top_kmh",[48.0,82.0,116.0,150.0,195.0])
    return rp

## The one place that sets a drive model up for a car: handling + (A mode) the power-curve drivetrain.
static func configure_model(model, variant: String, mode: String = "") -> void:
    var m: String = mode if mode != "" else physics_mode()
    model.apply_profile(handling(variant,m))
    if m == MODE_REAL_POWER and not baseline_physics_forced():
        var rp: Dictionary = real_power(variant)
        if not rp.is_empty():
            model.apply_real_power(rp)

static func engine(variant: String) -> Dictionary:
    return profile(variant).get("engine",{})

static func valid(variant: String) -> String:
    return variant if CARS.has(variant) else "red"

static func info(variant: String) -> Dictionary:
    return CARS[valid(variant)]

## New car node for a variant (Lada red/white, the RYU-32 coupe or a Car
## Factory GLB car wearing its saved cosmetics: same node in garage + race).
static func make(variant: String, remote_choice: Variant = null) -> Node3D:
    var v: String = valid(variant)
    if uses_factory_test_model(v):
        var fm: Dictionary = factory_model(v)
        var cprof: Dictionary = cosmetic_profile(v)
        # Cars with presets wear the player's saved look; the others (AI test
        # body, baked paint) the look from their model file.
        var chosen: Dictionary = COSMETICS.current(v,cprof) if COSMETICS.supported(cprof) else (fm["look"] as Dictionary)
        if remote_choice is Dictionary and COSMETICS.supported(cprof):
            chosen = COSMETICS.sanitize(remote_choice,cprof)
        return FACTORY_CAR.new().setup(v,{"model":fm["model"]},visual_choice(v,chosen))
    if v == "blue" or v == "flame":      # "flame" without its GLB falls back to the coupe
        return COUPE.new()
    if bool(info(v).get("factory",false)):
        var prof: Dictionary = profile(v)
        return FACTORY_CAR.new().setup(v,prof,COSMETICS.sanitize(remote_choice,prof) if remote_choice is Dictionary else COSMETICS.current(v,prof))
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
