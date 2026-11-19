extends Node3D
## Nitro Wheelz v0.1 driving laboratory: one original Japanese-style circuit.
## Authoritative vehicle state is planar; camera/visuals never modify the physics.

const TRACK = preload("res://scripts/world/drift_track.gd")
const DRIVE = preload("res://scripts/driving/drive_model.gd")
const HUD = preload("res://scripts/ui/race_hud.gd")
const RESULTS = preload("res://scripts/ui/race_results.gd")
const TOUCH = preload("res://scripts/ui/race_touch.gd")
const PAUSE_VIEW = preload("res://scripts/ui/race_pause.gd")
const LADA = preload("res://scripts/vehicles/lada_lowpoly.gd")
const AUDIO = preload("res://scripts/audio/drive_audio.gd")

var model: NitroDriveModel
var sfx: NitroDriveAudio
var track: NitroDriftTrack
var car_root: Node3D
var front_wheels: Array[Node3D] = []
var overhead: Camera3D
var chase: Camera3D
var touch: NitroRaceTouch
var hud: NitroRaceHUD
var pause_layer: CanvasLayer
var results_layer: CanvasLayer
var results_open: bool = false
var camera_mode: int = 0
var time_elapsed: float = 0.0
var race_started: bool = false
var lap: int = 1
var last_progress: float = 0.0
var lap_started_at: float = 0.0
var lap_score: int = 0
var active_drift_points: int = 0
var combo: float = 1.0
var combo_timer: float = 0.0
var paused: bool = false
var finished: bool = false
var offroad: bool = false
var collision_cooldown: float = 0.0
var camera_shake_strength: float = 0.0
var camera_shake_phase: float = 0.0
var camera_velocity_lead: Vector3 = Vector3.ZERO
var drone_direction: Vector3 = Vector3(0.0,0.0,-1.0)
var chase_occlusion_point: Vector3 = Vector3.ZERO
var chase_is_blocked: bool = false
const CAMERA_LOOKAHEAD_SECONDS: float = 0.45
const CAMERA_LEAD_MAX_METRES: float = 19.0
const OVERHEAD_BASE_PORTRAIT: float = 46.0
const OVERHEAD_BASE_LANDSCAPE: float = 58.0
const OVERHEAD_FRAMING_PORTRAIT: float = 0.11
const VIGNETTE_SHADER = preload("res://assets/shaders/night_vignette.gdshader")
var wall_collision_count: int = 0
var tyre_smoke: Array[CPUParticles3D] = []

var skid_mesh: ImmediateMesh
var skid_material: StandardMaterial3D
var skid_segments: Array[PackedVector2Array] = []
var last_left: Vector2 = Vector2.ZERO
var last_right: Vector2 = Vector2.ZERO
var had_skid: bool = false
var skid_clock: float = 0.0

func _ready() -> void:
    track = TRACK.new()
    track.track_data_path = str(ProjectSettings.get_setting(
        "nitro/selected_track",TRACK.TRACK_DATA))
    track.name = "Nitro Track DNA"
    add_child(track)
    if not track.track_valid:
        push_error("Selected benchmark track invalid: "+track.track_data_path)
        return
    model = DRIVE.new()
    model.reset(track.start_position(),track.start_heading())
    _make_car()
    sfx = AUDIO.new()
    sfx.name = "Layered WAN SFX"
    add_child(sfx)
    _make_cameras()
    _make_tyre_marks()
    _make_ui()
    last_progress = float(track.sample_info(model.position)["progress"])
    _update_visuals()

func _make_car() -> void:
    # Visual-only original low-poly car. The driving model owns physics.
    car_root = LADA.new()
    car_root.name = "Nitro Wheelz VAZ-2106 drift spec"
    (car_root as NitroLadaLowPoly).paint_variant = str(ProjectSettings.get_setting(
        "nitro/car_variant","red"))
    add_child(car_root)
    _make_tyre_smoke()

func _make_tyre_smoke() -> void:
    # Restrained white tyre smoke from both rear wheels while sliding.
    # CPU particles keep GL Compatibility / Android support predictable.
    var puff := GradientTexture2D.new()
    var ramp := Gradient.new()
    ramp.set_color(0,Color(1,1,1,1))
    ramp.set_color(1,Color(1,1,1,0))
    puff.gradient = ramp
    puff.fill = GradientTexture2D.FILL_RADIAL
    puff.fill_from = Vector2(0.5,0.5)
    puff.fill_to = Vector2(1.0,0.5)
    puff.width = 64
    puff.height = 64
    var mat := StandardMaterial3D.new()
    mat.albedo_texture = puff
    mat.vertex_color_use_as_albedo = true
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
    mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
    var quad := QuadMesh.new()
    quad.size = Vector2(1.0,1.0)
    quad.material = mat
    var fade := Gradient.new()
    fade.set_color(0,Color(0.92,0.92,0.98,0.42))
    fade.set_color(1,Color(0.80,0.80,0.90,0.0))
    var grow := Curve.new()
    grow.add_point(Vector2(0.0,0.9))
    grow.add_point(Vector2(1.0,3.4))
    for side in [-1.0,1.0]:
        var smoke := CPUParticles3D.new()
        smoke.name = "Tyre smoke "+("left" if side < 0.0 else "right")
        smoke.mesh = quad
        smoke.amount = 36
        smoke.lifetime = 1.15
        smoke.local_coords = false
        smoke.emitting = false
        smoke.direction = Vector3(0.0,0.6,1.0)
        smoke.spread = 35.0
        smoke.initial_velocity_min = 0.6
        smoke.initial_velocity_max = 1.8
        smoke.gravity = Vector3(0.0,0.35,0.0)
        smoke.damping_min = 0.8
        smoke.damping_max = 1.4
        smoke.scale_amount_min = 0.9
        smoke.scale_amount_max = 1.4
        smoke.scale_amount_curve = grow
        smoke.color_ramp = fade
        smoke.position = Vector3(side*0.80,0.30,1.25)
        smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        car_root.add_child(smoke)
        tyre_smoke.append(smoke)

func _make_cameras() -> void:
    overhead = Camera3D.new()
    overhead.name = "Elevated drone follow"
    overhead.projection = Camera3D.PROJECTION_ORTHOGONAL
    overhead.size = 80.0
    overhead.current = true
    add_child(overhead)
    chase = Camera3D.new()
    chase.name = "Behind car"
    chase.fov = 78.0
    chase.current = false
    add_child(chase)
    _update_camera(1.0)

func _make_tyre_marks() -> void:
    skid_mesh = ImmediateMesh.new()
    skid_material = StandardMaterial3D.new()
    skid_material.albedo_color = Color(0.02,0.02,0.03,0.50)
    skid_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    skid_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    skid_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    var marks := MeshInstance3D.new()
    marks.name = "Persistent skid marks"
    marks.mesh = skid_mesh
    marks.material_override = skid_material
    add_child(marks)

func _make_ui() -> void:
    # Night atmosphere: soft violet vignette under the HUD.
    var mood := CanvasLayer.new()
    mood.layer = 2
    mood.name = "Night vignette"
    add_child(mood)
    var vignette := ColorRect.new()
    vignette.name = "Vignette"
    vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var vmat := ShaderMaterial.new()
    vmat.shader = VIGNETTE_SHADER
    vignette.material = vmat
    mood.add_child(vignette)
    vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var overlay := CanvasLayer.new()
    overlay.layer = 4
    overlay.name = "Race HUD"
    add_child(overlay)
    hud = HUD.new()
    hud.name = "Lap / Speed / Score"
    overlay.add_child(hud)
    hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    hud.track_name = "SHIN-KAWA" if track.track_id=="shin_kawa_v2" else (
        "FULL CIRCUIT" if track.track_id=="shin_kawa_full_circuit" else track.display_name)
    hud.track_points = PackedVector2Array(track.centerline)
    hud.track_id = track.track_id
    # Same provisional local target as the finish screen uses, so the HUD
    # chasing-time stars and the result stars always agree.
    hud.target_time = 75.0 if track.track_id=="benchmark_oval" else (
        90.0 if track.track_id=="benchmark_sweepers" else track.length_metres*3.0/14.0)

    var touch_layer := CanvasLayer.new()
    touch_layer.layer = 6
    touch_layer.name = "Multitouch controls"
    add_child(touch_layer)
    touch = TOUCH.new()
    touch.name = "Steering / Drift / Brake / Gas"
    touch_layer.add_child(touch)
    touch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    touch.visible = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
    touch.camera_requested.connect(_toggle_camera)
    touch.pause_requested.connect(_toggle_pause)
    touch.restart_requested.connect(_restart)
    touch.menu_requested.connect(func():get_tree().change_scene_to_file("res://scenes/boot.tscn"))

func _physics_process(delta: float) -> void:
    if paused or finished:
        return
    collision_cooldown = maxf(0.0,collision_cooldown-delta)

    var steer: float = Input.get_axis("steer_left","steer_right")
    var gas: float = Input.get_action_strength("throttle")
    var braking: float = Input.get_action_strength("brake")
    var handbrake: float = Input.get_action_strength("handbrake")
    if touch != null and touch.visible:
        if touch.active_joystick:
            steer = touch.steer
        gas = maxf(gas,touch.throttle)
        braking = maxf(braking,touch.brake)
        handbrake = maxf(handbrake,touch.handbrake)

    # Race clock starts only on the first throttle input.
    if not race_started and gas > 0.05:
        race_started = true
    if race_started:
        time_elapsed += delta

    # Fixed 120 Hz Godot tick and two internal model substeps (240 Hz).
    model.step(delta*0.5,steer,gas,braking,handbrake)
    model.step(delta*0.5,steer,gas,braking,handbrake)

    # Resolve physical contact against the SAME raised wall shown on screen.
    # Never drive through the wall into sand and then teleport back.
    var collision: Dictionary = track.resolve_wall(model.position,model.velocity)
    if bool(collision["hit"]):
        model.position = Vector2(collision["position"])
        model.velocity = Vector2(collision["velocity"])
        model.yaw_rate *= 0.35
        model.slide_hold = 0.0
        model.rear_traction = maxf(model.rear_traction,0.80)
        had_skid = false
        if float(collision["impact_speed"]) > 1.2:
            _wall_feedback(float(collision["impact_speed"]))
    var info: Dictionary = track.sample_info(model.position)
    offroad = false
    if sfx != null:
        sfx.drive_tick(model.speed_kmh(),model.drift_angle,gas,handbrake,offroad,delta)
        if absf(float(info["distance"])-float(info["width"])) < 0.75:
            sfx.kerb_event(model.speed_kmh())

    _update_chase_occlusion()
    _lap_logic(float(info["progress"]),Vector2(info["tangent"]),delta)
    _drift_scoring(delta)
    _record_marks(delta)
    _update_visuals()
    if finished and not results_open:
        _show_results()

func _show_results() -> void:
    # Separate full-screen result presentation. Never stack the old pause
    # popup, HUD and touch controls underneath the finish buttons.
    results_open = true
    if sfx != null:
        sfx.silence()
    if hud != null:
        hud.visible = false
    if touch != null:
        touch.release_all()
        touch.visible = false
        touch.set_process_input(false)
    results_layer = CanvasLayer.new()
    results_layer.layer = 24
    results_layer.name = "Finish results and local leaderboard"
    add_child(results_layer)
    var view: NitroRaceResults = RESULTS.new()
    results_layer.add_child(view)
    var target: float = float(hud.target_time) if hud != null else 0.0
    if target <= 0.0:
        # Uncalibrated courses use provisional local practice tiers.
        target = track.length_metres*3.0/14.0
    view.show_race(track.track_id,track.display_name,time_elapsed,lap_score,target,
        Callable(self,"_restart"),func(): get_tree().change_scene_to_file("res://scenes/boot.tscn"))

func _wall_feedback(impact_speed: float) -> void:
    if collision_cooldown > 0.0:
        return
    collision_cooldown = 0.35
    wall_collision_count += 1
    if sfx != null:
        sfx.wall_event(impact_speed)
    camera_shake_strength = clampf(impact_speed*0.035,0.16,0.43)
    # On Android Godot requires the VIBRATE export permission. The user may
    # disable vibrations in system accessibility settings.
    if OS.has_feature("mobile"):
        Input.vibrate_handheld(100,clampf(impact_speed/17.0,0.3,0.75))
    var joypads: Array[int] = Input.get_connected_joypads()
    if not joypads.is_empty():
        Input.start_joy_vibration(joypads[0],0.20,0.42,0.14)

func _lap_logic(progress: float, tangent: Vector2, _delta: float) -> void:
    # Count only a forward finish-line crossing after sufficient driving time.
    if last_progress > 0.94 and progress < 0.06 and time_elapsed-lap_started_at > 7.0:
        if model.velocity.dot(tangent) > 1.5:
            lap += 1
            lap_started_at = time_elapsed
            combo = 1.0
            if lap > 3:
                lap = 3
                finished = true
                model.velocity = Vector2.ZERO
    last_progress = progress

func _drift_scoring(dt: float) -> void:
    if model.is_drifting() and not offroad:
        var angle_ratio: float = minf(absf(model.drift_angle),75.0)/45.0
        var points: float = model.speed_mps()*pow(angle_ratio,1.2)*combo*dt*3.0
        var gain: int = int(maxf(points,0.0)*10.0)
        lap_score += gain
        active_drift_points += gain
        combo_timer += dt
        if combo_timer > 1.8:
            combo = minf(5.0,combo+0.1)
            combo_timer = 0.0
    elif offroad:
        active_drift_points = 0
        combo = 1.0
        combo_timer = 0.0
    else:
        if not model.is_drifting():
            active_drift_points = 0
        combo_timer = maxf(combo_timer-dt,0.0)

func _record_marks(dt: float) -> void:
    skid_clock += dt
    if skid_clock < 0.07:
        return
    skid_clock = 0.0
    if not model.is_drifting() or offroad:
        had_skid = false
        return
    var p: Vector2 = model.position-model.forward()*1.22
    var left_p: Vector2 = p-model.right()*0.72
    var right_p: Vector2 = p+model.right()*0.72
    if had_skid:
        skid_segments.append(PackedVector2Array([last_left,left_p]))
        skid_segments.append(PackedVector2Array([last_right,right_p]))
        while skid_segments.size()>700:
            skid_segments.pop_front()
        _refresh_skid_mesh()
    last_left = left_p
    last_right = right_p
    had_skid = true

func _refresh_skid_mesh() -> void:
    skid_mesh.clear_surfaces()
    if skid_segments.is_empty():
        return
    skid_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES,skid_material)
    for line in skid_segments:
        var a: Vector2 = line[0]
        var b: Vector2 = line[1]
        var delta: Vector2 = b-a
        if delta.length_squared() < 0.0001:
            continue
        var n: Vector2 = Vector2(-delta.y,delta.x).normalized()*0.15
        for p in [a-n,b-n,a+n,a+n,b-n,b+n]:
            skid_mesh.surface_set_normal(Vector3.UP)
            skid_mesh.surface_add_vertex(Vector3(p.x,0.08,p.y))
    skid_mesh.surface_end()

func _update_visuals() -> void:
    if car_root == null:
        return
    car_root.position = Vector3(model.position.x,0.0,model.position.y)
    # Physics +heading turns toward +X; Godot +Y turns local -Z toward -X.
    car_root.rotation.y = -model.heading
    var smoking: bool = model.is_drifting() and model.speed_kmh() > 18.0 and not paused and not finished
    for smoke in tyre_smoke:
        smoke.emitting = smoking
    if car_root is NitroLadaLowPoly:
        (car_root as NitroLadaLowPoly).set_motion(model.steering_angle, model.signed_forward_speed_mps(), get_physics_process_delta_time())
    if hud != null:
        hud.race_time = time_elapsed
        hud.car_world_position = model.position
        hud.track_progress = float(track.sample_info(model.position)["progress"])
        hud.lap = lap
        hud.speed = model.speed_kmh()
        hud.reversing = model.is_reversing()
        hud.drift_degrees = model.drift_angle
        hud.score = lap_score
        hud.drift_score = active_drift_points
        hud.combo = combo
        hud.mode = "TOP-DOWN" if camera_mode == 0 else "CHASE"
        hud.paused = paused
        hud.finished = finished
        hud.road_status = "OFF TRACK" if offroad else "ON TRACK"
    if touch != null:
        touch.overlay_visible = false

func _process(delta: float) -> void:
    camera_shake_strength = move_toward(camera_shake_strength,0.0,delta*1.6)
    camera_shake_phase += delta*36.0
    _update_camera(delta)

func _update_chase_occlusion() -> void:
    # Physics direct-space queries belong in _physics_process only.
    var car: Vector3 = Vector3(model.position.x,0.0,model.position.y)
    var direction2: Vector2 = model.forward()
    var f: Vector3 = Vector3(direction2.x,0.0,direction2.y)
    var speed_t: float = clampf(model.speed_kmh()/120.0,0.0,1.0)
    var desired: Vector3 = car-f*lerpf(16.0,22.0,speed_t) + Vector3.UP*lerpf(9.0,12.0,speed_t)
    var q := PhysicsRayQueryParameters3D.create(car+Vector3.UP*1.4,desired)
    var wall: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
    chase_is_blocked = not wall.is_empty()
    if chase_is_blocked:
        chase_occlusion_point = Vector3(wall["position"])+Vector3(wall["normal"])*0.65

func _zoom_factor_for_speed(kmh: float) -> float:
    # Prototype Camera2D reference converted to orthographic Camera3D size:
    # Camera3D.size = base_size / target_zoom.
    var speed: float = maxf(kmh,0.0)
    if speed <= 20.0:
        return 1.15
    if speed <= 50.0:
        return lerpf(1.15,1.0,(speed-20.0)/30.0)
    if speed <= 90.0:
        return lerpf(1.0,0.82,(speed-50.0)/40.0)
    if speed <= 120.0:
        return lerpf(0.82,0.72,(speed-90.0)/30.0)
    return 0.72

func _camera_lead_target(real_velocity: Vector2) -> Vector3:
    # Use true direction of travel, not where the bonnet is pointing.
    var lead := Vector3(real_velocity.x,0.0,real_velocity.y)*CAMERA_LOOKAHEAD_SECONDS
    return lead.limit_length(CAMERA_LEAD_MAX_METRES)

func _update_camera(delta: float) -> void:
    if model == null or overhead == null or chase == null:
        return
    var car_position: Vector3 = Vector3(model.position.x,0.0,model.position.y)
    var forward_dir: Vector2 = model.forward()
    # Chase direction does not instantly flip when selecting reverse.
    var view_dir: Vector2 = forward_dir
    if model.signed_forward_speed_mps() > 2.0 and model.speed_mps() > 5.0:
        view_dir = forward_dir.lerp(model.velocity.normalized(),0.25).normalized()
    var f: Vector3 = Vector3(view_dir.x,0.0,view_dir.y)
    var portrait: bool = get_viewport().get_visible_rect().size.y > get_viewport().get_visible_rect().size.x
    # v0.1.13: closer framing (approved gameplay reference) so the car reads
    # as a collectible model; speed-responsive zoom still widens the view.
    var base_size: float = OVERHEAD_BASE_PORTRAIT if portrait else OVERHEAD_BASE_LANDSCAPE
    var zoom_target: float = base_size/_zoom_factor_for_speed(model.speed_kmh())
    var zoom_alpha: float = 1.0-exp(-3.3*maxf(delta,0.0))
    overhead.size = lerpf(overhead.size,zoom_target,zoom_alpha)

    var desired_lead: Vector3 = _camera_lead_target(model.velocity)
    var lead_alpha: float = 1.0-exp(-4.2*maxf(delta,0.0))
    camera_velocity_lead = camera_velocity_lead.lerp(desired_lead,lead_alpha)
    var focus: Vector3 = car_position+camera_velocity_lead

    # Drone follow: tilted ~25 degrees off vertical, damped rotation,
    # and extra forward track preview; keeps the car lower in the frame.
    var drone_alpha: float = 1.0-exp(-4.5*maxf(delta,0.0))
    drone_direction = drone_direction.lerp(f,drone_alpha).normalized()
    var overhead_target: Vector3 = focus-drone_direction*31.0+Vector3.UP*76.0
    var pan_alpha: float = 1.0-exp(-5.0*maxf(delta,0.0))
    overhead.position = overhead.position.lerp(overhead_target,pan_alpha)
    # Reduce the old forward look target: the car was pushed beneath pedals.
    overhead.look_at(focus+drone_direction*5.0,Vector3.UP)

    var speed_lerp: float = clampf(model.speed_kmh()/120.0,0.0,1.0)
    var chase_back: float = lerpf(16.0,22.0,speed_lerp)
    var chase_height: float = lerpf(9.0,12.0,speed_lerp)
    var chase_target: Vector3 = car_position-f*chase_back+camera_velocity_lead*0.22+Vector3.UP*chase_height
    var look_target: Vector3 = car_position+f*(2.0 if model.is_reversing() else 7.0)+camera_velocity_lead*0.32+Vector3.UP*0.8
    # A nearby wall must not snap the camera to the bumper.
    if chase_is_blocked:
        var candidate: Vector3 = chase_occlusion_point+Vector3.UP*3.5
        if candidate.distance_to(car_position) > 12.0:
            chase_target = candidate
        else:
            chase_target = car_position-f*chase_back+Vector3.UP*(chase_height+8.0)
    var chase_alpha: float = 1.0-exp(-3.6*maxf(delta,0.0))
    chase.position = chase.position.lerp(chase_target,chase_alpha)
    chase.look_at(look_target,Vector3.UP)
    chase.fov = lerpf(chase.fov,lerpf(76.0,82.0,speed_lerp),zoom_alpha)

    # Portrait framing: lift the car out of the pedal/handbrake area while the
    # velocity lookahead still opens the view ahead of it.
    var framing: float = -overhead.size*(OVERHEAD_FRAMING_PORTRAIT if portrait else 0.0)
    overhead.h_offset = sin(camera_shake_phase)*camera_shake_strength*0.42
    overhead.v_offset = framing+cos(camera_shake_phase*1.3)*camera_shake_strength*0.42
    chase.h_offset = sin(camera_shake_phase)*camera_shake_strength*0.38
    chase.v_offset = cos(camera_shake_phase*1.3)*camera_shake_strength*0.22

func _toggle_camera() -> void:
    camera_mode = 1-camera_mode
    overhead.current = camera_mode == 0
    chase.current = camera_mode == 1

func _toggle_pause() -> void:
    if finished:
        return
    paused = not paused
    if paused:
        if sfx != null:
            sfx.silence()
        if touch != null:
            touch.release_all()
            touch.visible = false
            touch.set_process_input(false)
        pause_layer = CanvasLayer.new()
        pause_layer.name = "Exclusive Pause Menu"
        pause_layer.layer = 24
        add_child(pause_layer)
        var panel: NitroPauseMenu = PAUSE_VIEW.new()
        pause_layer.add_child(panel)
        panel.show_pause(Callable(self,"_toggle_pause"),Callable(self,"_restart"),
            func(): get_tree().change_scene_to_file("res://scenes/boot.tscn"))
    else:
        if pause_layer != null:
            pause_layer.queue_free()
            pause_layer = null
        if touch != null:
            touch.set_process_input(true)
            touch.visible = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
    _update_visuals()

func _restart() -> void:
    if pause_layer != null:
        pause_layer.queue_free()
        pause_layer = null
    if results_layer != null:
        results_layer.queue_free()
        results_layer = null
    results_open = false
    if hud != null:
        hud.visible = true
    if touch != null:
        touch.set_process_input(true)
        touch.visible = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
    model.reset(track.start_position(),track.start_heading())
    if sfx != null:
        sfx.reset()
    time_elapsed = 0.0
    race_started = false
    lap = 1
    last_progress = 0.0
    lap_started_at = 0.0
    lap_score = 0
    active_drift_points = 0
    combo = 1.0
    combo_timer = 0.0
    paused = false
    finished = false
    offroad = false
    skid_segments.clear()
    skid_mesh.clear_surfaces()
    had_skid = false
    collision_cooldown = 0.0
    camera_shake_strength = 0.0
    camera_velocity_lead = Vector3.ZERO
    drone_direction = Vector3(0.0,0.0,-1.0)
    chase_is_blocked = false
    wall_collision_count = 0
    _update_visuals()

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("camera_toggle"):
        get_viewport().set_input_as_handled()
        _toggle_camera()
    elif event.is_action_pressed("game_pause") or event.is_action_pressed("ui_cancel"):
        get_viewport().set_input_as_handled()
        _toggle_pause()
    elif event.is_action_pressed("race_restart"):
        get_viewport().set_input_as_handled()
        _restart()
    elif event is InputEventKey and event.pressed and event.physical_keycode == KEY_M:
        get_viewport().set_input_as_handled()
        get_tree().change_scene_to_file("res://scenes/boot.tscn")

