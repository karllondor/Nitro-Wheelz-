extends SceneTree
## Offline local multiplayer (issue #31): the multiplayer side of the REAL race scene, on the loopback of one
## desktop process (host race scene + a second ENet session standing in for the other phone).
##  * interpolation maths (bracketing Hermite, bounded extrapolation, heading wrap),
##  * both start slots are on the road of every shareable circuit and 5.2 m apart,
##  * the car stands still during the countdown and drives after GO; solo play is untouched,
##  * the remote car is a visual only, moves smoothly (no teleport), ignores impossible jumps, snaps on a reset,
##  * multiplayer runs never write a record or a star, and leaving leaves no network state behind,
##  * a lost peer never stops the local drive.
## NOT proven here: Wi-Fi / hotspot timing, Android lifecycle, real thumbs (owner QA on two phones).
const P = preload("res://scripts/net/net_protocol.gd")
const SESSION = preload("res://scripts/net/net_session.gd")
const NET_RACE = preload("res://scripts/net/net_race.gd")
const RACE = preload("res://scenes/race.tscn")
const TRACK = preload("res://scripts/world/drift_track.gd")
const RESULTS = preload("res://scripts/ui/race_results.gd")
const CARS = preload("res://scripts/vehicles/car_catalog.gd")
const RUNS: String = "user://nitro_local_runs.json"

var _track_before: Variant = null
var _created: Array = []

func _initialize() -> void:
    _track_before = ProjectSettings.get_setting("nitro/selected_track","")
    call_deferred("_run")

func _fail(message: String) -> void:
    for s in _created:
        if is_instance_valid(s):
            s.leave()
    Input.action_release("throttle")
    ProjectSettings.set_setting("nitro/selected_track",_track_before)
    printerr("FAIL: "+message)
    quit(1)

func _until(cond: Callable, seconds: float = 6.0) -> bool:
    var t0: int = Time.get_ticks_msec()
    while Time.get_ticks_msec()-t0 < int(seconds*1000.0):
        if cond.call():
            return true
        await process_frame
    return cond.call()

func _snap(k: int, t_ms: int, x: float, z: float, vx: float, vz: float, heading: float) -> Dictionary:
    return {"flags":0,"seq":k,"ms":t_ms,"x":x,"z":z,"heading":heading,"vx":vx,"vz":vz,"yaw":0.0,"steer":0.0,"score":0}

func _run() -> void:
    # ------------------------------------------------------------ interpolation maths
    var buf: Array[Dictionary] = []
    for k in range(10):
        buf.append(_snap(k,1000+50*k,float(k),0.0,20.0,0.0,PI/2.0))
    var mid: Dictionary = NET_RACE.interpolate(buf,1125.0)
    if absf(float(mid["x"])-2.5) > 0.02 or absf(float(mid["z"])) > 0.02:
        _fail("interpolation between two snapshots: %s" % str(mid))
        return
    if absf(float(NET_RACE.interpolate(buf,500.0)["x"])) > 0.001:
        _fail("before the first snapshot the car must stay at the first pose")
        return
    var ahead: Dictionary = NET_RACE.interpolate(buf,1450.0+100.0)
    if absf(float(ahead["x"])-(9.0+2.0)) > 0.02:
        _fail("extrapolation over 100 ms: %s" % str(ahead))
        return
    var capped: Dictionary = NET_RACE.interpolate(buf,1450.0+5000.0)
    if absf(float(capped["x"])-(9.0+20.0*NET_RACE.EXTRAPOLATE_MAX_S)) > 0.02:
        _fail("extrapolation must stop after %.2f s: %s" % [NET_RACE.EXTRAPOLATE_MAX_S,str(capped)])
        return
    var wrap: Array[Dictionary] = [_snap(0,0,0.0,0.0,0.0,0.0,3.1),_snap(1,100,0.0,0.0,0.0,0.0,-3.1)]
    var wh: float = float(NET_RACE.interpolate(wrap,50.0)["heading"])
    if cos(wh) > -0.99:
        _fail("heading must interpolate through +-PI, not through 0 (got %.3f)" % wh)
        return
    # ------------------------------------------------------------------ start slots
    for path in P.TRACKS:
        var t: Node = TRACK.new()
        t.set("track_data_path",path)
        root.add_child(t)
        if not bool(t.get("track_valid")):
            _fail("shareable circuit does not load: "+path)
            return
        var base: Vector2 = t.start_position()
        var h: float = t.start_heading()
        var a: Vector2 = NET_RACE.spawn_position(base,h,0)
        var b: Vector2 = NET_RACE.spawn_position(base,h,1)
        if absf(a.distance_to(b)-2.0*NET_RACE.SLOT_LATERAL_M) > 0.01 or a.distance_to(b) < 4.5:
            _fail("start slots too close on "+path)
            return
        for slot in [a,b]:
            var info: Dictionary = t.sample_info(slot)
            if float(info["distance"]) > float(info["width"])-1.4:
                _fail("a start slot is off the road (or against the wall) on %s: %.2f m from the centre, half width %.2f" % [path,float(info["distance"]),float(info["width"])])
                return
        t.queue_free()
        await process_frame
    # --------------------------------------------------------------------- solo race
    ProjectSettings.set_setting("nitro/selected_track",P.TRACKS[0])
    var solo: Node3D = RACE.instantiate()
    root.add_child(solo)
    await process_frame
    if solo.get("net") != null or NET_RACE.should_attach() or not RESULTS.record_allowed():
        _fail("solo play must not create any multiplayer object or block records")
        return
    var solo_start: Vector2 = solo.model.position
    Input.action_press("throttle",1.0)
    for i in range(60):
        solo._physics_process(1.0/120.0)
    Input.action_release("throttle")
    if solo.model.position.distance_to(solo_start) < 0.05:
        _fail("the solo car must drive at once")
        return
    solo.queue_free()
    await process_frame
    # ------------------------------------------------------ host race + the other phone
    var runs_before: String = FileAccess.get_file_as_string(RUNS) if FileAccess.file_exists(RUNS) else ""
    var host: NitroNetSession = SESSION.new()
    root.add_child(host)
    _created.append(host)
    var client: NitroNetSession = SESSION.new()
    root.add_child(client)
    _created.append(client)
    if host.host(47931,"ANNA","e30",P.TRACKS[0]) != OK or client.join("127.0.0.1",47931,"BORYS","blue") != OK:
        _fail("loopback host / join failed: "+host.last_error+" "+client.last_error)
        return
    var ok: bool = await _until(func(): return host.state == NitroNetSession.State.LOBBY and client.state == NitroNetSession.State.LOBBY and not host.other.is_empty() and not client.other.is_empty())
    if not ok:
        _fail("no lobby")
        return
    host.set_ready(true)
    client.set_ready(true)
    ok = await _until(func(): return host.can_start())
    if not ok or not host.start_race():
        _fail("host cannot start")
        return
    ok = await _until(func(): return client.state == NitroNetSession.State.STARTING)
    if not ok:
        _fail("joiner did not get START")
        return
    SESSION.current = host
    ProjectSettings.set_setting("nitro/selected_track",host.track_path)
    var race: Node3D = RACE.instantiate()
    root.add_child(race)
    await process_frame
    if not host.holds_screen or not client.holds_screen:
        _fail("the screen must stay on while a multiplayer session exists (a locked phone drops the connection)")
        return
    var net: Node = race.get("net")
    if net == null:
        _fail("the race scene did not attach the multiplayer controller")
        return
    var h0: float = race.track.start_heading()
    var slot0: Vector2 = NET_RACE.spawn_position(race.track.start_position(),h0,0)
    var slot1: Vector2 = NET_RACE.spawn_position(race.track.start_position(),h0,1)
    if race.model.position.distance_to(slot0) > 0.01:
        _fail("the host car must start in slot 0")
        return
    if net.remote_car == null or Vector2(net.remote_car.position.x,net.remote_car.position.z).distance_to(slot1) > 0.05:
        _fail("the remote car must stand in slot 1 (%s)" % str(net.remote_car))
        return
    var colliders: int = 0
    for n in net.remote_car.find_children("*","CollisionObject3D",true,false):
        colliders += 1
    if colliders != 0:
        _fail("the remote car must have no collision body (no car-to-car collisions)")
        return
    if RESULTS.record_allowed():
        _fail("records must be blocked while the multiplayer race runs")
        return
    # the countdown: the car is frozen until GO on the host
    Input.action_press("throttle",1.0)
    var frozen_at: Vector2 = race.model.position
    await process_frame
    if host.state != NitroNetSession.State.STARTING:
        _fail("the host waits for the joiner to load (state %d)" % host.state)
        return
    client.report_loaded()
    ok = await _until(func(): return host.state == NitroNetSession.State.COUNTDOWN)
    if not ok:
        _fail("no countdown after both loaded")
        return
    var guard: int = 0
    while host.state == NitroNetSession.State.COUNTDOWN and guard < 2000:
        race._physics_process(1.0/120.0)
        guard += 1
        await process_frame
    if race.model.position.distance_to(frozen_at) > 0.001 and host.state == NitroNetSession.State.COUNTDOWN:
        _fail("the car moved during the countdown")
        return
    ok = await _until(func(): return host.state == NitroNetSession.State.RACING)
    if not ok:
        _fail("GO never came")
        return
    for i in range(240):
        race._physics_process(1.0/120.0)
    if race.model.position.distance_to(frozen_at) < 1.0:
        _fail("the car does not drive after GO")
        return
    # snapshots of the host car reach the other phone (20 Hz, flags: paused)
    var seen: Array = []
    client.remote_snapshot.connect(func(s: Dictionary): seen.append(s))
    for i in range(120):
        race._physics_process(1.0/120.0)
        net._physics_process(1.0/120.0)
        if i%20 == 0:
            await process_frame
    ok = await _until(func(): return seen.size() >= 15)
    if not ok:
        _fail("the host car's snapshots did not reach the other phone (%d)" % seen.size())
        return
    var last: Dictionary = seen.back()
    if Vector2(float(last["x"]),float(last["z"])).distance_to(race.model.position) > 12.0:
        _fail("the sent position is not the car's position")
        return
    race.paused = true
    seen.clear()
    for i in range(30):
        net._physics_process(1.0/120.0)
        await process_frame
    ok = await _until(func(): return not seen.is_empty() and (int(seen.back()["flags"])&2) != 0)
    race.paused = false
    if not ok:
        _fail("the paused flag did not reach the other phone")
        return
    # the remote car follows the other phone smoothly
    var t_start: int = Time.get_ticks_msec()
    var x0: float = slot1.x
    var z0: float = slot1.y
    var speed: float = 15.0
    var next_send: int = 0
    var prev: Vector3 = net.remote_car.position
    var worst_step: float = 0.0
    var prev_ticks: int = Time.get_ticks_usec()
    while Time.get_ticks_msec()-t_start < 2200:
        var el: float = float(Time.get_ticks_msec()-t_start)/1000.0
        if Time.get_ticks_msec()-t_start >= next_send:
            client.send_snapshot({"flags":1,"ms":SESSION.now_ms(),"x":x0+speed*el,"z":z0,"heading":PI/2.0,"vx":speed,"vz":0.0,"yaw":0.0,"steer":0.1,"score":1234})
            next_send += 50
        await process_frame
        var now: int = Time.get_ticks_usec()
        var dt: float = float(now-prev_ticks)/1000000.0
        prev_ticks = now
        var cur: Vector3 = net.remote_car.position
        if el > 0.5:
            var step: float = cur.distance_to(prev)
            worst_step = maxf(worst_step,step)
            if step > speed*dt*2.0+0.4:
                _fail("the remote car jumped %.2f m in one frame of %.3f s (jitter / teleport)" % [step,dt])
                return
        prev = cur
    var travelled: float = net.remote_car.position.x-x0
    if travelled < 14.0 or travelled > speed*2.2:
        _fail("the remote car did not follow the other phone (moved %.1f m, expected about %.1f m minus the 120 ms delay)" % [travelled,speed*2.2-speed*0.12])
        return
    if net.remote_score != 1234:
        _fail("the remote score label must show the other player's points (informational)")
        return
    var score_label: Label = net.get("_score") as Label
    if score_label == null or not score_label.text.contains("1234 PTS") or not score_label.text.contains("LINK "):
        _fail("the other player's label must carry the points and the LINK quality word (got '%s')" % (score_label.text if score_label != null else "null"))
        return
    if absf(net.remote_car.rotation.y+PI/2.0) > 0.05:
        _fail("the remote car heading does not match (%.3f)" % net.remote_car.rotation.y)
        return
    # an impossible jump is ignored, a deliberate reset snaps
    var before_jump: Vector3 = net.remote_car.position
    var jumps: int = net.dropped_jumps
    client.send_snapshot({"flags":0,"ms":SESSION.now_ms()+10,"x":x0+speed*2.2+900.0,"z":z0,"heading":0.0,"vx":0.0,"vz":0.0,"yaw":0.0,"steer":0.0,"score":1234})
    ok = await _until(func(): return net.dropped_jumps > jumps)
    for i in range(10):
        await process_frame
    if not ok or net.remote_car.position.distance_to(before_jump) > 8.0:
        _fail("an impossible jump must be dropped, not shown (%.1f m)" % net.remote_car.position.distance_to(before_jump))
        return
    var far: Vector2 = Vector2(x0+60.0,z0+40.0)
    client.send_snapshot({"flags":4,"ms":SESSION.now_ms(),"x":far.x,"z":far.y,"heading":0.0,"vx":0.0,"vz":0.0,"yaw":0.0,"steer":0.0,"score":0})
    ok = await _until(func(): return Vector2(net.remote_car.position.x,net.remote_car.position.z).distance_to(far) < 3.0)
    if not ok:
        _fail("a reset (flag 4) must snap the remote car to the new place")
        return
    # A social run has no star target in the driving HUD.
    race._update_visuals()
    if str(race.hud.chase_label().text).contains("★"):
        _fail("multiplayer HUD advertised a solo star: "+str(race.hud.chase_label().text))
        return
    # nothing of this is a record
    var rs: Control = RESULTS.new()
    root.add_child(rs)
    rs.show_race("qa_net_race","QA",42.0,9999,60.0,func(): pass,func(): pass,{"length_m":900.0,"laps":[]})
    var saved: String = FileAccess.get_file_as_string(RUNS) if FileAccess.file_exists(RUNS) else ""
    if bool(rs.data.get("stored",true)) or not bool(rs.data.get("multiplayer",false)) or saved != runs_before:
        _fail("a multiplayer run was saved or not marked (stored=%s)" % str(rs.data.get("stored")))
        return
    rs.queue_free()
    # connection lost: a readable message, the local car keeps driving
    client.leave()
    ok = await _until(func(): return host.state == NitroNetSession.State.LOST)
    if not ok or net.lost_reason == "":
        _fail("a lost peer must be reported in the race (state %d)" % host.state)
        return
    if net.freezes():
        _fail("a lost peer must never freeze the local car")
        return
    var before_drive: Vector2 = race.model.position
    for i in range(120):
        race._physics_process(1.0/120.0)
    Input.action_release("throttle")
    if race.model.position.distance_to(before_drive) < 0.5:
        _fail("the local car must keep driving after the other phone left")
        return
    race._show_results()
    var loss_view = race.results_layer.get_child(0)
    var after_loss: String = FileAccess.get_file_as_string(RUNS) if FileAccess.file_exists(RUNS) else ""
    if loss_view.data.stored or not loss_view.data.multiplayer or after_loss != runs_before:
        _fail("finishing after the peer left changed official results")
        return
    # leaving the race scene leaves no network state and re-enables records
    var host_id: int = host.get_instance_id()
    race.queue_free()
    ok = await _until(func(): return SESSION.current == null and not is_instance_id_valid(host_id))
    if client.holds_screen:
        _fail("leaving the session must release the keep-screen-on request")
        return
    if not ok or not RESULTS.record_allowed() or NET_RACE.should_attach():
        _fail("leaving the race left multiplayer state behind (current=%s)" % str(SESSION.current))
        return
    ProjectSettings.set_setting("nitro/selected_track",_track_before)
    print("PASS: local multiplayer race integration on the loopback - interpolation (bracketing Hermite, 0.25 s extrapolation cap, heading wrap), both start slots on the road of all %d shareable circuits, car frozen until GO and driving after, solo race has no multiplayer object, remote car = visual only (no collider) moves without jumps (worst frame step %.2f m at 15 m/s), impossible jump dropped, reset snaps, pause flag + remote score arrive, multiplayer run not saved (no record / star), lost peer reported while the local car keeps driving, leaving cleans up" % [P.TRACKS.size(),worst_step])
    print("NOT RUN: two real Android phones on Wi-Fi or a hotspot without Internet (owner QA), phone sleep / background, thumb controls on a real touch screen")
    quit(0)
