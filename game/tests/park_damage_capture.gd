extends Node
## Shared capture and frame-time probe for a renderer or an installed debug APK.
## Render the actual Park and factory model. Record wall-clock intervals between
## completed render callbacks. Each sample uses the same camera and vehicle pose.
const RACE = preload("res://scenes/race.tscn")
const P = preload("res://scripts/net/net_protocol.gd")
const SITE = preload("res://scripts/park/park_site.gd")
var race: Node3D
var cam: Camera3D
var directory: String
var samples: Array = []
var failed := false
var interactive := false

func _ready() -> void:
    _run.call_deferred()

func _run() -> void:
    directory = OS.get_environment("OUT_DIR")
    if directory.is_empty():
        directory = ProjectSettings.globalize_path("user://park-damage-qa")
    DirAccess.make_dir_recursive_absolute(directory)
    var previous := {}
    for key in ["nitro/selected_track","nitro/car_variant","nitro/park_mode","nitro/park_reset"]:
        previous[key] = ProjectSettings.get_setting(key,null)
    ProjectSettings.set_setting("nitro/park_mode","free")
    ProjectSettings.set_setting("nitro/park_reset",false)
    ProjectSettings.set_setting("nitro/selected_track",P.PARK_PATH)
    ProjectSettings.set_setting("nitro/car_variant","white")
    race = RACE.instantiate()
    get_tree().root.add_child(race)
    if get_tree().current_scene!=null:
        get_tree().current_scene.hide()
    race.set_physics_process(false)
    race.hud.hide()
    race.touch.hide()
    cam = Camera3D.new()
    race.add_child(cam)
    var m: NitroDriveModel = race.model
    var dmg: Node = race.park.damage
    m.reset(Vector2(222,-2),0)
    _frame_car(false)
    for i in 16: await RenderingServer.frame_post_draw
    await _shot("01-intact")
    await _measure("intact")
    var at := m.position
    dmg.impact(0,at,0,at+Vector2(0.8,-2),Vector2.UP*10,10)
    dmg.impact(0,at,0,at+Vector2(-0.8,2),Vector2.DOWN*10,10)
    failed = dmg.mounts[0]!=1 or dmg.mounts[1]!=2
    m.velocity = Vector2(3,-13)
    m.yaw_rate = 0.78
    await _shot("02-front-dangling")
    _frame_car(true)
    await _shot("03-rear-dangling")
    _frame_car(false)
    await _measure("both_dangling")
    dmg.clock+=0.7
    dmg.impact(0,at,0,at+Vector2(-0.8,-2),Vector2(-1,-3),12)
    failed = failed or dmg.mounts[0]!=0
    for i in 25: await get_tree().physics_frame
    await _shot("04-detached")
    await _measure("front_debris_rear_dangling")
    m.reset(SITE.REPAIR.get_center(),0)
    # Photograph the open bay from its entrance.
    m.heading=PI
    _frame_car(false)
    cam.position = race.car_root.position+Vector3(1.25,1.8,6.6)
    cam.look_at(race.car_root.position+Vector3(0,0.65,0))
    race.park._service_step(SITE.STOP_SECONDS+0.01,m)
    failed = failed or dmg.mounts[0]!=3 or dmg.mounts[1]!=3 or dmg.parts[0].debris!=null
    await _shot("05-repaired")
    var report := {"ok":not failed,"platform":OS.get_name(),"model":OS.get_model_name(),
        "renderer":RenderingServer.get_video_adapter_name(),"viewport":str(get_viewport().get_visible_rect().size),
        "method":"48 wall-clock intervals between frame_post_draw callbacks per state; stationary camera; one white Lada; live Park and debris physics","samples":samples}
    var output := FileAccess.open(directory.path_join("frames.json"),FileAccess.WRITE)
    output.store_string(JSON.stringify(report,"  "))
    output.close()
    print(JSON.stringify(report))
    race.queue_free()
    await get_tree().process_frame
    if not interactive:
        get_tree().quit(1 if failed else 0)
        return
    for key in previous:
        ProjectSettings.set_setting(key,previous[key])
    get_tree().current_scene.show()
    var summary := AcceptDialog.new()
    summary.title = "Park damage frame times"
    summary.dialog_text = "%s  %s\nMedian / 95th percentile" % [OS.get_model_name(),report.viewport]
    for row in samples:
        summary.dialog_text += "\n%s   %.1f / %.1f ms" % [str(row.state).replace("_"," "),row.median_ms,row.p95_ms]
    add_child(summary)
    summary.confirmed.connect(queue_free)
    summary.canceled.connect(queue_free)
    summary.popup_centered()

func _frame_car(rear: bool) -> void:
    race._update_visuals()
    var car: Vector3 = race.car_root.position
    cam.position = car+Vector3(4.05,1.62,5.5 if rear else -5.5)
    cam.look_at(car+Vector3(0,0.69,0))
    cam.fov = 41
    cam.current = true

func _shot(label: String) -> void:
    for i in 2: await RenderingServer.frame_post_draw
    var image := get_viewport().get_texture().get_image()
    if image==null or image.save_png(directory.path_join(label+".png"))!=OK:
        failed = true

func _measure(state: String) -> void:
    var gaps: Array[float] = []
    await RenderingServer.frame_post_draw
    var start := Time.get_ticks_usec()
    for i in 48:
        await RenderingServer.frame_post_draw
        var end := Time.get_ticks_usec()
        gaps.append((end-start)*0.001)
        start=end
    gaps.sort()
    samples.append({"state":state,"frames":gaps.size(),"median_ms":snappedf((gaps[23]+gaps[24])*0.5,0.01),
        "p95_ms":snappedf(gaps[45],0.01),"max_ms":snappedf(gaps.back(),0.01)})
