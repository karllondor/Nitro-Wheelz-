extends Node3D
## Driver poses remain locally simulated. Only the host resolves an encounter and issues a
## reliable bounded planar change. Bumper masks are durable, debris is a short local effect.
const P = preload("res://scripts/net/net_protocol.gd")
const SITE = preload("res://scripts/park/park_site.gd")
const CARS = preload("res://scripts/vehicles/car_catalog.gd")
const BUMPER = preload("res://scripts/park/park_bumper_visual.gd")
const DEBRIS_FLOOR := 1 << 14
const INTACT := 3
const LIGHT_HIT := 4.8
const TEAR_HIT := 8.5

var park: Node
var race: Node
var room: NitroNetSession
var local_slot := 0
var mounts := PackedByteArray([3,3,3,3])
var parts := [null,null,null,null]
var next_hit := PackedFloat64Array([0,0,0,0])
var clock := 0.0
var guest := {}
var guest_half := Vector2(1.1,2.4) # width, length
var guest_stop := 0.0
var guest_serviced := false
var contact_active := false
var next_push := 0.0
var pushes := 0

func setup(controller: Node) -> void:
    park = controller
    race = park.race
    room = park.room
    if room != null:
        local_slot = room.local_index
        mounts = room.bumper_mounts.duplicate()
        room.park_event_received.connect(_event)
        room.park_peer_ready.connect(_on_partner)
        room.peer_lost.connect(_on_lost)
        if room.is_host:
            room.remote_snapshot.connect(_observe_guest)
        else:
            room.remote_snapshot.connect(_observe_host)
    bind_car(local_slot,race.car_root)
    park.repair_requested.connect(_service_local)
    # A single isolated floor catches loose pieces everywhere in Park. Cars and props
    # never collide with it or the disposable pieces.
    var floor_body := StaticBody3D.new()
    floor_body.collision_layer = DEBRIS_FLOOR
    floor_body.collision_mask = 0
    var floor_shape := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = Vector3(SITE.BOUNDS.size.x+10.0,0.5,SITE.BOUNDS.size.y+10.0)
    floor_shape.shape = box
    var middle := SITE.BOUNDS.get_center()
    floor_body.position = Vector3(middle.x,-0.25,middle.y)
    floor_body.add_child(floor_shape)
    add_child(floor_body)

func bind_car(slot: int, car: Node3D) -> void:
    for part in 2:
        var index := 2*slot+part
        if parts[index] != null:
            parts[index].clear_debris()
        parts[index] = null
        var mesh := car.find_child("FrontBumper" if part == 0 else "RearBumper",true,false) as MeshInstance3D
        if mesh != null:
            var visual := BUMPER.new()
            visual.setup(mesh,part)
            parts[index] = visual
            visual.set_mounts(mounts[index])

func _on_partner() -> void:
    _forget_contact()
    mounts = room.bumper_mounts.duplicate()
    for i in 4:
        if parts[i] != null:
            parts[i].set_mounts(mounts[i])
    var car := CARS.info(room.other.get("car","red"))
    guest_half = Vector2(car.width,car.length)*0.575-Vector2(0.048,0.095)

func _on_lost(_reason: String) -> void:
    _forget_contact()
    for part in 2:
        var i := 2*(1-local_slot)+part
        mounts[i] = INTACT
        if parts[i] != null:
            parts[i].set_mounts(INTACT)

func _forget_contact() -> void:
    guest = {}
    for part in 2:
        next_hit[(1-local_slot)*2+part] = 0.0
    guest_stop = 0.0
    guest_serviced = false
    contact_active = false
    next_push = clock+0.18

func _observe_host(s: Dictionary) -> void:
    guest = s

func _observe_guest(s: Dictionary) -> void:
    var previous := guest
    guest = s
    if (int(s.flags)&6) != 0 or previous.is_empty():
        guest_stop = 0.0
        contact_active = false
        next_push = clock+0.18
        return
    var at := Vector2(s.x,s.z)
    var old_at := Vector2(previous.x,previous.z)
    var elapsed := float(s.recv_ms-previous.recv_ms)*0.001
    if elapsed < 0 or elapsed > 0.22 or at.distance_to(old_at)>6.0:
        guest_stop = 0.0
        next_push = clock+0.18
        return
    var velocity := Vector2(s.vx,s.vz)
    if SITE.REPAIR.has_point(at) and float(s.height)<0.1:
        if SITE.REPAIR.has_point(old_at) and velocity.length() <= SITE.STOP_SPEED_MPS and at.distance_to(old_at) <= elapsed*SITE.STOP_SPEED_MPS+0.02:
            guest_stop += elapsed
            if not guest_serviced and guest_stop >= SITE.STOP_SECONDS:
                guest_serviced = true
                _repair(1)
        else:
            guest_stop = 0.0
    else:
        guest_serviced = false
        guest_stop = 0.0
    # Reconstruct static contact against the same Park obstacles. Fast deceleration
    # alone is insufficient: the last incoming pose must actually reach a solid.
    var incoming := Vector2(previous.vx,previous.vz)
    if incoming.length()-velocity.length() < 2.0 or s.height>0.4:
        return
    var predicted := old_at+incoming*clampf(elapsed+0.018,0.02,0.09)
    var correction: Vector2 = race.track.site.resolve_contact(predicted,s.heading,guest_half.x,guest_half.y)
    if correction.length_squared()>0.000001:
        var normal := correction.normalized()
        _wall(1,at,s.heading,incoming,maxf(0,-incoming.dot(normal)),normal)

func _authoritative() -> bool:
    return room == null or room.is_host or room.state == room.State.LOST

func _commit(kind: int, data: Dictionary) -> void:
    if room != null and room.is_host and room.state == room.State.PARK:
        room.host_park_event(kind,data)
    elif _authoritative():
        _event(kind,0,data)

func _service_local() -> void:
    if _authoritative():
        _repair(local_slot)

func _repair(slot: int) -> void:
    if mounts[slot*2] != INTACT or mounts[slot*2+1] != INTACT:
        _commit(P.ParkEvent.SERVICE_REPAIR,{"slot":slot})

func wall_impact(hit: Dictionary) -> void:
    if _authoritative() and hit.impact_speed >= LIGHT_HIT and park.air.height < 0.4:
        var m: NitroDriveModel = race.model
        _wall(local_slot,m.position,m.heading,m.velocity-hit.normal*hit.impact_speed,hit.impact_speed,hit.normal)

func _wall(slot: int, pos: Vector2, heading: float, velocity: Vector2, strength: float, normal: Vector2) -> void:
    var contact: Vector2 = race.track.site.impact_point(pos,normal)
    impact(slot,pos,heading,contact,velocity,strength)

func prop_impact(_id: int, driver: int, point: Vector3, force: Vector3) -> void:
    var slot := local_slot if driver < 0 else driver
    if not _authoritative() or (slot != local_slot and guest.is_empty()):
        return
    var local := slot == local_slot
    var pos: Vector2 = race.model.position if local else Vector2(guest.x,guest.z)
    var heading: float = race.model.heading if local else guest.heading
    var velocity: Vector2 = race.model.velocity if local else Vector2(guest.vx,guest.vz)
    var target := Vector2(point.x,point.z)
    var approach := maxf(0,velocity.normalized().dot((target-pos).normalized()))
    impact(slot,pos,heading,target,velocity,Vector2(force.x,force.z).length()*approach)

func impact(slot: int, pos: Vector2, heading: float, point: Vector2, velocity: Vector2, strength: float) -> void:
    if not _authoritative() or strength < LIGHT_HIT:
        return
    var f := Vector2(sin(heading),-cos(heading))
    var d := point-pos
    var along := d.dot(f)
    if absf(along)<1.25:
        return # Doors and broadside scrapes do not remove a bumper.
    var part := 0 if along>0.0 else 1
    var index := slot*2+part
    if parts[index]==null or mounts[index]==0 or clock < next_hit[index]:
        return
    var right := Vector2(-f.y,f.x)
    var struck := 1 if d.dot(right)<0 else 2
    var mask := int(mounts[index])
    if mask != INTACT and strength < TEAR_HIT*(1.0 if mask==struck else 1.35):
        return
    next_hit[index] = clock+0.65
    if mask == INTACT:
        _commit(P.ParkEvent.BUMPER_DAMAGE,{"slot":slot,"part":part,"mask":3^struck})
    else:
        var height: float = park.air.height if slot==local_slot else guest.get("height",0.0)
        _commit(P.ParkEvent.DETACH_COMPONENT,{"slot":slot,"part":part,"at":Vector3(pos.x,height,pos.y),
            "angle":heading,"velocity":velocity.limit_length(18.0)})

func _event(kind: int, _revision: int, data: Dictionary) -> void:
    if kind == P.ParkEvent.PLAYER_CONTACT:
        if room == null or not room.vehicle_collisions: return
        # A reliable contact may arrive after local RECOVER. Do not nudge a new spawn.
        if local_slot==1 and race.model.position.distance_to(data.guest_at)>8.0: return
        var sign_slot := -1.0 if local_slot==0 else 1.0
        race.model.velocity += data.dv*sign_slot
        race.model.position += data.shift*sign_slot
        pushes += 1
        return
    if kind == P.ParkEvent.SERVICE_REPAIR:
        for part in 2:
            _set_mask(data.slot*2+part,INTACT)
        if data.slot==local_slot:
            park._show_site_notice("BUMPERS REPAIRED  •  FREE SERVICE")
    elif kind in [P.ParkEvent.BUMPER_DAMAGE,P.ParkEvent.DETACH_COMPONENT]:
        var i: int = data.slot*2+data.part
        if kind==P.ParkEvent.DETACH_COMPONENT and mounts[i]!=0 and parts[i]!=null:
            parts[i].drop(self,data.at,data.angle,data.velocity,race.RACE_CAR_SCALE,DEBRIS_FLOOR)
        _set_mask(i,int(data.get("mask",0)))

func _set_mask(i: int, mask: int) -> void:
    mounts[i] = mask
    if room != null: room.bumper_mounts[i] = mask
    if parts[i]!=null: parts[i].set_mounts(mask)

func _physics_process(dt: float) -> void:
    clock += dt
    if room != null and room.is_host and room.park_peer_loaded() and room.vehicle_collisions:
        _contact()
    for i in 4:
        if parts[i] == null: continue
        parts[i].step_debris(dt)
        if mounts[i] not in [1,2]: continue
        var local := i/2 == local_slot
        var velocity: Vector2 = race.model.velocity if local else Vector2(guest.get("vx",0),guest.get("vz",0))
        var yaw: float = race.model.yaw_rate if local else guest.get("yaw",0.0)
        parts[i].animate(dt,velocity.length(),yaw)

func _contact() -> void:
    if guest.is_empty() or race.paused or park.freezes() or (int(guest.flags)&6)!=0:
        contact_active = false
        return
    var age := (Time.get_ticks_msec()-int(guest.recv_ms))*0.001
    if age>0.16 or absf(float(guest.height)-park.air.height)>0.7:
        contact_active = false
        return
    var m: NitroDriveModel = race.model
    var v := Vector2(guest.vx,guest.vz)
    var pos := Vector2(guest.x,guest.z)+v*clampf(age,0,0.075)
    var delta := pos-m.position
    if delta.length_squared()>32.0:
        contact_active = false
        return
    var a := m.forward()
    var b := Vector2(sin(guest.heading),-cos(guest.heading))
    var ar := m.right()
    var br := Vector2(-b.y,b.x)
    var depth := INF
    var normal := Vector2.ZERO
    for axis: Vector2 in [a,ar,b,br]:
        var reach: float = absf(axis.dot(a))*race.track.body_half_length+absf(axis.dot(ar))*race.track.body_half_width
        reach += absf(axis.dot(b))*guest_half.y+absf(axis.dot(br))*guest_half.x
        var projected := delta.dot(axis)
        var overlap := reach-absf(projected)
        if overlap<=0.0:
            if overlap < -0.15: contact_active = false
            return
        if overlap<depth:
            depth = overlap
            normal = axis if projected>=0 else -axis
    if clock<next_push: return
    var closing := maxf(0,(m.velocity-v).dot(normal))
    var incoming := m.velocity
    var separation := normal*clampf(depth*0.53+0.015,0,0.49)
    var dv := normal*minf(12.0,0.51*closing)
    # Allow gentle separation during sustained throttle, once per network round-trip window.
    _commit(P.ParkEvent.PLAYER_CONTACT,{"dv":dv,"shift":separation,"guest_at":pos})
    if not contact_active:
        var on_host := m.position+a*clampf(delta.dot(a),-race.track.body_half_length,race.track.body_half_length)+ar*clampf(delta.dot(ar),-race.track.body_half_width,race.track.body_half_width)
        var on_guest := pos+b*clampf(-delta.dot(b),-guest_half.y,guest_half.y)+br*clampf(-delta.dot(br),-guest_half.x,guest_half.x)
        impact(0,m.position,m.heading,on_host,incoming,closing*0.70)
        impact(1,pos,guest.heading,on_guest,v,closing*0.70)
    contact_active = true
    next_push = clock+maxf(0.14,0.075+minf(0.16,room.rtt_ms*0.001))
