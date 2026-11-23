extends Node
## #33 on-device integration check (debuggable install only, started by an explicit adb run-as marker, see
## tools/android_integration_smoke.sh). Runs IN the exported APK on the Android emulator:
##  1. local multiplayer through the real ENet stack of the device: a host and a joiner session on 127.0.0.1 in this
##     process, lobby -> READY -> START -> the real race scene with the countdown, the other car driven by snapshots,
##  2. leaving the race leaves no session behind and records are allowed again,
##  3. a Terrain Builder circuit (#29 Club event) opened in the node editor with its landscape, SET START, SAVE AS,
##     then DRIVE: the race builds the terrain, judges it as a Club event and starts on the chosen node.
## The host phone captures the visible screen at each "ready-<label>" marker. Verdict: user://integration-verdict.txt.
const SESSION = preload("res://scripts/net/net_session.gd")
const P = preload("res://scripts/net/net_protocol.gd")
const DRIVE = preload("res://scripts/driving/drive_model.gd")
const CARS = preload("res://scripts/vehicles/car_catalog.gd")
const RESULTS = preload("res://scripts/ui/race_results.gd")
const TT = preload("res://scripts/world/terrain/terrain_track.gd")
const FIELD = preload("res://scripts/world/terrain/terrain_field.gd")
const CAT = preload("res://scripts/world/terrain/terrain_catalog.gd")
const TOOLS = preload("res://scripts/world/track_edit_tools.gd")
const DEVICE_TRACK: String = "user://nitro_track_qa_device_terrain.json"

var notes: Array[String] = []
var failed: bool = false

func _ready() -> void:
    run.call_deferred()

func note(ok: bool, text: String) -> void:
    print("[integration] ",("ok " if ok else "FAIL "),text)
    notes.append(("ok " if ok else "FAIL ")+text)
    if not ok:
        failed = true

func snapshot(label_: String) -> void:
    print("[integration] snapshot ",label_)
    await RenderingServer.frame_post_draw
    var marker := FileAccess.open("user://ready-"+label_,FileAccess.WRITE)
    marker.store_line(label_)
    marker.close()
    var t0: int = Time.get_ticks_msec()
    while not FileAccess.file_exists("user://captured-"+label_) and Time.get_ticks_msec()-t0 < 60000:
        await get_tree().create_timer(0.15).timeout

func until(cond: Callable, seconds: float) -> bool:
    var t0: int = Time.get_ticks_msec()
    while Time.get_ticks_msec()-t0 < int(seconds*1000.0):
        if cond.call():
            return true
        await get_tree().process_frame
    return cond.call()

func scene_is(path: String) -> bool:
    var cs: Node = get_tree().current_scene
    return cs != null and cs.scene_file_path == path

func run() -> void:
    var tree := get_tree()
    # ------------------------------------------------------------- 1. multiplayer on the device network stack
    var host: NitroNetSession = SESSION.new()
    tree.root.add_child(host)
    var client: NitroNetSession = SESSION.new()
    tree.root.add_child(client)
    var track: String = P.TRACKS[0]
    note(host.host(P.DEFAULT_PORT,"HOST","red",track) == OK,"host on UDP %d: %s" % [P.DEFAULT_PORT,host.last_error])
    note(client.join("127.0.0.1",P.DEFAULT_PORT,"JOINER","blue") == OK,"join 127.0.0.1: %s" % client.last_error)
    var lobby: bool = await until(func(): return host.state == NitroNetSession.State.LOBBY and client.state == NitroNetSession.State.LOBBY and not host.other.is_empty(),12.0)
    note(lobby,"lobby reached (host %d, joiner %d)" % [host.state,client.state])
    host.set_ready(true)
    client.set_ready(true)
    var can: bool = await until(func(): return host.can_start(),8.0)
    note(can and host.start_race(),"START after both READY")
    await until(func(): return client.state == NitroNetSession.State.STARTING,8.0)
    SESSION.current = host
    ProjectSettings.set_setting("nitro/selected_track",track)
    tree.change_scene_to_file("res://scenes/race.tscn")
    await until(func(): return scene_is("res://scenes/race.tscn"),20.0)
    var race: Node = tree.current_scene
    client.report_loaded()
    var go: bool = await until(func(): return host.state == NitroNetSession.State.RACING and client.state == NitroNetSession.State.RACING,20.0)
    note(go,"synchronised GO on both sessions")
    note(race != null and race.get("net") != null,"race scene attached the multiplayer controller")
    note(not RESULTS.record_allowed(),"records blocked during the multiplayer race")
    # the other phone: a scripted drive model through the real snapshot path
    var h0: float = race.track.start_heading()
    var other = DRIVE.new()
    CARS.configure_model(other,"red")
    other.reset(race.net.spawn_position(race.track.start_position(),h0,1),h0)
    var start_remote: Vector3 = race.net.remote_car.position
    var t0: int = Time.get_ticks_msec()
    var prev: int = t0
    var acc: float = 0.0
    var next_send: int = 0
    Input.action_press("throttle",1.0)
    while Time.get_ticks_msec()-t0 < 3500:
        var now: int = Time.get_ticks_msec()
        acc += float(now-prev)/1000.0
        prev = now
        while acc >= 1.0/120.0:
            other.step(1.0/120.0,0.0,1.0,0.0,0.0)
            acc -= 1.0/120.0
        if now-t0 >= next_send:
            next_send += 50
            client.send_snapshot({"flags":0,"ms":SESSION.now_ms(),"x":other.position.x,"z":other.position.y,"heading":other.heading,
                "vx":other.velocity.x,"vz":other.velocity.y,"yaw":other.yaw_rate,"steer":other.steering_angle,"score":321})
        await tree.process_frame
    Input.action_release("throttle")
    await snapshot("mp_race")
    var remote_moved: float = race.net.remote_car.position.distance_to(start_remote)
    note(remote_moved > 5.0,"remote car followed the other session (%.1f m)" % remote_moved)
    note(race.net.remote_score == 321,"remote score label")
    note(race.model.speed_kmh() > 5.0,"own car drives after GO (%.0f km/h)" % race.model.speed_kmh())
    # leaving: no session remains, records allowed again
    tree.change_scene_to_file("res://scenes/boot.tscn")
    await until(func(): return scene_is("res://scenes/boot.tscn"),20.0)
    client.leave()
    client.queue_free()
    var clean: bool = await until(func(): return SESSION.current == null and RESULTS.record_allowed(),10.0)
    note(clean,"leaving cleans the session up, records allowed again")
    # ----------------------------------------------- 2. Terrain Builder circuit (#29 Club) in the node editor
    var desc: Dictionary = CAT.descriptor("jp_sakura",7,-1,"club")
    var field = FIELD.new("jp_sakura",7)
    var gen: Dictionary = TT.generate_loop(TT.new_grid(),field,desc,5)
    note(bool(gen.get("ok",false)),"terrain loop generated on the device")
    var data: Dictionary = gen.get("data",{})
    data["name"] = "DEVICE QA TERRAIN"
    var f := FileAccess.open(DEVICE_TRACK,FileAccess.WRITE)
    f.store_string(JSON.stringify(data,"  ",false,true))
    f.close()
    var m := FileAccess.open(TOOLS.LAST_SAVED,FileAccess.WRITE)
    m.store_string(DEVICE_TRACK)
    m.close()
    tree.change_scene_to_file("res://scenes/track_editor.tscn")
    await until(func(): return scene_is("res://scenes/track_editor.tscn"),20.0)
    var ed: Node = tree.current_scene
    var loaded: bool = await until(func(): return ed.get("terrain_field") != null and bool(ed.get("ready_to_play")),30.0)
    note(loaded,"node editor opened the terrain circuit with its landscape: "+str(ed.get("message_label").text))
    if ed.get("dialog_overlay") != null:
        ed.call("_close_help")
    var n: int = (ed.get("data")["control_points"] as Array).size()
    var chosen: Array = ed.get("data")["control_points"][n/3]
    ed.set("selected",n/3)
    ed.call("_set_start")
    await tree.process_frame
    await snapshot("editor_set_start")
    var first: Array = ed.get("data")["control_points"][0]
    note(Vector2(float(first[0]),float(first[1])).distance_to(Vector2(float(chosen[0]),float(chosen[1]))) < 0.01,"SET START moved the start to the chosen node")
    note(bool(ed.call("_persist_track","DEVICE QA SHAPED")),"SAVE AS with terrain heights")
    var saved: String = str(ed.get("last_saved_path"))
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(saved))
    note(raw is Dictionary and TOOLS.node_shaped(raw) and not TT.world_of(raw).is_empty(),"saved: node-shaped, world kept")
    ProjectSettings.set_setting("nitro/selected_track",saved)
    tree.change_scene_to_file("res://scenes/race.tscn")
    await until(func(): return scene_is("res://scenes/race.tscn"),30.0)
    var race2: Node = tree.current_scene
    await until(func(): return race2.track.pending_terrain.is_empty(),60.0)
    for i in range(20):
        await tree.process_frame
    await snapshot("editor_drive")
    note(race2.track.terrain != null,"race built the terrain of the shaped circuit")
    note(str(race2.track.event_mode) == "club" and not (race2.track.event_layout["zones"] as Array).is_empty(),"race judges it as a Club event (%d zones)" % (race2.track.event_layout["zones"] as Array).size())
    var k0: Array = (raw as Dictionary)["control_points"][0] if raw is Dictionary else [0,0]
    note(race2.track.start_position().distance_to(Vector2(float(k0[0]),float(k0[1]))) < 0.01,"race starts on the chosen node")
    var out := FileAccess.open("user://integration-verdict.txt",FileAccess.WRITE)
    out.store_line("%s | %s | %s" % ["FAIL" if failed else "PASS",OS.get_name(),"; ".join(notes)])
    out.close()
