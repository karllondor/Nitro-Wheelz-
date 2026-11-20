extends Node3D
class_name NitroGlbCar
## A Car Factory car (Blender -> GLB). Same interface as the procedural
## cars (set_motion, front_wheels, rolling_wheels, shadow_height), and the
## SAME node tree in the garage and in the race: looks never switch per mode.
##
## GLB conventions (tools/car_factory/blender/nwcf.py):
##   materials NW_Paint (swappable colour), NW_Atlas (all other opaque parts,
##   textures in the GLB), NW_Glass; empties wheel_FL/FR/RL/RR at the hubs.
## Wheels are separate GLBs (assets/cars/wheels), chosen by the cosmetics.
const PAINT_SHADER = preload("res://assets/shaders/diecast_paint.gdshader")
const ATLAS_SHADER = preload("res://assets/shaders/nitro_car_atlas.gdshader")
const GLASS_SHADER = preload("res://assets/shaders/nitro_car_glass.gdshader")
const SHADOW_SHADER = preload("res://assets/shaders/soft_shadow.gdshader")
const COSMETICS = preload("res://scripts/vehicles/car_cosmetics.gd")
const WHEEL_NODES: Array[String] = ["wheel_FL","wheel_FR","wheel_RL","wheel_RR"]

var variant: String = ""
var profile: Dictionary = {}
var cosmetic: Dictionary = {}
var shadow_height: float = 0.10
var front_wheels: Array[Node3D] = []
var rolling_wheels: Array[Node3D] = []
var wheel_mounts: Array[Node3D] = []
var wheel_radius: float = 0.29
var paint_material: ShaderMaterial
var body: Node3D
var shadow: MeshInstance3D
static var _scenes: Dictionary = {}
static var _converted: Dictionary = {}

func setup(car_variant: String, car_profile: Dictionary, choice: Dictionary) -> NitroGlbCar:
    variant = car_variant
    profile = car_profile
    cosmetic = choice
    return self

func _ready() -> void:
    var model: Dictionary = profile.get("model",{})
    wheel_radius = float(model.get("wheel_radius_m",0.29))
    paint_material = ShaderMaterial.new()
    paint_material.shader = PAINT_SHADER
    paint_material.set_shader_parameter("studio",Color(0.97,0.97,1.0))
    paint_material.set_shader_parameter("floor_tint",Color(0.11,0.11,0.13))
    apply_paint(cosmetic)
    body = _scene(str(model.get("glb",""))).instantiate() as Node3D
    body.name = "Factory body"
    add_child(body)
    _convert_materials(body)
    _mount_wheels(model)
    _make_shadow(model)

static func _scene(path: String) -> PackedScene:
    if not _scenes.has(path):
        _scenes[path] = load(path)
    return _scenes[path]

## Paint colour/finish only: the mesh and every other material stay.
func apply_paint(choice: Dictionary) -> void:
    cosmetic = choice
    var p: Dictionary = COSMETICS.paint_params(choice)
    for key in p.keys():
        paint_material.set_shader_parameter(key,p[key])

## Swap the wheel asset on all four hubs (cosmetic only).
func apply_wheels(choice: Dictionary) -> void:
    cosmetic = choice
    for mount in wheel_mounts:
        for child in mount.get_children():
            mount.remove_child(child)
            child.queue_free()
        mount.add_child(_wheel_instance(bool(mount.get_meta("left",false))))

func _convert_materials(node: Node) -> void:
    if node is MeshInstance3D:
        var mi := node as MeshInstance3D
        for i in range(mi.mesh.get_surface_count()):
            var src: Material = mi.get_active_material(i)
            mi.set_surface_override_material(i,_material_for(src))
    for child in node.get_children():
        _convert_materials(child)

func _material_for(src: Material) -> Material:
    if src == null:
        return null
    var name: String = src.resource_name
    if name.begins_with("NW_Paint"):
        return paint_material
    var key: int = src.get_instance_id()
    if _converted.has(key):
        return _converted[key]
    var out: Material = src
    if name.begins_with("NW_Glass"):
        var glass := ShaderMaterial.new()
        glass.shader = GLASS_SHADER
        out = glass
    elif name.begins_with("NW_Atlas") and src is BaseMaterial3D:
        var std := src as BaseMaterial3D
        var atlas := ShaderMaterial.new()
        atlas.shader = ATLAS_SHADER
        atlas.set_shader_parameter("albedo_tex",std.albedo_texture)
        atlas.set_shader_parameter("orm_tex",std.roughness_texture if std.roughness_texture != null else std.metallic_texture)
        atlas.set_shader_parameter("emission_tex",std.emission_texture)
        out = atlas
    _converted[key] = out
    return out

func _mount_wheels(model: Dictionary) -> void:
    var camber: Dictionary = model.get("camber_deg",{})
    for wheel_name in WHEEL_NODES:
        var hub: Node3D = body.find_child(wheel_name,true,false) as Node3D
        if hub == null:
            push_error("Factory car %s has no %s" % [variant,wheel_name])
            continue
        var front: bool = wheel_name.substr(6,1) == "F"
        var left: bool = wheel_name.ends_with("L")
        var steer := Node3D.new()
        steer.name = "Steer pivot" if front else "Rear hub"
        hub.add_child(steer)
        if front:
            front_wheels.append(steer)
        var tilt := Node3D.new()
        tilt.name = "Camber"
        var deg: float = float(camber.get("front" if front else "rear",0.0))
        # Negative camber: the top of the tyre leans in towards the car.
        tilt.rotation.z = deg_to_rad(-deg)*(-1.0 if left else 1.0)
        steer.add_child(tilt)
        var roll := Node3D.new()
        roll.name = "Rolling wheel"
        tilt.add_child(roll)
        rolling_wheels.append(roll)
        roll.set_meta("left",left)
        wheel_mounts.append(roll)
        roll.add_child(_wheel_instance(left))

func _wheel_instance(left: bool) -> Node3D:
    var info: Dictionary = COSMETICS.wheels().get(str(cosmetic.get("wheel_asset_id","")),{})
    var path: String = "res://assets/cars/wheels/"+str(info.get("file",""))
    var wheel: Node3D = _scene(path).instantiate() as Node3D
    wheel.name = "Wheel "+str(cosmetic.get("wheel_asset_id",""))
    var s: float = wheel_radius/float(info.get("tyre_radius_m",wheel_radius))
    wheel.scale = Vector3.ONE*s
    if left:
        wheel.rotation.y = PI   # outer face (+X in the asset) points left
    _convert_materials(wheel)
    return wheel

func _make_shadow(model: Dictionary) -> void:
    shadow = MeshInstance3D.new()
    shadow.name = "Soft contact shadow"
    var plane := PlaneMesh.new()
    var size: Array = model.get("shadow_size_m",[2.5,5.4])
    plane.size = Vector2(float(size[0]),float(size[1]))
    shadow.mesh = plane
    var mat := ShaderMaterial.new()
    mat.shader = SHADOW_SHADER
    mat.set_shader_parameter("core",Vector2(0.30,0.37))
    mat.set_shader_parameter("softness",0.13)
    mat.set_shader_parameter("corner",0.12)
    mat.set_shader_parameter("opacity",0.72)
    shadow.material_override = mat
    shadow.position = Vector3(0.0,shadow_height,0.0)
    shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(shadow)

func set_motion(steer_rad: float, speed_mps: float, dt: float) -> void:
    for wheel in front_wheels:
        wheel.rotation.y = -steer_rad
    for roll in rolling_wheels:
        roll.rotation.x -= speed_mps*dt/wheel_radius
