extends SceneTree
## Recreate the edge crossing measured on the #29 baseline in the two actual
## playable scenes. Both revisions use identical seed, road, input and cameras.
const CAT=preload("res://scripts/world/terrain/terrain_catalog.gd")
const FIELD=preload("res://scripts/world/terrain/terrain_field.gd")
const TT=preload("res://scripts/world/terrain/terrain_track.gd")
const BUILDER=preload("res://scenes/terrain_builder.tscn")
const RACE=preload("res://scenes/race.tscn")
const PATH="user://nitro_water_19_capture.json"
const CROSSING=Vector2(-15.58902,-296.1882)
var out_dir:=OS.get_environment("OUT_DIR")

func _initialize() -> void:
    run.call_deferred()

func frame(label_: String) -> void:
    if out_dir.is_empty():
        return
    for i in range(5):
        await process_frame
    var error:=root.get_texture().get_image().save_png(out_dir+"/"+label_+".png")
    assert(error==OK)

func run() -> void:
    var desc:=CAT.descriptor("pl_ojcow",621727)
    var field:=FIELD.new("pl_ojcow",621727)
    var generated:=TT.generate_loop(TT.new_grid(),field,desc,3)
    if not generated.ok:
        quit(1)
        return
    var file:=FileAccess.open(PATH,FileAccess.WRITE)
    file.store_string(JSON.stringify(generated.data))
    file.close()
    ProjectSettings.set_setting("nitro/terrain_edit_track",PATH)
    var builder=BUILDER.instantiate()
    root.add_child(builder)
    builder.set_process(false)
    builder.cam_target=Vector3(CROSSING.x,builder.world.height_at(CROSSING.x,CROSSING.y),CROSSING.y)
    builder.cam_dist=68
    builder.cam_yaw=145
    builder.cam_pitch=55
    builder.view_pitch=55
    builder.cam_lift=0
    builder._apply_camera()
    await frame("builder")
    builder.free()
    ProjectSettings.set_setting("nitro/selected_track",PATH)
    ProjectSettings.set_setting("nitro/car_variant","red")
    var race=RACE.instantiate()
    root.add_child(race)
    race.set_physics_process(false)
    var track=race.track
    var start: int=track.sample_info(CROSSING).index
    var i:=posmod(start-3,track.centerline.size())
    var t: Vector2=(track.centerline[i+1]-track.centerline[i]).normalized()
    race.model.reset(track.centerline[i],atan2(t.x,-t.y))
    race.model.velocity=t*7.0
    Input.action_press("throttle",0.6)
    for k in range(48):
        race._physics_process(1.0/120)
    Input.action_release("throttle")
    race._snap_cameras()
    await frame("drive")
    race._toggle_camera()
    for k in range(100):
        race._update_camera(1.0/60)
    await frame("chase")
    print("Ojców 621727 loop 3, grid and race loaded from same save, car speed ",race.model.speed_kmh()," km/h")
    race.free()
    DirAccess.remove_absolute(PATH)
    quit(0)
