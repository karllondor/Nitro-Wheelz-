extends Node3D
class_name NitroLadaLowPoly
## Original low-poly four-door drift sedan, visually inspired by the approved
## red Lada concept sheet. Front of vehicle is LOCAL -Z, world heading is
## handled by the race controller. No third-party geometry or texture is used.

const RED := Color(0.62, 0.025, 0.085)
const BRIGHT_RED := Color(0.89, 0.035, 0.092)
const SHADOW_RED := Color(0.38, 0.018, 0.05)
const GLASS := Color(0.055, 0.075, 0.13)
const CHROME := Color(0.70, 0.74, 0.77)
const RUBBER := Color(0.055, 0.055, 0.068)
const BLACK := Color(0.035, 0.04, 0.055)
const LAMP := Color(1.0, 0.96, 0.75)

var front_wheels: Array[Node3D] = []
var rolling_wheels: Array[Node3D] = []
var cached_materials: Dictionary = {}

func _ready() -> void:
    _make_body()
    _make_cabin()
    _make_front_and_engine()
    _make_rear()
    _make_wheels()
    _make_details()

func _material(col: Color, metallic: float = 0.0, glow: bool = false) -> StandardMaterial3D:
    var key := str(col) + ":" + str(metallic) + ":" + str(glow)
    if cached_materials.has(key):
        return cached_materials[key]
    var mat := StandardMaterial3D.new()
    mat.albedo_color = col
    mat.metallic = metallic
    mat.roughness = 0.35 if metallic > 0.0 else 0.56
    if glow:
        mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    cached_materials[key] = mat
    return mat

func _cube(label: String, pos: Vector3, size: Vector3,
        color: Color, metallic: float = 0.0, parent: Node3D = null) -> MeshInstance3D:
    var part := MeshInstance3D.new()
    part.name = label
    var mesh := BoxMesh.new()
    mesh.size = size
    part.mesh = mesh
    part.position = pos
    part.material_override = _material(color, metallic)
    if parent == null:
        add_child(part)
    else:
        if parent == null:
        add_child(part)
    else:
        parent.add_child(part)
    return part

func _cylinder(label: String, pos: Vector3, radius: float,
        length: float, col: Color, parent: Node3D = null,
        axis_x: bool = false) -> MeshInstance3D:
    var part := MeshInstance3D.new()
    part.name = label
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = length
    mesh.radial_segments = 12
    mesh.rings = 1
    part.mesh = mesh
    part.position = pos
    if axis_x:
        part.rotation.z = PI * 0.5
    part.material_override = _material(col, 0.45 if col == CHROME else 0.0)
    if parent == null:
        add_child(part)
    else:
        if parent == null:
        add_child(part)
    else:
        parent.add_child(part)
    return part

func _make_body() -> void:
    _cube("Unibody lower tub", Vector3(0, 0.56, 0.05),
        Vector3(1.91, 0.72, 4.24), RED)
    _cube("Driver floor and shadow sill", Vector3(0, 0.27, 0.05),
        Vector3(1.98, 0.20, 4.05), SHADOW_RED)
    _cube("Rear trunk deck", Vector3(0, 0.93, 1.52),
        Vector3(1.86, 0.11, 1.26), BRIGHT_RED)
    _cube("Front bonnet shoulder left", Vector3(-0.80, 0.89, -1.42),
        Vector3(0.32, 0.14, 1.14), BRIGHT_RED)
    _cube("Front bonnet shoulder right", Vector3(0.80, 0.89, -1.42),
        Vector3(0.32, 0.14, 1.14), BRIGHT_RED)
    _cube("Engine bay black", Vector3(0, 0.84, -1.49),
        Vector3(1.38, 0.035, 1.05), BLACK)
    _cube("Front face", Vector3(0, 0.73, -2.10),
        Vector3(1.88, 0.52, 0.15), RED)
    _cube("Rear deck vertical", Vector3(0, 0.65, 2.13),
        Vector3(1.86, 0.58, 0.12), RED)
    for side in [-1.0, 1.0]:
        _cube("Door upper ledge", Vector3(side*0.91, 0.99, 0.08),
            Vector3(0.08, 0.055, 2.15), BRIGHT_RED)
        _cube("Rocker chrome trim", Vector3(side*0.975, 0.29, 0.07),
            Vector3(0.045, 0.045, 3.87), CHROME, 0.55)
        _cube("Body chrome belt line", Vector3(side*0.975, 0.73, 0.12),
            Vector3(0.046, 0.025, 3.86), CHROME, 0.6)
        for door_at in [-0.46, 0.60]:
            _cube("Four-door shut line", Vector3(side*0.980, 0.62, door_at),
                Vector3(0.023, 0.70, 0.025), SHADOW_RED)
            _cube("Silver door handle", Vector3(side*1.015, 0.87, door_at+0.12),
                Vector3(0.055, 0.06, 0.23), CHROME, 0.68)

func _make_cabin() -> void:
    _cube("Passenger cabin", Vector3(0, 1.24, 0.03),
        Vector3(1.72, 0.65, 2.10), RED)
    _cube("Squared roof", Vector3(0, 1.62, 0.03),
        Vector3(1.76, 0.13, 2.24), BRIGHT_RED)
    _cube("Front windshield", Vector3(0, 1.28, -1.041),
        Vector3(1.56, 0.56, 0.044), GLASS)
    _cube("Rear window", Vector3(0, 1.28, 1.104),
        Vector3(1.55, 0.52, 0.035), GLASS)
    for side in [-1.0, 1.0]:
        for at_z in [-0.52, 0.49]:
            _cube("Dark side glass", Vector3(side*0.874, 1.28, at_z),
                Vector3(0.027, 0.49, 0.90), GLASS)
        for at_z in [-1.02, -0.02, 1.07]:
            _cube("Cabin pillars", Vector3(side*0.907, 1.30, at_z),
                Vector3(0.07, 0.66, 0.085), RED)
        _cube("Side window chrome lower", Vector3(side*0.909, 1.02, 0.02),
            Vector3(0.025, 0.028, 2.11), CHROME, 0.58)
        _cube("Roof rain gutter", Vector3(side*0.91, 1.65, 0.02),
            Vector3(0.035, 0.045, 2.24), CHROME, 0.4)
        _cube("Mirror housing", Vector3(side*1.06, 1.07, -1.03),
            Vector3(0.25, 0.14, 0.23), CHROME, 0.5)

func _make_front_and_engine() -> void:
    _cube("Black front grille", Vector3(0, 0.80, -2.195),
        Vector3(1.02, 0.32, 0.04), BLACK)
    for row in range(4):
        _cube("Horizontal grille trim", Vector3(0, 0.66+row*0.085, -2.226),
            Vector3(0.99, 0.015, 0.025), CHROME, 0.58)
    for side in [-1.0, 1.0]:
        for column in range(2):
            _cylinder("Round classic headlamp", Vector3(side*(0.56+column*0.26),
                0.80, -2.226), 0.126, 0.035, LAMP).rotation.x = PI * 0.5
        _cube("Amber indicator", Vector3(side*0.81, 0.57, -2.222),
            Vector3(0.25, 0.10, 0.04), Color(1.0, 0.42, 0.04))
    _cube("Front silver bumper", Vector3(0, 0.46, -2.26),
        Vector3(2.02, 0.17, 0.18), CHROME, 0.8)
    _cube("Black drift front lip", Vector3(0, 0.28, -2.34),
        Vector3(2.09, 0.13, 0.47), BLACK)
    _cube("Engine black block", Vector3(0, 0.96, -1.42),
        Vector3(0.85, 0.24, 0.70), RUBBER)
    for i in range(3):
        _cylinder("Triple polished intake trumpet", Vector3((i-1)*0.29,
            1.16, -1.44), 0.115, 0.34, CHROME)
        _cylinder("Intake dark throat", Vector3((i-1)*0.29,
            1.346, -1.44), 0.075, 0.025, BLACK)

func _make_rear() -> void:
    _cube("Rear chrome bumper", Vector3(0, 0.48, 2.28),
        Vector3(2.03, 0.18, 0.19), CHROME, 0.8)
    _cube("Low rear spoiler", Vector3(0, 1.12, 1.98),
        Vector3(1.93, 0.085, 0.33), RED)
    for side in [-1.0, 1.0]:
        _cube("Rectangular tail lamp", Vector3(side*0.59, 0.76, 2.218),
            Vector3(0.54, 0.22, 0.047), Color(0.82, 0.055, 0.07))
        _cube("Amber tail indicator", Vector3(side*0.86, 0.76, 2.251),
            Vector3(0.15, 0.18, 0.02), Color(1, 0.43, 0.06))
    _cylinder("Visible drift exhaust", Vector3(0.52,0.30,2.38),
        0.115, 0.27, CHROME).rotation.x = PI * 0.5

func _make_wheels() -> void:
    for side in [-1.0, 1.0]:
        for axle_z in [-1.39, 1.42]:
            var pivot := Node3D.new()
            pivot.name = "Front steer pivot" if axle_z < 0.0 else "Rear fixed axle"
            pivot.position = Vector3(side*1.01, 0.36, axle_z)
            add_child(pivot)
            if axle_z < 0.0:
                front_wheels.append(pivot)
            var roll := Node3D.new()
            roll.name = "Rolling deep dish wheel"
            pivot.add_child(roll)
            rolling_wheels.append(roll)
            _cylinder("Low poly tyre", Vector3.ZERO, 0.38, 0.33,
                RUBBER, roll, true)
            _cylinder("Dish silver outer lip", Vector3(side*0.19,0,0),
                0.31, 0.065, CHROME, roll, true)
            _cylinder("Five spoke hub", Vector3(side*0.23,0,0),
                0.095, 0.078, CHROME, roll, true)
            for spoke in range(5):
                var theta: float = TAU*float(spoke)/5.0
                var y: float = sin(theta)*0.18
                var z: float = cos(theta)*0.18
                var bar: MeshInstance3D = _cube("Five spoke silver", 
                    Vector3(side*0.235,y,z),Vector3(0.075,0.085,0.30),
                    CHROME,0.65,roll)
                bar.rotation.x = -theta
            _arch(side, axle_z)

func _arch(side: float, z: float) -> void:
    # Faceted flare segments around each wheel; lightweight geometry.
    for index in range(7):
        var a: float = PI*float(index)/6.0
        var flare := _cube("Bolted wide fender segment",
            Vector3(side*1.015,0.37+sin(a)*0.45,z+cos(a)*0.45),
            Vector3(0.20,0.105,0.26),RED)
        flare.rotation.x = -a

func _make_details() -> void:
    _cube("Black hood rear cowl",Vector3(0,1.045,-0.91),
        Vector3(1.60,0.055,0.16),SHADOW_RED)
    for side in [-1.0,1.0]:
        _cube("Amber side marker",Vector3(side*1.005,0.83,-1.77),
            Vector3(0.035,0.085,0.18),Color(1.0,0.46,0.06))

func set_motion(steer_rad: float, speed_mps: float, dt: float) -> void:
    # Godot +Y rotation maps local -Z to -X; invert to match +steer/right.
    for wheel in front_wheels:
        wheel.rotation.y = -steer_rad
    for roll in rolling_wheels:
        roll.rotation.x += speed_mps*dt/0.38
