extends SceneTree
## Normal lobby and gameplay scenes, driven by tools/test_net_rounds.py in two processes.
const TIME = preload("res://scripts/lighting/time_of_day.gd")
const LAMPS = preload("res://scripts/lighting/car_lamps.gd")
const P = preload("res://scripts/net/net_protocol.gd")
const S = preload("res://scripts/net/net_session.gd")
const SITE = preload("res://scripts/park/park_site.gd")
const TUTORIAL = preload("res://scripts/park/park_tutorial.gd")
const CARS = preload("res://scripts/vehicles/car_catalog.gd")
const DT := 1.0/120.0
const LOBBY := "res://scenes/multiplayer_lobby.tscn"

var host: bool
var driver: String
var sync_dir: String
var port: String
var room: NitroNetSession
var race: Node3D

func _initialize() -> void:
    call_deferred("_run")

func _check(test: bool, label: String) -> bool:
    if not test:
        printerr("FAIL: ",driver," ",label)
        quit(1)
    return test

func _until(test: Callable, label: String, milliseconds := 10000) -> bool:
    var end := Time.get_ticks_msec()+milliseconds
    while not test.call() and Time.get_ticks_msec() < end:
        await process_frame
    return _check(test.call(),label)

func _sync(label: String) -> bool:
    _mark(label+driver)
    return await _until(func(): return _marked(label+"KARLL") and _marked(label+"KEVIN"),label)

func _mark(label: String) -> void:
    FileAccess.open(sync_dir.path_join(label),FileAccess.WRITE).close()

func _marked(label: String) -> bool:
    return FileAccess.file_exists(sync_dir.path_join(label))

func _lobby() -> bool:
    return current_scene != null and current_scene.scene_file_path == LOBBY

func _in_park() -> bool:
    return current_scene != null and current_scene.scene_file_path == "res://scenes/race.tscn" and         S.current != null and S.current.state == S.State.PARK

func _connect_ui() -> void:
    current_scene.join_game()
    current_scene.ip_input.text = "127.0.0.1:"+port
    current_scene.connect_now()
    room = current_scene.session

func _run() -> void:
    var args := OS.get_cmdline_user_args()
    host = args[0] == "host"
    driver = args[1]
    port = args[2]
    sync_dir = args[3]
    CARS.select("red" if driver == "KARLL" else "white")
    _protect_progress_snapshot()
    change_scene_to_file(LOBBY)
    if not await _until(_lobby,"open LAN menu"):
        return
    if host:
        if not _check(current_scene.find_child("HOST PARK",true,false) != null,"Host Park entry"):
            return
        current_scene.host_game(P.PARK_PATH,int(port))
        room = current_scene.session
        if not _check(room != null and room.state == S.State.HOSTING,"host Park from lobby"):
            return
        room.set_time_of_day(TIME.Preset.DAWN)
        _mark("listening")
    else:
        if not await _until(func(): return _marked("listening"),"host port ready"):
            return
        _connect_ui()

    var countdown := [0]
    room.countdown_started.connect(func(_s: float): countdown[0] += 1)
    if not await _until(func(): return room.state == S.State.LOBBY,"join and match Park fingerprint"):
        return
    current_scene.ready_toggle()
    if host:
        if not await _until(room.can_start,"both Park players ready"):
            return
        current_scene.start_game()
    if not await _until(_in_park,"both scenes loaded into free roam"):
        return
    race = current_scene
    var slot := Vector2(-5.0 if host else 5.0,30.0)
    if not _check(race.model.position.distance_to(slot)<0.05 and race.net.remote_car.visible and
            race.net.remote_car.has_node("Opponent marker") and room.round_start_usec == 0 and countdown[0] == 0,
            "independent spawns, visible remote car, no GO countdown"):
        return
    if not _check(race.time_of_day == TIME.Preset.DAWN and race.lamps.spots[0].visible,
            "lobby preset at start"):
        return
    if not host:
        room.set_time_of_day(TIME.Preset.GOLDEN_HOUR)
        if not _check(room.time_of_day == TIME.Preset.DAWN,"guest cannot change shared time"):
            return
    if not await _sync("lighting_ready"):
        return
    if host:
        race._toggle_pause()
        var selector: Node = race.pause_menu.find_child("TIME OF DAY",true,false)
        selector.get_node("NIGHT").pressed.emit()
        race._toggle_pause()
    if not await _until(func(): return race.time_of_day == TIME.Preset.NIGHT,"host Park pause updates both scenes live"):
        return
    race._set_lamp_mode(LAMPS.Mode.ON if host else LAMPS.Mode.OFF)
    Input.action_press("handbrake")
    var expected := LAMPS.BRAKING if host else (LAMPS.POSITION | LAMPS.BRAKING)
    if not await _until(func(): return race.net.remote_lamps.bits == expected,"other peer lamp and handbrake state"):
        return
    if not await _sync("lighting_brake"):
        return
    Input.action_release("handbrake")
    race._set_lamp_mode(LAMPS.Mode.AUTO)
    if not await _until(func(): return race.net.remote_lamps.bits == LAMPS.POSITION,"release restores shared tail state"):
        return
    if not await _sync("lighting_release"):
        return
    print("PARK_LIGHTING ",driver," host=",host," start=DAWN live=NIGHT lamp=ON/OFF brake=SYNCED")
    var received: Array[int] = []
    var sample := func(s: Dictionary): received.append(s.recv_ms)
    room.remote_snapshot.connect(sample)
    Input.action_press("throttle",0.38)
    if not await _until(func(): return received.size() >= 62,"live 20 Hz tandem snapshots"):
        return
    Input.action_release("throttle")
    room.remote_snapshot.disconnect(sample)
    if not _check(race.model.position.distance_to(slot)>8.0 and race.net.remote_view.has_data(), "live driving and remote interpolation"):
        return
    var gaps: Array[int] = []
    for i in range(1,received.size()):
        gaps.append(received[i]-received[i-1])
    gaps.sort()
    print("PARK_NET %s samples=%d rtt_ms=%.2f median_gap_ms=%d p95_gap_ms=%d accepted=%d" %
        [driver,received.size(),room.rtt_ms,gaps[gaps.size()/2],gaps[floori(gaps.size()*0.95)],room.accepted_snapshots])
    if not await _sync("sample"):
        return

    race._restart()
    if not await _tour():
        return
    if not await _sync("tour"):
        return
    race._restart()
    if not _check(race.model.position.x * slot.x > 0.0 and race.model.velocity == Vector2.ZERO and
            race.time_elapsed == 0.0 and room.standings().is_empty(),"independent recovery and no clock/standings"):
        return

    if not await _jump_together():
        return
    race._restart()
    if not await _sync("stunt_end"):
        return

    var cone_home: Vector2 = race.park.cones.homes[0]
    if host:
        if not _check(room.host_park_event(P.ParkEvent.RESET_TRAINING),"host training reset"):
            return
        _mark("cones-ready")
    else:
        if not await _until(func(): return _marked("cones-ready") and room.park_revision == 1,"host reset replicated"):
            return
        if not _check(not room.host_park_event(P.ParkEvent.RESET_TRAINING),"guest lacks reset authority"):
            return
        var props: Node = race.park.stunts
        if not _check(props.visuals[13].position == props.fixtures[13].at,"host reset restored cardboard on guest"):
            return
        race.model.reset(cone_home,0.0)
    if not await _until(func(): return race.park.cones.positions[0].distance_to(cone_home)>0.18,"guest contact moved authoritative cone on this peer"):
        return
    if not host:
        race._restart()
    if not await _sync("contact"):
        return
    race.park.toggle_tutorial()
    if not _check(race.park.tutorial.lesson().id == "donut_left" and not race.park.tutorial.persist_progress and
            race.park.cones.displaced_count() > 0,"shared training keeps cone state and starts local donut guide"):
        return
    for exercise in ["eight_large","eight_small"]:
        race.park.tutorial._begin_lesson(TUTORIAL.lesson_ids().find(exercise))
        if not _check(race.park.tutorial.lesson().id == exercise and race.park.cones.displaced_count() > 0,
                "figure-eight guide leaves remote and shared objects alone"):
            return
    race.park.skip_tutorial()
    if not await _sync("guided"):
        return

    if not host:
        _pause_button("RETURN TO LOBBY")
        if not await _until(_lobby,"guest returned to LAN menu"):
            return
        if not await _until(func(): return _marked("host-open"),"host left Park open"):
            return
        _connect_ui()
        if not await _until(_in_park,"guest rejoined directly into living Park"):
            return
        race = current_scene
        if not await _until(func(): return race.time_of_day == TIME.Preset.GOLDEN_HOUR and race.net.remote_lamps.bits == LAMPS.POSITION,
                "late join receives current preset and host override"):
            return
        if not await _until(func(): return race.park.cones.positions[0].distance_to(cone_home)>0.18,"late join received displaced cone state"):
            return
        if not await _until(func(): return race.park.stunts.visuals[13].position.distance_to(race.park.stunts.fixtures[13].at)>0.3,
                "late join receives current stunt prop transforms"):
            return
        if not _check(room.round_id == 2 and not race.net.freezes() and race.model.position.distance_to(Vector2(5,45)) < 0.5,
                "reconnect avoids the occupied nominal spawn without a countdown"):
            return
        _mark("guest-back")
    else:
        if not await _until(func(): return room.other_id == 0 and not race.net.remote_car.visible,"guest disconnected and remote car removed"):
            return
        if not _check(room.state == S.State.PARK and not race.net.freezes(),"host can still drive"):
            return
        race.model.reset(Vector2(5,30),0.0)
        if not await _until(func(): return room.park_host_position == Vector2(5,30),"host occupies the nominal guest spawn"):
            return
        var parked_world: Node = race.park.stunts
        var hit_at: Vector3 = parked_world.fixtures[13].at
        parked_world.contact(hit_at,hit_at,0.0,Vector2(0,-13),Vector2(2.6,1.1))
        if not await _until(func(): return parked_world.visuals[13].position.distance_to(hit_at)>0.4,"solo host displaces cardboard while room stays open"):
            return
        room.set_time_of_day(TIME.Preset.GOLDEN_HOUR)
        race._set_lamp_mode(LAMPS.Mode.ON)
        _mark("host-open")
        if not await _until(func(): return _marked("guest-back") and room.park_peer_loaded() and race.net.remote_car.visible,"host saw reconnect"):
            return
        var reserved := [P.ParkEvent.OBJECT_IMPULSE,P.ParkEvent.PLAYER_CONTACT,P.ParkEvent.BUMPER_DAMAGE,
            P.ParkEvent.DETACH_COMPONENT,P.ParkEvent.SERVICE_REPAIR]
        for kind in reserved:
            if not _check(not room.host_park_event(kind),"reserved future event was accepted"):
                return
        print("PARK_CONES packets=%d payload_bytes=%d" %
            [race.park.shared_training.packets_sent,race.park.shared_training.payload_bytes_sent])
        _pause_button("RESET TRAINING OBJECTS")
    if not await _until(func(): return room.park_revision == 2 and race.park.cones.displaced_count() == 0,"host pause command reset both cone sets"):
        return
    if not _check(race.park.stunts.visuals[13].position==race.park.stunts.fixtures[13].at,
            "host reset reached the reconnected player's props"):
        return
    if not _check(_progress_unchanged() and race.time_elapsed == 0.0 and race.lap == 1 and not race.finished,
            "Park did not write progress, scores or race timers"):
        return
    if not await _sync("reset"):
        return
    if host:
        _pause_button("RETURN TO LOBBY")
    if not await _until(func(): return _lobby() and current_scene.session == room and room.state == S.State.LOBBY,
            "host returned both peers to the same ready room"):
        return
    if not await _sync("lobby"):
        return
    if not _check(room.is_park() and not room.me.ready and not room.other.ready and countdown[0] == 0,"ready flags cleared, never entered countdown"):
        return
    # Ensure the re-used connection can switch right back to a scored circuit.
    if host:
        current_scene.cycle_track(1)
    if not await _until(func(): return room.track_path == P.TRACKS[0],"switch from Park to competitive circuit"):
        return
    current_scene.ready_toggle()
    if host:
        if not await _until(room.can_start,"competitive ready after Park"):
            return
        current_scene.start_game()
    if not await _until(func(): return room.state == S.State.COUNTDOWN,"competitive countdown still scheduled"):
        return
    room.set_time_of_day(TIME.Preset.NIGHT)
    if not _check(current_scene.time_of_day == TIME.Preset.GOLDEN_HOUR,"competitive environment starts shared and stays fixed"):
        return
    if not await _sync("end"):
        return
    unload_current_scene()
    await process_frame
    await process_frame
    print("PASS: Park LAN ",driver," ",("host" if host else "guest")," drives every zone, rendezvous, sees shared cones, and returns to competitive play")
    quit(0)

func _jump_together() -> bool:
    var world: Node = race.park.stunts
    var ramp: Dictionary = SITE.RAMPS[1 if host else 2]
    var own := 0.0
    var other := 0.0
    race.park._reset_air()
    race.model.reset(ramp.start+Vector2(0,7),0.0)
    race.model.velocity = Vector2(0,-8.5)
    if not await _sync("stunt_start"):
        return false
    var until_ms := Time.get_ticks_msec()+5500
    while Time.get_ticks_msec() < until_ms:
        Input.action_press("throttle",clampf(0.30+(8.5-race.model.speed_mps())*0.19,0.0,1.0))
        own = maxf(own,race.car_y)
        other = maxf(other,race.net.remote_car.position.y)
        await process_frame
    Input.action_release("throttle")
    var moved := func(id: int) -> bool: return world.visuals[id].position.distance_to(world.fixtures[id].at) > 0.18
    if not await _until(func(): return moved.call(3) and moved.call(13),"both simultaneous cardboard hits resolved on this peer"):
        return false
    print("STUNT_LAN %s own_apex=%.2f m remote_apex=%.2f m sent=%d payload_bytes=%d bodies_peak=%d" %
        [driver,own,other,world.packets,world.payload_bytes,world.peak_active])
    return _check(own>1.9 and other>1.9 and (host or world.pool.is_empty()),"remote height interpolates and only the host owns rigid bodies")

func _pause_button(label: String) -> void:
    race._toggle_pause()
    var button: Button = race.find_child(label,true,false)
    if not _check(button != null,"pause button "+label):
        return
    button.pressed.emit()
    button.pressed.emit()

var _progress_before: Dictionary = {}

func _protect_progress_snapshot() -> void:
    for name in ["nitro_park.cfg","nitro_local_runs.json"]:
        _progress_before[name] = FileAccess.get_file_as_bytes("user://"+name)

func _progress_unchanged() -> bool:
    for name in _progress_before:
        if FileAccess.get_file_as_bytes("user://"+name) != _progress_before[name]:
            return false
    return true

func _tour() -> bool:
    var checkpoints := [race.model.position,Vector2(-95,26),Vector2(-170,20),Vector2(-244,18),
        Vector2(-285,20),Vector2(-297,39),Vector2(-266,57),Vector2(-211,60),Vector2(-163,44),
        Vector2(-85,24),Vector2(10,36),Vector2(161,67),Vector2(198,82),Vector2(263,82),
        Vector2(292,79),Vector2(306,85),Vector2(297,96),Vector2(269,96),Vector2(212,97),Vector2(179,88),Vector2(161,72),Vector2(155,42),Vector2(165,25),
        Vector2(190,14),Vector2(214,2),Vector2(224,-14),Vector2(224,-33),Vector2(207,-37)]
    checkpoints.append_array(SITE.STUNT_ACCESS)
    checkpoints.append_array([Vector2(81,-378),Vector2(22,-411),Vector2(-42,-402),Vector2(-91,-372),
        Vector2(-71,-350),Vector2(-5,-348),Vector2(68,-350),Vector2(124,-355)])
    var return_road := SITE.STUNT_ACCESS.duplicate()
    return_road.reverse()
    checkpoints.append_array(return_road.slice(1))
    checkpoints.append_array([Vector2(149,-55),Vector2(82,-54),Vector2(15,-48),Vector2(-75,-67)])
    checkpoints.append_array(SITE.ENTRY_LANE)
    var route := SITE.road(checkpoints)
    var loop := SITE.road(SITE.LOOP,true)
    route.append_array(loop.slice(1))
    route.append(loop[0])
    for p in loop.slice(1):
        if p.distance_to(SITE.EXIT) < 2.0:
            break
        route.append(p)
    route.append_array(SITE.road(SITE.EXIT_LANE))
    route.append_array(SITE.road([SITE.EXIT_LANE[-1],Vector2(80,-67),Vector2(29,-19),Vector2(0,18)]).slice(1))
    race.set_physics_process(false)
    var cursor := 0
    for tick in range(95000):
        var model: NitroDriveModel = race.model
        var nearest := INF
        for j in range(maxi(cursor-4,0),mini(cursor+12,route.size())):
            var dist := model.position.distance_squared_to(route[j])
            if dist < nearest:
                nearest = dist
                cursor = j
        if cursor >= route.size()-3:
            Input.action_release("throttle")
            Input.action_release("steer_left")
            Input.action_release("steer_right")
            race.set_physics_process(true)
            print("PARK_TOUR %s virtual_seconds=%.1f checkpoint=%d" % [driver,tick*DT,cursor])
            return true
        if tick > 120 and nearest > 7.0*7.0:
            return _check(false,"tour strayed near %s targeting %s" % [model.position,route[cursor]])
        var aim := route[mini(cursor+6,route.size()-1)]-model.position
        var steer := clampf(wrapf(atan2(aim.x,-aim.y)-model.heading,-PI,PI)*1.8,-1.0,1.0)
        var desired := lerpf(39.0,26.0,absf(steer))
        Input.action_press("steer_left",maxf(-steer,0.0))
        Input.action_press("steer_right",maxf(steer,0.0))
        Input.action_press("throttle",clampf(0.40+(desired-model.speed_kmh())*0.11,0.0,1.0))
        race._physics_process(DT)
        if tick%150 == 0:
            await process_frame
    return _check(false,"tour timed out at "+str(race.model.position))
