extends SceneTree
## The ordinary Park race scene, fixed-step drive model and pooled Godot rigid bodies.
const RACE = preload("res://scenes/race.tscn")
const SITE = preload("res://scripts/park/park_site.gd")
const P = preload("res://scripts/net/net_protocol.gd")
const DT := 1.0/120.0

var race: Node3D

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, label: String) -> bool:
    if not ok:
        printerr("FAIL: ",label)
        quit(1)
    return ok

func _run() -> void:
    ProjectSettings.set_setting("nitro/selected_track",P.PARK_PATH)
    ProjectSettings.set_setting("nitro/park_mode","free")
    ProjectSettings.set_setting("nitro/car_variant","red")
    race = RACE.instantiate()
    root.add_child(race)
    race.set_physics_process(false)
    await process_frame
    var world: Node = race.park.stunts
    if not _check(world.pool.size()==world.MAX_ACTIVE and world.fixtures.size()==33,"fixed pool and placements"):
        return
    if not _check(_packet_codec(),"Park pose packet bounds, precision and retired-object marker"):
        return
    var heights := []
    for ramp in SITE.RAMPS:
        if not _ramp(ramp,3.4) or not _ramp(ramp,34.0):
            return
        heights.append(_last_peak)
    if not _check(heights[0]<heights[1] and heights[1]<heights[2],"different ramps give different flight profiles"):
        return

    var large: Dictionary = SITE.RAMPS[2]
    race.model.reset(Vector2(large.start.x,large.start.y-large.run-8),PI)
    race.model.velocity = Vector2(0,8)
    race.park._reset_air()
    var crashes: int = race.wall_collision_count
    for i in 210:
        race._physics_process(DT)
    if not _check(race.park.air.height==0 and race.wall_collision_count>crashes,"reverse approach meets visible rear lip"):
        return

    world.reset()
    var wall_id := 13
    var wall_at: Vector3 = world.fixtures[wall_id].at
    world.contact(wall_at+Vector3(0,3.4,4),wall_at+Vector3(0,3.4,-2),0.0,Vector2(0,-18),Vector2(2.6,1.0))
    if not _check(world.active.is_empty(),"car cleared the wall at jump height"):
        return
    world.contact(wall_at+Vector3(0,-wall_at.y,4),wall_at+Vector3(0,-wall_at.y,-2),0.0,Vector2(0,-18),Vector2(2.6,1.0))
    if not _check(world.active.size()>=8,"ground impact woke the wall layers"):
        return
    for i in 60:
        await physics_frame
    var max_displacement := 0.0
    for index in range(11,21):
        max_displacement = maxf(max_displacement, world.visuals[index].position.distance_to(world.fixtures[index].at))
    if not _check(max_displacement>0.40,"wall cardboard moved under real engine physics"):
        return
    print("Stunt wall: %d direct contacts, %.2f m maximum box displacement" % [world.contacts,max_displacement])

    world.reset()
    var barrier: Vector3 = world.fixtures[30].at
    world.contact(barrier+Vector3(0,0,2),barrier,0.0,Vector2(0,-14),Vector2(2.6,1.0))
    for i in 50:
        await physics_frame
    if not _check(world.visuals[30].position.distance_to(barrier)>0.21,"lightweight barrier moved"):
        return
    world.reset()
    for id in [4,13,0,1,2,21,30,31,32]:
        var at: Vector3 = world.fixtures[id].at
        world.contact(at,at,0.0,Vector2(0,-15),Vector2(2.5,1.0))
    if not _check(world.active.size()==world.MAX_ACTIVE and world.peak_active==world.MAX_ACTIVE,"stress reached and respected cap"):
        return
    var first_id: int = world.active.keys()[0]
    world.pool[int(world.active[first_id])].position = Vector3(500,-2,500)
    for i in 6:
        await physics_frame
    if not _check(not world.active.has(first_id) and not world.visuals[first_id].visible,"out-of-bounds prop returned to pool"):
        return
    for id in world.active:
        world.pool[int(world.active[id])].sleeping = true
    for i in 60:
        await physics_frame
    if not _check(world.free_slots.size()>1,"sleep releases pooled bodies"):
        return
    world.reset()
    if not _check(world.free_slots.size()==world.MAX_ACTIVE and world.visuals[first_id].visible and
            world.visuals[first_id].position==world.fixtures[first_id].at,"reset restores original props and pool"):
        return

    race.park.air.airborne = true
    race.park.air.height = 2.0
    race.model.position = Vector2(3000,3000)
    race._physics_process(DT)
    if not _check(race.model.position==Vector2(0,30) and race.car_y==0 and not race.park.air.airborne and
            race.park.air.deck<0,"airborne out-of-bounds recovery clears jump state"):
        return
    if "--bench" in OS.get_cmdline_user_args():
        await _bench()
    race.queue_free()
    await process_frame
    print("PASS: Park stunt ramp speed ranges, stable landing and both cameras, cardboard impacts, pool limit, sleeping, cleanup and reset")
    quit(0)

var _last_peak := 0.0
func _ramp(ramp: Dictionary, speed: float) -> bool:
    race.park._reset_air()
    race.park.stunts.reset()
    race.model.reset(ramp.start+Vector2(0,8),0.0)
    race.model.velocity = Vector2(0,-speed)
    var total: int = race.park.air.landings
    var launches: int = race.park.air.launches
    var peak := 0.0
    var flight := false
    var flight_ticks := 0
    for tick in 1000:
        Input.action_press("throttle",clampf(0.30+(speed-race.model.speed_mps())*0.16,0.0,1.0))
        race._physics_process(DT)
        var air: Variant = race.park.air
        peak = maxf(peak,air.height)
        if air.airborne:
            flight = true
            flight_ticks += 1
            if flight_ticks in [5,15]:
                race._toggle_camera()
                race._update_camera(0.3)
                var cam: Camera3D = root.get_camera_3d()
                if not _check(cam!=null and not cam.is_position_behind(race.car_root.position) and
                        is_equal_approx(race.car_root.position.y,race.car_y) and absf(race.body_pitch)<0.40,
                        "camera tracks stable airborne car"):
                    return false
        if air.landings>total:
            break
    Input.action_release("throttle")
    var distance: float = float(ramp.start.y)-float(ramp.run)-race.model.position.y
    print("Stunt %s %.0f km/h: apex %.2f m, airtime %.2f s, landing %.1f m from lip" %
        [ramp.id,speed*3.6,peak,flight_ticks*DT,distance])
    _last_peak = peak
    return _check(flight and race.park.air.launches==launches+1 and race.park.air.landings==total+1 and
        distance>=0 and distance<=ramp.landing.size.y and peak<6.0 and race.car_y==0 and
        race.model.speed_mps()>0.8 and absf(race.model.heading)<0.15,"stable single launch/landing: "+str(ramp.id))

func _packet_codec() -> bool:
    var at := Vector3(30.23,0.41,-476.78)
    var packet := P.pack_park_objects(7,5,65535,[
        {"id":16,"position":at,"rotation":Vector3(0.2,-2.0,0.1)},
        {"id":17,"position":Vector3(0,-8,0),"rotation":Vector3.ZERO}])
    var decoded := P.unpack_park_objects(packet)
    if decoded.is_empty() or decoded.round!=7 or decoded.revision!=5 or decoded.seq!=65535 or             decoded.poses[0].position.distance_to(at)>0.025 or decoded.poses[1].position.y!=-8:
        return false
    if not P.unpack_park_objects(packet.slice(0,-1)).is_empty():
        return false
    packet[P.PARK_CONE_HEADER+P.PARK_OBJECT_BYTES] = 16
    if not P.unpack_park_objects(packet).is_empty():
        return false
    return P.unpack_snapshot(P.pack_snapshot({"height":4.45,"pitch":0.27},true)).height > 4.4 and         P.unpack_snapshot(P.pack_snapshot({"height":NAN},true)).is_empty()

func _bench() -> void:
    race.set_physics_process(true)
    for scenario in ["empty practice","normal plaza drift","jump plus pooled props"]:
        await _sample(scenario)

func _sample(scenario: String) -> void:
    var samples := PackedFloat32Array()
    var peak := 0
    for repeat in 6:
        race._restart()
        if scenario == "normal plaza drift":
            race.model.velocity = Vector2(0,-14.0)
            Input.action_press("throttle")
            Input.action_press("steer_left",0.95)
            Input.action_press("handbrake",0.8)
        elif scenario == "jump plus pooled props":
            var world: Node = race.park.stunts
            var start: Vector2 = SITE.RAMPS[2].start
            race.model.reset(start+Vector2(0,1),0.0)
            race.model.velocity = Vector2(0,-28)
            for id in [4,13]:
                var pos: Vector3 = world.fixtures[id].at
                world.contact(pos,pos,0.0,Vector2(0,-16),Vector2(2.5,1.0))
            peak = maxi(peak,world.active.size())
        for i in 126:
            await physics_frame
        samples.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)
        Input.action_release("throttle")
        Input.action_release("steer_left")
        Input.action_release("handbrake")
    samples.sort()
    print("STUNT_BENCH %s | 6 x 1.05 s | monitor median %.3f ms | max %.3f ms | peak active %d" %
        [scenario,(samples[2]+samples[3])*0.5,samples[-1],peak])
