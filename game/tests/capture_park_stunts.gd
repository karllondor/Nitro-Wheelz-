extends SceneTree
## Run the actual Park scene with a display. OUT_DIR selects the image destination.
const RACE = preload("res://scenes/race.tscn")
const SITE = preload("res://scripts/park/park_site.gd")
const DT := 1.0/120.0
var race: Node3D
var out: String

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    out = OS.get_environment("OUT_DIR")
    if out.is_empty():
        out = ProjectSettings.globalize_path("user://stunt_captures")
    DirAccess.make_dir_recursive_absolute(out)
    ProjectSettings.set_setting("nitro/selected_track","res://tracks/nitro_wheelz_park.json")
    ProjectSettings.set_setting("nitro/park_mode","free")
    ProjectSettings.set_setting("nitro/car_variant","red")
    race = RACE.instantiate()
    root.add_child(race)
    race.set_physics_process(false)
    race.touch.hide()
    race.hud.hide()
    var overview := Camera3D.new()
    race.add_child(overview)
    overview.position = Vector3(78,150,-346)
    overview.look_at(Vector3(-7,0,-448))
    overview.current = true
    await _shot("01-stunt-slab")
    overview.queue_free()
    for i in SITE.RAMPS.size():
        var ramp: Dictionary = SITE.RAMPS[i]
        race.park._reset_air()
        race.park.reset_objects()
        race.model.reset(ramp.start+Vector2(0,7),0.0)
        race.model.velocity = Vector2(0,-28)
        var launch_ticks := 0
        for tick in 220:
            race._physics_process(DT)
            if race.park.air.airborne:
                launch_ticks += 1
            if launch_ticks == 30:
                break
        if not race.park.air.airborne:
            printerr("Screenshot launch failed: ",ramp.id)
            quit(1)
            return
        if i < 2:
            race.chase.current = true
            race.camera_mode = 1
        else:
            race.overhead.current = true
            race.camera_mode = 0
        race._snap_cameras()
        race._update_visuals()
        await _shot("%02d-%s-airborne" % [i+2,ramp.id])
        if i == 2:
            race.chase.current = true
            race.camera_mode = 1
            race._snap_cameras()
            await _shot("05-large-ramp-chase")
            var side := Camera3D.new()
            race.add_child(side)
            var car: Vector3 = race.car_root.position
            side.position = car+Vector3(13,4,9)
            side.look_at(car+Vector3(0,-1,-2))
            side.current = true
            await _shot("07-large-ramp-clearance")
            race.chase.current = true
            side.queue_free()

    race.park._reset_air()
    race.park.reset_objects()
    race.model.reset(Vector2(30,-469),0.0)
    race.model.velocity = Vector2(0,-14)
    var contacts: int = race.park.stunts.contacts
    var impact_ticks := 0
    for tick in 125:
        await physics_frame
        race._physics_process(DT)
        if race.park.stunts.contacts > contacts:
            impact_ticks += 1
        if impact_ticks == 49:
            break
    if race.park.stunts.contacts <= contacts:
        printerr("Screenshot impact failed")
        quit(1)
        return
    var impact_cam := Camera3D.new()
    race.add_child(impact_cam)
    impact_cam.position = Vector3(40,7,-469)
    impact_cam.look_at(Vector3(30,0.9,-479))
    impact_cam.current = true
    await _shot("06-cardboard-wall-impact")
    race.queue_free()
    await process_frame
    quit(0)

func _shot(label: String) -> void:
    for i in 6:
        await RenderingServer.frame_post_draw
    var image := root.get_texture().get_image()
    if image.save_png(out.path_join(label+".png")) != OK:
        printerr("Capture failed: ",label)
        quit(1)
