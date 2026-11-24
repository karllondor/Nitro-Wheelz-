extends Node3D
class_name NitroVisualLab
## Issue #37. Isolated runtime sandbox: the existing race remains unmodified.
## Never label Shin-Kawa preview evidence as Fuji Speedway evidence.

const RACE_SCENE = preload("res://scenes/race.tscn")
const MATERIALS = preload("res://scripts/visual_lab/visual_materials.gd")
const STYLE = preload("res://scripts/ui/hud_style.gd")
const FUJI_PATH = "res://tracks/fuji_speedway_small.json"
const PREVIEW_PATH = "res://tracks/shin_kawa_v2.json"

var race: Node3D
var track: Node3D
var vehicle: Node3D
var materials: NitroVisualLabMaterials
var fuji_available: bool = false
var vehicle_style: String = "A"
var environment_style: String = "A"
var time_of_day: String = "DAY"
var automatic_lights: bool = true
var manual_lights: bool = false
var brake_test: bool = false
var handbrake_test: bool = false
var original_track: Variant
var lab_props: Node3D
var lab_layer: CanvasLayer
var panel: PanelContainer
var stats: Label
var mode_label: Label
var status_label: Label
var _sun_records: Array[Dictionary] = []
var _sky_records: Array[Dictionary] = []
var _headlights: Array[SpotLight3D] = []
var _tail: StandardMaterial3D
var _brake: StandardMaterial3D
var _reverse: StandardMaterial3D
var _last_stats: float = 0.0
var _capturing: bool = false
var _is_restored: bool = false

func _ready() -> void:
    fuji_available = FileAccess.file_exists(FUJI_PATH)
    original_track = ProjectSettings.get_setting("nitro/selected_track", PREVIEW_PATH)
    ProjectSettings.set_setting("nitro/selected_track", FUJI_PATH if fuji_available else PREVIEW_PATH)
    race = RACE_SCENE.instantiate() as Node3D
    race.name = "Unmodified Nitro Wheelz race"
    add_child(race)
    ProjectSettings.set_setting("nitro/selected_track", original_track)
    track = race.get("track") as Node3D
    vehicle = race.get("car_root") as Node3D
    if track == null or vehicle == null or not bool(track.get("track_valid")):
        push_error("Visual Lab: selected track failed to initialise")
        return
    _record_environment()
    _make_optional_scenery()
    materials = MATERIALS.new()
    materials.capture(track, "environment")
    materials.capture(lab_props, "environment")
    materials.capture(vehicle, "vehicle")
    _make_vehicle_lights()
    _make_panel()
    _apply_presets()

func _exit_tree() -> void:
    if materials != null:
        materials.restore()
    _restore_environment()
    # The menu's chosen track never becomes the visual lab preview track.
    if original_track != null:
        ProjectSettings.set_setting("nitro/selected_track", original_track)

func _record_environment() -> void:
    for node in race.find_children("*", "WorldEnvironment", true, false):
        var world := node as WorldEnvironment
        _sky_records.append({"node": world, "resource": world.environment})
    for node in race.find_children("*", "DirectionalLight3D", true, false):
        var sun := node as DirectionalLight3D
        _sun_records.append({"node": sun, "color": sun.light_color, "energy": sun.light_energy,
            "rotation": sun.rotation_degrees, "shadows": sun.shadow_enabled})

func _restore_environment() -> void:
    for item in _sky_records:
        if is_instance_valid(item["node"]):
            (item["node"] as WorldEnvironment).environment = item["resource"]
    for item in _sun_records:
        if not is_instance_valid(item["node"]):
            continue
        var sun: DirectionalLight3D = item["node"]
        sun.light_color = item["color"]
        sun.light_energy = item["energy"]
        sun.rotation_degrees = item["rotation"]
        sun.shadow_enabled = item["shadows"]

func _make_optional_scenery() -> void:
    # Non-colliding art-only preview additions. Nothing modifies track DNA.
    lab_props = Node3D.new()
    lab_props.name = "Visual Lab scenery only — no collision"
    race.add_child(lab_props)
    var points: Array = track.get("centerline")
    var half: PackedFloat32Array = track.get("halfwidths")
    if points.size() < 8:
        return
    var petals: StandardMaterial3D = _paint(Color.html("#E5A2B6"), 0.94)
    var bark: StandardMaterial3D = _paint(Color.html("#4D3D3B"), 1.0)
    var needles: StandardMaterial3D = _paint(Color.html("#315B4B"), 0.98)
    var container: StandardMaterial3D = _paint(Color.html("#163D63"), 0.80)
    var count: int = 0
    for i in range(0, points.size(), maxi(1, points.size() / 10)):
        if count >= 10:
            break
        var p: Vector2 = points[i]
        var before: Vector2 = points[(i - 2 + points.size()) % points.size()]
        var after: Vector2 = points[(i + 2) % points.size()]
        var tangent: Vector2 = (after - before).normalized()
        var normal := Vector2(-tangent.y, tangent.x)
        var side: float = -1.0 if count % 2 == 0 else 1.0
        var location: Vector2 = p + normal * side * (float(half[i]) + 15.0)
        var h: float = track.call("road_height_at", location)
        _add_tree(Vector3(location.x, h, location.y), petals if count % 3 == 0 else needles, bark, count % 3 == 0)
        if count == 2 or count == 7:
            var c := MeshInstance3D.new()
            c.name = "Trackside shipping container"
            var block := BoxMesh.new()
            block.size = Vector3(6.0, 2.7, 2.5)
            c.mesh = block
            c.material_override = container
            c.position = Vector3(location.x + side * 11.0, h + 1.40, location.y)
            c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            lab_props.add_child(c)
        count += 1

static func _paint(color: Color, roughness: float) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness
    material.metallic = 0.0
    return material

func _add_tree(position_3d: Vector3, leaves: Material, trunk_mat: Material, sakura: bool) -> void:
    var stem := MeshInstance3D.new()
    stem.name = "Sakura trunk" if sakura else "Japanese pine trunk"
    var cylinder := CylinderMesh.new()
    cylinder.top_radius = 0.17
    cylinder.bottom_radius = 0.30
    cylinder.height = 4.0 if sakura else 6.0
    stem.mesh = cylinder
    stem.material_override = trunk_mat
    stem.position = position_3d + Vector3(0.0, cylinder.height * 0.5, 0.0)
    stem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    lab_props.add_child(stem)
    # Low-poly spherical clumps, never rectangular foliage cards.
    for i in range(3 if sakura else 2):
        var crown := MeshInstance3D.new()
        crown.name = "Rounded sakura canopy" if sakura else "Pine canopy"
        var sphere := SphereMesh.new()
        sphere.radial_segments = 9
        sphere.rings = 5
        sphere.radius = 2.1 if sakura else 1.7
        sphere.height = 3.3 if sakura else 4.0
        crown.mesh = sphere
        crown.material_override = leaves
        crown.position = position_3d + Vector3(float(i - 1) * (1.2 if sakura else 0.65),
            (4.0 if sakura else 5.2) + float(i % 2) * 0.8, float(i % 2) * 0.8)
        crown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        lab_props.add_child(crown)

func _make_vehicle_lights() -> void:
    # Visual-only lamp positions approximate the chosen placeholder GLB.
    # No changes to wheel hubs, handling, steering or contact physics.
    var extent: float = 2.30
    var lateral: float = 0.72
    for x in [-lateral, lateral]:
        var beam := SpotLight3D.new()
        beam.name = "Visual Lab functional low-cost headlight"
        beam.position = Vector3(x, 0.88, -extent + 0.10)
        beam.rotation_degrees = Vector3(-8.0, 0.0, 0.0)
        beam.spot_range = 29.0
        beam.spot_angle = 32.0
        beam.light_color = Color.html("#FFF1C9")
        beam.light_energy = 1.9
        beam.shadow_enabled = false
        beam.visible = false
        vehicle.add_child(beam)
        _headlights.append(beam)
    _tail = _lamp_material(Color.html("#B32D3A"))
    _brake = _lamp_material(Color.html("#FA203A"))
    _reverse = _lamp_material(Color.html("#F9F5E8"))
    for x in [-lateral, lateral]:
        _lamp_mesh(Vector3(x, 0.78, extent - 0.14), Vector3(0.34, 0.10, 0.075), _tail, "Rear position light")
        _lamp_mesh(Vector3(x, 0.66, extent - 0.14), Vector3(0.37, 0.12, 0.075), _brake, "Brake and handbrake light")
        _lamp_mesh(Vector3(x * 0.74, 0.66, extent - 0.15), Vector3(0.12, 0.10, 0.078), _reverse, "Reverse light")

static func _lamp_material(col: Color) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = col.darkened(0.45)
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.emission_enabled = true
    m.emission = col
    m.emission_energy_multiplier = 0.0
    return m

func _lamp_mesh(at: Vector3, size: Vector3, material: Material, title: String) -> void:
    var n := MeshInstance3D.new()
    n.name = "Visual Lab " + title
    var cube := BoxMesh.new()
    cube.size = size
    n.mesh = cube
    n.material_override = material
    n.position = at
    n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    vehicle.add_child(n)

func _apply_presets() -> void:
    if materials == null:
        return
    _is_restored = false
    materials.set_styles(vehicle_style, environment_style, time_of_day == "NIGHT")
    _apply_time()
    if lab_props != null:
        lab_props.visible = true
    _update_lamps()
    _refresh_panel_text()

func _apply_time() -> void:
    var sky_top: Color
    var sky_horizon: Color
    var ambient: Color
    var sunlight: Color
    var light_level: float
    match time_of_day:
        "SUNSET":
            sky_top = Color.html("#536E9B")
            sky_horizon = Color.html("#E5A2B6")
            ambient = Color.html("#C5A6A0")
            sunlight = Color.html("#FFD39A")
            light_level = 0.90
        "NIGHT":
            sky_top = Color.html("#091A37")
            sky_horizon = Color.html("#163D63")
            ambient = Color.html("#566D92")
            sunlight = Color.html("#A5B7D4")
            light_level = 0.27
        _:
            sky_top = Color.html("#79C8E1")
            sky_horizon = Color.html("#EAE4D6")
            ambient = Color.html("#B3CBCE")
            sunlight = Color.html("#FFF4DA")
            light_level = 1.28
    for item in _sky_records:
        var world: WorldEnvironment = item["node"]
        if not is_instance_valid(world):
            continue
        var env := Environment.new()
        env.background_mode = Environment.BG_SKY
        var sky := Sky.new()
        var sky_mat := ProceduralSkyMaterial.new()
        sky_mat.sky_top_color = sky_top
        sky_mat.sky_horizon_color = sky_horizon
        sky_mat.ground_horizon_color = sky_horizon.darkened(0.20)
        sky_mat.ground_bottom_color = sky_top.darkened(0.60)
        sky.sky_material = sky_mat
        env.sky = sky
        env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
        env.ambient_light_color = ambient
        env.ambient_light_energy = 0.75 if time_of_day != "NIGHT" else 0.49
        env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
        env.fog_enabled = false
        world.environment = env
    for item in _sun_records:
        var sun: DirectionalLight3D = item["node"]
        if not is_instance_valid(sun):
            continue
        sun.light_color = sunlight
        sun.light_energy = light_level
        sun.rotation_degrees = Vector3(-24.0 if time_of_day == "SUNSET" else -58.0, -38.0, 0.0)
        sun.shadow_enabled = false

func _process(delta: float) -> void:
    if vehicle == null:
        return
    _update_lamps()
    _last_stats += delta
    if _last_stats >= 0.35:
        _last_stats = 0.0
        _refresh_panel_text()

func _update_lamps() -> void:
    if vehicle == null or _tail == null or _is_restored:
        return
    var on: bool = (time_of_day == "NIGHT") if automatic_lights else manual_lights
    for light in _headlights:
        light.visible = on
    var controls: Node = race.get("touch") as Node
    var physical_brake: bool = Input.get_action_strength("brake") > 0.1
    var physical_handbrake: bool = Input.get_action_strength("handbrake") > 0.1
    if controls != null and controls.visible:
        physical_brake = physical_brake or float(controls.get("brake")) > 0.1
        physical_handbrake = physical_handbrake or float(controls.get("handbrake")) > 0.1
    var braking: bool = physical_brake or physical_handbrake or brake_test or handbrake_test
    var model: RefCounted = race.get("model") as RefCounted
    var reverse_on: bool = model != null and model.has_method("is_reversing") and bool(model.call("is_reversing"))
    _tail.emission_energy_multiplier = 0.90 if on else 0.0
    _brake.emission_energy_multiplier = 3.5 if braking else 0.0
    _reverse.emission_energy_multiplier = 2.0 if reverse_on else 0.0

func _make_panel() -> void:
    lab_layer = CanvasLayer.new()
    lab_layer.name = "Visual Lab developer panel only"
    lab_layer.layer = 25
    add_child(lab_layer)
    var root := Control.new()
    root.name = "Visual Lab UI"
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    lab_layer.add_child(root)
    var open_button := Button.new()
    open_button.name = "Visual Lab toggle"
    open_button.text = "VISUAL LAB  •  #37"
    open_button.anchor_left = 1.0
    open_button.anchor_right = 1.0
    open_button.offset_left = -205.0
    open_button.offset_right = -8.0
    open_button.offset_top = 7.0
    open_button.offset_bottom = 47.0
    STYLE.style_button(open_button, 0.72, true)
    root.add_child(open_button)
    panel = PanelContainer.new()
    panel.name = "Visual Lab overlay (independent of production HUD)"
    panel.anchor_left = 1.0
    panel.anchor_right = 1.0
    panel.anchor_bottom = 1.0
    var screen: Vector2 = get_viewport().get_visible_rect().size
    panel.offset_left = -minf(390.0, screen.x * 0.79)
    panel.offset_right = -8.0
    panel.offset_top = 52.0
    panel.offset_bottom = -8.0
    panel.mouse_filter = Control.MOUSE_FILTER_STOP
    var skin := StyleBoxFlat.new()
    skin.bg_color = Color(0.04, 0.055, 0.09, 0.90)
    skin.border_color = Color.html("#8B43CB")
    skin.set_border_width_all(1)
    skin.set_corner_radius_all(9)
    skin.set_content_margin_all(10)
    panel.add_theme_stylebox_override("panel", skin)
    root.add_child(panel)
    open_button.pressed.connect(func(): panel.visible = not panel.visible)
    var scroller := ScrollContainer.new()
    scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    panel.add_child(scroller)
    var column := VBoxContainer.new()
    column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    column.add_theme_constant_override("separation", 5)
    scroller.add_child(column)
    mode_label = _label(column, "", 18, Color.html("#F5C343"))
    status_label = _label(column, "", 12, Color.html("#E5A2B6"))
    _button(column, "VEHICLE  A / C", func():
        vehicle_style = "C" if vehicle_style == "A" else "A"
        _apply_presets())
    _button(column, "ENVIRONMENT  A / C", func():
        environment_style = "C" if environment_style == "A" else "A"
        _apply_presets())
    _button(column, "DAY  /  SUNSET  /  NIGHT", func():
        time_of_day = "SUNSET" if time_of_day == "DAY" else ("NIGHT" if time_of_day == "SUNSET" else "DAY")
        _apply_presets())
    _button(column, "CHASE / TOP-DOWN", func():
        _set_camera(0 if int(race.get("camera_mode")) == 1 else 1))
    _button(column, "HEADLIGHTS  AUTO / MANUAL", func():
        automatic_lights = not automatic_lights
        _update_lamps()
        _refresh_panel_text())
    _button(column, "MANUAL HEADLIGHTS  ON / OFF", func():
        manual_lights = not manual_lights
        _update_lamps()
        _refresh_panel_text())
    _button(column, "BRAKE LIGHT TEST  ON / OFF", func():
        brake_test = not brake_test
        _update_lamps()
        _refresh_panel_text())
    _button(column, "HANDBRAKE TEST  ON / OFF", func():
        handbrake_test = not handbrake_test
        _update_lamps()
        _refresh_panel_text())
    stats = _label(column, "", 13, Color.html("#EAE4D6"))
    _button(column, "SCREENSHOT THIS VIEW", func(): _screenshot("manual"))
    _button(column, "CAPTURE ALL 12 × 2 CAMERAS", _capture_matrix)
    _button(column, "RESET LAB TO AA / DAY", func():
        vehicle_style = "A"
        environment_style = "A"
        time_of_day = "DAY"
        automatic_lights = true
        manual_lights = false
        brake_test = false
        handbrake_test = false
        _apply_presets())
    _button(column, "RESTORE ORIGINAL MATERIALS", _restore_production)
    _button(column, "HIDE PANEL", func(): panel.visible = false)
    _button(column, "EXIT LAB / RETURN TO MENU", func():
        get_tree().change_scene_to_file("res://scenes/boot.tscn"))

static func _label(parent: Node, value: String, size: int, color: Color) -> Label:
    var lbl := Label.new()
    lbl.text = value
    lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    lbl.add_theme_font_size_override("font_size", size)
    lbl.add_theme_color_override("font_color", color)
    parent.add_child(lbl)
    return lbl

static func _button(parent: Node, title: String, callback: Callable) -> Button:
    var b := Button.new()
    b.text = title
    b.custom_minimum_size = Vector2(0.0, 39.0)
    b.pressed.connect(callback)
    parent.add_child(b)
    return b

func _set_camera(idx: int) -> void:
    race.set("camera_mode", idx)
    var camera: Camera3D = (race.get("overhead") if idx == 0 else race.get("chase")) as Camera3D
    if camera != null:
        camera.make_current()
    _refresh_panel_text()

func _restore_production() -> void:
    if materials != null:
        materials.restore()
    _restore_environment()
    _is_restored = true
    if lab_props != null:
        lab_props.visible = false
    for light in _headlights:
        light.visible = false
    if _tail != null:
        _tail.emission_energy_multiplier = 0.0
        _brake.emission_energy_multiplier = 0.0
        _reverse.emission_energy_multiplier = 0.0
    _refresh_panel_text()

func _refresh_panel_text() -> void:
    if mode_label == null or stats == null:
        return
    var mode: String = "ORIGINAL" if _is_restored else vehicle_style + environment_style + "  /  " + time_of_day
    mode_label.text = "VISUAL LAB v0.1   •   " + mode
    status_label.text = ("FUJI SPEEDWAY SMALL — TRACK DATA FOUND" if fuji_available
        else "FUJI MISSING • SHIN-KAWA PROXY ONLY • NOT FUJI QA")
    var fps: float = float(Engine.get_frames_per_second())
    var draw_calls: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
    var renderer: String = str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "unknown"))
    stats.text = "FPS %.1f  •  FRAME BUDGET %.1f ms\nDRAW CALLS %d  •  %s\nHEADLIGHTS %s • MANUAL %s\nBRAKE %s • HANDBRAKE %s\n%s" % [
        fps, 1000.0 / maxf(fps, 1.0), draw_calls, renderer,
        "AUTO" if automatic_lights else "MANUAL", "ON" if manual_lights else "OFF",
        "ON" if brake_test else "OFF", "ON" if handbrake_test else "OFF",
        "CAPTURE IN PROGRESS" if _capturing else "Android / Web / PC: test on actual targets"]

func _screenshot(label: String) -> void:
    if lab_layer == null:
        return
    var folder: String = "user://visual_lab"
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
    var file: String = "%s/%s.png" % [folder, label]
    var img: Image = get_viewport().get_texture().get_image()
    var code: Error = img.save_png(file)
    if status_label != null:
        status_label.text = "Saved %s" % file if code == OK else "Screenshot failed (%d)" % code

func _capture_matrix() -> void:
    if _capturing or race == null:
        return
    _capturing = true
    var old_car: String = vehicle_style
    var old_env: String = environment_style
    var old_time: String = time_of_day
    var old_camera: int = int(race.get("camera_mode"))
    var old_physics: bool = race.is_physics_processing()
    var old_visible: bool = lab_layer.visible
    race.set_physics_process(false)
    lab_layer.visible = false
    for car_style in ["A", "C"]:
        for world_style in ["A", "C"]:
            for daytime in ["DAY", "SUNSET", "NIGHT"]:
                vehicle_style = car_style
                environment_style = world_style
                time_of_day = daytime
                _apply_presets()
                for cam in [0, 1]:
                    _set_camera(cam)
                    race.call("_snap_cameras")
                    await get_tree().process_frame
                    await get_tree().process_frame
                    _screenshot("%s%s_%s_%s" % [car_style, world_style, daytime,
                        "TOP" if cam == 0 else "CHASE"])
    vehicle_style = old_car
    environment_style = old_env
    time_of_day = old_time
    _apply_presets()
    _set_camera(old_camera)
    race.set_physics_process(old_physics)
    lab_layer.visible = old_visible
    _capturing = false
    _refresh_panel_text()
