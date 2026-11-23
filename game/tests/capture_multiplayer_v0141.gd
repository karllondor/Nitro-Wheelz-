extends SceneTree
## v0.1.41 evidence for issue #31 (developer tool, needs a display). Run:
##   OUT_DIR=/abs/dir xvfb-run -a -s "-screen 0 900x2000x24" godot --path game --rendering-driver opengl3 \
##     --resolution 900x2000 --script res://tests/capture_multiplayer_v0141.gd
## Two lobby screens (host + guest) talk through a REAL ENet loopback session; the host's race scene is captured
## in the lobby, the countdown and while driving. The OTHER car is driven by a scripted NitroDriveModel whose state
## goes through the real snapshot path (loopback) - this is a container capture, NOT a second phone.
const P = preload("res://scripts/net/net_protocol.gd")
const SESSION = preload("res://scripts/net/net_session.gd")
const LOBBY = preload("res://scenes/multiplayer_lobby.tscn")
const RACE = preload("res://scenes/race.tscn")
const DRIVE = preload("res://scripts/driving/drive_model.gd")
const CARS = preload("res://scripts/vehicles/car_catalog.gd")
const NET_RACE = preload("res://scripts/net/net_race.gd")
const DT: float = 1.0/120.0

var out_dir: String = "user://mp/"

func _frames(n: int) -> void:
    for i in range(n):
        await process_frame

func _shot(name: String) -> void:
    await _frames(5)
    root.get_viewport().get_texture().get_image().save_png(out_dir+name+".png")
    print("SHOT ",name)

func _until(cond: Callable, seconds: float = 8.0) -> bool:
    var t0: int = Time.get_ticks_msec()
    while Time.get_ticks_msec()-t0 < int(seconds*1000.0):
        if cond.call():
            return true
        await process_frame
    return cond.call()

func _run() -> void:
    var env_dir: String = OS.get_environment("OUT_DIR")
    if env_dir != "":
        out_dir = env_dir.trim_suffix("/")+"/"
    DirAccess.make_dir_recursive_absolute(out_dir)
    ProjectSettings.set_setting("nitro/car_variant","red")
    Engine.max_physics_steps_per_frame = 60     # software rendering is slow: keep the simulation at real time
    var host_ui: Control = LOBBY.instantiate()
    host_ui.set("navigate_enabled",false)
    root.add_child(host_ui)
    await _frames(4)
    await _shot("01_lobby_menu")
    host_ui.call("host_game")
    await _frames(4)
    await _shot("02a_host_waiting_container_has_no_lan_address")
    # a container has no Wi-Fi interface: this shot shows an EXAMPLE address injected for the picture only
    NitroMultiplayerLobby.address_override = ["192.168.43.1   (EXAMPLE - WI-FI / HOTSPOT)"]
    host_ui.call("_refresh")
    await _frames(3)
    await _shot("02b_host_waiting_EXAMPLE_ADDRESS")
    NitroMultiplayerLobby.address_override = []
    var guest_ui: Control = LOBBY.instantiate()
    guest_ui.set("navigate_enabled",false)
    root.add_child(guest_ui)
    host_ui.visible = false
    await _frames(2)
    guest_ui.call("join_game")
    await _frames(4)
    (guest_ui.find_child("IP input",true,false) as LineEdit).text = "192.168.43.1"
    await _shot("03_join_address")
    (guest_ui.find_child("IP input",true,false) as LineEdit).text = "127.0.0.1"
    guest_ui.call("connect_now")
    var hs: NitroNetSession = host_ui.get("session")
    var gs: NitroNetSession = guest_ui.get("session")
    await _until(func(): return hs.state == NitroNetSession.State.LOBBY and gs.state == NitroNetSession.State.LOBBY and not hs.other.is_empty() and not gs.other.is_empty())
    gs.set_car("blue")
    await _frames(4)
    await _shot("04_ready_room_guest")
    host_ui.visible = true
    guest_ui.visible = false
    await _frames(2)
    host_ui.call("ready_toggle")
    guest_ui.call("ready_toggle")
    await _until(func(): return hs.can_start())
    await _frames(4)
    await _shot("05_ready_room_host_start_enabled")
    host_ui.call("start_game")
    await _until(func(): return gs.state == NitroNetSession.State.STARTING)
    host_ui.queue_free()
    guest_ui.queue_free()
    await _frames(3)
    SESSION.current = hs
    var race: Node3D = RACE.instantiate()
    root.add_child(race)
    await _frames(10)
    gs.report_loaded()
    await _until(func(): return hs.state == NitroNetSession.State.COUNTDOWN)
    await _until(func(): return hs.countdown_remaining() < 2.2)
    await _shot("06_countdown")
    await _until(func(): return hs.state == NitroNetSession.State.RACING)
    # the other phone: a second drive model, scripted, sends real snapshots through the loopback session
    var h0: float = race.track.start_heading()
    var slot1: Vector2 = NET_RACE.spawn_position(race.track.start_position(),h0,1)
    var other = DRIVE.new()
    CARS.configure_model(other,"red")      # same handling as the host car so both stay in one picture; the visual is the guest's BLUE car
    other.reset(slot1,h0)
    var t0: int = Time.get_ticks_msec()
    var acc: float = 0.0
    var next_send: int = 0
    var shots: Array = [[1200,"07_two_cars_after_go"],[3400,"08_two_cars_drifting"],[4800,"09_two_cars_drifting_later"]]
    var prev: int = Time.get_ticks_msec()
    var frames_dir: String = OS.get_environment("FRAMES_DIR")      # optional: a 10 fps frame sequence for a short recording
    if frames_dir != "":
        DirAccess.make_dir_recursive_absolute(frames_dir)
    var last_frame: int = -1000
    var frame_no: int = 0
    while Time.get_ticks_msec()-t0 < 9000:
        var now: int = Time.get_ticks_msec()
        var el: float = float(now-t0)/1000.0
        acc += float(now-prev)/1000.0
        prev = now
        # host car (this screen): gas, a right turn with a handbrake flick
        Input.action_press("throttle",1.0)
        Input.action_release("steer_left")
        if el > 2.0 and el < 6.0:
            Input.action_press("steer_right",0.55)
        else:
            Input.action_release("steer_right")
        if el > 2.1 and el < 2.4:
            Input.action_press("handbrake",1.0)
        else:
            Input.action_release("handbrake")
        # the other car: slightly later and a bit stronger
        var steer: float = 0.0
        var hb: float = 0.0
        if el > 2.2 and el < 6.2:
            steer = 0.55
        if el > 2.3 and el < 2.6:
            hb = 1.0
        while acc >= DT:
            other.step(DT,steer,1.0,0.0,hb)
            acc -= DT
        if now-t0 >= next_send:
            next_send += 50
            gs.send_snapshot({"flags":1 if other.is_drifting() else 0,"ms":SESSION.now_ms(),"x":other.position.x,"z":other.position.y,"heading":other.heading,
                "vx":other.velocity.x,"vz":other.velocity.y,"yaw":other.yaw_rate,"steer":other.steering_angle,"score":int(el*180.0)})
        if frames_dir != "" and now-last_frame >= 100:
            last_frame = now
            var img: Image = root.get_viewport().get_texture().get_image()
            img.resize(450,1000,Image.INTERPOLATE_BILINEAR)
            img.save_png("%s/f_%04d.png" % [frames_dir,frame_no])
            frame_no += 1
        if not shots.is_empty() and now-t0 >= int(shots[0][0]):
            await _shot(str(shots[0][1]))
            shots.pop_front()
        await process_frame
    for a in ["throttle","steer_right","handbrake"]:
        Input.action_release(a)
    print("DONE host score=%d remote_score=%d dropped=%d" % [int(race.scorer.total),race.net.remote_score,race.net.dropped_jumps])
    race.queue_free()
    await _frames(3)
    quit(0)

func _initialize() -> void:
    call_deferred("_run")
