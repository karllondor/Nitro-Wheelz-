extends RefCounted
## Per-race resources. DAY keeps the original environment and unshaded art.
## A lit copy of the pavement receives real spots whenever headlights are on;
## other presets use the same lit surface for sunlight and ambient response.
const TIME = preload("res://scripts/lighting/time_of_day.gd")
const ROAD_NAMES := ["Nitro Wheelz Park paving", "Site asphalt", "Single continuous driving surface"]
const ROAD_SHADER = preload("res://assets/shaders/road_lighting.gdshader")
const PAINT_SHADER = preload("res://assets/shaders/pavement_paint.gdshader")
const VERGE_SHADER = preload("res://assets/shaders/park_verge.gdshader")
const LOOKS := {
    TIME.Preset.DAWN: {
        "angle": Vector2(-10, 38), "sun": Color("#ffbc94"), "energy": 0.64,
        "ambient": Color("#8595d7"), "ambient_energy": 0.54,
        "sky": Color("#364475"), "horizon": Color("#b47987"), "haze": Color("#7579a1"),
        "art": Color(0.55, 0.55, 0.73), "reflection": 0.58
    },
    TIME.Preset.GOLDEN_HOUR: {
        "angle": Vector2(-17, -64), "sun": Color("#ffb870"), "energy": 1.03,
        "ambient": Color("#d5bcab"), "ambient_energy": 0.57,
        "sky": Color("#675f8a"), "horizon": Color("#e2a06e"), "haze": Color("#ac816f"),
        "art": Color(0.86, 0.72, 0.61), "reflection": 0.78
    },
    TIME.Preset.NIGHT: {
        "angle": Vector2(-48, -21), "sun": Color("#8fa7fb"), "energy": 0.13,
        "ambient": Color("#889de0"), "ambient_energy": 0.28,
        "sky": Color("#0b132d"), "horizon": Color("#192748"), "haze": Color("#202b49"),
        "art": Color(0.30, 0.36, 0.54), "reflection": 0.31
    }
}

var _world: WorldEnvironment
var _sun: DirectionalLight3D
var _day: Environment
var _alternate: Environment
var _sky: ProceduralSkyMaterial
var _day_sun := {}
var _surface_states: Array[Dictionary] = []
var _tinted_shaders: Array[ShaderMaterial] = []
var _labels: Array[Dictionary] = []
var _shadow_meshes: Array[MeshInstance3D] = []
var _preset := -1
var _road_lit := false

func bind(track: Node3D) -> void:
    _surface_states.clear()
    _tinted_shaders.clear()
    _labels.clear()
    _shadow_meshes.clear()
    _preset = -1
    _road_lit = false
    var worlds := track.find_children("*", "WorldEnvironment", true, false)
    var suns := track.find_children("*", "DirectionalLight3D", true, false)
    if worlds.is_empty() or suns.is_empty():
        return
    _world = worlds.back() as WorldEnvironment
    _sun = suns.back() as DirectionalLight3D
    _day = _world.environment
    _day_sun = {"rotation": _sun.rotation_degrees, "color": _sun.light_color,
        "energy": _sun.light_energy, "shadows": _sun.shadow_enabled}
    _alternate = _day.duplicate() as Environment
    _alternate.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    _alternate.ambient_light_sky_contribution = 0.0
    _alternate.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
    _alternate.sky = Sky.new()
    _alternate.sky.process_mode = Sky.PROCESS_MODE_QUALITY
    _sky = ProceduralSkyMaterial.new()
    _sky.sun_angle_max = 9.0
    _sky.sun_curve = 0.17
    _alternate.sky.sky_material = _sky
    _alternate.background_mode = Environment.BG_SKY
    _alternate.background_energy_multiplier = 1.0
    _alternate.fog_enabled = true
    _alternate.fog_mode = Environment.FOG_MODE_DEPTH
    _alternate.fog_depth_begin = 115.0
    _alternate.fog_depth_end = 1800.0
    _alternate.fog_density = 0.38
    _sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
    _sun.directional_shadow_max_distance = 110.0
    for mesh in track.find_children("*", "MeshInstance3D", true, false):
        _remember_mesh(mesh as MeshInstance3D)
    for node in track.find_children("*", "Label3D", true, false):
        _labels.append({"node": node, "color": (node as Label3D).modulate})

func _remember_mesh(mesh: MeshInstance3D) -> void:
    if mesh.mesh == null:
        return
    if str(mesh.name).begins_with("Vegetation quadrant") or mesh.name in ["Workshop walls and canopy posts", "Parked cars"]:
        _shadow_meshes.append(mesh)
    if mesh.material_override != null:
        _remember_material(mesh, -1, mesh.material_override)
        return
    for index in mesh.mesh.get_surface_count():
        _remember_material(mesh, index, mesh.get_active_material(index))

func _remember_material(mesh: MeshInstance3D, index: int, original: Material) -> void:
    if original is ShaderMaterial and original.shader in [PAINT_SHADER, VERGE_SHADER]:
        var tinted := original.duplicate() as ShaderMaterial
        _set_material(mesh, index, tinted)
        _tinted_shaders.append(tinted)
    elif original is StandardMaterial3D and original.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
        var road := ROAD_NAMES.has(str(mesh.name))
        var responsive: Material
        if road:
            var physical := ShaderMaterial.new()
            physical.shader = ROAD_SHADER
            physical.set_shader_parameter("pavement", original.albedo_texture)
            responsive = physical
        else:
            var lit := original.duplicate() as StandardMaterial3D
            lit.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
            lit.roughness = 0.92
            lit.metallic_specular = 0.12
            responsive = lit
        _surface_states.append({"mesh": mesh, "index": index,
            "override": mesh.get_surface_override_material(index) if index >= 0 else original,
            "responsive": responsive, "road": road})

func apply(preset: int, headlights: bool) -> void:
    if _world == null or not TIME.valid(preset) or (preset == _preset and headlights == _road_lit):
        return
    var day := preset == TIME.Preset.DAY
    var change_preset := preset != _preset
    _preset = preset
    _road_lit = headlights
    var art := Color.WHITE
    if change_preset:
        if day:
            _world.environment = _day
            _sun.rotation_degrees = _day_sun.rotation
            _sun.light_color = _day_sun.color
            _sun.light_energy = _day_sun.energy
            _sun.shadow_enabled = _day_sun.shadows
        else:
            var look: Dictionary = LOOKS[preset]
            art = look.art
            _sky.sky_top_color = look.sky
            _sky.sky_horizon_color = look.horizon
            _sky.ground_horizon_color = look.horizon.darkened(0.28)
            _sky.ground_bottom_color = look.sky.darkened(0.28)
            _alternate.ambient_light_color = look.ambient
            _alternate.ambient_light_energy = look.ambient_energy
            _alternate.fog_light_color = look.haze
            _world.environment = _alternate
            _sun.rotation_degrees = Vector3(look.angle.x, look.angle.y, 0)
            _sun.light_color = look.sun
            _sun.light_energy = look.energy
            _sun.shadow_enabled = preset != TIME.Preset.NIGHT
        for shader in _tinted_shaders:
            shader.set_shader_parameter("time_of_day_tint", art)
        for entry in _labels:
            entry.node.modulate = entry.color * art
        for mesh in _shadow_meshes:
            mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if not day and _sun.shadow_enabled else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    for entry in _surface_states:
        var use_lighting: bool = not day or (headlights and entry.road)
        _set_material(entry.mesh, entry.index, entry.responsive if use_lighting else entry.override)

static func reflection(preset: int) -> float:
    return 1.0 if preset == TIME.Preset.DAY else float(LOOKS[preset].reflection)

static func _set_material(mesh: MeshInstance3D, index: int, material: Material) -> void:
    if index < 0:
        mesh.material_override = material
    else:
        mesh.set_surface_override_material(index, material)
