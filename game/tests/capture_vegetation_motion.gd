extends SceneTree
## Issue #20 evidence (developer tool, needs a display):
##   OUT_DIR=/abs/dir CAM=top xvfb-run -a -s "-screen 0 540x1170x24" godot --path game \
##     --rendering-driver opengl3 --resolution 540x1170 --fixed-fps 2 \
##     --script res://tests/capture_vegetation_motion.gd
## With --fixed-fps 2 every frame advances the engine clock (TIME in the shaders)
## by 0.5 s, so 60 frames are 30 s of a FIXED camera on a parked car. The same
## Ojców loop as the owner's world (seed 621727) is shown with the vegetation
## wind at 1.0 (the build's default) and at 0.0, 60 frames each. The frames are
## compared offline (temporal standard deviation per pixel), so every moving
## thing in the picture shows up, not only the wind. Works with the v0.1.33 code
## too (BEFORE) - it only uses the scenery's material / set_wind().
const CAT = preload("res://scripts/world/terrain/terrain_catalog.gd")
const FIELD = preload("res://scripts/world/terrain/terrain_field.gd")
const TT = preload("res://scripts/world/terrain/terrain_track.gd")
const RACE = preload("res://scenes/race.tscn")
const PATH: String = "user://nitro_veg_capture.json"

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var out_dir: String = OS.get_environment("OUT_DIR") if OS.get_environment("OUT_DIR") != "" else "user://veg/"
    out_dir = out_dir.trim_suffix("/")+"/"
    DirAccess.make_dir_recursive_absolute(out_dir)
    var cam_tag: String = OS.get_environment("CAM") if OS.get_environment("CAM") != "" else "top"
    var desc: Dictionary = CAT.descriptor("pl_ojcow",621727)
    var field: NitroTerrainField = FIELD.new("pl_ojcow",621727)
    field.bake()
    var grid: NitroTrackGrid = TT.new_grid()
    var gen: Dictionary = TT.generate_loop(grid,field,desc,5)
    var f := FileAccess.open(PATH,FileAccess.WRITE)
    f.store_string(JSON.stringify(gen["data"]))
    f.close()
    ProjectSettings.set_setting("nitro/selected_track",PATH)
    ProjectSettings.set_setting("nitro/car_variant","red")
    var race: Node3D = RACE.instantiate()
    root.add_child(race)
    for i in range(10):
        await process_frame
    race.set_physics_process(false)
    race.race_started = false
    var track: NitroDriftTrack = race.track
    # Park the car on a stretch away from the stream, facing along the road.
    var n: int = track.centerline.size()
    var at: int = n/3
    var p: Vector2 = track.centerline[at]
    var t: Vector2 = (track.centerline[(at+1)%n]-p).normalized()
    race.model.reset(p,atan2(t.x,-t.y))
    race._physics_process(1.0/120.0)
    race._update_visuals()
    var want_mode: int = 0 if cam_tag == "top" else 1
    if int(race.camera_mode) != want_mode:
        race._toggle_camera()
    for k in range(60):
        race.call("_update_camera",1.0/60.0)
    var scenery = track.terrain.scenery
    for wind in [1.0,0.0]:
        if scenery.has_method("set_wind"):
            scenery.set_wind(wind)
        else:
            scenery._veg_mat.set_shader_parameter("sway",wind)   # v0.1.33: one material
        for i2 in range(4):
            await process_frame
        for i3 in range(60):
            await process_frame
            root.get_viewport().get_texture().get_image().save_png("%sveg_%s_wind%d_%02d.png" % [out_dir,cam_tag,int(wind*10.0),i3])
    DirAccess.remove_absolute(PATH)
    print("VEGETATION CAPTURED to %s (fixed clock step %.2f s)" % [ProjectSettings.globalize_path(out_dir),1.0/maxf(float(Engine.max_fps),1.0)])
    quit(0)
