extends Node
class_name NitroNetRace
## Offline local multiplayer (issue #31): the multiplayer side of the normal race scene.
## race.gd creates ONE of these only while a NitroNetSession is starting / running (solo play never does),
## and asks it two things: freezes() (the countdown) and nothing else. Everything below lives here:
##   * the two start slots (side by side on the start line, 5.2 m apart) and the host / joiner car choice,
##   * the 3-2-1-GO overlay and the "waiting for the other phone" line,
##   * 20 Hz snapshots of the LOCAL car (read from race.model, which is never modified by networking),
##   * the REMOTE car: a visual node only (no physics body, no collider, no drive model), moved from buffered
##     snapshots with a fixed 120 ms interpolation delay, velocity-based extrapolation for at most 250 ms,
##     a snap on a deliberate reset and a refusal of impossible jumps,
##   * the other player's score as a small informational label (NOT ranked, NOT saved),
##   * lost connection / leaving: a readable message, the local drive is never interrupted.
## Remote data is client-reported and untrusted: nothing here writes records, stars or scores.
const P = preload("res://scripts/net/net_protocol.gd")
const SESSION = preload("res://scripts/net/net_session.gd")
const CARS = preload("res://scripts/vehicles/car_catalog.gd")
const STYLE = preload("res://scripts/ui/hud_style.gd")

const SEND_EVERY_TICKS: int = 6               # 120 Hz physics -> 20 Hz snapshots
const INTERP_DELAY_MS: float = 120.0
const EXTRAPOLATE_MAX_S: float = 0.25
const MAX_BUFFER: int = 40
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
var _buf: Array[Dictionary] = []
var _offsets: Array[float] = []
var _offset_ms: float = 0.0
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

## True while a session is on its way into a race (solo play: false, nothing is created).
static func should_attach() -> bool:
    var s: NitroNetSession = SESSION.current
    return s != null and (s.state == NitroNetSession.State.STARTING or s.state == NitroNetSession.State.COUNTDOWN or s.state == NitroNetSession.State.RACING)

## Start position of a slot (0 = host, 1 = joiner): side by side on the start line, 2.6 m left / right of the centre line.
static func spawn_position(base: Vector2, heading: float, slot: int) -> Vector2:
    var right := Vector2(cos(heading),sin(heading))
    return base+right*(-SLOT_LATERAL_M if slot == 0 else SLOT_LATERAL_M)

func setup(race_node: Node3D) -> void:
    race = race_node
    name = "Local multiplayer"
    session = SESSION.current
    session.in_race = true
    var base: Vector2 = race.track.start_position()
    var h: float = race.track.start_heading()
    race.model.reset(spawn_position(base,h,session.local_index),h)
    _last_sent_pos = race.model.position
    var other_slot: int = 1-session.local_index
    var rcar: String = str(session.other.get("car","red"))
    remote_car = CARS.make(rcar)
    remote_car.name = "Remote player car"
    remote_car.scale = Vector3.ONE*CAR_SCALE
    race.add_child(remote_car)
    var rp: Vector2 = spawn_position(base,h,other_slot)
    _place_remote(rp,h,0.0,0.0,0.0)
    remote_label = Label3D.new()
    remote_label.name = "Remote player name"
    remote_label.text = str(session.other.get("name","PLAYER"))
    remote_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    remote_label.no_depth_test = true
    remote_label.font_size = 56
    remote_label.pixel_size = 0.016
    remote_label.outline_size = 14
    remote_label.modulate = Color(0.45,0.97,1.0)
    remote_label.position = Vector3(0.0,3.4,0.0)
    remote_car.add_child(remote_label)
    remote_label.scale = Vector3.ONE/CAR_SCALE
    session.remote_snapshot.connect(_on_snapshot)
    session.peer_lost.connect(_on_lost)
    session.state_changed.connect(_on_state)
    _build_ui()
    call_deferred("_report_loaded")

func _report_loaded() -> void:
    if session != null:
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
    remote_paused = false
    if _toast != null:
        _toast.text = "%s\n\nYOU CAN KEEP DRIVING. PAUSE > GARAGE / MENU LEAVES THE GAME." % reason
        _toast.visible = true

func _refresh_ui() -> void:
    if session == null or _count == null:
        return
    var st: int = session.state
    _count.text = ""
    _status.text = ""
    if st == NitroNetSession.State.STARTING:
        _status.text = "WAITING FOR THE OTHER PLAYER TO LOAD THE TRACK"
    elif st == NitroNetSession.State.COUNTDOWN:
        var left: float = session.countdown_remaining()
        _count.text = str(maxi(1,int(ceil(left)))) if left > 0.0 else "GO!"
        _count.add_theme_color_override("font_color",Color(1,1,1) if left > 1.0 else Color(1.0,0.86,0.3))
    elif st == NitroNetSession.State.RACING and Time.get_ticks_msec() < _go_until_msec:
        _count.text = "GO!"
        _count.add_theme_color_override("font_color",Color(0.4,1.0,0.5))
    if st == NitroNetSession.State.RACING or st == NitroNetSession.State.COUNTDOWN:
        var who: String = str(session.other.get("name","PLAYER")) if not session.other.is_empty() else "OTHER PLAYER"
        if lost_reason == "":
            _score.text = "%s  %d PTS%s" % [who,remote_score,"  (PAUSED)" if remote_paused else ""]
        else:
            _score.text = ""

# ---------------------------------------------------------------- local snapshots

func _physics_process(_delta: float) -> void:
    if session == null or race == null or race.model == null:
        return
    _tick += 1
    if _tick%SEND_EVERY_TICKS != 0 or not session.connected():
        return
    var m: NitroDriveModel = race.model
    var flags: int = 0
    if m.is_drifting():
        flags |= 1
    if bool(race.get("paused")):
        flags |= 2
    if m.position.distance_to(_last_sent_pos) > 15.0:
        flags |= 4                                # a restart: the other phone snaps instead of gliding
    _last_sent_pos = m.position
    var scorer: Variant = race.get("scorer")
    var pts: int = 0
    if scorer != null:
        pts = maxi(0,int(scorer.total)+int(scorer.chain_score()))
    session.send_snapshot({"flags":flags,"ms":SESSION.now_ms(),"x":m.position.x,"z":m.position.y,"heading":m.heading,
        "vx":m.velocity.x,"vz":m.velocity.y,"yaw":m.yaw_rate,"steer":m.steering_angle,"score":pts})

# --------------------------------------------------------------- remote snapshots

func _on_snapshot(s: Dictionary) -> void:
    var sent_ms: float = float(s["ms"])
    _offsets.append(float(s["recv_ms"])-sent_ms)
    if _offsets.size() > 40:
        _offsets.pop_front()
    _offset_ms = _offsets.min()                  # the fastest recent delivery = the clock offset
    var flags: int = int(s["flags"])
    remote_paused = (flags&2) != 0
    remote_score = int(s["score"])
    var p := Vector2(float(s["x"]),float(s["z"]))
    if (flags&4) != 0:
        _buf.clear()                             # a deliberate jump (restart): no gliding across the map
    elif not _buf.is_empty():
        var last: Dictionary = _buf.back()
        var dt: float = maxf(0.0,(sent_ms-float(last["ms"]))/1000.0)
        var jump: float = p.distance_to(Vector2(float(last["x"]),float(last["z"])))
        if jump > 160.0*dt+10.0:
            dropped_jumps += 1                   # impossible at drift speeds: ignore this packet
            return
    _buf.append(s)
    while _buf.size() > MAX_BUFFER:
        _buf.pop_front()

func _process(delta: float) -> void:
    _refresh_ui()
    if remote_car == null or session == null:
        return
    if lost_reason != "":
        _remote_fade = maxf(0.0,_remote_fade-delta*0.8)
        remote_car.visible = _remote_fade > 0.05
    if _buf.is_empty():
        return
    var render_ms: float = float(SESSION.now_ms())-_offset_ms-INTERP_DELAY_MS
    var pose: Dictionary = interpolate(_buf,render_ms)
    _place_remote(Vector2(float(pose["x"]),float(pose["z"])),float(pose["heading"]),float(pose["steer"]),float(pose["speed"]),delta)

## Pose of the remote car at `render_ms` (sender clock) from the buffered snapshots: Hermite between the two
## snapshots that bracket it, velocity extrapolation (<= 250 ms) after the newest one, the oldest before the first.
static func interpolate(buf: Array[Dictionary], render_ms: float) -> Dictionary:
    var first: Dictionary = buf[0]
    var last: Dictionary = buf[buf.size()-1]
    if render_ms <= float(first["ms"]):
        return _pose(first)
    if render_ms >= float(last["ms"]):
        var dt: float = minf((render_ms-float(last["ms"]))/1000.0,EXTRAPOLATE_MAX_S)
        var out: Dictionary = _pose(last)
        out["x"] = float(last["x"])+float(last["vx"])*dt
        out["z"] = float(last["z"])+float(last["vz"])*dt
        out["heading"] = float(last["heading"])+float(last["yaw"])*dt
        return out
    for i in range(buf.size()-1):
        var a: Dictionary = buf[i]
        var b: Dictionary = buf[i+1]
        if render_ms >= float(a["ms"]) and render_ms <= float(b["ms"]):
            var span: float = maxf(float(b["ms"])-float(a["ms"]),1.0)
            var t: float = (render_ms-float(a["ms"]))/span
            var h: float = span/1000.0
            var t2: float = t*t
            var t3: float = t2*t
            var h00: float = 2.0*t3-3.0*t2+1.0
            var h10: float = t3-2.0*t2+t
            var h01: float = -2.0*t3+3.0*t2
            var h11: float = t3-t2
            var out2: Dictionary = {}
            out2["x"] = h00*float(a["x"])+h10*h*float(a["vx"])+h01*float(b["x"])+h11*h*float(b["vx"])
            out2["z"] = h00*float(a["z"])+h10*h*float(a["vz"])+h01*float(b["z"])+h11*h*float(b["vz"])
            out2["heading"] = float(a["heading"])+wrapf(float(b["heading"])-float(a["heading"]),-PI,PI)*t
            out2["steer"] = lerpf(float(a["steer"]),float(b["steer"]),t)
            out2["speed"] = lerpf(Vector2(float(a["vx"]),float(a["vz"])).length(),Vector2(float(b["vx"]),float(b["vz"])).length(),t)
            return out2
    return _pose(last)

static func _pose(s: Dictionary) -> Dictionary:
    return {"x":float(s["x"]),"z":float(s["z"]),"heading":float(s["heading"]),"steer":float(s["steer"]),
        "speed":Vector2(float(s["vx"]),float(s["vz"])).length()}

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
func on_restart() -> void:
    if race == null or session == null:
        return
    var h: float = race.track.start_heading()
    race.model.reset(spawn_position(race.track.start_position(),h,session.local_index),h)
    _last_sent_pos = race.model.position

func _exit_tree() -> void:
    # leaving the race scene (pause > GARAGE / MENU, back, app exit) always leaves the session: no network state remains
    if session != null and is_instance_valid(session):
        if session.remote_snapshot.is_connected(_on_snapshot):
            session.remote_snapshot.disconnect(_on_snapshot)
        if session.peer_lost.is_connected(_on_lost):
            session.peer_lost.disconnect(_on_lost)
        if session.state_changed.is_connected(_on_state):
            session.state_changed.disconnect(_on_state)
        session.in_race = false
        session.leave()
        session.queue_free()
    session = null
