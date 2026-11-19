extends Node3D
class_name NitroLadaLowPoly
## Original low-poly four-door drift sedan, visually inspired by the approved
## red Lada concept sheet. Front of vehicle is LOCAL -Z, world heading is
## handled by the race controller. No third-party geometry or texture is used.

const RED = Color(0.62, 0.025, 0.085)
const BRIGHT_RED = Color(0.89, 0.035, 0.092)
const SHADOW_RED = Color(0.38, 0.018, 0.05)
const GLASS = Color(0.055, 0.075, 0.13)
const CHROME = Color(0.70, 0.74, 0.77)
const RUBBER = Color(0.055, 0.055, 0.068)
const BLACK = Color(0.035, 0.04, 0.055)
const LAMP = Color(1.0, 0.96, 0.75)
# Stock VAZ-2106 dimensions, scaled 1 Godot unit = 1 metre.
# Drift widebody can be wider than the stock 1.611 m shell.
const BODY_LENGTH_M: float = 4.166
const WHEELBASE_M: float = 2.424
const FRONT_AXLE_Z: float = -WHEELBASE_M * 0.5
const REAR_AXLE_Z: float = WHEELBASE_M * 0.5
const DRIFT_BODY_WIDTH_M: float = 1.91
var paint_variant: String = "red"   # red exposed-engine / pearl-white clean hood

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
    var body_col: Color = col
    if paint_variant == "white":
        if col == RED:
            body_col = Color(0.91,0.91,0.98)
        elif col == BRIGHT_RED:
            body_col = Color(1.0,0.99,1.0)
        elif col == SHADOW_RED:
            body_col = Color(0.66,0.67,0.76)
    mat.albedo_color = body_col
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
    mesh.radial_segments = 24
    mesh.rings = 1
    part.mesh = mesh
    part.position = pos
    if axis_x:
        part.rotation.z = PI * 0.5
    part.material_override = _material(col, 0.45 if col == CHROME else 0.0)
    if parent == null:
        add_child(part)
    else:
        parent.add_child(part)
    return part

func _make_body() -> void:
    # Fixed true 4.166 m silhouette. Roof is shorter so bonnet and boot
    # read as proper 2106 overhangs rather than a tiny toy with no trunk.
    _cube("Unibody lower tub",Vector3(0,0.55,0),
        Vector3(DRIFT_BODY_WIDTH_M,0.72,4.07),RED)
    _cube("Shadow sill",Vector3(0,0.28,0),
        Vector3(1.95,0.20,3.87),SHADOW_RED)
    _cube("Front nose lip",Vector3(0,0.79,-2.035),
        Vector3(1.86,0.30,0.09),RED)
    _cube("Rear vertical trunk face",Vector3(0,0.76,2.035),
        Vector3(1.86,0.44,0.09),RED)
    # Trunk deck from C-pillar rear edge (+0.92) to the trailing edge (+2.05).
    _cube("Long rear boot lid",Vector3(0,0.96,1.50),
        Vector3(1.82,0.09,1.10),BRIGHT_RED)
    _cube("Boot seam near rear windscreen",Vector3(0,1.016,0.96),
        Vector3(1.70,0.008,0.025),SHADOW_RED)
    _cube("Boot lid trailing seam",Vector3(0,1.016,2.02),
        Vector3(1.70,0.008,0.02),SHADOW_RED)
    for side in [-1.0,1.0]:
        # Long bonnet with a central engine cut-out on the RED drift spec.
        _cube("Bonnet shoulder long",Vector3(side*0.74,0.955,-1.51),
            Vector3(0.31,0.115,1.02),BRIGHT_RED)
        _cube("Front bonnet edge",Vector3(side*0.73,0.957,-2.04),
            Vector3(0.30,0.11,0.07),BRIGHT_RED)
        _cube("Extended front wing",Vector3(side*0.81,0.84,-1.54),
            Vector3(0.25,0.18,1.04),RED)
        _cube("Door chrome belt",Vector3(side*0.973,0.74,0.01),
            Vector3(0.034,0.022,3.71),CHROME,0.57)
        _cube("Rocker chrome",Vector3(side*0.974,0.28,0),
            Vector3(0.04,0.035,3.72),CHROME,0.6)
        _cube("Upper door edge",Vector3(side*0.94,0.965,0.02),
            Vector3(0.055,0.045,1.85),BRIGHT_RED)
        for door_at in [-0.46,0.46]:
            _cube("Door gap vertical",Vector3(side*0.979,0.62,door_at),
                Vector3(0.023,0.69,0.021),SHADOW_RED)
            _cube("Individual chrome door handle",
                Vector3(side*1.003,0.84,door_at+0.20),
                Vector3(0.042,0.045,0.20),CHROME,0.68)
        _cube("Amber front side marker",Vector3(side*0.981,0.80,-1.72),
            Vector3(0.027,0.082,0.16),Color(1.0,0.47,0.05))
    _cube("Recessed engine aperture",Vector3(0,0.917,-1.53),
        Vector3(1.23,0.027,0.96),BLACK)
    if paint_variant == "white":
        _cube("White variant closed long bonnet",Vector3(0,1.014,-1.51),
            Vector3(1.19,0.045,1.10),BRIGHT_RED)
        for side in [-1.0,1.0]:
            _cube("White bonnet outline seam",Vector3(side*0.61,1.042,-1.51),
                Vector3(0.012,0.006,1.03),SHADOW_RED)
    else:
        _cube("Exposed-engine bay dark center",Vector3(0,0.906,-1.52),
            Vector3(1.16,0.05,1.0),BLACK)

func _make_cabin() -> void:
    # Boxy but sloping glass. Roof 1.89 m long, preserving bonnet/boot.
    _cube("Short four-door cabin",Vector3(0,1.23,0.03),
        Vector3(1.71,0.54,1.92),RED)
    _cube("Flat squared metal roof",Vector3(0,1.545,0.025),
        Vector3(1.75,0.125,1.91),BRIGHT_RED)
    _cube("Black windshield",Vector3(0,1.25,-0.967),
        Vector3(1.57,0.51,0.040),GLASS)
    _cube("Black rear window",Vector3(0,1.25,1.022),
        Vector3(1.56,0.49,0.038),GLASS)
    for side in [-1.0,1.0]:
        for at_z in [-0.49,0.49]:
            _cube("Dark side windows",Vector3(side*0.874,1.25,at_z),
                Vector3(0.028,0.45,0.83),GLASS)
        for at_z in [-0.965,-0.01,0.98]:
            _cube("A B C body pillar",Vector3(side*0.893,1.25,at_z),
                Vector3(0.07,0.59,0.082),RED)
        _cube("Chrome window sill",Vector3(side*0.911,0.992,0.025),
            Vector3(0.022,0.025,1.95),CHROME,0.61)
        _cube("Roof gutter",Vector3(side*0.891,1.566,0.025),
            Vector3(0.032,0.035,1.96),CHROME,0.45)
        _cube("Silver rear-view mirror",Vector3(side*1.02,1.055,-0.93),
            Vector3(0.22,0.12,0.20),CHROME,0.56)

func _make_front_and_engine() -> void:
    _cube("Black front grille", Vector3(0, 0.80, -2.082),
        Vector3(1.02, 0.32, 0.04), BLACK)
    for row in range(4):
        _cube("Horizontal grille trim", Vector3(0, 0.66+row*0.085, -2.113),
            Vector3(0.99, 0.015, 0.025), CHROME, 0.58)
    for side in [-1.0, 1.0]:
        for column in range(2):
            _cylinder("Round classic headlamp", Vector3(side*(0.56+column*0.26),
                0.80, -2.113), 0.126, 0.035, LAMP).rotation.x = PI * 0.5
        _cube("Amber indicator", Vector3(side*0.81, 0.57, -2.111),
            Vector3(0.25, 0.10, 0.04), Color(1.0, 0.42, 0.04))
    _cube("Front silver bumper", Vector3(0, 0.46, -2.137),
        Vector3(2.02, 0.17, 0.18), CHROME, 0.8)
    _cube("Black drift front lip", Vector3(0, 0.28, -2.146),
        Vector3(2.09, 0.13, 0.47), BLACK)
    if paint_variant == "white":
        return
    _cube("Engine black block", Vector3(0, 0.96, -1.53),
        Vector3(0.85, 0.24, 0.70), RUBBER)
    for i in range(3):
        _cylinder("Triple polished intake trumpet", Vector3((i-1)*0.29,
            1.16, -1.53), 0.115, 0.34, CHROME)
        _cylinder("Intake dark throat", Vector3((i-1)*0.29,
            1.346, -1.53), 0.075, 0.025, BLACK)

func _make_rear() -> void:
    _cube("Rear chrome bumper", Vector3(0, 0.48, 2.14),
        Vector3(2.03, 0.18, 0.19), CHROME, 0.8)
    _cube("Low rear spoiler", Vector3(0, 1.12, 1.89),
        Vector3(1.93, 0.085, 0.33), RED)
    for side in [-1.0, 1.0]:
        _cube("Rectangular tail lamp", Vector3(side*0.59, 0.76, 2.098),
            Vector3(0.54, 0.22, 0.047), Color(0.82, 0.055, 0.07))
        _cube("Amber tail indicator", Vector3(side*0.86, 0.76, 2.125),
            Vector3(0.15, 0.18, 0.02), Color(1, 0.43, 0.06))
    _cylinder("Visible drift exhaust", Vector3(0.52,0.30,2.145),
        0.115, 0.27, CHROME).rotation.x = PI * 0.5

func _make_wheels() -> void:
    for side in [-1.0, 1.0]:
        for axle_z in [FRONT_AXLE_Z, REAR_AXLE_Z]:
            var pivot := Node3D.new()
            pivot.name = "Front steer pivot" if axle_z < 0.0 else "Rear fixed axle"
            pivot.position = Vector3(side*0.995, 0.36, axle_z)
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
    for index in range(13):
        var a: float = PI*float(index)/12.0
        var flare := _cube("Bolted wide fender segment",
            Vector3(side*1.015,0.36+sin(a)*0.43,z+cos(a)*0.41),
            Vector3(0.155,0.09,0.15),RED)
        flare.rotation.x = -a

func _make_details() -> void:
    _cube("Black hood rear cowl",Vector3(0,1.045,-0.96),
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
