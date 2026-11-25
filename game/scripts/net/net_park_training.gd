extends Node
## Host owns cone contact and motion. Guests see complete sparse poses and
## never author object state. The car stream remains client-owned and visual.
const P = preload("res://scripts/net/net_protocol.gd")
const CARS = preload("res://scripts/vehicles/car_catalog.gd")
const SEND_INTERVAL := 0.10
const MAX_CONTACT_SPEED := 65.0
const MAX_SWEEP_M := 6.0

var session: NitroNetSession
var cones: NitroParkCones
var packets_sent := 0
var payload_bytes_sent := 0
var _send_clock := 0.0
var _motion_pending := false
var _remote_at := Vector2.INF
var _remote_half_size := Vector2.ZERO

func setup(room: NitroNetSession, training: NitroParkCones) -> void:
    session = room
    cones = training
    session.park_event_received.connect(_on_event)
    if session.is_host:
        session.remote_snapshot.connect(_on_remote_car)
        session.park_peer_ready.connect(_on_partner)
        session.peer_lost.connect(_on_peer_lost)
        session.park_cones_sync_requested.connect(_send.bind(true))
    else:
        session.park_cones_received.connect(cones.apply_network_poses)
        set_physics_process(false)

func local_contact(model: NitroDriveModel, track: NitroDriftTrack) -> void:
    if session.is_host and session.state == session.State.PARK:
        cones.contact(model.position,model.heading,model.velocity,track.body_half_length,track.body_half_width)

func _on_partner() -> void:
    var car: Dictionary = CARS.info(str(session.other.get("car","red")))
    _remote_half_size = Vector2(float(car.length)*1.15*0.5-0.095,float(car.width)*1.15*0.5-0.048)
    _remote_at = Vector2.INF

func _on_peer_lost(_reason: String) -> void:
    _remote_at = Vector2.INF

func _on_remote_car(s: Dictionary) -> void:
    if not session.park_peer_loaded():
        return
    var pos := Vector2(s.x,s.z)
    var pre := _remote_at
    _remote_at = pos
    if (int(s.flags) & 6) != 0:
        return # Paused poses and recovery jumps cannot sweep through cones.
    var velocity := Vector2(s.vx,s.vz).limit_length(MAX_CONTACT_SPEED)
    if not pre.is_finite() or pre.distance_to(pos) > MAX_SWEEP_M:
        pre = pos
    var steps := maxi(1,ceili(pre.distance_to(pos)))
    for i in range(1,steps+1):
        cones.contact(pre.lerp(pos,float(i)/steps),float(s.heading),velocity,_remote_half_size.x,_remote_half_size.y)

func _physics_process(delta: float) -> void:
    if session.state != session.State.PARK:
        return
    _motion_pending = _motion_pending or not cones.awake.is_empty()
    if not _motion_pending:
        return
    cones.advance(delta)
    if cones.awake.is_empty():
        _send(true)
        _motion_pending = false
        _send_clock = 0.0
    else:
        _send_clock += delta
        if _send_clock >= SEND_INTERVAL:
            _send_clock = fmod(_send_clock,SEND_INTERVAL)
            _send(false)

func _send(reliable: bool) -> void:
    if not session.park_peer_loaded():
        return
    var size := session.send_park_cones(cones.network_poses(),reliable)
    if size > 0:
        packets_sent += 1
        payload_bytes_sent += size

func _on_event(kind: int, _revision: int, _payload: Dictionary) -> void:
    if kind == P.ParkEvent.RESET_TRAINING:
        cones.reset_all()
        _motion_pending = false
        _send_clock = 0.0
        _remote_at = Vector2.INF
