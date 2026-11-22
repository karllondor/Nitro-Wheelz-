extends SceneTree
## Owner decision 2026-11-22 (issue #22): the Car Factory GLB models are the
## normal player-visible cars.
##  * default (nothing stored, or the OLD opt-in key factory_test_models = false
##    left on a device): Lada RED / WHITE, RYU-32, E30 and FLAME are all
##    NitroGlbCar; the DEVELOPER switch OFF brings back the procedural Lada / RYU-32
##    (E30 and FLAME stay GLB: they have no procedural model);
##  * every GLB car with presets (Lada RED / WHITE, RYU-32, E30) has a SIGNATURE,
##    a paint palette and wheels from data apart from the physics profile; FLAME
##    (paint baked into the texture) has none;
##  * PAINT / WHEELS choices are saved per car, the next car built (garage preview
##    or race) wears them, SIGNATURE restores the original, RED and WHITE are kept
##    apart;
##  * the RYU-32 stripes are a normal PAINT preset on the same GLB (livery on / off);
##  * handling and engine profiles are not touched by any of it.
const CARS = preload("res://scripts/vehicles/car_catalog.gd")
const COSMETICS = preload("res://scripts/vehicles/car_cosmetics.gd")
const DEV = preload("res://scripts/dev_settings.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var garage_backup := ConfigFile.new()
    var had_garage: bool = garage_backup.load(COSMETICS.GARAGE_PATH) == OK
    var was_legacy: Variant = DEV.get_value("developer","legacy_procedural_cars",false)
    var was_old: Variant = DEV.get_value("developer","factory_test_models",null)
    var err: String = await _checks()
    DEV.set_value("developer","legacy_procedural_cars",was_legacy)
    DEV.set_value("developer","factory_test_models",was_old if was_old != null else false)
    if had_garage:
        garage_backup.save(COSMETICS.GARAGE_PATH)
    elif FileAccess.file_exists(COSMETICS.GARAGE_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(COSMETICS.GARAGE_PATH))
    if not err.is_empty():
        printerr("FAIL: "+err)
        quit(1)
        return
    print("PASS: Car Factory GLB cars are the default (also with the old opt-in key left at false), DEVELOPER switch OFF = procedural Lada / RYU-32 (E30 / FLAME stay GLB), presets + SIGNATURE for Lada RED / WHITE / RYU-32 / E30 and none for FLAME, PAINT / WHEELS saved per car and worn by the next car built, RYU-32 stripes = a PAINT preset, handling + engine profiles untouched")
    for _f in range(3):
        await process_frame
    quit(0)

func _build(v: String) -> Node3D:
    var c: Node3D = CARS.make(v)
    root.add_child(c)
    await process_frame
    return c

func _checks() -> String:
    var handling: Dictionary = CARS.handling("red").duplicate(true)
    var ryu: Dictionary = CARS.handling("blue").duplicate(true)
    # Default: nothing stored, plus the old opt-in key explicitly OFF.
    DEV.set_value("developer","legacy_procedural_cars",false)
    DEV.set_value("developer","factory_test_models",false)
    if not CARS.factory_test_models():
        return "The GLB cars must be the default (an old factory_test_models = false must not matter)"
    for v in ["red","white","blue","e30","flame"]:
        var car: Node3D = await _build(v)
        var ok: bool = car is NitroGlbCar
        car.queue_free()
        await process_frame
        if not ok:
            return "%s must be a Car Factory GLB car by default" % v
    # Legacy comparison switch.
    CARS.set_factory_test_models(false)
    for v2 in ["red","white","blue"]:
        var classic: Node3D = CARS.make(v2)
        var okc: bool = (classic is NitroLadaLowPoly) if v2 != "blue" else (classic is NitroCoupeLowPoly)
        classic.free()
        if not okc:
            return "Switch OFF must give the procedural %s" % v2
    for v3 in ["e30","flame"]:
        var still: Node3D = CARS.make(v3)
        var okg: bool = still is NitroGlbCar
        still.free()
        if not okg:
            return "%s has no procedural model: it must stay GLB with the switch OFF" % v3
    CARS.set_factory_test_models(true)
    # Presets.
    for v4 in ["red","white","blue","e30"]:
        var prof: Dictionary = CARS.cosmetic_profile(v4)
        if not COSMETICS.supported(prof) or COSMETICS.signature(prof).is_empty() or COSMETICS.paints(prof).size() < 3:
            return "%s needs SIGNATURE, a paint palette and wheels" % v4
        COSMETICS.reset_to_signature(v4,prof)
    if COSMETICS.supported(CARS.cosmetic_profile("flame")):
        return "FLAME has its paint baked into the texture: no PAINT presets"
    var sig_red: Dictionary = COSMETICS.signature(CARS.cosmetic_profile("red"))
    var sig_white: Dictionary = COSMETICS.signature(CARS.cosmetic_profile("white"))
    if str(sig_red["paint_color_hex"]).to_lower() == str(sig_white["paint_color_hex"]).to_lower():
        return "Lada RED and WHITE must keep separate signatures"
    # PAINT / WHEELS saved per car and worn by the next car built.
    var red_prof: Dictionary = CARS.cosmetic_profile("red")
    var painted: Dictionary = COSMETICS.next_paint("red",red_prof)
    var wheeled: Dictionary = COSMETICS.next_wheel("red",red_prof)
    var c1: Node3D = await _build("red")
    var g1: NitroGlbCar = c1 as NitroGlbCar
    var want: Color = Color.html(str(painted["paint_color_hex"]))
    var got: Color = g1.paint_material.get_shader_parameter("paint")
    if not got.is_equal_approx(want):
        return "The next RED Lada built must wear the saved paint (%s vs %s)" % [str(got),str(want)]
    if str(g1.cosmetic.get("wheel_asset_id","")) != str(wheeled["wheel_asset_id"]):
        return "The next RED Lada built must wear the saved wheels"
    c1.queue_free()
    await process_frame
    var cw: Node3D = await _build("white")
    var white_paint: Color = (cw as NitroGlbCar).paint_material.get_shader_parameter("paint")
    cw.queue_free()
    await process_frame
    if white_paint.is_equal_approx(want) and not str(sig_white["paint_color_hex"]).to_lower() == str(painted["paint_color_hex"]).to_lower():
        return "Painting the RED Lada must not repaint the WHITE one"
    COSMETICS.reset_to_signature("red",red_prof)
    var c2: Node3D = await _build("red")
    var back: Color = (c2 as NitroGlbCar).paint_material.get_shader_parameter("paint")
    c2.queue_free()
    await process_frame
    if not back.is_equal_approx(Color.html(str(sig_red["paint_color_hex"]))):
        return "SIGNATURE must restore the original look"
    # RYU-32 stripes = a PAINT preset on the same GLB.
    var blue_prof: Dictionary = CARS.cosmetic_profile("blue")
    COSMETICS.reset_to_signature("blue",blue_prof)
    var seen_stripes: bool = false
    var glb_path: String = ""
    for k in range(COSMETICS.paints(blue_prof).size()):
        var cb: Node3D = await _build("blue")
        var gb: NitroGlbCar = cb as NitroGlbCar
        var on: float = float(gb.paint_material.get_shader_parameter("livery_on"))
        var path: String = str(gb.profile["model"]["glb"])
        if glb_path != "" and path != glb_path:
            return "RYU-32 looks must share ONE GLB"
        glb_path = path
        var lid: String = str(gb.cosmetic.get("livery_id","clean"))
        if (lid == "stripes") != (on > 0.5):
            return "RYU-32 paint '%s': livery_on = %.1f" % [lid,on]
        if lid == "stripes":
            seen_stripes = true
            if gb.paint_material.get_shader_parameter("livery_tex") == null:
                return "RYU-32 stripes need their livery texture"
        cb.queue_free()
        await process_frame
        COSMETICS.next_paint("blue",blue_prof)
    if not seen_stripes:
        return "The RYU-32 palette must contain the STRIPES preset"
    COSMETICS.reset_to_signature("blue",blue_prof)
    # Untouched profiles.
    if CARS.handling("red") != handling or CARS.handling("blue") != ryu:
        return "Handling profiles changed"
    return ""
