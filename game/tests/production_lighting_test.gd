extends SceneTree
## Normal race scene, live Park switches and actual input actions.
const TIME = preload("res://scripts/lighting/time_of_day.gd")
const LAMPS = preload("res://scripts/lighting/car_lamps.gd")
const PROTOCOL = preload("res://scripts/net/net_protocol.gd")
const RACE = preload("res://scenes/race.tscn")
const BOOT = preload("res://scenes/boot.tscn")
var failures := PackedStringArray()

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    if not ok:
        failures.append(message)

func _run() -> void:
    _check(TIME.selected() == TIME.Preset.DAY, "new race defaults to DAY")
    ProjectSettings.set_setting("nitro/car_variant", "white")
    ProjectSettings.set_setting("nitro/park_mode", "free")
    ProjectSettings.set_setting("nitro/selected_track", PROTOCOL.PARK_PATH)
    var race = RACE.instantiate()
    root.add_child(race)
    race.set_physics_process(false)
    var original_weather: Environment = race.race_environment._world.environment
    var original_pos: Vector2 = race.model.position
    var original_yaw: float = race.model.heading
    var original_cone: Vector2 = race.park.cones.positions[0] + Vector2(0.9, -0.45)
    race.park.cones.positions[0] = original_cone
    var prop: MeshInstance3D = race.park.stunts.visuals[3]
    prop.position += Vector3(0.8, 0, 0.7)
    var original_prop := prop.position
    race.park.damage.mounts[0] = 1
    race.park.damage.parts[0].set_mounts(1)
    var bumper: MeshInstance3D = race.park.damage.parts[0].mesh
    var bumper_pose := bumper.transform
    race._toggle_camera()
    race._toggle_pause()
    var picker: HBoxContainer = race.pause_menu.find_child("TIME OF DAY", true, false)
    var modes: HBoxContainer = race.pause_menu.find_child("VEHICLE LIGHTS", true, false)
    _check(picker != null and modes != null, "Park pause contains both selectors")
    if picker != null:
        for preset in [TIME.Preset.DAWN,TIME.Preset.GOLDEN_HOUR,TIME.Preset.DAY,TIME.Preset.NIGHT]:
            (picker.get_node(TIME.LABELS[preset]) as Button).pressed.emit()
            _check(race.time_of_day == preset and race.lamps.spots[0].visible == TIME.requires_headlights(preset),
                "Park changes live and AUTO follows " + TIME.LABELS[preset])
            var day: bool = preset == TIME.Preset.DAY
            _check((race.race_environment._world.environment == original_weather) == day, "original DAY environment restored")
            _check(race.model.position == original_pos and race.model.heading == original_yaw and race.camera_mode == 1,
                "preset keeps current pose and camera")
            _check(race.park.cones.positions[0] == original_cone and prop.position == original_prop and
                race.park.damage.mounts[0] == 1 and bumper.transform == bumper_pose,
                "preset keeps displaced cones, cardboard and bumper")
    var road := race.track.get_node("Nitro Wheelz Park paving") as MeshInstance3D
    _check(road.material_override is ShaderMaterial and race.track.find_child("Site asphalt", true, false).material_override is ShaderMaterial,
        "Park plaza and circuit pavement receive real lights")
    if modes != null:
        (modes.get_node("OFF") as Button).pressed.emit()
        _check(race.lamps.bits == 0, "manual OFF overrides NIGHT")
        (modes.get_node("ON") as Button).pressed.emit()
        _check(race.lamps.bits == LAMPS.POSITION, "manual ON works immediately in pause")
    race._toggle_pause()
    for preset in TIME.LABELS.size():
        race._request_park_time_of_day(preset)
        for mode in LAMPS.MODE_LABELS.size():
            race._set_lamp_mode(mode)
            var position := LAMPS.POSITION if mode == LAMPS.Mode.ON or (mode == LAMPS.Mode.AUTO and TIME.requires_headlights(preset)) else 0
            Input.action_press("brake")
            race._read_lamps()
            _check(race.lamps.bits == (position | LAMPS.BRAKING), "BRAKE works in all presets and modes")
            Input.action_press("handbrake")
            race._read_lamps()
            Input.action_release("brake")
            race._read_lamps()
            _check(race.lamps.bits == (position | LAMPS.BRAKING), "handbrake remains lit after brake release")
            Input.action_release("handbrake")
            race._read_lamps()
            _check(race.lamps.bits == position, "release restores normal lamp state")
    race.touch.show()
    race.touch.brake = 1.0
    race._read_lamps()
    _check((race.lamps.bits & LAMPS.BRAKING) != 0, "touch brake")
    race.touch.brake = 0.0
    race.touch.handbrake = 1.0
    race._read_lamps()
    _check((race.lamps.bits & LAMPS.BRAKING) != 0, "touch handbrake")
    race.touch.release_all()
    race._read_lamps()
    race.model.heading = 1.2
    race.model.velocity = Vector2(0, 12)
    race._set_lamp_mode(LAMPS.Mode.ON)
    race._update_visuals()
    var beam: SpotLight3D = race.lamps.spots[0]
    var forward := -beam.global_basis.z.normalized()
    _check(Vector2(forward.x,forward.z).normalized().dot(race.model.forward()) > 0.99,
        "beam follows body instead of sideways velocity")
    _check(beam.spot_range == LAMPS.RANGE and is_equal_approx(beam.light_energy, LAMPS.LAB_ENERGY * 8.0) and not beam.shadow_enabled,
        "light calibration and no per-lamp shadow")
    race.queue_free()
    await process_frame
    var menu = BOOT.instantiate()
    root.add_child(menu)
    menu.navigate_enabled = false
    menu.show_page("setup")
    var setup_picker: HBoxContainer = menu.find_child("Time of day", true, false)
    _check(setup_picker != null and setup_picker.get_child_count() == 4, "setup has four options")
    if setup_picker != null:
        (setup_picker.get_node("GOLDEN HOUR") as Button).pressed.emit()
    menu.queue_free()
    ProjectSettings.set_setting("nitro/selected_track", PROTOCOL.TRACKS[0])
    race = RACE.instantiate()
    root.add_child(race)
    _check(race.time_of_day == TIME.Preset.GOLDEN_HOUR and race.park == null, "ordinary circuit uses setup preset")
    race._toggle_pause()
    _check(race.pause_menu.find_child("TIME OF DAY", true, false) == null, "competitive time remains locked")
    _check(race.pause_menu.find_child("VEHICLE LIGHTS", true, false) != null, "competitive light override available")
    race.queue_free()
    _check(PROTOCOL.validate_control({"t":PROTOCOL.Msg.PARK_TIME,"round":2,"tod":TIME.Preset.NIGHT}) == "", "valid shared preset")
    _check(PROTOCOL.validate_control({"t":PROTOCOL.Msg.PARK_TIME,"round":2,"tod":-1}) != "", "out-of-range shared preset rejected")
    _check(PROTOCOL.validate_control({"t":PROTOCOL.Msg.PARK_TIME,"round":2,"tod":3.0}) != "", "non-integer shared preset rejected")
    await process_frame
    if failures.is_empty():
        print("PASS: time of day, real Park road materials, lamp modes, hardware/touch brake inputs, Park state and race setup")
        quit(0)
    else:
        printerr("FAIL: " + "; ".join(failures))
        quit(1)
