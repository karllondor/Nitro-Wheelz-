extends SceneTree
## A rolling entry into the first real sector, then the same drift at the
## opposite edge. The normal race tick supplies physics, collisions and HUD.
const RACE=preload("res://scenes/race.tscn")
const BUILDER=preload("res://scenes/terrain_builder.tscn")
const FIXTURE="res://tracks/event_workshop_29.json"
var failures: Array[String]=[]
var output:=OS.get_environment("NITRO_EVENT_CAPTURES")

func _initialize() -> void:
    call_deferred("run")

func check(ok: bool,msg: String) -> void:
    if not ok:
        failures.append(msg)

func shot(name_: String) -> void:
    if output.is_empty():
        return
    for frame in range(4):
        await process_frame
    root.get_texture().get_image().save_png(output+"/"+name_+".png")

func run() -> void:
    ProjectSettings.set_setting("nitro/terrain_edit_track",FIXTURE)
    var b=BUILDER.instantiate()
    root.add_child(b)
    b._fit()
    for k in range(60):
        b._process(0.05)
    var club: Array=b.last_eval.event_layout.zones.duplicate(true)
    check(club.size()>=3,"fixture Club sectors")
    await shot("builder-club")
    b._pick_event("practice")
    check(b.last_eval.event_layout.zones.is_empty(),"Practice paint")
    b._pick_event("pro")
    check(not b.last_eval.event_layout.zones.is_empty() and b.last_eval.event_layout.zones!=club,"Pro layout")
    await shot("builder-pro")
    b._pick_event("club")
    check(b.last_eval.event_layout.zones==club,"deterministic switch")
    check(b._write(b.DRIVE_PATH,"Workshop","test29"),"write fixture")
    var path: String=b.DRIVE_PATH
    b.free()
    ProjectSettings.set_setting("nitro/selected_track",path)
    var race=RACE.instantiate()
    root.add_child(race)
    race.set_physics_process(false)
    check(race.track.event_layout.zones==club,"Builder/race parity")
    for variant in ["e30","blue"]:
        for wrong_side in [true,false]:
            race._restart()
            race.CARS.configure_model(race.model,variant)
            var size_: Dictionary=race.CARS.info(variant)
            race.track.body_half_length=size_.length*0.575-0.095
            race.track.body_half_width=size_.width*0.575-0.048
            var z: Dictionary=club[0]
            var frame: Dictionary=race.track._road_at_arc(z.a+0.25)
            var right: Vector2=frame.across
            var fwd:=Vector2(right.y,-right.x)
            race.model.reset(frame.centre,fwd.angle()+PI/2+deg_to_rad(26)*z.turn)
            var side:=signf(z.d)
            var offset: float=z.d+race.model.forward().dot(right)*race.track.body_half_length-side*absf(race.model.right().dot(right))*race.track.body_half_width
            race.model.position+=right*(-offset if wrong_side else offset)
            race.model.velocity=fwd*z.pace
            race.model.rear_traction=0.45
            Input.action_press("throttle",0.65)
            Input.action_press("steer_right" if z.turn>0 else "steer_left",0.55)
            for tick in range(42):
                race._physics_process(1.0/120)
                race._update_camera(1.0/120)
            Input.action_release("throttle")
            Input.action_release("steer_right")
            Input.action_release("steer_left")
            print("Event trace ",variant," wrong side ",wrong_side," chain ",race.scorer.pending_total()," technical ",race.judge.technical)
            check(race.scorer.pending_total()>0,"base drift")
            check(race.judge.technical==0 if wrong_side else race.judge.technical>0,"designated zone")
            if not wrong_side:
                race._snap_cameras()
                await shot("drive-"+variant)
            var original: float=race.judge.technical
            race.model.velocity=Vector2.ZERO
            for tick in range(60):
                race._physics_process(1.0/120)
            check(race.judge.technical==original,"parked farm")
    race.free()
    if failures.is_empty():
        print("PASS: Event workshop modes, save/load, both vehicle traces and wrong-edge control")
    else:
        print("FAIL: ",failures)
    quit(0 if failures.is_empty() else 1)
