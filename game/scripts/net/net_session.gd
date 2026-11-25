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

## True while a race scene is running on top of a multiplayer session: such a run is never saved (no records, no stars).
static func race_active() -> bool:
    return current != null and is_instance_valid(current) and current.in_race

enum State { IDLE, HOSTING, CONNECTING, LOBBY, STARTING, COUNTDOWN, RACING, LOST, CLOSED, FAILED, PARK }

signal state_changed(state: int)
signal roster_changed
signal error_raised(text: String)
signal start_requested(track: String)
signal countdown_started(seconds: float)
signal round_restarted
signal standings_changed
signal remote_snapshot(snap: Dictionary)
signal peer_lost(reason: String)
signal park_peer_ready
signal park_lobby_returned
signal park_event_received(kind: int, revision: int, payload: Dictionary)
signal park_cones_received(poses: Array)
signal park_objects_received(poses: Array)
signal park_cones_sync_requested

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
var holds_screen: bool = false             # this session asked the OS to keep the screen on (released in _teardown)
var in_race: bool = false                  # set by the race scene (NitroNetRace) for as long as it exists
var last_error: String = ""
var dropped_packets: int = 0
var stale_snapshots: int = 0
var accepted_snapshots: int = 0
var round_start_usec: int = 0              # Scheduled GO on this peer’s monotonic clock
var go_local_usec: int = 0                 # local clock at the moment GO happened (measurement)
## Test hooks only (tests/net_session_test.gd): pretend to run another build / carry another track file.
var version_override: String = ""
var fingerprint_override: String = ""
var countdown_announced_usec: int = 0

var round_id: int = 0
var vehicle_collisions := false
var bumper_mounts := PackedByteArray([3,3,3,3]) # front/rear for host, then guest
var park_revision := 0
var park_host_position := Vector2(-5.0,30.0)
var returning_to_lobby := false
var _park_cone_seq := 0
var _last_park_cone_seq := -1
var _park_object_seq := 0
var _last_park_object_seq := -1
var drivers: Array[Dictionary] = []        # Stable host/join slots, retained after disconnect
var _host_offset_ms: float = 0.0
var _best_ping_ms: float = INF

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
    track_fp = P.track_fingerprint(track)
    if track_fp == "":
        return _fail("TRACK FILE NOT AVAILABLE: "+track)
    track_path = track
    peer = ENetMultiplayerPeer.new()
    var err: int = peer.create_server(port,4)
    if err != OK:
        return _fail("COULD NOT OPEN PORT %d (%s). Is another game already hosting?" % [port,error_string(err)])
    _make_api()
    is_host = true
    local_index = 0
    host_address = ""
    current = self
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
    current = self
    _set_state(State.CONNECTING)
    return OK

func _make_api() -> void:
    # A phone that locks its screen while waiting in the lobby or driving drops off the network: keep the screen on for as long
    # as the session exists (released again in _teardown, so nothing stays changed after leaving).
    DisplayServer.screen_set_keep_on(true)
    holds_screen = true
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

func is_park() -> bool:
    return track_path == P.PARK_PATH

func connected() -> bool:
    return api != null and state in [State.LOBBY,State.STARTING,State.COUNTDOWN,State.RACING,State.PARK]

func park_peer_loaded() -> bool:
    return state == State.PARK and (not is_host or (_loaded_other and other_id != 0))

# ----------------------------------------------------------------------- sending

func _send(msg: Dictionary, to: int) -> void:
    if api == null or to == 0:
        return
    api.send_bytes(P.pack_control(msg),to,MultiplayerPeer.TRANSFER_MODE_RELIABLE,0)

func _peer_target() -> int:
    return other_id if is_host else 1

func _info_message() -> Dictionary:
    var profile := CARS.cosmetic_profile(me.car)
    var saved := CARS.COSMETICS.current(me.car,profile)
    var look := {}
    for field in CARS.COSMETICS.SAVE_FIELDS:
        if saved.has(field):
            look[field] = saved[field]
    return {"collisions":vehicle_collisions,"look":look,"t":P.Msg.INFO,"name":me["name"],"car":me["car"],"ready":bool(me["ready"]),"fp":track_fp}

# --------------------------------------------------------------------- lobby API

func set_ready(on: bool) -> void:
    if state != State.LOBBY:
        return
    me["ready"] = on
    _send(_info_message(),_peer_target())
    roster_changed.emit()

func set_car(car: String) -> void:
    if state in [State.HOSTING, State.LOBBY] and CARS.CARS.has(car):
        me["car"] = car
        if connected():
            _send(_info_message(),_peer_target())
        roster_changed.emit()

## The Park host selects contact mode before entering the scene.
func set_park_collisions(enabled: bool) -> void:
    if not is_host or not is_park() or state not in [State.HOSTING,State.LOBBY]:
        return
    vehicle_collisions = enabled
    if other_id != 0:
        _send(_info_message(),other_id)
    roster_changed.emit()

## Both players confirm READY again after a circuit change.
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
    _prepare_round(round_id+1)
    park_revision = 0
    bumper_mounts.fill(3)
    _send_start()
    _set_state(State.STARTING)
    start_requested.emit(track_path)
    return true

func _prepare_round(id: int) -> void:
    round_id = id
    _loaded_me = false
    _loaded_other = false
    _load_deadline = now_ms()+LOAD_TIMEOUT_MS
    _last_snap_seq = -1
    _go_usec = 0
    round_start_usec = 0
    go_local_usec = 0
    drivers.clear()
    _last_park_cone_seq = -1
    _last_park_object_seq = -1
    if is_park():
        return
    for slot in 2:
        var player := me if slot == local_index else other
        drivers.append({"slot":slot, "name":player.name, "car":player.car,
            "points":0, "time_ms":-1, "status":"RACING"})

func restart_race() -> bool:
    if not is_host or is_park() or state != State.RACING:
        return false
    _prepare_round(round_id+1)
    _send({"t":P.Msg.RESTART,"round":round_id},other_id)
    _set_state(State.STARTING)
    round_restarted.emit()
    return true

func finish_local(points: int, time_ms: int) -> void:
    if is_park() or state not in [State.RACING, State.LOST] or drivers.size() != 2 or drivers[local_index].status != "RACING":
        return
    if state == State.RACING:
        _send({"t":P.Msg.FINISH,"round":round_id,"points":points,"time_ms":time_ms},_peer_target())
    _finish_slot(local_index,points,time_ms)

func _finish_slot(slot: int, points: int, time_ms: int) -> void:
    if drivers[slot].status == "RACING":
        drivers[slot].merge({"points":points,"time_ms":time_ms,"status":"FINISHED"},true)
        standings_changed.emit()

func standings() -> Array[Dictionary]:
    var rows := drivers.duplicate()
    rows.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
        if a.points != b.points:
            return a.points > b.points
        if a.time_ms != b.time_ms:
            return a.time_ms >= 0 and (b.time_ms < 0 or a.time_ms < b.time_ms)
        return a.slot < b.slot)
    return rows

func _live_points(slot: int, points: int) -> void:
    if drivers.size() == 2 and drivers[slot].status == "RACING" and drivers[slot].points != points:
        drivers[slot].points = points
        standings_changed.emit()

## The race scene of this phone is built and the car is waiting: the host starts the countdown when both are.
func report_loaded() -> void:
    if state != State.STARTING and not (is_host and state == State.PARK):
        return
    if is_host:
        _loaded_me = true
        _maybe_open_drive()
    else:
        _send({"t":P.Msg.LOADED,"round":round_id},1)

func _maybe_open_drive() -> void:
    if not is_host or not _loaded_me or not _loaded_other:
        return
    if is_park():
        if state in [State.STARTING,State.PARK] and other_id != 0:
            _send({"t":P.Msg.PARK_OPEN,"round":round_id,"revision":park_revision,"host_at":park_host_position,"mounts":bumper_mounts,"collisions":vehicle_collisions},other_id)
            _set_state(State.PARK)
            park_peer_ready.emit()
            park_cones_sync_requested.emit()
        return
    if state == State.STARTING:
        countdown_announced_usec = Time.get_ticks_usec()
        _go_usec = countdown_announced_usec+int(COUNTDOWN_SECONDS*1000000.0)
        _send({"t":P.Msg.COUNTDOWN,"round":round_id,"secs":COUNTDOWN_SECONDS,"go_ms":int(_go_usec/1000)},other_id)
        _set_state(State.COUNTDOWN)
        countdown_started.emit(COUNTDOWN_SECONDS)

## Seconds until GO on THIS phone (negative once it has happened, 99 when no countdown runs).
func countdown_remaining() -> float:
    if state == State.COUNTDOWN and _go_usec != 0:
        return float(_go_usec-Time.get_ticks_usec())/1000000.0
    return 99.0 if state != State.RACING else -1.0

func send_snapshot(s: Dictionary) -> void:
    if api == null or _peer_target() == 0:
        return
    if is_park():
        if not park_peer_loaded():
            return
        s["score"] = 0
    elif state not in [State.COUNTDOWN,State.RACING,State.STARTING]:
        return
    _live_points(local_index,int(s.get("score",0)))
    s["round"] = round_id
    s["seq"] = _snap_seq
    _snap_seq = (_snap_seq+1) & 0xFFFF
    var transfer := MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED
    if is_park() and (int(s.get("flags",0)) & 4) != 0:
        transfer = MultiplayerPeer.TRANSFER_MODE_RELIABLE
    api.send_bytes(P.pack_snapshot(s,is_park()),_peer_target(),transfer,0)

func _send_start() -> void:
    _send({"round":round_id,"t":P.Msg.START,"track":track_path,"fp":track_fp},other_id)

## Shared Park state can only be committed by the host. Events are ephemeral.
func host_park_event(kind: int, payload: Dictionary = {}) -> bool:
    if not is_host or state != State.PARK:
        return false
    var event := {"t":P.Msg.PARK_EVENT,"round":round_id,"event":kind,
        "revision":park_revision+1,"payload":payload}
    if P.validate_control(event) != "":
        return false
    park_revision = event.revision
    _send(event,other_id)
    park_event_received.emit(kind,park_revision,payload)
    return true

func send_park_cones(poses: Array, reliable: bool) -> int:
    if not is_host or not park_peer_loaded() or poses.size() > P.MAX_PARK_CONES:
        return 0
    var packet := P.pack_park_cones(round_id,park_revision,_park_cone_seq,poses)
    var transfer := MultiplayerPeer.TRANSFER_MODE_RELIABLE if reliable else MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED
    if api.send_bytes(packet,other_id,transfer,0) != OK:
        return 0
    _park_cone_seq = (_park_cone_seq+1) & 0xffff
    return packet.size()

func send_park_objects(poses: Array, reliable: bool) -> int:
    if not is_host or not park_peer_loaded() or poses.size() > P.PARK_SITE.STUNT_PROP_CAP:
        return 0
    var packet := P.pack_park_objects(round_id,park_revision,_park_object_seq,poses)
    var transfer := MultiplayerPeer.TRANSFER_MODE_RELIABLE if reliable else MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED
    if api.send_bytes(packet,other_id,transfer,0) != OK:
        return 0
    _park_object_seq = (_park_object_seq+1) & 0xffff
    return packet.size()

func return_park_lobby() -> bool:
    if not is_host or state != State.PARK:
        return false
    if not other.is_empty():
        _send({"t":P.Msg.PARK_LOBBY,"round":round_id},other_id)
    _enter_lobby_again()
    return true

func _enter_lobby_again() -> void:
    returning_to_lobby = true
    last_error = ""
    _loaded_me = false
    _loaded_other = false
    me["ready"] = false
    if not other.is_empty():
        other["ready"] = false
    _set_state(State.HOSTING if other.is_empty() else State.LOBBY)
    park_lobby_returned.emit()
    roster_changed.emit()

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
    DisplayServer.screen_set_keep_on(false)
    holds_screen = false
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
    var keep_park_open := is_host and is_park() and state in [State.PARK,State.STARTING]
    var was_host_waiting: bool = is_host and (state == State.LOBBY or state == State.HOSTING)
    if drivers.size() == 2 and drivers[1-local_index].status == "RACING":
        drivers[1-local_index].status = "DNF"
        standings_changed.emit()
    other = {}
    var disconnected_id := other_id
    other_id = 0
    if disconnected_id != 0:
        _safe_disconnect(disconnected_id)
    _hello_deadline = 0
    _go_usec = 0
    last_error = reason
    if keep_park_open:
        bumper_mounts[2] = 3
        bumper_mounts[3] = 3
        _loaded_other = false
        _last_snap_seq = -1
        _set_state(State.PARK)
    elif was_host_waiting:
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
    if other_id != 0 or state not in [State.HOSTING,State.PARK]:
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
    _fail("COULD NOT REACH %s. On the same Wi-Fi or the host phone's hotspot (no router needed)? Right IP? Is the host waiting?" % host_address)

func _on_server_disconnected() -> void:
    _lose("THE HOST LEFT")

func _on_packet(id: int, bytes: PackedByteArray) -> void:
    if bytes.is_empty() or bytes.size() > P.MAX_CONTROL_BYTES:
        dropped_packets += 1
        return
    if (is_host and id != other_id) or (not is_host and id != 1):
        return                                       # not the phone this session talks to
    if bytes[0] == P.KIND_PARK_CONES or bytes[0] == P.KIND_PARK_OBJECTS:
        _on_park_world(bytes)
        return
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
    if s.is_empty() or is_park() != s.has("height"):
        dropped_packets += 1
        return
    var driving := park_peer_loaded() if is_park() else state in [State.STARTING,State.COUNTDOWN,State.RACING]
    if not driving or s.round != round_id or (_last_snap_seq >= 0 and not P.seq_newer(int(s["seq"]),_last_snap_seq)):
        stale_snapshots += 1
        return
    if is_park():
        if not P.PARK_SITE.BOUNDS.has_point(Vector2(s.x,s.z)):
            dropped_packets += 1
            return
        s["score"] = 0
    _last_snap_seq = int(s["seq"])
    accepted_snapshots += 1
    s["recv_ms"] = now_ms()
    _live_points(1-local_index,int(s.score))
    remote_snapshot.emit(s)

func _on_park_world(bytes: PackedByteArray) -> void:
    if is_host or state != State.PARK:
        return
    var cones := bytes[0] == P.KIND_PARK_CONES
    var state_packet := P.unpack_park_cones(bytes) if cones else P.unpack_park_objects(bytes)
    if state_packet.is_empty():
        dropped_packets += 1
        return
    if state_packet.round != round_id or state_packet.revision != park_revision:
        return
    var previous := _last_park_cone_seq if cones else _last_park_object_seq
    if previous >= 0 and not P.seq_newer(state_packet.seq,previous):
        return
    _last_rx_msec = now_ms()
    if cones:
        _last_park_cone_seq = state_packet.seq
        park_cones_received.emit(state_packet.poses)
    else:
        _last_park_object_seq = state_packet.seq
        park_objects_received.emit(state_packet.poses)

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
            if not is_host and state == State.LOBBY and m.round > round_id and str(m.track) == track_path:
                if _track_matches(str(m["track"]),str(m["fp"])):
                    _prepare_round(m.round)
                    me["ready"] = true
                    _set_state(State.STARTING)
                    start_requested.emit(str(m["track"]))
        P.Msg.RESTART:
            # The host can press restart on its first GO frame before the joiner has polled its deadline.
            if not is_host and not is_park() and state in [State.COUNTDOWN,State.RACING] and m.round == round_id+1:
                _prepare_round(m.round)
                _set_state(State.STARTING)
                round_restarted.emit()
        P.Msg.FINISH:
            if not is_park() and state in [State.COUNTDOWN,State.RACING] and m.round == round_id:
                _finish_slot(1-local_index,m.points,m.time_ms)
        P.Msg.LOADED:
            if is_host and state in [State.STARTING,State.PARK] and m.round == round_id and not _loaded_other and not other.is_empty():
                _loaded_other = true
                _maybe_open_drive()
        P.Msg.COUNTDOWN:
            if not is_host and not is_park() and state == State.STARTING and m.round == round_id:
                var secs: float = float(m["secs"])
                countdown_announced_usec = Time.get_ticks_usec()
                # the announcement took about half a round trip to arrive: the joiner's GO is that much earlier
                _go_usec = countdown_announced_usec+int(maxf(0.0,secs*1000.0-rtt_ms*0.5)*1000.0)
                if is_finite(_best_ping_ms):
                    _go_usec = int((float(m.go_ms)-_host_offset_ms)*1000.0)
                _set_state(State.COUNTDOWN)
                countdown_started.emit(secs)
        P.Msg.PARK_OPEN:
            if not is_host and is_park() and state == State.STARTING and m.round == round_id:
                park_revision = m.revision
                park_host_position = m.host_at
                vehicle_collisions = m.collisions
                bumper_mounts = m.mounts
                _set_state(State.PARK)
                park_peer_ready.emit()
        P.Msg.PARK_EVENT:
            if not is_host and is_park() and state == State.PARK and m.round == round_id and m.revision == park_revision+1:
                park_revision = m.revision
                park_event_received.emit(m.event,park_revision,m.payload)
        P.Msg.PARK_LOBBY:
            if not is_host and is_park() and state in [State.PARK,State.STARTING] and m.round == round_id:
                _enter_lobby_again()
        P.Msg.LEAVE:
            _lose("THE OTHER PLAYER LEFT")
        P.Msg.PING:
            if is_host:
                _send({"t":P.Msg.PONG,"c":int(m["c"]),"host_ms":now_ms()},other_id)
        P.Msg.PONG:
            if not is_host:
                var sample: float = float(now_ms()-int(m["c"]))
                if sample >= 0 and sample <= _best_ping_ms:
                    _best_ping_ms = sample
                    _host_offset_ms = float(m.host_ms)-(float(m.c)+sample*0.5)
                rtt_ms = sample if rtt_ms == 0.0 else lerpf(rtt_ms,sample,0.3)

func _on_hello(m: Dictionary) -> void:
    if state not in [State.HOSTING,State.PARK] or other_id == 0 or not other.is_empty():
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
    _send({"t":P.Msg.WELCOME,"collisions":vehicle_collisions,"idx":1,"name":me["name"],"car":me["car"],"track":track_path,"fp":(fingerprint_override if fingerprint_override != "" else track_fp)},other_id)
    if state == State.PARK:
        round_id += 1
        _loaded_other = false
        _last_snap_seq = -1
        _load_deadline = now_ms()+LOAD_TIMEOUT_MS
        _send(_info_message(),other_id)
    else:
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
    vehicle_collisions = m.collisions
    other = {"name":P.clean_name(str(m["name"])),"car":str(m["car"]) if CARS.CARS.has(str(m["car"])) else "red","ready":false,"fp_ok":true}
    _hello_deadline = 0
    _set_state(State.LOBBY)
    _send(_info_message(),1)
    _send({"t":P.Msg.PING,"c":now_ms()},1)
    roster_changed.emit()

func _on_info(m: Dictionary) -> void:
    if other.is_empty() or (state != State.LOBBY and not (is_host and state == State.PARK and not _loaded_other)):
        return
    if not is_host:
        vehicle_collisions = m.collisions
    other["look"] = m.look
    other["name"] = P.clean_name(str(m["name"]))
    other["car"] = str(m["car"]) if CARS.CARS.has(str(m["car"])) else "red"
    other["ready"] = bool(m["ready"])
    if is_host:
        other["fp_ok"] = str(m["fp"]) == track_fp and track_fp != ""
        if state == State.PARK and other.fp_ok:
            _send_start()
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
                _fail("NO ANSWER FROM %s. On the same Wi-Fi or the host phone's hotspot (no router needed)? Right IP? Is the host waiting?" % host_address)
            elif _hello_deadline != 0 and now > _hello_deadline:
                _fail("THE HOST DID NOT ANSWER THE HELLO (wrong game version?)")
        State.HOSTING:
            if other_id != 0 and _hello_deadline != 0 and now > _hello_deadline:
                _kick_id = other_id
                _kick_at = now
                other_id = 0
                _hello_deadline = 0
        State.PARK:
            if is_host and other_id == 0:
                return
            if is_host and not _loaded_other:
                if (other.is_empty() and now > _hello_deadline) or (not other.is_empty() and now > _load_deadline):
                    _lose("THE OTHER PLAYER DID NOT FINISH JOINING")
                return
            if now-_last_rx_msec > SILENCE_TIMEOUT_MS:
                _lose("CONNECTION LOST")
            elif not is_host and now-_last_ping_msec >= 1000:
                _last_ping_msec = now
                _send({"t":P.Msg.PING,"c":now},1)
        State.LOBBY, State.STARTING, State.COUNTDOWN, State.RACING:
            if state != State.STARTING and now-_last_rx_msec > SILENCE_TIMEOUT_MS:
                _lose("CONNECTION LOST (NO DATA FOR %d s)" % (SILENCE_TIMEOUT_MS/1000))
                return
            if not is_host and now-_last_ping_msec >= 1000:
                _last_ping_msec = now
                _send({"t":P.Msg.PING,"c":now},1)
            if state == State.STARTING and now > _load_deadline:
                _lose("THE OTHER PLAYER DID NOT FINISH LOADING")
            if state == State.COUNTDOWN and _go_usec != 0 and Time.get_ticks_usec() >= _go_usec:
                round_start_usec = _go_usec
                go_local_usec = Time.get_ticks_usec()
                _go_usec = 0
                _set_state(State.RACING)

func _exit_tree() -> void:
    if state != State.CLOSED and state != State.FAILED:
        _teardown()
    if current == self:
        current = null
