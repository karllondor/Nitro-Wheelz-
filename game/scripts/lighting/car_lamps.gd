extends RefCounted
## Light amounts and placements are car-local (-Z is the front).
const TIME = preload("res://scripts/lighting/time_of_day.gd")
const ATLAS_SHADER = preload("res://assets/shaders/nitro_car_atlas.gdshader")
const LAB_ENERGY := 1.9
const ENERGY := LAB_ENERGY * 8.0
const RANGE := 54.0
const ANGLE := 18.5
const DOWN_DEGREES := 2.35

enum Mode { AUTO, ON, OFF }
const MODE_LABELS := ["AUTO", "ON", "OFF"]
const POSITION := 1
const BRAKING := 2
# Separate profiles for the two Lada fascia variants, RYU and E30.
# Values use the source mesh coordinates before the race visual scale.
const MOUNTS := {
    "red": [Vector3(0.64, 0.54, -2.041), Vector3(0.59, 0.536, 2.038)],
    "white": [Vector3(0.595, 0.553, -2.043), Vector3(0.578, 0.549, 2.038)],
    "blue": [Vector3(0.66, 0.57, -2.18), Vector3(0.515, 0.663, 2.193)],
    "e30": [Vector3(0.65, 0.46, -2.156), Vector3(0.492, 0.647, 2.089)],
    "flame": [Vector3(0.66, 0.57, -2.18), Vector3(0.62, 0.61, 2.193)]
}
var mode := Mode.AUTO
var bits := 0
var spots: Array[SpotLight3D] = []
var _atlas: Array[ShaderMaterial] = []
var _legacy_front: ShaderMaterial
var _legacy_rear: ShaderMaterial
var _fallback_front: StandardMaterial3D
var _fallback_rear: StandardMaterial3D
var _front_lenses: Array[MeshInstance3D] = []
var _rear_lenses: Array[MeshInstance3D] = []
var _paint: ShaderMaterial
var _reflection := 1.0
var _applied := -1

func setup(car: Node3D, variant: String) -> void:
    var profile: Array = MOUNTS.get(variant, MOUNTS.red)
    var mount: Vector3 = profile[0]
    var tail: Vector3 = profile[1]
    if car is NitroGlbCar:
        _paint = car.paint_material
        _bind_atlas(car.body, mount, tail)
        if variant == "flame" or _atlas.is_empty():
            _make_fallback(car, mount, tail)
    else:
        # Procedural cars already have separately batched glass lenses.
        _legacy_front = car.materials.get("lamp")
        _legacy_rear = car.materials.get("tail")
        mount = Vector3(0.60, 0.55, -2.20) if variant == "blue" else Vector3(0.61, 0.55, -2.04)
    for side in [-1.0, 1.0]:
        var light := SpotLight3D.new()
        light.name = "Left headlight beam" if side < 0.0 else "Right headlight beam"
        light.position = Vector3(side * mount.x, mount.y, mount.z - 0.025)
        light.rotation_degrees = Vector3(-DOWN_DEGREES, -side * 2.0, 0)
        light.light_color = Color("#fff4dc")
        light.light_energy = ENERGY
        light.light_specular = 0.18
        light.spot_range = RANGE
        light.spot_angle = ANGLE
        light.spot_attenuation = 0.72
        light.spot_angle_attenuation = 0.84
        light.shadow_enabled = false
        light.visible = false
        car.add_child(light)
        spots.append(light)
    _apply()

func _bind_atlas(body: Node3D, front: Vector3, rear: Vector3) -> void:
    var copies := {}
    for node in body.find_children("*", "MeshInstance3D", true, false):
        var mesh := node as MeshInstance3D
        if mesh.mesh == null:
            continue
        for index in mesh.mesh.get_surface_count():
            var original := mesh.get_active_material(index) as ShaderMaterial
            if original == null or original.shader != ATLAS_SHADER or original.get_shader_parameter("emission_tex") == null:
                continue
            if not copies.has(original):
                var mat := original.duplicate() as ShaderMaterial
                mat.set_shader_parameter("road_lamp_limits", Vector2(front.z + 0.19, rear.z - 0.18))
                mat.set_shader_parameter("road_lights_enabled", true)
                copies[original] = mat
                _atlas.append(mat)
            mesh.set_surface_override_material(index, copies[original])

func _make_fallback(car: Node3D, front: Vector3, rear: Vector3) -> void:
    _fallback_front = _lens_material(Color("#fff2d8"))
    _fallback_rear = _lens_material(Color("#ff1b30"))
    for side in [-1.0, 1.0]:
        _front_lenses.append(_fallback_lens(car, "Front lamp lens", Vector3(front.x * side, front.y, front.z - 0.012), _fallback_front))
        _rear_lenses.append(_fallback_lens(car, "Rear lamp lens", Vector3(rear.x * side, rear.y, rear.z + 0.012), _fallback_rear))

static func _lens_material(color: Color) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.albedo_color = color
    return mat

static func _fallback_lens(car: Node3D, label: String, at: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
    var lens := MeshInstance3D.new()
    var surface := BoxMesh.new()
    surface.size = Vector3(0.19, 0.075, 0.020)
    lens.name = label
    lens.mesh = surface
    lens.material_override = material
    lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    lens.position = at
    car.add_child(lens)
    return lens

func set_local(preset: int, brake: bool, handbrake: bool) -> bool:
    var previous := bits
    var on := mode == Mode.ON or (mode == Mode.AUTO and TIME.requires_headlights(preset))
    bits = (POSITION if on else 0) | (BRAKING if brake or handbrake else 0)
    _apply()
    return (previous & POSITION) != (bits & POSITION)

func set_remote(state: int) -> bool:
    var previous := bits
    bits = state & (POSITION | BRAKING)
    _apply()
    return (previous & POSITION) != (bits & POSITION)

func set_reflection(value: float) -> void:
    if is_equal_approx(value, _reflection):
        return
    _reflection = value
    if _paint != null:
        _paint.set_shader_parameter("road_reflection", value)
    for material in _atlas:
        material.set_shader_parameter("road_reflection", value)

func _apply() -> void:
    if bits == _applied:
        return
    _applied = bits
    var driving := (bits & POSITION) != 0
    var braking := (bits & BRAKING) != 0
    var rear := 1.0 if braking else (0.52 if driving else 0.0)
    for light in spots:
        light.visible = driving
    for material in _atlas:
        material.set_shader_parameter("road_lamp_levels", Vector2(3.2 if driving else 0.0, rear))
    if _legacy_front != null:
        _legacy_front.set_shader_parameter("road_lamp_emission", Color("#fff4dc") * (0.9 if driving else 0.0))
    if _legacy_rear != null:
        _legacy_rear.set_shader_parameter("road_lamp_emission", Color("#ff2034") * (rear * 1.15))
    if _fallback_rear != null:
        _fallback_rear.albedo_color = Color("#ff2e40") if braking else Color("#ae1825")
    for lens in _rear_lenses:
        lens.visible = rear > 0.0
    for lens in _front_lenses:
        lens.visible = driving
