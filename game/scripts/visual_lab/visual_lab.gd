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
var _panel_toggle: Button
var _panel_dim: ColorRect
var _ui_buttons: Array[Button] = []
var _ui_labels: Array[Label] = []
var _pages: Dictionary = {}
var _tabs: Dictionary = {}
var _controls: Dictionary = {}
var _ui_scale: float = 1.0
var stats: Label
var mode_label: Label
var status_label: Label
var _sun_records: Array[Dictionary] = []
var _sky_records: Array[Dictionary] = []
var _headlights: Array[SpotLight3D] = []
var _original_voxel_sakura: Array[Dictionary] = []
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
    _show_original_voxel_sakura(true)
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
    _make_rounded_sakura()
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

func _make_rounded_sakura() -> void:
    # Old Shin-Kawa uses deliberately square "pixel" blossoms. In this lab
    # only, hide that MultiMesh and replace its canopy with one cheap
    # instanced smooth-silhouette canopy. Do not edit production meshes.
    var old: MultiMeshInstance3D = track.find_child("Cherry blossom voxels", true, false) as MultiMeshInstance3D
    if old == null or old.multimesh == null:
        return
    _original_voxel_sakura.append({"node": old, "visible": old.visible})
    old.visible = false
    var source: MultiMesh = old.multimesh
    var occupied: Dictionary = {}
    var step: float = 3.5
    for i in range(source.instance_count):
        var pos: Vector3 = source.get_instance_transform(i).origin
        occupied[Vector2i(roundi(pos.x / step), roundi(pos.z / step))] = true
    var positions: Array = track.get("tree_positions")
    var transforms: Array[Transform3D] = []
    var colours: Array[Color] = []
    for p in positions:
        var pt: Vector2 = p
        var cell := Vector2i(roundi(pt.x / step), roundi(pt.y / step))
        var blossom: bool = false
        for cx in range(-1, 2):
            for cz in range(-1, 2):
                if occupied.has(cell + Vector2i(cx, cz)):
                    blossom = true
                    break
            if blossom:
                break
        if not blossom:
            continue
        var level: float = track.call("road_height_at", pt)
        for part in range(3):
            var shift: Vector3 = Vector3(float(part - 1) * 1.0, 0.25 * float(part % 2), float(part % 2) * 0.55)
            var centre: Vector3 = Vector3(pt.x, level + 3.7, pt.y) + shift
            var size: Vector3 = Vector3(1.85, 1.55, 1.85) if part != 1 else Vector3(2.2, 1.65, 2.2)
            transforms.append(Transform3D(Basis.from_scale(size), centre))
            colours.append(Color.html("#E5A2B6").lerp(Color.html("#F1CBD5"), float(part) * 0.20))
    if transforms.is_empty():
        push_warning("Visual Lab: unable to classify original voxel sakura locations")
        return
    var mesh := SphereMesh.new()
    mesh.radius = 1.0
    mesh.height = 2.0
    mesh.radial_segments = 9
    mesh.rings = 5
    var batch := MultiMesh.new()
    batch.transform_format = MultiMesh.TRANSFORM_3D
    batch.use_colors = true
    batch.mesh = mesh
    batch.instance_count = transforms.size()
    for i in range(transforms.size()):
        batch.set_instance_transform(i, transforms[i])
        batch.set_instance_color(i, colours[i])
    var tree := MultiMeshInstance3D.new()
    tree.name = "Visual Lab smooth Sakura canopy batch"
    tree.multimesh = batch
    var pink := StandardMaterial3D.new()
    pink.vertex_color_use_as_albedo = true
    pink.roughness = 0.94
    pink.metallic = 0.0
    tree.material_override = pink
    tree.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    lab_props.add_child(tree)

func _show_original_voxel_sakura(restored: bool) -> void:
    for item in _original_voxel_sakura:
        var node: MultiMeshInstance3D = item["node"]
        if is_instance_valid(node):
            node.visible = bool(item["visible"]) if restored else false

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
    _show_original_voxel_sakura(false)
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

## User-tested portrait layout: readable modal, large tap targets and only 3 tabs.
## Never overlay the driving HUD by default.
func _make_panel() -> void:
    STYLE.ensure_fonts()
    lab_layer = CanvasLayer.new()
    lab_layer.name = "Visual Lab mobile controls"
    lab_layer.layer = 25
    add_child(lab_layer)
    var root := Control.new()
    root.name = "Visual Lab responsive UI"
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    lab_layer.add_child(root)
    _panel_toggle = _ui_button(root, "LAB #37", func(): _set_panel_open(true), 54.0, 22.0, true)
    _panel_toggle.name = "Open Visual Lab controls"
    _panel_toggle.size_flags_horizontal = Control.SIZE_SHRINK_END
    _panel_dim = ColorRect.new()
    _panel_dim.name = "Modal scrim"
    _panel_dim.color = Color(0.01, 0.01, 0.025, 0.68)
    _panel_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _panel_dim.mouse_filter = Control.MOUSE_FILTER_STOP
    root.add_child(_panel_dim)
    panel = PanelContainer.new()
    panel.name = "Visual Lab settings, three tabs"
    panel.mouse_filter = Control.MOUSE_FILTER_STOP
    var skin := STYLE.modal_box(1.0)
    skin.bg_color = Color(0.035, 0.042, 0.065, 0.985)
    skin.set_content_margin_all(16)
    panel.add_theme_stylebox_override("panel", skin)
    root.add_child(panel)
    var shell := VBoxContainer.new()
    shell.add_theme_constant_override("separation", 12)
    panel.add_child(shell)
    var header := HBoxContainer.new()
    header.add_theme_constant_override("separation", 10)
    shell.add_child(header)
    mode_label = _ui_label(header, "", 26.0, Color.html("#F5C343"), true)
    mode_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _ui_button(header, "CLOSE ×", func(): _set_panel_open(false), 54.0, 18.0)
    status_label = _ui_label(shell, "", 17.0, Color.html("#E5A2B6"))
    var tab_row := HBoxContainer.new()
    tab_row.add_theme_constant_override("separation", 8)
    shell.add_child(tab_row)
    for key in ["STYLE", "LIGHTS", "TOOLS"]:
        var tab_name: String = key
        _tabs[key] = _ui_button(tab_row, key, func(): _set_tab(tab_name), 60.0, 21.0)
    var scroll := ScrollContainer.new()
    scroll.name = "Scrollable settings"
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    shell.add_child(scroll)
    var holder := VBoxContainer.new()
    holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(holder)
    for key in ["STYLE", "LIGHTS", "TOOLS"]:
        var pg := VBoxContainer.new()
        pg.name = key + " controls"
        pg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        pg.add_theme_constant_override("separation", 12)
        holder.add_child(pg)
        _pages[key] = pg
    var styles: VBoxContainer = _pages["STYLE"]
    _ui_label(styles, "Compare car and world independently.", 18.0, STYLE.MUTED)
    _controls["car"] = _ui_button(styles, "CAR STYLE • A", func():
        vehicle_style = "C" if vehicle_style == "A" else "A"
        _apply_presets())
    _controls["world"] = _ui_button(styles, "WORLD STYLE • A", func():
        environment_style = "C" if environment_style == "A" else "A"
        _apply_presets())
    _controls["time"] = _ui_button(styles, "TIME • DAY", func():
        time_of_day = "SUNSET" if time_of_day == "DAY" else ("NIGHT" if time_of_day == "SUNSET" else "DAY")
        _apply_presets())
    _controls["camera"] = _ui_button(styles, "CAMERA • TOP-DOWN", func():
        _set_camera(0 if int(race.get("camera_mode")) == 1 else 1))
    _ui_button(styles, "RESET • AA / DAY", func():
        vehicle_style = "A"
        environment_style = "A"
        time_of_day = "DAY"
        automatic_lights = true
        manual_lights = false
        brake_test = false
        handbrake_test = false
        _apply_presets())
    var lights: VBoxContainer = _pages["LIGHTS"]
    _ui_label(lights, "AUTO headlights follow the time of day.", 18.0, STYLE.MUTED)
    _controls["mode"] = _ui_button(lights, "HEADLIGHTS • AUTO", func():
        automatic_lights = not automatic_lights
        _update_lamps()
        _refresh_panel_text())
    _controls["manual"] = _ui_button(lights, "MANUAL LIGHTS • OFF", func():
        manual_lights = not manual_lights
        _update_lamps()
        _refresh_panel_text())
    _controls["brake"] = _ui_button(lights, "BRAKE TEST • OFF", func():
        brake_test = not brake_test
        _update_lamps()
        _refresh_panel_text())
    _controls["handbrake"] = _ui_button(lights, "HANDBRAKE TEST • OFF", func():
        handbrake_test = not handbrake_test
        _update_lamps()
        _refresh_panel_text())
    var tools_page: VBoxContainer = _pages["TOOLS"]
    stats = _ui_label(tools_page, "", 18.0, Color.html("#EAE4D6"))
    _ui_button(tools_page, "SAVE SCREENSHOT", func(): _screenshot("manual"))
    _ui_button(tools_page, "CAPTURE ALL 24 VIEWS", _capture_matrix)
    _ui_button(tools_page, "RESTORE ORIGINAL LOOK", _restore_production)
    _ui_button(tools_page, "RETURN TO MENU", func():
        get_tree().change_scene_to_file("res://scenes/boot.tscn"))
    _ui_button(shell, "CLOSE PANEL • DRIVE", func(): _set_panel_open(false), 62.0, 21.0, true)
    _set_tab("STYLE")
    _set_panel_open(false)
    get_viewport().size_changed.connect(_layout_panel)
    _layout_panel()

static func panel_geometry(screen: Vector2) -> Rect2:
    var portrait: bool = screen.y > screen.x
    var w: float = screen.x * (0.94 if portrait else 0.68)
    var h: float = screen.y * (0.82 if portrait else 0.90)
    if not portrait:
        w = minf(w, 780.0)
    return Rect2(Vector2((screen.x-w)*0.5, (screen.y-h)*0.5), Vector2(w,h))

func _layout_panel() -> void:
    if panel == null or _panel_toggle == null:
        return
    var screen: Vector2 = get_viewport().get_visible_rect().size
    var portrait: bool = screen.y > screen.x
    _ui_scale = clampf(minf(screen.x/(700.0 if portrait else 1050.0),
        screen.y/(1450.0 if portrait else 700.0)),1.0,1.35)
    var r: Rect2 = panel_geometry(screen)
    panel.position = r.position
    panel.size = r.size
    var tw: float = 166.0 * _ui_scale
    _panel_toggle.position = Vector2(screen.x-tw-14.0,screen.y*0.27 if portrait else 14.0)
    _panel_toggle.size = Vector2(tw,54.0*_ui_scale)
    for b in _ui_buttons:
        if is_instance_valid(b):
            b.custom_minimum_size.y = float(b.get_meta("base_h",68.0))*_ui_scale
            b.add_theme_font_size_override("font_size",maxi(18,roundi(float(b.get_meta("base_font",22.0))*_ui_scale)))
            STYLE.style_button(b,_ui_scale,bool(b.get_meta("selected",false)))
    for lbl in _ui_labels:
        if is_instance_valid(lbl):
            lbl.add_theme_font_size_override("font_size",maxi(17,roundi(float(lbl.get_meta("base_font",18.0))*_ui_scale)))

func _set_panel_open(opened: bool) -> void:
    panel.visible = opened
    _panel_dim.visible = opened
    _panel_toggle.visible = not opened

func _set_tab(tab: String) -> void:
    for key in _pages:
        var active: bool = key == tab
        var page: VBoxContainer = _pages[key]
        page.visible = active
        var button: Button = _tabs[key]
        button.set_meta("selected",active)
        STYLE.style_button(button,_ui_scale,active)

func _ui_label(parent: Node, value: String, size: float, color: Color, bold: bool = false) -> Label:
    var lbl := Label.new()
    lbl.text = value
    lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    lbl.add_theme_font_override("font",STYLE.BOLD if bold else STYLE.SEMI)
    lbl.add_theme_color_override("font_color",color)
    lbl.add_theme_font_size_override("font_size",int(size))
    lbl.set_meta("base_font",size)
    parent.add_child(lbl)
    _ui_labels.append(lbl)
    return lbl

func _ui_button(parent: Node, caption: String, callback: Callable,
        height: float = 68.0, size: float = 22.0, active: bool = false) -> Button:
    var b := Button.new()
    b.text = caption
    b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    b.custom_minimum_size.y = height
    b.add_theme_font_size_override("font_size",int(size))
    b.set_meta("base_h",height)
    b.set_meta("base_font",size)
    b.set_meta("selected",active)
    STYLE.style_button(b,1.0,active)
    b.pressed.connect(callback)
    parent.add_child(b)
    _ui_buttons.append(b)
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
    _show_original_voxel_sakura(true)
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
    var mode: String = "ORIGINAL" if _is_restored else vehicle_style + environment_style + " / " + time_of_day
    mode_label.text = "VISUAL LAB • " + mode
    status_label.text = ("FUJI TRACK DATA AVAILABLE" if fuji_available
        else "SHIN-KAWA PROXY — NOT FUJI") + "\nPLACEHOLDER CAR — NOT AE86"
    var fps: float = float(Engine.get_frames_per_second())
    var draw_calls: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
    var renderer: String = str(ProjectSettings.get_setting("rendering/renderer/rendering_method","unknown"))
    stats.text = "FPS %.0f  •  FRAME %.1f ms\nDRAW CALLS %d  •  %s\nHEADLIGHTS %s  •  MANUAL %s\nBRAKE %s  •  HANDBRAKE %s\n%s" % [
        fps,1000.0/maxf(fps,1.0),draw_calls,renderer,
        "AUTO" if automatic_lights else "MANUAL","ON" if manual_lights else "OFF",
        "ON" if brake_test else "OFF","ON" if handbrake_test else "OFF",
        "CAPTURING 24 VIEWS" if _capturing else "Check FPS on a real phone"]
    if _controls.is_empty():
        return
    (_controls["car"] as Button).text = "CAR STYLE • " + vehicle_style
    (_controls["world"] as Button).text = "WORLD STYLE • " + environment_style
    (_controls["time"] as Button).text = "TIME • " + time_of_day
    (_controls["camera"] as Button).text = "CAMERA • " + ("CHASE" if int(race.get("camera_mode")) == 1 else "TOP-DOWN")
    (_controls["mode"] as Button).text = "HEADLIGHTS • " + ("AUTO" if automatic_lights else "MANUAL")
    (_controls["manual"] as Button).text = "MANUAL LIGHTS • " + ("ON" if manual_lights else "OFF")
    (_controls["brake"] as Button).text = "BRAKE TEST • " + ("ON" if brake_test else "OFF")
    (_controls["handbrake"] as Button).text = "HANDBRAKE TEST • " + ("ON" if handbrake_test else "OFF")

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
