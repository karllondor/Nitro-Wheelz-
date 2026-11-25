extends SceneTree
const RACE = preload("res://scenes/race.tscn")
const P = preload("res://scripts/net/net_protocol.gd")
const SITE = preload("res://scripts/park/park_site.gd")
const CARS = preload("res://scripts/vehicles/car_catalog.gd")
const DT := 1.0/120.0

func _initialize() -> void:
    _run.call_deferred()

func check(ok: bool, label: String) -> bool:
    if not ok:
        printerr("FAIL: ",label)
        quit(1)
    return ok

func _run() -> void:
    ProjectSettings.set_setting("nitro/selected_track",P.PARK_PATH)
    ProjectSettings.set_setting("nitro/car_variant","white")
    var race := RACE.instantiate()
    root.add_child(race)
    race.set_physics_process(false)
    var damage: Node = race.park.damage
    var front = damage.parts[0]
    var rear = damage.parts[1]
    if not check(front!=null and rear!=null and front.mesh.get_active_material(0)==race.car_root.paint_material,"Park white Lada uses its original paint"): return
    var base := CARS.make("white")
    root.add_child(base)
    if not check(base.find_child("FrontBumper",true,false)==null,"production mesh stays in garage/races"): return
    base.queue_free()
    var model: NitroDriveModel = race.model
    model.reset(Vector2(273,-31),0)
    var right_corner := model.position+Vector2(0.8,-2)
    damage.impact(0,model.position,0,right_corner,Vector2.UP*3,3)
    damage.impact(0,model.position,0,model.position+Vector2.RIGHT,Vector2.RIGHT*15,15)
    if not check(front.mask==3 and rear.mask==3,"parking tap and side scrape"): return
    model.velocity = Vector2.UP*13
    for i in 80:
        race._physics_process(DT)
    if not check(front.mask in [1,2] and rear.mask==3,"front collision with real service building releases one mount"): return
    var side := -1.0 if front.mask==1 else 1.0
    var anchor: Vector3 = front.center+Vector3(side*0.77,0.04,0)
    front.animate(DT,18,1.8)
    if not check((front.mesh.transform*anchor).is_equal_approx(anchor) and front.mesh.transform.basis!=Basis.IDENTITY,"fixed surviving mount during yaw"): return
    var corner := model.position+Vector2(side*0.82,-2.3)
    damage.impact(0,model.position,0,corner,Vector2.UP*18,18)
    if not check(front.mask!=0,"one encounter cannot rip both mounts"): return
    damage.clock+=0.7
    damage.impact(0,model.position,0,corner,Vector2.UP*6,6)
    if not check(front.mask!=0,"second light hit leaves mount attached"): return
    damage.impact(0,model.position,0,corner,Vector2.UP*12,12)
    if not check(front.mask==0 and not front.mesh.visible and front.debris is RigidBody3D and front.debris.collision_layer==0,"detachment creates isolated debris"): return
    var rear_corner := model.position+Vector2(-0.7,2)
    damage.impact(0,model.position,0,rear_corner,Vector2.DOWN*10,10)
    if not check(rear.mask==2,"reverse contact breaks left rear mount independently"): return
    model.reset(Vector2(20,20),0)
    model.velocity = Vector2(5,-15)
    Input.action_press("throttle")
    Input.action_press("handbrake")
    for i in 35: race._physics_process(DT)
    Input.action_release("throttle")
    Input.action_release("handbrake")
    if not check(model.speed_mps()>5 and model.position.distance_to(Vector2(20,20))>2,"drive with one hanging and one missing bumper"): return
    model.reset(SITE.REPAIR.get_center(),0)
    model.velocity = Vector2.DOWN*2
    race.park._service_step(1.0,model)
    if not check(front.mask==0,"rolling through bay does not repair"): return
    model.velocity = Vector2.ZERO
    race.park._service_step(0.3,model)
    if not check(front.mask==0,"brief stop does not repair"): return
    race.park._service_step(0.36,model)
    if not check(front.mask==3 and rear.mask==3 and front.debris==null and front.mesh.visible and rear.mesh.transform==Transform3D.IDENTITY and race.park._site_notice.text.contains("FREE"),"stopped bay restores both attachments and recycles debris"): return
    if not check(not P.valid_park_event(P.ParkEvent.PLAYER_CONTACT,{"dv":Vector2(13,0),"shift":Vector2.ZERO,"guest_at":Vector2.ZERO}) and not P.valid_park_event(P.ParkEvent.BUMPER_DAMAGE,{"slot":2,"part":0,"mask":1}),"reject invalid contact and slot"): return
    race.queue_free()
    await process_frame
    print("PASS: bumper geometry, impact location and strength, attachment pivot, independent front/rear, debris, driving and free service")
    quit(0)
