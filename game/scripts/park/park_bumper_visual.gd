extends RefCounted
## Mesh positions in the Park glTF are in car-local coordinates, exactly as in the original.
## The attached end stays fixed when the other mount gives way.
var mesh: MeshInstance3D
var center: Vector3
var mask := 3
var phase := 0.0
var debris: RigidBody3D
var age := 0.0

func setup(node: MeshInstance3D, part: int) -> void:
    mesh = node
    center = Vector3(0,0.27,-1.99 if part == 0 else 1.94)

func set_mounts(value: int) -> void:
    mask = value
    if value == 3:
        clear_debris()
    if is_instance_valid(mesh):
        mesh.visible = value != 0
        mesh.transform = Transform3D.IDENTITY
        if value in [1,2]:
            animate(0,0,0)

func animate(dt: float, speed: float, yaw: float) -> void:
    if mask not in [1,2] or not is_instance_valid(mesh):
        return
    var side := -1.0 if mask == 1 else 1.0
    phase = fmod(phase+dt*(4.0+minf(speed,30.0)*0.17),TAU)
    var motion := minf(speed/12.0,1.0)
    var pivot := center+Vector3(side*0.77,0.04,0)
    var droop := 0.102+0.023*sin(phase)*motion
    var swing := (0.065+0.045*cos(phase)*motion)*side*signf(center.z)+clampf(yaw*0.04,-0.11,0.11)
    var rot := Basis(Vector3.UP,swing)*Basis(Vector3.BACK,side*droop)
    mesh.transform = Transform3D(rot,pivot-rot*pivot)

func drop(world: Node3D, at: Vector3, heading: float, velocity: Vector2, car_scale: float, floor_layer: int) -> void:
    if not is_instance_valid(mesh) or is_instance_valid(debris):
        return
    var chunk := MeshInstance3D.new()
    chunk.mesh = mesh.mesh
    for i in mesh.mesh.get_surface_count():
        chunk.set_surface_override_material(i,mesh.get_active_material(i))
    chunk.scale = Vector3.ONE*car_scale
    chunk.position = -center*car_scale
    debris = RigidBody3D.new()
    debris.name = "Loose bumper"
    debris.mass = 2.2
    debris.can_sleep = true
    debris.linear_damp = 1.7
    debris.angular_damp = 2.4
    debris.collision_layer = 0
    debris.collision_mask = floor_layer
    var hull := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = Vector3(1.65,0.22,0.37)*car_scale
    hull.shape = box
    debris.add_child(hull)
    debris.add_child(chunk)
    debris.rotation.y = -heading
    debris.position = at + debris.basis*(center*car_scale)
    debris.linear_velocity = Vector3(velocity.x,0.7,velocity.y)
    debris.angular_velocity = Vector3(0.65,1.25,0.4)
    world.add_child(debris)
    age = 0.0

func step_debris(dt: float) -> void:
    if is_instance_valid(debris):
        age += dt
        if age >= 7.0:
            clear_debris()

func clear_debris() -> void:
    if is_instance_valid(debris):
        debris.queue_free()
    debris = null
