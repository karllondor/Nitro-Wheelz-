extends Node
class_name NitroNetRace
## Offline local multiplayer (issue #31): the multiplayer side of the normal race scene.
## race.gd creates ONE of these only while a NitroNetSession is starting / running (solo play never does),
## and asks it two things: freezes() (the countdown) and nothing else. Everything below lives here:
##   * the two start slots (side by side on the start line, 5.2 m apart) and the host / joiner car choice,
##   * the 3-2-1-GO overlay and the "waiting for the other phone" line,
##   * 20 Hz snapshots of the LOCAL car (read from race.model, which is never modified by networking),
##   * the REMOTE car: a visual node only (no physics body, no collider, no drive model), moved by a
##     NitroNetRemoteView from buffered snapshots (v0.1.45: steered render clock, jitter-adaptive 110..340 ms delay,
##     discontinuity smoothing, <= 250 ms extrapolation), a snap on a deliberate reset, a refusal of impossible jumps,
##   * live opponent points and session-only standings,
##   * lost connection / leaving: a readable message, the local drive is never interrupted.
## Remote data is client-reported and untrusted: nothing here writes records, stars or scores.
const P = preload("res://scripts/net/net_protocol.gd")
const SESSION = preload("res://scripts/net/net_session.gd")
const CARS = preload("res://scripts/vehicles/car_catalog.gd")
const STYLE = preload("res://scripts/ui/hud_style.gd")
const VIEW = preload("res://scripts/net/net_remote_view.gd")

const SEND_EVERY_TICKS: int = 6               # 120 Hz physics -> 20 Hz snapshots
const EXTRAPOLATE_MAX_S: float = VIEW.EXTRAPOLATE_MAX_S
const SLOT_LATERAL_M: float = 2.6
const CAR_SCALE: float = 1.15                 # = race.gd RACE_CAR_SCALE

var race: Node3D = null
var session: NitroNetSession = null
var remote_car: Node3D = null
var remote_label: Label3D = null
var remote_score: int = 0
var remote_paused: bool = false
var lost_reason: String = ""
var dropped_jumps: int = 0
var remote_view: NitroNetRemoteView = VIEW.new()
var _tick: int = 0
var _last_sent_pos: Vector2 = Vector2.ZERO
var _layer: CanvasLayer = null
var _count: Label = null
var _status: Label = null
var _score: Label = null
var _toast: Label = null
var _go_until_msec: int = 0
var _last_render_pos: Vector2 = Vector2.ZERO
var _remote_fade: float = 1.0
var _park_recovery_sends := 0
var _park_last_reset_ms := -10000
var _park_toast_until := 0
var _remote_identity: Array = []

## True while a session is on its way into a race (solo play: false, nothing is created).
static func should_attach() -> bool:
    var s: NitroNetSession = SESSION.current
    return s != null and (s.state == NitroNetSession.State.STARTING or s.state == NitroNetSession.State.COUNTDOWN or s.state == NitroNetSession.State.RACING or s.state == NitroNetSession.State.PARK or (s.state == NitroNetSession.State.LOST and s.round_id > 0))

## Start position of a slot (0 = host, 1 = joiner): side by side on the start line, 2.6 m left / right of the centre line.
static func spawn_position(base: Vector2, heading: float, slot: int) -> Vector2:
    var right := Vector2(cos(heading),sin(heading))
    return base+right*(-SLOT_LATERAL_M if slot == 0 else SLOT_LATERAL_M)

func setup(race_node: Node3D) -> void:
    race = race_node
    name = "Local multiplayer"
    session = SESSION.current
    session.in_race = true
    var h: float = race.track.start_heading()
    race.model.reset(_spawn(session.local_index),h)
    _last_sent_pos = race.model.position
    _make_remote_car()
    session.round_restarted.connect(_on_round_restarted)
    session.remote_snapshot.connect(_on_snapshot)
    session.peer_lost.connect(_on_lost)
    session.state_changed.connect(_on_state)
    if session.is_park():
        session.park_peer_ready.connect(_on_park_partner)
        session.park_lobby_returned.connect(_back_to_lobby)
    _build_ui()
    if session.state == SESSION.State.LOST or (session.is_park() and session.other.is_empty()):
        _on_lost(session.last_error)

func _spawn(slot: int) -> Vector2:
    var base: Vector2 = race.track.start_position()
    if session.is_park():
        return base+Vector2(-5.0 if slot == 0 else 5.0,0.0)
    return spawn_position(base,race.track.start_heading(),slot)

func park_recovery_spawn() -> Vector2:
    var pos := _spawn(session.local_index)
    return _park_clear_spawn(pos,_last_render_pos) if session.park_peer_loaded() else pos

static func _park_clear_spawn(pos: Vector2, occupied: Vector2) -> Vector2:
    return pos+Vector2(0,15) if pos.distance_to(occupied) < 7.0 else pos

func mark_recovered() -> void:
    _park_recovery_sends = 3

func _make_remote_car() -> void:
    var h: float = race.track.start_heading()
    _remote_identity = [session.other.get("car","red"),session.other.get("look",{}),session.other.get("name","PLAYER")]
    var rcar: String = str(session.other.get("car","red"))
    remote_car = CARS.make(rcar,session.other.get("look",{}))
    remote_car.name = "Remote player car"
    remote_car.scale = Vector3.ONE*CAR_SCALE
    race.add_child(remote_car)
    var rp := _spawn(1-session.local_index)
    _place_remote(rp,h,0.0,0.0,0.0)
    remote_label = Label3D.new()
    remote_label.name = "Remote player name"
    remote_label.text = "▼  "+str(session.other.get("name","PLAYER"))
    remote_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    remote_label.no_depth_test = true
    remote_label.font_size = 56
    remote_label.pixel_size = 0.024
    remote_label.outline_size = 14
    remote_label.modulate = Color(0.45,0.97,1.0)
    remote_label.position = Vector3(0.0,3.4,0.0)
    remote_car.add_child(remote_label)
    remote_label.scale = Vector3.ONE/CAR_SCALE
    var ring := MeshInstance3D.new()
    ring.name = "Opponent marker"
    var torus := TorusMesh.new()
    torus.inner_radius = 2.65
    torus.outer_radius = 2.86
    torus.rings = 40
    torus.ring_segments = 6
    var ink := StandardMaterial3D.new()
    ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    ink.albedo_color = Color(0.10, 0.96, 1.0)
    torus.material = ink
    ring.mesh = torus
    ring.position.y = 0.13
    ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    remote_car.add_child(ring)
func _on_park_partner() -> void:
    lost_reason = ""
    _park_toast_until = 0
    _toast.hide()
    _toast.text = ""
    _next_ui_ms = 0
    if _remote_identity != [session.other.get("car","red"),session.other.get("look",{}),session.other.get("name","PLAYER")]:
        remote_car.hide()
        remote_car.queue_free()
        _make_remote_car()
    var peer_spawn := _spawn(1-session.local_index)
    if session.is_host:
        peer_spawn = _park_clear_spawn(peer_spawn,session.park_host_position)
    else:
        peer_spawn = session.park_host_position
        var safe_spawn := _park_clear_spawn(_spawn(session.local_index),peer_spawn)
        if safe_spawn != race.model.position:
            race.model.reset(safe_spawn,race.track.start_heading())
            race._snap_cameras()
            race._update_visuals()
    _place_remote(peer_spawn,race.track.start_heading(),0.0,0.0,0.0)
    remote_car.show()
    _remote_fade = 1.0
    remote_paused = false
    remote_view.reset()
    _park_last_reset_ms = -10000

func leave_park() -> void:
    if not session.return_park_lobby():
        _back_to_lobby()

func _back_to_lobby() -> void:
    get_tree().call_deferred("change_scene_to_file","res://scenes/multiplayer_lobby.tscn")

func report_scene_ready() -> void:
    # Let the first visible frame submit both liveries, wheels, labels and track before countdown.
    await get_tree().process_frame
    await get_tree().process_frame
    if is_inside_tree() and session != null:
        session.report_loaded()

## The car stands still until GO (countdown); never frozen once the connection is gone.
func freezes() -> bool:
    return session != null and (session.state == NitroNetSession.State.STARTING or session.state == NitroNetSession.State.COUNTDOWN)

# ------------------------------------------------------------------------------ UI

func _build_ui() -> void:
    _layer = CanvasLayer.new()
    _layer.layer = 12
    _layer.name = "Multiplayer layer"
    add_child(_layer)
    var s: Vector2 = get_viewport().get_visible_rect().size
    _count = _label(s.x*0.30,Color(1,1,1),true)
    _count.position = Vector2(0.0,s.y*0.22)
    _count.size = Vector2(s.x,s.x*0.40)
    _status = _label(s.x*0.045,Color(1.0,0.92,0.5),false)
    _status.position = Vector2(s.x*0.05,s.y*0.17)
    _status.size = Vector2(s.x*0.90,s.x*0.12)
    _score = _label(s.x*0.036,Color(0.55,0.97,1.0),false)
    _score.position = Vector2(s.x*0.03,s.y*0.135)
    _score.size = Vector2(s.x*0.55,s.x*0.08)
    _score.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    _toast = _label(s.x*0.045,Color(1.0,0.55,0.5),true)
    _toast.position = Vector2(s.x*0.04,s.y*0.40)
    _toast.size = Vector2(s.x*0.92,s.x*0.30)
    _toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _toast.visible = false

func _label(px: float, col: Color, bold: bool) -> Label:
    var l := Label.new()
    l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    l.add_theme_font_size_override("font_size",int(px))
    l.add_theme_color_override("font_color",col)
    l.add_theme_color_override("font_outline_color",Color(0,0,0,0.9))
    l.add_theme_constant_override("outline_size",int(maxf(4.0,px*0.12)))
    if bold:
        l.add_theme_font_override("font",STYLE.BOLD)
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _layer.add_child(l)
    return l

func _on_state(st: int) -> void:
    if st == NitroNetSession.State.RACING:
        _go_until_msec = Time.get_ticks_msec()+900

func _on_lost(reason: String) -> void:
    lost_reason = reason
    _score.text = ""
    remote_paused = false
    if session.is_park():
        remote_car.hide()
        remote_view.reset()
        var instructions := "THE ROOM IS OPEN FOR A PLAYER TO REJOIN." if session.is_host else "PAUSE > RETURN TO LOBBY TO RECONNECT."
        _toast_text("%s\n\n%s" % [reason,instructions])
        _park_toast_until = Time.get_ticks_msec()+4500
    elif _toast != null:
        _toast.text = "%s\n\nYOU CAN KEEP DRIVING. PAUSE > GARAGE / MENU LEAVES THE GAME." % reason
        _toast.visible = true

var _last_count: String = ""
var _next_ui_ms: int = 0

func _refresh_ui() -> void:
    if session == null or _count == null:
        return
    var st: int = session.state
    if session.is_park():
        _refresh_park_ui(st)
        return
    var count_text := ""
    var now := Time.get_ticks_msec()
    if st == SESSION.State.COUNTDOWN:
        count_text = str(clampi(ceili(session.countdown_remaining()),1,3))
    elif st == SESSION.State.RACING and now < _go_until_msec:
        count_text = "GO!"
    if count_text != _last_count:
        _last_count = count_text
        _count.text = count_text
        var color := Color.WHITE
        if count_text == "1":
            color = Color(1.0,0.86,0.3)
        elif count_text == "GO!":
            color = Color(0.4,1.0,0.5)
        _count.add_theme_color_override("font_color",color)
    if now < _next_ui_ms:
        return
    _next_ui_ms = now+100
    _status.text = "WAITING FOR THE OTHER PLAYER TO LOAD THE TRACK" if st == SESSION.State.STARTING else ""
    if st == NitroNetSession.State.RACING or st == NitroNetSession.State.COUNTDOWN:
        var who: String = str(session.other.get("name","PLAYER")) if not session.other.is_empty() else "OTHER PLAYER"
        if lost_reason == "":
            _score.text = "%s  %d PTS%s%s" % [who,remote_score,"  (PAUSED)" if remote_paused else "",
                "  LINK "+remote_view.quality() if remote_view.has_data() else ""]
        else:
            _score.text = ""

func _refresh_park_ui(st: int) -> void:
    var now := Time.get_ticks_msec()
    if now < _next_ui_ms:
        return
    _next_ui_ms = now+100
    _status.text = "OPENING PARK…" if st == SESSION.State.STARTING else ""
    if session.park_peer_loaded():
        var who: String = session.other.get("name","PLAYER")
        _score.text = "%s%s%s" % [who,"  (PAUSED)" if remote_paused else "",
            "  LINK "+remote_view.quality() if remote_view.has_data() else ""]
    elif session.is_host and st == SESSION.State.PARK:
        _score.text = "PARK ROOM OPEN  •  WAITING FOR PLAYER"
    else:
        _score.text = ""

# ---------------------------------------------------------------- local snapshots

func _physics_process(_delta: float) -> void:
    if session == null or race == null or race.model == null:
        return
    if session.is_host and session.is_park() and P.PARK_SITE.BOUNDS.has_point(race.model.position):
        session.park_host_position = race.model.position
    _tick += 1
    if _tick%SEND_EVERY_TICKS != 0 or not session.connected():
        return
    var m: NitroDriveModel = race.model
    var flags: int = 0
    if m.is_drifting():
        flags |= 1
    if bool(race.get("paused")):
        flags |= 2
    if _park_recovery_sends > 0 or m.position.distance_to(_last_sent_pos) > 15.0:
        flags |= 4
        _park_recovery_sends = maxi(0,_park_recovery_sends-1)                                # a restart: the other phone snaps instead of gliding
    _last_sent_pos = m.position
    var scorer: Variant = race.get("scorer")
    var pts: int = 0
    if scorer != null and not session.is_park():
        pts = maxi(0,int(scorer.total)+int(scorer.chain_score()))
    # stamped with SIMULATION time (tick x tick length): the wall-clock time of the frame a tick happened to run in is
    # uneven on a phone (30-60 fps, hitches) and made the other phone see an uneven car speed
    var sim_ms: int = int(round(float(_tick)*1000.0/float(maxi(1,Engine.physics_ticks_per_second))))
    session.send_snapshot({"flags":flags,"ms":sim_ms,"x":m.position.x,"z":m.position.y,"heading":m.heading,
        "vx":m.velocity.x,"vz":m.velocity.y,"yaw":m.yaw_rate,"steer":m.steering_angle,"score":pts})

# --------------------------------------------------------------- remote snapshots

func _on_snapshot(s: Dictionary) -> void:
    var flags: int = int(s["flags"])
    remote_paused = (flags&2) != 0
    remote_score = int(s["score"])
    if (flags&4) != 0:
        var at: int = s.recv_ms
        if not session.is_park() or at-_park_last_reset_ms > 210:
            remote_view.reset()
        _park_last_reset_ms = at                      # a deliberate jump (restart): no gliding across the map
    if not remote_view.feed(s,float(s["recv_ms"])):
        dropped_jumps += 1                       # impossible at drift speeds: this packet is ignored

func _process(delta: float) -> void:
    if _park_toast_until != 0 and Time.get_ticks_msec() >= _park_toast_until:
        _park_toast_until = 0
        _toast.hide()
    _refresh_ui()
    if remote_car == null or session == null:
        return
    if lost_reason != "":
        _remote_fade = maxf(0.0,_remote_fade-delta*0.8)
        remote_car.visible = _remote_fade > 0.05
    if freezes() or not remote_car.visible:
        return  # Both cars are already placed on the grid until GO. Keep buffering samples.
    var pose: Dictionary = remote_view.step(float(SESSION.now_ms()),delta)
    if pose.is_empty():
        return
    _place_remote(Vector2(float(pose["x"]),float(pose["z"])),float(pose["heading"]),float(pose["steer"]),float(pose["speed"]),delta)

## Kept for the #31 tests: the interpolation itself lives in NitroNetRemoteView.
static func interpolate(buf: Array[Dictionary], render_ms: float) -> Dictionary:
    return VIEW.interpolate(buf,render_ms)

func _place_remote(p: Vector2, heading: float, steer: float, speed: float, dt: float) -> void:
    var y: float = 0.0
    if race != null and race.track != null:
        y = race.track.road_height_at(p)
    remote_car.position = Vector3(p.x,y,p.y)
    remote_car.rotation = Vector3(0.0,-heading,0.0)
    _last_render_pos = p
    if remote_car.has_method("set_motion"):
        remote_car.call("set_motion",steer,speed,dt)

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_PAUSED and session != null and session.connected():
        _toast_text("APP IN THE BACKGROUND: THE OTHER PLAYER MAY LOSE YOU AFTER A FEW SECONDS")

func _toast_text(t: String) -> void:
    if _toast != null:
        _toast.text = t
        _toast.visible = true

## race.gd _restart(): the car goes back to ITS OWN start slot (not the centre line, not the other car's slot).
func _on_round_restarted() -> void:
    race._reset_run()
    session.report_loaded() # Same scene and meshes, both peers acknowledge their reset.

func on_restart() -> void:
    if race == null or session == null:
        return
    var h: float = race.track.start_heading()
    race.model.reset(spawn_position(race.track.start_position(),h,session.local_index),h)
    _last_sent_pos = race.model.position
    remote_view = VIEW.new()
    remote_score = 0
    remote_paused = false
    _next_ui_ms = 0
    _go_until_msec = 0
    _place_remote(spawn_position(race.track.start_position(),h,1-session.local_index),h,0.0,0.0,0.0)

func _exit_tree() -> void:
    # leaving the race scene (pause > GARAGE / MENU, back, app exit) always leaves the session: no network state remains
    if session != null and is_instance_valid(session):
        if session.remote_snapshot.is_connected(_on_snapshot):
            session.remote_snapshot.disconnect(_on_snapshot)
        if session.peer_lost.is_connected(_on_lost):
            session.peer_lost.disconnect(_on_lost)
        if session.state_changed.is_connected(_on_state):
            session.state_changed.disconnect(_on_state)
        for pair in [[session.round_restarted,_on_round_restarted],[session.park_peer_ready,_on_park_partner],
                [session.park_lobby_returned,_back_to_lobby]]:
            if pair[0].is_connected(pair[1]):
                pair[0].disconnect(pair[1])
        session.in_race = false
        if not session.returning_to_lobby:
            session.leave()
            session.queue_free()
    session = null
