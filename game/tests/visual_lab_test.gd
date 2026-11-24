extends SceneTree
## Issue #37: real scene runtime smoke + fixed-camera matrix capture.
## Requires a real display context (Xvfb works); NOT a phone GPU benchmark.
const LAB = preload("res://scenes/visual_lab.tscn")

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    printerr("FAIL: Visual Lab #37: " + message)
    quit(1)

func _frames(n: int) -> void:
    for _i in range(n):
        await process_frame

func _run() -> void:
    var selected: Variant = ProjectSettings.get_setting("nitro/selected_track", "res://tracks/shin_kawa_v2.json")
    ProjectSettings.set_setting("nitro/selected_track", "res://tracks/shin_kawa_v2.json")
    var lab: NitroVisualLab = LAB.instantiate() as NitroVisualLab
    if lab == null:
        _fail("cannot instantiate visual lab scene")
        return
    root.add_child(lab)
    await _frames(20)
    if lab.race == null or lab.vehicle == null or lab.track == null or lab.materials == null:
        _fail("race, track, vehicle or material capture missing")
        return
    if lab.fuji_available:
        _fail("unexpected Fuji track present; verify actual circuit before proxy QA")
        return
    if lab._headlights.size() != 2:
        _fail("headlights must be two independent vehicle-attached spots")
        return
    if not lab._headlights[0].get_parent() == lab.vehicle:
        _fail("headlight isn't attached to visual vehicle")
        return
    var track_points: Array = lab.track.get("centerline")
    var baseline_first: Vector2 = track_points[0]
    var baseline_count: int = track_points.size()
    var baseline_position: Vector2 = lab.race.model.position
    var baseline_heading: float = lab.race.model.heading
    lab.race.set_physics_process(false)
    lab.race.set_process(false)
    var folder: String = OS.get_environment("OUT_DIR")
    var do_screenshots: bool = folder != ""
    var evidence_count: int = 0
    if do_screenshots:
        DirAccess.make_dir_recursive_absolute(folder)
    for vehicle_style in ["A", "C"]:
        for world_style in ["A", "C"]:
            for time_label in ["DAY", "SUNSET", "NIGHT"]:
                lab.vehicle_style = vehicle_style
                lab.environment_style = world_style
                lab.time_of_day = time_label
                lab._apply_presets()
                if not lab._headlights[0].visible == (time_label == "NIGHT"):
                    _fail("automatic headlights disagree with " + time_label)
                    return
                for camera_idx in [0, 1]:
                    lab._set_camera(camera_idx)
                    lab.race.call("_snap_cameras")
                    lab.lab_layer.visible = false
                    await _frames(8)
                    var active_cam: Camera3D = lab.race.get_viewport().get_camera_3d()
                    if active_cam == null:
                        _fail("no active 3D camera")
                        return
                    if do_screenshots:
                        var name: String = "%s%s_%s_%s.png" % [
                            vehicle_style, world_style, time_label,
                            "TOP" if camera_idx == 0 else "CHASE"]
                        var image: Image = root.get_viewport().get_texture().get_image()
                        var err: Error = image.save_png(folder.trim_suffix("/") + "/" + name)
                        if err != OK:
                            _fail("cannot save screenshot " + name + " (" + str(err) + ")")
                            return
                        evidence_count += 1
    if track_points.size() != baseline_count or track_points[0] != baseline_first:
        _fail("track geometry changed during style comparison")
        return
    if lab.race.model.position != baseline_position or lab.race.model.heading != baseline_heading:
        _fail("vehicle state reset during style comparison")
        return
    lab.lab_layer.visible = true
    lab.automatic_lights = false
    lab.manual_lights = false
    lab._update_lamps()
    if lab._headlights[0].visible:
        _fail("manual headlights OFF still visible")
        return
    lab.manual_lights = true
    lab._update_lamps()
    if not lab._headlights[0].visible:
        _fail("manual headlights ON not visible")
        return
    lab.manual_lights = false
    Input.action_press("brake")
    lab._update_lamps()
    if lab._brake.emission_energy_multiplier < 2.0:
        _fail("brake input did not brighten rear brake light")
        return
    Input.action_release("brake")
    Input.action_press("handbrake")
    lab._update_lamps()
    if lab._brake.emission_energy_multiplier < 2.0:
        _fail("handbrake input did not brighten rear brake light")
        return
    Input.action_release("handbrake")
    lab._restore_production()
    if lab.lab_props.visible or lab._headlights[0].visible:
        _fail("restore originals left experimental geometry or lights enabled")
        return
    lab.queue_free()
    await _frames(3)
    if ProjectSettings.get_setting("nitro/selected_track") != selected:
        _fail("lab did not restore selected track setting")
        return
    print("PASS: Visual Lab #37 12 independent material/light combinations; 2 cameras; state/geometry preserved; functional lamps; restore")
    if do_screenshots:
        if evidence_count != 24:
            _fail("expected 24 snapshots; got %d" % evidence_count)
            return
        print("PASS: 24 preview PROXY screenshots saved to " + folder)
    print("NOT RUN: exact Fuji track, AE86, real handset, native desktop interactive play, browser GPU, physical FPS")
    quit(0)
