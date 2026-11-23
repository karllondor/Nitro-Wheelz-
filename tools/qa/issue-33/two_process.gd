extends SceneTree
## Run once with NITRO_ROLE=host and once with NITRO_ROLE=join, distinct XDG_DATA_HOME.
const NET = preload("res://scripts/net/net_session.gd")
const RESULTS = preload("res://scripts/ui/race_results.gd")
var role := OS.get_environment("NITRO_ROLE")
func _initialize() -> void:
    call_deferred("run")

func until(check: Callable, limit_ms := 15000) -> bool:
    var end := Time.get_ticks_msec()+limit_ms
    while Time.get_ticks_msec() < end:
        if check.call(): return true
        await process_frame
    return false

func fail(message: String) -> void:
    printerr("FAIL ",role,": ",message)
    quit(1)

func run() -> void:
    var f := FileAccess.open(RESULTS.STORAGE,FileAccess.WRITE)
    var prior := '[{"track_id":"qa-prior","score":321,"stars":1}]'
    f.store_string(prior)
    f.close()
    change_scene_to_file("res://scenes/multiplayer_lobby.tscn")
    await scene_changed
    var lobby = current_scene
    if role=="host":
        lobby.host_game()
    else:
        lobby.join_game()
        lobby.ip_input.text="127.0.0.1"
        lobby.connect_now()
    var session=NET.current
    if not await until(func(): return session and session.state==NET.State.LOBBY and not session.other.is_empty()):
        fail("lobby")
        return
    lobby.ready_toggle()
    if role=="host":
        if not await until(func(): return session.can_start()):
            fail("ready")
            return
        lobby.start_game()
    if not await until(func(): return current_scene and current_scene.scene_file_path=="res://scenes/race.tscn" and session.state==NET.State.RACING):
        fail("race did not launch on GO")
        return
    var race=current_scene
    var local_start:Vector2=race.model.position
    var remote_start:Vector3=race.net.remote_car.position
    Input.action_press("throttle",0.75)
    await create_timer(2.5).timeout
    Input.action_release("throttle")
    var moved:=local_start.distance_to(race.model.position)
    var followed:=remote_start.distance_to(race.net.remote_car.position)
    if moved<4.0 or followed<4.0 or RESULTS.record_allowed():
        fail("expected both cars to drive with records disabled: %s %s" % [moved,followed])
        return
    if role=="host":
        if not await until(func(): return session.state==NET.State.LOST):
            fail("host did not detect departing joiner")
            return
    race._show_results()
    var view=race.results_layer.get_child(0)
    if view.data.stored or not view.data.multiplayer or FileAccess.get_file_as_string(RESULTS.STORAGE)!=prior:
        fail("changed historic records")
        return
    change_scene_to_file("res://scenes/boot.tscn")
    await scene_changed
    if NET.current!=null or not RESULTS.record_allowed():
        fail("solo state did not recover")
        return
    print("PASS ",role,": local %.1f m, remote %.1f m, result storage byte-identical, solo recovered" % [moved,followed])
    quit()
