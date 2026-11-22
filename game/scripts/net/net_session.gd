extends Node
class_name NitroNetSession
## Offline local multiplayer (issue #31): one ENet session between two phones on the same Wi-Fi / hotspot.
## No Internet, no server, no account. One phone HOSTS, the other JOINS by local IP.
##
## The session owns its OWN SceneMultiplayer (not the tree default): leaving it leaves no network state behind,
## two sessions can be tested in one process (tests/net_session_test.gd) and single-player never touches it.
## Lifecycle: HOSTING -> (peer + HELLO accepted) LOBBY -> START -> STARTING (race scene loads, each side reports
## LOADED) -> COUNTDOWN (host announces seconds, the joiner subtracts half its measured round trip) -> RACING.
## Everything that can go wrong ends in a readable message (error_raised / peer_lost), never a crash.
const P = preload("res://scripts/net/net_protocol.gd")
const CARS = preload("res://scripts/vehicles/car_catalog.gd")

## The session that is in use by the app (set by the lobby, cleared by leave()); null in solo play.
static var current: NitroNetSession = null

enum State { IDLE, HOSTING, CONNECTING, LOBBY, STARTING, COUNTDOWN, RACING, LOST, CLOSED, FAILED }

signal state_changed(state: int)
signal roster_changed
signal error_raised(text: String)
signal start_requested(track: String)
signal countdown_started(seconds: float)
signal remote_snapshot(snap: Dictionary)
signal peer_lost(reason: String)

const HANDSHAKE_TIMEOUT_MS: int = 5000
const CONNECT_TIMEOUT_MS: int = 8000
const SILENCE_TIMEOUT_MS: int = 6000
const LOAD_TIMEOUT_MS: int = 30000
const COUNTDOWN_SECONDS: float = 3.0

var state: int = State.IDLE
var is_host: bool = false
var api: SceneMultiplayer = null
var peer: ENetMultiplayerPeer = null
var me: Dictionary = {"name":"PLAYER","car":"red","ready":false}
var other: Dictionary = {}                 # {"name","car","ready","fp_ok"} of the other phone, {} when alone
var other_id: int = 0
var track_path: String = P.TRACKS[0]
var track_fp: String = ""
var host_address: String = ""
var rtt_ms: float = 0.0
var local_index: int = 0                   # 0 = host, 1 = joiner (decides the start slot)
var last_error: String = ""
var dropped_packets: int = 0
var stale_snapshots: int = 0
var accepted_snapshots: int = 0
var go_local_usec: int = 0                 # local clock at the moment GO happened (measurement)
## Test hooks only (tests/net_session_test.gd): pretend to run another build / carry another track file.
var version_override: String = ""
var fingerprint_override: String = ""
var countdown_announced_usec: int = 0

var _last_rx_msec: int = 0
var _phase_started_msec: int = 0
var _hello_deadline: int = 0
var _last_ping_msec: int = 0
var _loaded_me: bool = false
var _loaded_other: bool = false
var _load_deadline: int = 0
var _go_usec: int = 0
var _snap_seq: int = 0
var _last_snap_seq: int = -1
var _kick_id: int = 0
var _kick_at: int = 0

static func now_ms() -> int:
    return Time.get_ticks_msec()

# ------------------------------------------------------------------------- start

func host(port: int, p_name: String, car: String, track: String) -> int:
    if state != State.IDLE:
        return ERR_ALREADY_IN_USE
    me = {"name":P.clean_name(p_name),"car":car if CARS.CARS.has(car) else "red","ready":false}
    if not P.track_allowed(track) or P.track_fingerprint(track) == "":
        return _fail("TRACK FILE NOT AVAILABLE: "+track)
    track_path = track
    track_fp = P.track_fingerprint(track)
    peer = ENetMultiplayerPeer.new()
    var err: int = peer.create_server(port,4)
    if err != OK:
        return _fail("COULD NOT OPEN PORT %d (%s). Is another game already hosting?" % [port,error_string(err)])
    _make_api()
    is_host = true
    local_index = 0
    host_address = ""
    _set_state(State.HOSTING)
    return OK

func join(ip: String, port: int, p_name: String, car: String) -> int:
    if state != State.IDLE:
        return ERR_ALREADY_IN_USE
    var ep: Dictionary = P.parse_endpoint("%s:%d" % [ip,port])
    if ep.is_empty():
        return _fail("THAT IS NOT A LOCAL IP ADDRESS (example 192.168.43.1)")
    me = {"name":P.clean_name(p_name),"car":car if CARS.CARS.has(car) else "red","ready":false}
    peer = ENetMultiplayerPeer.new()
    var err: int = peer.create_client(str(ep["ip"]),int(ep["port"]))
    if err != OK:
        return _fail("COULD NOT START THE CONNECTION (%s)" % error_string(err))
    _make_api()
    is_host = false
    local_index = 1
    host_address = "%s:%d" % [ep["ip"],ep["port"]]
    _phase_started_msec = now_ms()
    _set_state(State.CONNECTING)
    return OK

func _make_api() -> void:
    api = SceneMultiplayer.new()
    # A custom SceneMultiplayer needs a root path before it processes packets (we use no RPC / spawner,
    # only send_bytes, so any existing node will do).
    api.root_path = get_path() if is_inside_tree() else NodePath("/root")
    api.multiplayer_peer = peer
    api.peer_connected.connect(_on_peer_connected)
    api.peer_disconnected.connect(_on_peer_disconnected)
    api.connected_to_server.connect(_on_connected_to_server)
    api.connection_failed.connect(_on_connection_failed)
    api.server_disconnected.connect(_on_server_disconnected)
    api.peer_packet.connect(_on_packet)
    _last_rx_msec = now_ms()

func _set_state(s: int) -> void:
    if state == s:
        return
    state = s
    state_changed.emit(s)

func connected() -> bool:
    return api != null and (state == State.LOBBY or state == State.STARTING or state == State.COUNTDOWN or state == State.RACING)

# ----------------------------------------------------------------------- sending

func _send(msg: Dictionary, to: int) -> void:
    if api == null or to == 0:
        return
    api.send_bytes(P.pack_control(msg),to,MultiplayerPeer.TRANSFER_MODE_RELIABLE,0)

func _peer_target() -> int:
    return other_id if is_host else 1

func _info_message() -> Dictionary:
    return {"t":P.Msg.INFO,"name":me["name"],"car":me["car"],"ready":bool(me["ready"]),"fp":P.track_fingerprint(track_path)}

# --------------------------------------------------------------------- lobby API

func set_ready(on: bool) -> void:
    if state != State.LOBBY:
        return
    me["ready"] = on
    _send(_info_message(),_peer_target())
    roster_changed.emit()

func set_car(car: String) -> void:
    if CARS.CARS.has(car):
        me["car"] = car
        if connected():
            _send(_info_message(),_peer_target())
        roster_changed.emit()

## Host only: the circuit of this session. Both players have to confirm READY again.
func choose_track(path: String) -> void:
    if not is_host or not P.track_allowed(path) or (state != State.HOSTING and state != State.LOBBY):
        return
    track_path = path
    track_fp = P.track_fingerprint(path)
    me["ready"] = false
    if not other.is_empty():
        other["ready"] = false
        other["fp_ok"] = false
        _send({"t":P.Msg.TRACK,"track":track_path,"fp":track_fp},other_id)
    roster_changed.emit()

func can_start() -> bool:
    return is_host and state == State.LOBBY and bool(me["ready"]) and not other.is_empty() \
        and bool(other.get("ready",false)) and bool(other.get("fp_ok",false))

func start_race() -> bool:
    if not can_start():
        return false
    _loaded_me = false
    _loaded_other = false
    _load_deadline = now_ms()+LOAD_TIMEOUT_MS
    _send({"t":P.Msg.START,"track":track_path,"fp":track_fp},other_id)
    _set_state(State.STARTING)
    start_requested.emit(track_path)
    return true

## The race scene of this phone is built and the car is waiting: the host starts the countdown when both are.
func report_loaded() -> void:
    if state != State.STARTING:
        return
    if is_host:
        _loaded_me = true
        _maybe_start_countdown()
    else:
        _send({"t":P.Msg.LOADED},1)

func _maybe_start_countdown() -> void:
    if is_host and state == State.STARTING and _loaded_me and _loaded_other:
        _send({"t":P.Msg.COUNTDOWN,"secs":COUNTDOWN_SECONDS},other_id)
        countdown_announced_usec = Time.get_ticks_usec()
        _go_usec = countdown_announced_usec+int(COUNTDOWN_SECONDS*1000000.0)
        _set_state(State.COUNTDOWN)
        countdown_started.emit(COUNTDOWN_SECONDS)

## Seconds until GO on THIS phone (negative once it has happened, 99 when no countdown runs).
func countdown_remaining() -> float:
    if state == State.COUNTDOWN and _go_usec != 0:
        return float(_go_usec-Time.get_ticks_usec())/1000000.0
    return 99.0 if state != State.RACING else -1.0

func send_snapshot(s: Dictionary) -> void:
    if api == null or not (state == State.COUNTDOWN or state == State.RACING or state == State.STARTING):
        return
    s["seq"] = _snap_seq
    _snap_seq = (_snap_seq+1) & 0xFFFF
    api.send_bytes(P.pack_snapshot(s),_peer_target(),MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED,0)

## Leave for good (menu / back / app exit): tell the other phone, close the socket, forget everything.
func leave() -> void:
    if state == State.CLOSED:
        return
    if api != null and connected():
        _send({"t":P.Msg.LEAVE},_peer_target())
        api.poll()
    _teardown()
    _set_state(State.CLOSED)
    if current == self:
        current = null

func _teardown() -> void:
    if api != null:
        api.multiplayer_peer = null
    if peer != null:
        peer.close()
    peer = null
    api = null
    other = {}
    other_id = 0
    _go_usec = 0

## Disconnect a peer only while it still exists (the engine logs an error otherwise).
func _safe_disconnect(id: int) -> void:
    if peer == null:
        return
    var pp: ENetPacketPeer = peer.get_peer(id)
    if pp != null and pp.is_active():
        peer.disconnect_peer(id)

func _fail(text: String) -> int:
    last_error = text
    _teardown()
    _set_state(State.FAILED)
    error_raised.emit(text)
    return ERR_CANT_CONNECT

func _lose(reason: String) -> void:
    if state == State.CLOSED or state == State.FAILED or state == State.LOST:
        return
    var was_host_waiting: bool = is_host and (state == State.LOBBY or state == State.HOSTING)
    other = {}
    if other_id != 0:
        _safe_disconnect(other_id)
    other_id = 0
    _go_usec = 0
    last_error = reason
    if was_host_waiting:
        me["ready"] = false
        _set_state(State.HOSTING)             # the host keeps the room open for another join
    else:
        _set_state(State.LOST)
    peer_lost.emit(reason)
    roster_changed.emit()

# ---------------------------------------------------------------- engine signals

func _on_peer_connected(id: int) -> void:
    if not is_host:
        return
    if other_id != 0 or state != State.HOSTING:
        _send({"t":P.Msg.REJECT,"code":"FULL","text":"THE SESSION IS FULL (2 PLAYERS)"},id)
        _kick_id = id
        _kick_at = now_ms()+400
        return
    other_id = id
    _hello_deadline = now_ms()+HANDSHAKE_TIMEOUT_MS

func _on_peer_disconnected(id: int) -> void:
    if is_host and id == other_id:
        _lose("THE OTHER PLAYER LEFT")
    elif not is_host and id == 1:
        _lose("THE HOST LEFT")

func _on_connected_to_server() -> void:
    _last_rx_msec = now_ms()
    _send({"t":P.Msg.HELLO,"proto":P.PROTOCOL_VERSION,"ver":(version_override if version_override != "" else P.game_version()),"name":me["name"],"car":me["car"]},1)
    _hello_deadline = now_ms()+HANDSHAKE_TIMEOUT_MS

func _on_connection_failed() -> void:
    _fail("COULD NOT REACH %s. Same Wi-Fi / hotspot? Right IP? Is the host waiting?" % host_address)

func _on_server_disconnected() -> void:
    _lose("THE HOST LEFT")

func _on_packet(id: int, bytes: PackedByteArray) -> void:
    if bytes.is_empty() or bytes.size() > P.MAX_CONTROL_BYTES:
        dropped_packets += 1
        return
    if (is_host and id != other_id) or (not is_host and id != 1):
        return                                       # not the phone this session talks to
    _last_rx_msec = now_ms()
    if bytes[0] == P.KIND_SNAPSHOT:
        _on_snapshot(bytes)
        return
    var m: Dictionary = P.unpack_control(bytes)
    if m.is_empty() or P.validate_control(m) != "":
        dropped_packets += 1
        return
    _on_control(m)

func _on_snapshot(bytes: PackedByteArray) -> void:
    var s: Dictionary = P.unpack_snapshot(bytes)
    if s.is_empty():
        dropped_packets += 1
        return
    if _last_snap_seq >= 0 and not P.seq_newer(int(s["seq"]),_last_snap_seq):
        stale_snapshots += 1
        return
    _last_snap_seq = int(s["seq"])
    accepted_snapshots += 1
    s["recv_ms"] = now_ms()
    remote_snapshot.emit(s)

func _on_control(m: Dictionary) -> void:
    match int(m["t"]):
        P.Msg.HELLO:
            if is_host:
                _on_hello(m)
        P.Msg.WELCOME:
            if not is_host:
                _on_welcome(m)
        P.Msg.REJECT:
            if not is_host:
                _fail(str(m["text"]))
        P.Msg.INFO:
            _on_info(m)
        P.Msg.TRACK:
            if not is_host:
                _on_track(m)
        P.Msg.START:
            if not is_host and state == State.LOBBY:
                if _track_matches(str(m["track"]),str(m["fp"])):
                    me["ready"] = true
                    _set_state(State.STARTING)
                    start_requested.emit(str(m["track"]))
        P.Msg.LOADED:
            if is_host and state == State.STARTING:
                _loaded_other = true
                _maybe_start_countdown()
        P.Msg.COUNTDOWN:
            if not is_host and state == State.STARTING:
                var secs: float = float(m["secs"])
                countdown_announced_usec = Time.get_ticks_usec()
                # the announcement took about half a round trip to arrive: the joiner's GO is that much earlier
                _go_usec = countdown_announced_usec+int(maxf(0.0,secs*1000.0-rtt_ms*0.5)*1000.0)
                _set_state(State.COUNTDOWN)
                countdown_started.emit(secs)
        P.Msg.LEAVE:
            _lose("THE OTHER PLAYER LEFT")
        P.Msg.PING:
            if is_host:
                _send({"t":P.Msg.PONG,"c":int(m["c"])},other_id)
        P.Msg.PONG:
            if not is_host:
                var sample: float = float(now_ms()-int(m["c"]))
                rtt_ms = sample if rtt_ms == 0.0 else lerpf(rtt_ms,sample,0.3)

func _on_hello(m: Dictionary) -> void:
    if state != State.HOSTING or other_id == 0:
        return
    var reject: String = ""
    if int(m["proto"]) != P.PROTOCOL_VERSION:
        reject = "PROTOCOL"
    elif str(m["ver"]) != P.game_version():
        reject = "VERSION"
    if reject != "":
        _send({"t":P.Msg.REJECT,"code":reject,"text":("DIFFERENT NETWORK PROTOCOL: update both phones to the same APK" if reject == "PROTOCOL" else
            "DIFFERENT GAME VERSION: host %s, you %s. Install the same APK on both phones." % [P.game_version(),str(m["ver"])])},other_id)
        _kick_id = other_id
        _kick_at = now_ms()+400
        other_id = 0
        return
    other = {"name":P.clean_name(str(m["name"])),"car":str(m["car"]) if CARS.CARS.has(str(m["car"])) else "red","ready":false,"fp_ok":false}
    _hello_deadline = 0
    _send({"t":P.Msg.WELCOME,"idx":1,"name":me["name"],"car":me["car"],"track":track_path,"fp":(fingerprint_override if fingerprint_override != "" else track_fp)},other_id)
    _set_state(State.LOBBY)
    roster_changed.emit()

func _track_matches(path: String, fp: String) -> bool:
    if not P.track_allowed(path):
        _fail("THE HOST CHOSE A TRACK THIS GAME DOES NOT KNOW (%s)" % path.get_file())
        return false
    if P.track_fingerprint(path) != fp:
        _fail("TRACK MISMATCH: your copy of %s differs from the host's. Install the same APK on both phones." % str(P.TRACK_NAMES.get(path,path)))
        return false
    return true

func _on_welcome(m: Dictionary) -> void:
    if state != State.CONNECTING:
        return
    if not _track_matches(str(m["track"]),str(m["fp"])):
        return
    track_path = str(m["track"])
    track_fp = str(m["fp"])
    other = {"name":P.clean_name(str(m["name"])),"car":str(m["car"]) if CARS.CARS.has(str(m["car"])) else "red","ready":false,"fp_ok":true}
    _hello_deadline = 0
    _set_state(State.LOBBY)
    _send(_info_message(),1)
    roster_changed.emit()

func _on_info(m: Dictionary) -> void:
    if other.is_empty():
        return
    other["name"] = P.clean_name(str(m["name"]))
    other["car"] = str(m["car"]) if CARS.CARS.has(str(m["car"])) else "red"
    other["ready"] = bool(m["ready"])
    if is_host:
        other["fp_ok"] = str(m["fp"]) == track_fp and track_fp != ""
    roster_changed.emit()

func _on_track(m: Dictionary) -> void:
    if state != State.LOBBY or not _track_matches(str(m["track"]),str(m["fp"])):
        return
    track_path = str(m["track"])
    track_fp = str(m["fp"])
    me["ready"] = false
    other["ready"] = false
    _send(_info_message(),1)
    roster_changed.emit()

# ------------------------------------------------------------------------ polling

func _process(_delta: float) -> void:
    if api == null:
        return
    api.poll()
    if api == null:
        return                                        # a signal handler closed the session
    var now: int = now_ms()
    if _kick_id != 0 and now >= _kick_at:
        _safe_disconnect(_kick_id)
        _kick_id = 0
    match state:
        State.CONNECTING:
            if now-_phase_started_msec > CONNECT_TIMEOUT_MS:
                _fail("NO ANSWER FROM %s. Same Wi-Fi / hotspot? Right IP? Is the host waiting?" % host_address)
            elif _hello_deadline != 0 and now > _hello_deadline:
                _fail("THE HOST DID NOT ANSWER THE HELLO (wrong game version?)")
        State.HOSTING:
            if other_id != 0 and _hello_deadline != 0 and now > _hello_deadline:
                _kick_id = other_id
                _kick_at = now
                other_id = 0
                _hello_deadline = 0
        State.LOBBY, State.STARTING, State.COUNTDOWN, State.RACING:
            if now-_last_rx_msec > SILENCE_TIMEOUT_MS:
                _lose("CONNECTION LOST (NO DATA FOR %d s)" % (SILENCE_TIMEOUT_MS/1000))
                return
            if not is_host and now-_last_ping_msec >= 1000:
                _last_ping_msec = now
                _send({"t":P.Msg.PING,"c":now},1)
            if state == State.STARTING and is_host and now > _load_deadline:
                _lose("THE OTHER PLAYER DID NOT FINISH LOADING")
            if state == State.COUNTDOWN and _go_usec != 0 and Time.get_ticks_usec() >= _go_usec:
                go_local_usec = Time.get_ticks_usec()
                _go_usec = 0
                _set_state(State.RACING)

func _exit_tree() -> void:
    if state != State.CLOSED and state != State.FAILED:
        _teardown()
    if current == self:
        current = null
