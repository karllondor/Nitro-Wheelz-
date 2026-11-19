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
        _fail("Textured road or sand ground missing")
        return
    var road_material: StandardMaterial3D = road.mesh.surface_get_material(0) as StandardMaterial3D
    var sand_material: StandardMaterial3D = exterior.material_override as StandardMaterial3D
    if road_material == null or road_material.albedo_texture == null:
        _fail("User asphalt image not assigned to road UV material")
        return
    if sand_material == null or sand_material.albedo_texture == null:
        _fail("User sand image not assigned to ground material")
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
    race.call("_toggle_pause")
    if bool(race.get("paused")) or race.get("pause_layer") != null:
        _fail("Resume failed to remove exclusive Pause panel")
        return
    if RESULTS.short_date("2026-11-19T01:21:56") != "19 Nov  01:21":
        _fail("Local results should display short date and time")
        return
    print("PASS: logo texture, asphalt+sand UV, exclusive PAUSE/RESUME, concise run history")
    print("NOT RUN: actual mobile touch coordinates, physical speed sensation, on-device keyboard")
    quit(0)

func _fail(message: String) -> void:
    printerr("FAIL: "+message)
    quit(1)
