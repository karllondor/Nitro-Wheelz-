extends SceneTree
## Regression for exclusive pause UI, brand artwork and real textured road.
const BOOT = preload("res://scenes/boot.tscn")
const RACE = preload("res://scenes/race.tscn")
const RESULTS = preload("res://scripts/ui/race_results.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var menu: Control = BOOT.instantiate()
    root.add_child(menu)
    await process_frame
    var logo: TextureRect = menu.find_child("Nitro Wheelz Graffiti Crown Logo",true,false) as TextureRect
    if logo == null or logo.texture == null or logo.texture.get_width() < 100:
        _fail("Owner-provided logo missing from top of menu")
        return
    menu.queue_free()
    await process_frame

    var race: Node3D = RACE.instantiate()
    root.add_child(race)
    await process_frame
    var track: Node = race.get("track")
    var road: MeshInstance3D = track.find_child("Single continuous driving surface",true,false) as MeshInstance3D
    var exterior: MeshInstance3D = track.find_child("Ground outside track",true,false) as MeshInstance3D
    if road == null or exterior == null:
        _fail("Textured road or grass ground missing")
        return
    var road_material: StandardMaterial3D = road.mesh.surface_get_material(0) as StandardMaterial3D
    var ground_material: StandardMaterial3D = exterior.material_override as StandardMaterial3D
    if road_material == null or road_material.albedo_texture == null:
        _fail("User asphalt image not assigned to road UV material")
        return
    if ground_material == null or ground_material.albedo_texture == null:
        _fail("Night grass texture not assigned to ground material")
        return
    race.call("_toggle_pause")
    var pause_layer: CanvasLayer = race.get("pause_layer")
    var touch: Control = race.get("touch")
    var hud: Control = race.get("hud")
    if pause_layer == null or not bool(race.get("paused")):
        _fail("PAUSE must create exactly one modal CanvasLayer")
        return
    if touch.visible or touch.is_processing_input():
        _fail("Old touch controls not disabled behind PAUSE")
        return
    if hud == null or hud.get("paused") != true:
        _fail("Race HUD did not record paused state")
        return
    # Player settings live in the pause panel: sound toggle + accent colour.
    var STYLE = load("res://scripts/ui/hud_style.gd")
    var menu_panel: NitroPauseMenu = pause_layer.get_child(0) as NitroPauseMenu
    if menu_panel == null or menu_panel.find_child("Sound toggle",true,false) == null \
            or menu_panel.find_child("Accent swatches",true,false) == null:
        _fail("Pause menu must offer sound on/off and accent colours")
        return
    if (menu_panel.find_child("Accent swatches",true,false) as Control).get_child_count() != STYLE.ACCENT_ORDER.size():
        _fail("Every accent colour needs a swatch")
        return
    var accent_before: String = STYLE.accent_name
    var sound_before: bool = STYLE.sound_on
    menu_panel.choose_accent("cyan")
    if STYLE.PINK != STYLE.ACCENTS["cyan"] or STYLE.accent_name != "cyan":
        _fail("Choosing an accent must recolour the shared HUD accent")
        return
    var cfg := ConfigFile.new()
    if cfg.load(STYLE.SETTINGS_PATH) != OK or str(cfg.get_value("ui","accent","")) != "cyan":
        _fail("Accent choice was not persisted")
        return
    menu_panel.call("_toggle_sound")
    if STYLE.sound_on == sound_before or AudioServer.is_bus_mute(0) == STYLE.sound_on:
        _fail("Sound toggle must mute/unmute the master bus")
        return
    # Separate ENGINE / TYRES / EFFECTS volumes drive the synth mix.
    var engine_before: float = STYLE.vol_engine
    var tyres_before: float = STYLE.vol_tyres
    var fx_before: float = STYLE.vol_fx
    var panel_now: NitroSettingsPanel = (pause_layer.get_child(0) as NitroPauseMenu).settings
    for g in ["engine","tyres","fx"]:
        if panel_now.find_child("Slider "+g,true,false) == null:
            _fail("Volume slider missing: "+g)
            return
    panel_now.set_volume("engine",0.25)
    panel_now.set_volume("tyres",0.0)
    panel_now.set_volume("fx",0.6)
    var sfx = race.get("sfx")
    if sfx != null:
        sfx._process(0.016)
        if absf(sfx.synth.engine_gain-0.25) > 0.001 or sfx.synth.tyre_gain != 0.0 or absf(sfx.synth.fx_gain-0.6) > 0.001:
            _fail("Volume sliders must reach the synth mix")
            return
    var vcfg := ConfigFile.new()
    if vcfg.load(STYLE.SETTINGS_PATH) != OK or absf(float(vcfg.get_value("audio","engine",-1.0))-0.25) > 0.001:
        _fail("Volumes were not persisted")
        return
    STYLE.vol_engine = engine_before
    STYLE.vol_tyres = tyres_before
    STYLE.vol_fx = fx_before
    STYLE.set_sound(sound_before)
    STYLE.set_accent(accent_before)
    STYLE.save_settings()
    race.call("_toggle_pause")
    if bool(race.get("paused")) or race.get("pause_layer") != null:
        _fail("Resume failed to remove exclusive Pause panel")
        return
    if RESULTS.short_date("2026-11-19T01:21:56") != "19 Nov  01:21":
        _fail("Local results should display short date and time")
        return
    print("PASS: logo texture, asphalt+grass UV, exclusive PAUSE/RESUME with sound, engine/tyre/effects volumes + accent settings, concise run history")
    print("NOT RUN: actual mobile touch coordinates, physical speed sensation, on-device keyboard")
    quit(0)

func _fail(message: String) -> void:
    printerr("FAIL: "+message)
    quit(1)
