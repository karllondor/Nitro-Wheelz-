extends SceneTree
## One real game process. tools/test_net_rounds.py runs two isolated profiles and swaps hosts.
const S = preload("res://scripts/net/net_session.gd")
const P = preload("res://scripts/net/net_protocol.gd")
const RACE = preload("res://scenes/race.tscn")
const CARS = preload("res://scripts/vehicles/car_catalog.gd")
var session := S.new()
var race: Node3D
var host_role: bool
var driver: String
var sync_dir: String

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> bool:
    if not ok:
        printerr("FAIL: ",driver," ",message)
        quit(1)
    return ok

func _until(check: Callable) -> bool:
    var until_ms := Time.get_ticks_msec() + 9500
    while not check.call() and Time.get_ticks_msec() < until_ms:
        await process_frame
    return _check(check.call(),"timeout, round %d state %d" % [session.round_id,session.state])

func _marker(id: String) -> void:
    FileAccess.open(sync_dir+"/"+id,FileAccess.WRITE).close()

func _peer_checked(id: String) -> bool:
    return FileAccess.file_exists(sync_dir+"/"+id)

func _state(st: int) -> void:
    if st == S.State.RACING:
        print("GO_OBS ",session.round_id," ",roundi(Time.get_unix_time_from_system()*1000))

func _countdown(id: int) -> bool:
    if not await _until(func(): return session.state == S.State.COUNTDOWN and session.round_id == id):
        return false
    var home: Vector2 = race.net.spawn_position(race.track.start_position(),race.track.start_heading(),session.local_index)
    var seen: Array[String] = []
    while session.state == S.State.COUNTDOWN:
        var value: String = race.net._count.text
        if not value.is_empty() and not seen.has(value):
            seen.append(value)
        if not _check(race.model.position.distance_to(home)<0.01 and race.time_elapsed==0 and race.lap==1 and
                race.lap_splits.is_empty() and race.scorer.total==0 and not race.paused and not race.results_open,
                "dirty round reset or movement before GO"):
            return false
        await process_frame
    if not await _until(func(): return race.net._count.text=="GO!"):
        return false
    return _check(seen==["3","2","1"],"countdown displayed "+str(seen))

func _run() -> void:
    var args := OS.get_cmdline_user_args()
    host_role = args[0]=="host"
    driver = args[1]
    sync_dir = args[3]
    var car := "blue" if driver=="KEVIN" else "red"
    CARS.select(car)
    if car=="blue":
        var prof := CARS.cosmetic_profile(car)
        var choice := CARS.COSMETICS.current(car,prof)
        choice.livery_id = "stripes"
        CARS.COSMETICS.save(car,choice)
    root.add_child(session)
    session.state_changed.connect(_state)
    var err: int
    if host_role:
        err = session.host(int(args[2]),driver,car,P.TRACKS[0])
        _marker("listening")
    else:
        if not await _until(func(): return _peer_checked("listening")):
            return
        err = session.join("127.0.0.1",int(args[2]),driver,car)
    if not _check(err==OK,"open socket") or not await _until(func(): return session.state==S.State.LOBBY):
        return
    session.set_ready(true)
    if host_role:
        if not await _until(session.can_start):
            return
        session.start_race()
    if not await _until(func(): return session.state==S.State.STARTING):
        return
    ProjectSettings.set_setting("nitro/selected_track",session.track_path)
    race = RACE.instantiate()
    root.add_child(race)
    if not _check(race.net.remote_car.has_node("Opponent marker"),"missing opponent marker"):
        return
    if driver=="KARLL" and not _check(race.net.remote_car.cosmetic.livery_id=="stripes" and
            race.net.remote_car.paint_material.get_shader_parameter("livery_on")==1.0,"peer livery replaced by local save"):
        return
    if not await _countdown(1):
        return
    race.scorer.total = 809
    race.lap = 2
    race.lap_splits.append({"time":3,"score":9})
    race.model.position += Vector2(8,8)
    race._toggle_pause()
    if not host_role:
        race._restart()
        if not _check(session.round_id==1 and race.paused,"client restarted its own race"):
            return
    else:
        if not await _until(func(): return race.net.remote_paused):
            return
        race._restart()
        race._restart() # rapid second activation during reset
    if not await _countdown(2):
        return
    # A delayed result and transform from round one must never affect round two.
    session._on_control({"t":P.Msg.FINISH,"round":1,"points":99999,"time_ms":1})
    session._on_snapshot(P.pack_snapshot({"round":1,"seq":2300,"score":99999}))
    if not _check(session.drivers[1-session.local_index].status=="RACING" and
            session.drivers[1-session.local_index].points==0,"previous round crossed reset"):
        return
    for round_number in [2,3]:
        if round_number==3 and not await _countdown(3):
            return
        # One driver reaches the actual finish presentation while the other is still racing.
        var first: bool = (driver=="KEVIN") == (round_number==2)
        if not first:
            if not await _until(func(): return session.drivers[1-session.local_index].status=="FINISHED"):
                return
        race.scorer.total = 900 if driver=="KARLL" or round_number==3 else 400
        race.lap_score = race.scorer.total
        race.time_elapsed = 56.789 if driver=="KARLL" else 45.123
        race.finished = true
        race._show_results()
        var board = race.results_layer.get_child(0)
        if first and not _check(board.cells[3].text=="RACING" or board.cells[7].text=="RACING","missing pending driver"):
            return
        if not await _until(func(): return session.drivers.all(func(row): return row.status=="FINISHED")):
            return
        var winner := "KARLL" if round_number==2 else "KEVIN"
        if not _check(board.cells[0].text=="1. "+winner and board.cells[2].text=="900" and
                board.cells[1].text==CARS.info("red" if winner=="KARLL" else "blue").short and
                board.cells[3].text==board.RESULTS.clock(56.789 if winner=="KARLL" else 45.123)
                and board.restart.disabled!=host_role,"comparative results or restart authority"):
            return
        _marker(driver+str(round_number))
        if not await _until(func(): return _peer_checked(("KARLL" if driver=="KEVIN" else "KEVIN")+str(round_number))):
            return
        if round_number==2 and host_role:
            board.restart.pressed.emit()
    if driver=="KEVIN":
        race.queue_free()
    else:
        if not await _until(func(): return session.state==S.State.LOST):
            return
        if not _check(session.standings()[0].status=="FINISHED" and race.results_layer.get_child(0).restart.disabled,"lost final result"):
            return
        race.queue_free()
    await process_frame
    await process_frame
    if not _check(S.current==null,"session survived exit"):
        return
    print("PASS: ",driver," three rounds, livery, reset from pause/results, ranking and clean leave")
    quit()
