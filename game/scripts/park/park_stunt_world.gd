extends Node3D
## A planar-car contact proxy wakes pooled 3D props. Only solo or the LAN host runs bodies.
signal object_impact(id: int, driver_slot: int, position: Vector3, impulse: Vector3)

const SITE = preload("res://scripts/park/park_site.gd")
const MESH = preload("res://scripts/park/park_site_mesh.gd")
const PROTOCOL = preload("res://scripts/net/net_protocol.gd")
const FLOOR_LAYER := 1 << 10
const PROP_LAYER := 1 << 11
const MAX_ACTIVE := 18
const SEND_PERIOD := 0.10
const MAX_BODY_AGE := 12.0

var room: NitroNetSession
var fixtures: Array[Dictionary]
var visuals: Array[Node3D] = []
var pool: Array[RigidBody3D] = []
var free_slots: Array[int] = []
var active: Dictionary = {}
var peak_active := 0
var contacts := 0
var packets := 0
var payload_bytes := 0
var _age: Dictionary = {}
var _hit_after: Dictionary = {}
var _changed: Dictionary = {}
var _targets: Dictionary = {}
var _clock := 0.0
var _send_clock := 0.0
var _pending := false
var _remote_previous := Vector3.INF
var _remote_half := Vector2(2.6,1.1)

func setup(session: NitroNetSession) -> void:
    name = "Interactive stunt objects"
    room = session
    fixtures = SITE.stunt_props()
    assert(fixtures.size() <= SITE.STUNT_PROP_CAP)
    var art := _create_art()
    for def in fixtures:
        var visual := MeshInstance3D.new()
        visual.mesh = art[int(def.barrier)]
        visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        visual.position = def.at
        add_child(visual)
        visuals.append(visual)
    if room == null or room.is_host:
        _create_pool()
        set_process(false)
    else:
        set_physics_process(false)
        room.park_objects_received.connect(_receive)
    if room != null:
        room.park_event_received.connect(_on_event)
        if room.is_host:
            room.remote_snapshot.connect(_on_remote)
            room.park_peer_ready.connect(_on_partner)
            room.peer_lost.connect(_on_peer_lost)
            room.park_cones_sync_requested.connect(_send.bind(true))

func _create_art() -> Array[Mesh]:
    var carton = MESH.new()
    carton.box(Vector3.ZERO, SITE.BOX_SIZE, Color("#b98554"))
    carton.box(Vector3(0,0.363,0), Vector3(0.14,0.009,0.78), Color("#dbac71"))
    carton.box(Vector3(0.18,0.04,0.392), Vector3(0.24,0.18,0.006), Color("#e5d2ad"))
    for i in 5:
        carton.box(Vector3(0.099+i*0.035,0.04,0.396), Vector3(0.012,0.094,0.006), Color("#5f4c3d"))
    var barrier = MESH.new()
    barrier.box(Vector3.ZERO, SITE.BARRIER_SIZE, Color("#9452c3"))
    barrier.box(Vector3(0,-0.16,0), Vector3(1.66,0.16,0.56), Color("#53386b"))
    for i in 5:
        barrier.box(Vector3(-0.62+i*0.31,0.05,0.204), Vector3(0.16,0.28,0.012), Color("#ffcb56"),
            Basis(Vector3.BACK,-0.32))
    var meshes: Array[Mesh] = []
    for batch in [carton,barrier]:
        var renderer: MeshInstance3D = batch.commit(self,"Prop mesh")
        var mesh := renderer.mesh
        mesh.surface_set_material(0,renderer.material_override)
        renderer.free()
        meshes.append(mesh)
    return meshes

func _create_pool() -> void:
    var ground := StaticBody3D.new()
    ground.collision_layer = FLOOR_LAYER
    ground.collision_mask = 0
    var area := SITE.STUNT.grow(16.0)
    ground.position = Vector3(area.get_center().x,-0.45,area.get_center().y)
    var shape := BoxShape3D.new()
    shape.size = Vector3(area.size.x,1.0,area.size.y)
    var ground_shape := CollisionShape3D.new()
    ground_shape.shape = shape
    ground.add_child(ground_shape)
    add_child(ground)
    var physics_material := PhysicsMaterial.new()
    physics_material.friction = 0.78
    physics_material.bounce = 0.12
    for i in MAX_ACTIVE:
        var body := RigidBody3D.new()
        body.freeze = true
        body.collision_layer = 0
        body.collision_mask = 0
        body.continuous_cd = true
        body.can_sleep = true
        body.linear_damp = 0.85
        body.angular_damp = 1.2
        body.physics_material_override = physics_material
        var body_shape := CollisionShape3D.new()
        body_shape.shape = BoxShape3D.new()
        body.add_child(body_shape)
        add_child(body)
        pool.append(body)
        free_slots.append(i)

func reset() -> void:
    for id: int in active.keys():
        _retire(id)
    for i in fixtures.size():
        visuals[i].position = fixtures[i].at
        visuals[i].rotation = Vector3.ZERO
        visuals[i].show()
    _changed.clear()
    _targets.clear()
    _hit_after.clear()
    _pending = false
    _send_clock = 0.0
    _remote_previous = Vector3.INF

func _on_event(kind: int, _revision: int, _payload: Dictionary) -> void:
    if kind == PROTOCOL.ParkEvent.RESET_TRAINING:
        reset()

func _on_partner() -> void:
    var catalog = preload("res://scripts/vehicles/car_catalog.gd")
    var car: Dictionary = catalog.info(str(room.other.get("car","red")))
    _remote_half = Vector2(car.length,car.width)*0.575
    _remote_previous = Vector3.INF

func _on_peer_lost(_reason: String) -> void:
    _remote_previous = Vector3.INF

func _on_remote(s: Dictionary) -> void:
    var at := Vector3(s.x,s.get("height",0.0),s.z)
    var before := _remote_previous
    _remote_previous = at
    if (int(s.flags) & 6) != 0:
        return
    if not before.is_finite() or before.distance_to(at) > 5.0:
        return
    contact(before,at,float(s.heading),Vector2(s.vx,s.vz),_remote_half,1-room.local_index)

func contact(from: Vector3, to: Vector3, heading: float, speed: Vector2, half: Vector2, driver_slot := -1) -> void:
    if (room != null and not room.is_host) or not SITE.STUNT.grow(5.0).has_point(Vector2(to.x,to.z)):
        return
    if speed.length_squared() < 1.0:
        return
    var fwd := Vector2(sin(heading),-cos(heading))
    var right := Vector2(-fwd.y,fwd.x)
    for id in fixtures.size():
        if not visuals[id].visible or float(_hit_after.get(id,0.0)) > _clock:
            continue
        var p := visuals[id].position
        var near := Geometry3D.get_closest_point_to_segment(p,from,to)
        if p.y < near.y-0.40 or p.y > near.y+1.85:
            continue
        var d := Vector2(p.x-near.x,p.z-near.z)
        var size := _size(id)
        var reach := maxf(size.x,size.z)*0.5
        if absf(d.dot(fwd)) <= half.x+reach and absf(d.dot(right)) <= half.y+reach:
            _strike(id, speed, d, driver_slot)

func _strike(id: int, speed: Vector2, radial: Vector2, driver_slot: int) -> void:
    var group: int = fixtures[id].group
    if group >= 0 and not _changed.has(id):
        var slots_needed := 0
        for member in fixtures.size():
            if fixtures[member].group == group and not _changed.has(member):
                slots_needed += 1
        if slots_needed > free_slots.size():
            return # Keep an untouched stack intact until its whole formation fits.
    var body := _activate(id)
    if body == null:
        return
    var direction := (speed.normalized()*0.8+radial.normalized()*0.2).normalized()
    var force := clampf(speed.length()*0.43,0.65,12.0)
    var impulse := Vector3(direction.x*force,minf(force*0.18,2.0),direction.y*force)
    body.apply_impulse(impulse,Vector3(0.16 if id%2 == 0 else -0.16,0.21,0))
    _hit_after[id] = _clock+0.22
    contacts += 1
    object_impact.emit(id,driver_slot,body.position,impulse)
    if group < 0:
        return
    # Wake an arrangement together so supports fall and the upper layers tumble.
    for member in fixtures.size():
        if member == id or fixtures[member].group != group or _changed.has(member):
            continue
        var neighbour := _activate(member)
        if neighbour != null:
            var spread := Vector3(float(posmod(member,3)-1)*0.23,0.03,0.08)
            neighbour.apply_impulse(impulse*0.18+spread,Vector3(0.13,0.1,0))

func _size(id: int) -> Vector3:
    return SITE.BARRIER_SIZE if fixtures[id].barrier else SITE.BOX_SIZE

func _activate(id: int) -> RigidBody3D:
    if active.has(id):
        var existing := pool[int(active[id])]
        existing.sleeping = false
        return existing
    if free_slots.is_empty():
        return null
    var slot: int = free_slots.pop_back()
    var body := pool[slot]
    body.freeze = true
    body.transform = visuals[id].transform
    body.mass = 1.8 if fixtures[id].barrier else 0.85
    body.get_child(0).shape.size = _size(id)
    body.collision_layer = PROP_LAYER
    body.collision_mask = FLOOR_LAYER | PROP_LAYER
    body.linear_velocity = Vector3.ZERO
    body.angular_velocity = Vector3.ZERO
    body.freeze = false
    body.sleeping = false
    active[id] = slot
    _age[id] = 0.0
    _changed[id] = true
    _pending = true
    peak_active = maxi(peak_active,active.size())
    return body

func _retire(id: int) -> void:
    var slot: int = active[id]
    var body := pool[slot]
    body.freeze = true
    body.collision_layer = 0
    body.collision_mask = 0
    body.linear_velocity = Vector3.ZERO
    body.angular_velocity = Vector3.ZERO
    free_slots.append(slot)
    active.erase(id)
    _age.erase(id)

func _physics_process(delta: float) -> void:
    _clock += delta
    if active.is_empty() and not _pending:
        return
    var cleanup := SITE.STUNT.grow(15.0)
    for id: int in active.keys():
        var body := pool[int(active[id])]
        var p := body.position
        _age[id] = float(_age[id])+delta
        visuals[id].transform = body.transform
        if p.y < -0.5 or not cleanup.has_point(Vector2(p.x,p.z)):
            visuals[id].hide()
            _retire(id)
        elif (body.sleeping and float(_age[id])>0.25) or float(_age[id]) > MAX_BODY_AGE:
            _retire(id)
    if active.is_empty():
        _send(true)
        _pending = false
        _send_clock = 0.0
    else:
        _send_clock += delta
        if _send_clock >= SEND_PERIOD:
            _send_clock = fmod(_send_clock,SEND_PERIOD)
            _send(false)

func _send(reliable: bool) -> void:
    if room == null or not room.park_peer_loaded():
        return
    var poses := []
    for id in _changed:
        var visual := visuals[id]
        poses.append({"id":id,"position":visual.position if visual.visible else Vector3(0,-8,0),
            "rotation":visual.rotation})
    var bytes := room.send_park_objects(poses,reliable)
    if bytes > 0:
        packets += 1
        payload_bytes += bytes

func _receive(poses: Array) -> void:
    for pose in poses:
        var id: int = pose.id
        if id >= visuals.size():
            continue
        if pose.position.y < -1.0:
            visuals[id].hide()
            _targets.erase(id)
        else:
            visuals[id].show()
            _targets[id] = Transform3D(Basis.from_euler(pose.rotation),pose.position)

func _process(delta: float) -> void:
    if _targets.is_empty():
        return
    var step := 1.0-exp(-30.0*delta)
    for id in _targets.keys():
        var visual := visuals[id]
        var target: Transform3D = _targets[id]
        if visual.position.distance_squared_to(target.origin) < 0.0004 and                 visual.basis.get_rotation_quaternion().angle_to(target.basis.get_rotation_quaternion()) < 0.018:
            visual.transform = target
            _targets.erase(id)
        else:
            visual.transform = visual.transform.interpolate_with(target,step)
