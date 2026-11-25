extends Node
class_name NitroParkController
## Glue of NITRO WHEELZ PARK inside the normal race scene (issue #27). race.gd creates
## one of these when the selected track is the Park and calls three hooks:
##   freezes()   - the car stands still while a lesson schematic is up
##   after_step()- once per physics tick with the real input
##   restart()   - RESTART from the pause menu
## Cones, recovery, service and tutorial guidance live here, so
## the circuits and the drive model are untouched. FREE DRIVE = mode "free": no
## tutorial object, no guide, no ghost - just the pad, the paint and the cones.
const LAYOUT = preload("res://scripts/park/park_layout.gd")
const SITE = preload("res://scripts/park/park_site.gd")
const CONES = preload("res://scripts/park/park_cones.gd")
const TUTORIAL = preload("res://scripts/park/park_tutorial.gd")
const PROGRESS = preload("res://scripts/park/park_progress.gd")
const GHOST = preload("res://scripts/park/park_ghost.gd")
const GUIDE = preload("res://scripts/park/park_guide.gd")

## nitro/park_mode: "free" (FREE DRIVE = SKIP TUTORIAL) or "tutorial".
const SETTING_MODE: String = "nitro/park_mode"
## RESTART TUTORIAL from the menu: forget the saved progress before starting.
const SETTING_RESET: String = "nitro/park_reset"

## Hook for a future Park-only repair system.
signal repair_requested

var race: Node3D
var mode: String = "free"
var cones: NitroParkCones
var tutorial: NitroParkTutorial = null
var ghost: NitroParkGhost
var guide: NitroParkGuide = null
var beacon: MeshInstance3D
var rings: Array[MeshInstance3D] = []       # flat ring(s) painted around the exercise (cone) on the pavement
var guide_line: MeshInstance3D = null       # dashed line on the asphalt from the car to the exercise
var _ring_mat: StandardMaterial3D = null
var _line_mat: ShaderMaterial = null
var _ring_r: float = 10.0
var _toast_clock: float = 0.0
var _cone_hint_clock: float = 99.0
var _clock: float = 0.0
var _repair_wait := 0.0
var _repair_serviced := false
var _site_notice: Label
var _notice_left := 0.0

func setup(race_node: Node3D) -> void:
    race = race_node
    name = "Nitro Wheelz Park controller"
    mode = str(ProjectSettings.get_setting(SETTING_MODE,"free"))
    ProjectSettings.set_setting(SETTING_MODE,"free")           # consumed
    if bool(ProjectSettings.get_setting(SETTING_RESET,false)):
        PROGRESS.reset()
        ProjectSettings.set_setting(SETTING_RESET,false)
    cones = CONES.new()
    cones.name = "Park cones"
    race.add_child(cones)
    cones.build(LAYOUT.cones())
    cones.cone_hit.connect(_on_cone_hit)
    ghost = GHOST.new()
    race.add_child(ghost)
    var hud: Variant = race.get("hud")
    if hud != null:
        hud.set("park_mode",true)
    _make_site_notice()
    if mode == "tutorial":
        _start_tutorial()

# ------------------------------------------------------------------- tutorial

func _start_tutorial() -> void:
    if tutorial == null:
        tutorial = TUTORIAL.new()
        tutorial.lesson_started.connect(_on_lesson_started)
        tutorial.lesson_completed.connect(_on_lesson_completed)
        tutorial.hint_shown.connect(func(t: String): _toast(t,"hint",4.5))
        tutorial.tutorial_finished.connect(func(): _toast(TUTORIAL.txt(TUTORIAL.FINISHED_TEXT),"good",4.0); _end_beacon())
        var layer := CanvasLayer.new()
        layer.layer = 9
        layer.name = "Park guide layer"
        race.add_child(layer)
        guide = GUIDE.new()
        guide.tutorial = tutorial
        guide.touch = race.get("touch")
        if guide.touch != null:
            # a full-screen card is up: its dismissing tap must not press a pedal (see race_touch.gd)
            guide.touch.press_blocker = func() -> bool: return tutorial != null and tutorial.blocks_presses()
        guide.controller = self
        layer.add_child(guide)
    var start_at: int = PROGRESS.first_open(TUTORIAL.lesson_ids())
    if start_at >= TUTORIAL.LESSONS.size():
        start_at = 0          # everything done before: replay from the beginning
    tutorial.start(start_at)

func _on_lesson_started(index: int) -> void:
    cones.reset_all()                       # owner suggestion: cones return for every lesson
    var l: Dictionary = TUTORIAL.LESSONS[index]
    _place_beacon(l)
    _place_markers(l)
    _start_ghost(l)
    # ROOT CAUSE FIX (#27 phone QA): this used to switch the touch layer OFF while a schematic was up
    # and nothing switched it on again after the tap, so GAS / stick / handbrake were dead (and the
    # last pressed state stayed stuck) in every exercise lesson. The touch layer is never disabled
    # here any more: the car is frozen by freezes() and the guide consumes the dismissing tap.

func _on_lesson_completed(_index: int) -> void:
    if guide != null:
        guide.show_toast(tutorial.success_text(),"good",1.7)
    ghost.stop()
    _end_beacon()

func _toast(text: String, kind: String, seconds: float) -> void:
    if guide != null:
        guide.show_toast(text,kind,seconds)

func _on_cone_hit(_index: int, _speed: float) -> void:
    # a calm, non-interrupting remark, at most every 12 s, only while learning
    if tutorial != null and tutorial.phase == "active" and _cone_hint_clock > 12.0 and guide != null:
        _cone_hint_clock = 0.0
        guide.show_toast(TUTORIAL.txt(TUTORIAL.CONE_TEXT),"hint",2.6)

## SKIP TUTORIAL: guidance off, paint / cones / the car untouched.
func skip_tutorial() -> void:
    if tutorial != null:
        tutorial.skip()
    ghost.stop()
    _end_beacon()
    _end_markers()
    var touch: Variant = race.get("touch")
    if touch != null:
        touch.set_process_input(true)

func toggle_ghost() -> void:
    if guide == null or tutorial == null:
        return
    guide.ghost_on = not guide.ghost_on
    if guide.ghost_on:
        _start_ghost(tutorial.lesson())
    else:
        ghost.stop()

func repeat_lesson() -> void:
    if tutorial == null or not tutorial.is_active():
        return
    tutorial.repeat_lesson()

## Pause menu row: TUTORIAL ON -> skip, OFF -> (re)start at the first open lesson.
func toggle_tutorial() -> void:
    if tutorial != null and tutorial.is_active():
        skip_tutorial()
    else:
        _start_tutorial()

func pause_label() -> String:
    if tutorial != null and tutorial.is_active():
        return "TUTORIAL: ON  •  TAP TO SKIP"
    return "TUTORIAL: OFF  •  TAP TO START"

func freezes() -> bool:
    return tutorial != null and tutorial.freezes_car()

## RESTART (pause menu): car back to the start (done by race.gd), cones back, the
## current lesson starts again. Paint is paint: nothing to reset.
func restart() -> void:
    cones.reset_all()
    _reset_visit()
    _notice_left = 0.0
    _site_notice.hide()
    if tutorial != null and tutorial.is_active():
        tutorial.repeat_lesson()
    elif tutorial != null and tutorial.phase == "finished":
        pass

# --------------------------------------------------------------------- per frame

func _process(delta: float) -> void:
    if race == null:
        return
    var camera := race.get_viewport().get_camera_3d()
    var track := race.get("track") as NitroParkTrack
    if track.site != null and camera != null:
        track.site.update_roofs(race.model.position, Vector2(camera.global_position.x, camera.global_position.z))
    if _notice_left > 0.0 and not race.paused:
        _notice_left = maxf(0.0, _notice_left - delta)
        if _notice_left == 0.0:
            _site_notice.hide()
    if tutorial == null:
        return
    # The car is frozen while a card is up, so no physics tick runs: the card clock runs here.
    if tutorial.freezes_car() and not bool(race.get("paused")):
        tutorial.tick_overlay(delta)
    _animate_markers()

# --------------------------------------------------------------------- per tick

func after_step(dt: float, steer: float, gas: float, braking: float, handbrake: float) -> void:
    _clock += dt
    _cone_hint_clock += dt
    var model: NitroDriveModel = race.get("model")
    var track: NitroDriftTrack = race.get("track")
    if _recover_if_outside(model):
        return
    cones.step(dt,model.position,model.heading,model.velocity,track.body_half_length,track.body_half_width)
    _service_step(dt, model)
    if tutorial != null:
        tutorial.update(dt,{"pos":model.position,"speed_kmh":model.speed_kmh(),"drift_angle":model.drift_angle,
            "steer":steer,"gas":gas,"brake":braking,"handbrake":handbrake})
    if ghost != null and ghost.playing and guide != null and guide.ghost_on and tutorial != null and tutorial.phase == "active":
        ghost.advance(dt)
    if beacon != null:
        _pulse_beacon()
    var nav: Dictionary = nav_state()
    if guide != null:
        guide.target = nav.get("target",null)
        guide.target_dist = float(nav.get("dist",0.0))
    _nav_hint(nav)
    _update_line(model,nav)

func _recover_if_outside(model: NitroDriveModel) -> bool:
    if model.position.is_finite() and SITE.BOUNDS.has_point(model.position):
        return false
    model.reset(LAYOUT.START_POS, LAYOUT.START_HEADING)
    race.had_skid = false
    race._snap_cameras()
    _reset_visit()
    _show_site_notice("BACK ON THE PLAZA")
    return true

func _reset_visit() -> void:
    _repair_wait = 0.0
    _repair_serviced = false

func _service_step(dt: float, model: NitroDriveModel) -> void:
    if not SITE.REPAIR.has_point(model.position):
        _reset_visit()
        return
    if _repair_serviced:
        return
    if model.speed_mps() > SITE.STOP_SPEED_MPS:
        _repair_wait = 0.0
        return
    _repair_wait += dt
    if _repair_wait >= SITE.STOP_SECONDS:
        _repair_serviced = true
        repair_requested.emit()
        _show_site_notice("SERVICE COMPLETE")

func _make_site_notice() -> void:
    var layer := CanvasLayer.new()
    layer.layer = 8
    add_child(layer)
    _site_notice = Label.new()
    _site_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _site_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _site_notice.add_theme_font_size_override("font_size", 24)
    _site_notice.add_theme_color_override("font_color", Color("#ffe48e"))
    _site_notice.add_theme_color_override("font_outline_color", Color("#161224"))
    _site_notice.add_theme_constant_override("outline_size", 7)
    layer.add_child(_site_notice)
    _site_notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
    _site_notice.offset_left = -155.0
    _site_notice.offset_right = 155.0
    _site_notice.offset_top = 72.0
    _site_notice.hide()

func _show_site_notice(message: String) -> void:
    _site_notice.text = message
    _site_notice.show()
    _notice_left = 3.0

# ---------------------------------------------------------------- exercise helpers

## Planar position the current lesson wants the player to go to (or null).
func _target() -> Variant:
    if tutorial == null or not tutorial.is_active():
        return null
    var l: Dictionary = tutorial.lesson()
    if not l.has("exercise"):
        return null
    var e: Dictionary = LAYOUT.exercise(str(l["exercise"]))
    if e.is_empty():
        return null
    if str(e["kind"]) == "route":
        return LAYOUT.route_path(6.0)[0]
    return e["centre"]

## Where the exercise of a lesson is: ring centres, the painted ring radius and the radius at which
## "you are there" starts (the detectors accept the car inside r_max = 1.7 x radius of a donut).
func zone_of(l: Dictionary) -> Dictionary:
    if not l.has("exercise"):
        return {}
    var e: Dictionary = LAYOUT.exercise(str(l["exercise"]))
    if e.is_empty():
        return {}
    match str(e["kind"]):
        "donut":
            return {"centres":[Vector2(e["centre"])],"ring_r":float(e["radius"]),"zone_r":float(e["radius"])*1.7}
        "eight":
            return {"centres":[Vector2(e["lobes"][0]),Vector2(e["lobes"][1])],"ring_r":float(e["radius"]),"zone_r":float(e["radius"])*1.7}
        _:
            return {"centres":[Vector2(LAYOUT.route_path(6.0)[0])],"ring_r":6.0,"zone_r":14.0}

## The live navigation state, from the REAL car every call (never cached): target, distance,
## inside the exercise zone or not, and the side it is on relative to the car's heading.
func nav_state() -> Dictionary:
    if tutorial == null or race == null or not (tutorial.phase == "active" or tutorial.phase == "success"):
        return {}
    var z: Dictionary = zone_of(tutorial.lesson())
    if z.is_empty():
        return {}
    var model: NitroDriveModel = race.get("model")
    var best: Vector2 = Vector2((z["centres"] as Array)[0])
    var best_d: float = INF
    for c in z["centres"]:
        var d: float = model.position.distance_to(Vector2(c))
        if d < best_d:
            best_d = d
            best = Vector2(c)
    var v: Vector2 = best-model.position
    var f: float = v.dot(model.forward())
    var r: float = v.dot(model.right())
    var ang: float = rad_to_deg(atan2(r,f))
    var side: String = "ahead"
    if absf(ang) > 135.0:
        side = "behind"
    elif absf(ang) > 25.0:
        side = "right" if ang > 0.0 else "left"
    return {"target":best,"dist":best_d,"in_zone":best_d <= float(z["zone_r"]),"side":side,"angle":ang,
        "ring_r":float(z["ring_r"]),"dir":v.normalized() if v.length() > 0.001 else Vector2(0,-1)}

## Car position on screen and the screen direction towards the target (from two points next to the
## car, so it works for every camera and heading and never depends on the target being visible).
func nav_screen(cam: Camera3D, nav: Dictionary) -> Dictionary:
    var model: NitroDriveModel = race.get("model")
    var d: Vector2 = Vector2(nav["dir"])
    var p3 := Vector3(model.position.x,0.3,model.position.y)
    var q3 := Vector3(model.position.x+d.x*8.0,0.3,model.position.y+d.y*8.0)
    var a: Vector2 = cam.unproject_position(p3)
    var b: Vector2 = cam.unproject_position(q3)
    var dir: Vector2 = b-a
    if dir.length() < 0.5:
        dir = Vector2(0,-1)
    return {"car":a,"dir":dir.normalized()}

## One calm reminder when the player has been wandering for a while far from the exercise.
func _nav_hint(nav: Dictionary) -> void:
    if nav.is_empty() or tutorial.phase != "active" or tutorial.nav_hint_given or guide == null:
        return
    if tutorial.lesson_time > TUTORIAL.NAV_HINT_AFTER and not bool(nav["in_zone"]) and float(nav["dist"]) > float(nav["ring_r"])*3.0:
        tutorial.nav_hint_given = true
        guide.show_toast(TUTORIAL.txt(TUTORIAL.NAV_LINE_HINT),"hint",4.5)

# ------------------------------------------------------------ ground markers

static func _ring_mesh(radius: float, width: float, segments: int = 72) -> ArrayMesh:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var r0: float = radius-width*0.5
    var r1: float = radius+width*0.5
    for k in range(segments):
        var a0: float = TAU*float(k)/float(segments)
        var a1: float = TAU*float(k+1)/float(segments)
        var p00 := Vector3(cos(a0)*r0,0.0,sin(a0)*r0)
        var p01 := Vector3(cos(a0)*r1,0.0,sin(a0)*r1)
        var p10 := Vector3(cos(a1)*r0,0.0,sin(a1)*r0)
        var p11 := Vector3(cos(a1)*r1,0.0,sin(a1)*r1)
        for v in [p00,p01,p10,p10,p01,p11]:
            st.set_normal(Vector3.UP)
            st.add_vertex(v)
    return st.commit()

## Rings on the pavement around every cone of the exercise + a dashed guide line from the car.
func _place_markers(l: Dictionary) -> void:
    _end_markers()
    var z: Dictionary = zone_of(l)
    if z.is_empty():
        return
    _ring_r = float(z["ring_r"])
    _ring_mat = StandardMaterial3D.new()
    _ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    _ring_mat.albedo_color = Color(0.35,0.95,1.0,0.75)
    _ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    _ring_mat.render_priority = 1
    for c in z["centres"]:
        var ring := MeshInstance3D.new()
        ring.name = "Exercise ring"
        ring.mesh = _ring_mesh(_ring_r,maxf(0.9,_ring_r*0.09))
        ring.material_override = _ring_mat
        ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        ring.position = Vector3(Vector2(c).x,0.09,Vector2(c).y)
        race.add_child(ring)
        rings.append(ring)
    var shader := Shader.new()
    shader.code = """shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
uniform float length_m = 10.0;
uniform vec4 tint : source_color = vec4(0.35, 0.95, 1.0, 0.65);
void fragment() {
    float d = UV.y * length_m;
    float dash = step(0.42, fract(d * 0.16 - TIME * 1.1));
    float edge = smoothstep(0.0, 0.25, UV.x) * smoothstep(1.0, 0.75, UV.x);
    ALBEDO = tint.rgb;
    ALPHA = tint.a * dash * edge;
}
"""
    _line_mat = ShaderMaterial.new()
    _line_mat.shader = shader
    _line_mat.render_priority = 1
    guide_line = MeshInstance3D.new()
    guide_line.name = "Exercise guide line"
    var plane := PlaneMesh.new()
    plane.size = Vector2(2.4,1.0)
    guide_line.mesh = plane
    guide_line.material_override = _line_mat
    guide_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    guide_line.visible = false
    race.add_child(guide_line)

func _end_markers() -> void:
    for r in rings:
        if is_instance_valid(r):
            r.queue_free()
    rings.clear()
    if guide_line != null:
        guide_line.queue_free()
        guide_line = null
    _ring_mat = null
    _line_mat = null

## The guide line runs from the car to the edge of the ring and is hidden inside the zone.
func _update_line(model: NitroDriveModel, nav: Dictionary) -> void:
    if guide_line == null:
        return
    if nav.is_empty() or tutorial.phase != "active" or bool(nav["in_zone"]) or float(nav["dist"]) < float(nav["ring_r"])*1.4:
        guide_line.visible = false
        return
    var dir: Vector2 = Vector2(nav["dir"])
    var start: Vector2 = model.position+dir*2.5
    var stop: Vector2 = Vector2(nav["target"])-dir*(float(nav["ring_r"])+0.8)
    var length: float = start.distance_to(stop)
    if length < 1.0:
        guide_line.visible = false
        return
    var mid: Vector2 = (start+stop)*0.5
    guide_line.visible = true
    guide_line.position = Vector3(mid.x,0.11,mid.y)
    guide_line.rotation = Vector3(0.0,atan2(dir.x,dir.y),0.0)
    guide_line.scale = Vector3(1.0,1.0,length)
    _line_mat.set_shader_parameter("length_m",length)

## Pulse the rings; teal while far, gold inside the zone, brighter as the circle fills.
func _animate_markers() -> void:
    if _ring_mat == null or tutorial == null:
        return
    var t: float = Time.get_ticks_msec()/1000.0
    var nav: Dictionary = nav_state()
    var gold: bool = not nav.is_empty() and bool(nav["in_zone"])
    var progress: float = tutorial.progress() if gold else 0.0
    var base: Color = Color(0.35,0.95,1.0).lerp(Color(1.0,0.86,0.25),1.0 if gold else 0.0)
    base = base.lerp(Color(0.55,1.0,0.45),progress)
    base.a = 0.6+0.3*sin(t*5.0)
    _ring_mat.albedo_color = base

func _start_ghost(l: Dictionary) -> void:
    if guide != null and not guide.ghost_on:
        ghost.stop()
        return
    if not l.has("exercise"):
        ghost.stop()
        return
    var e: Dictionary = LAYOUT.exercise(str(l["exercise"]))
    match str(l["kind"]):
        "donut":
            var r: float = float(e["radius"])*0.5
            var pts := PackedVector2Array()
            var turn: int = int(e["turn"])
            for k in range(72):
                var a: float = TAU*float(k)/72.0*float(-turn)       # left = counter-clockwise
                pts.append(Vector2(e["centre"])+Vector2(cos(a),sin(a))*r)
            ghost.play(pts,true,9.5,30.0)
        "eight":
            ghost.play(LAYOUT.eight_path(Vector2(e["centre"]),float(e["radius"]),LAYOUT.EIGHT_SPREAD,1.5),true,10.5,28.0)
        "route":
            ghost.play(LAYOUT.route_path(1.5),true,13.0,22.0)
        _:
            ghost.stop()

func _place_beacon(l: Dictionary) -> void:
    _end_beacon()
    var target: Variant = _target_for(l)
    if target == null:
        return
    var p: Vector2 = target
    beacon = MeshInstance3D.new()
    beacon.name = "Lesson beacon"
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var sides: int = 20
    var radius: float = 1.1
    var height: float = 16.0
    for k in range(sides):
        var a0: float = TAU*float(k)/float(sides)
        var a1: float = TAU*float(k+1)/float(sides)
        var b0 := Vector3(cos(a0)*radius,0.0,sin(a0)*radius)
        var b1 := Vector3(cos(a1)*radius,0.0,sin(a1)*radius)
        var t0 := Vector3(cos(a0)*radius,height,sin(a0)*radius)
        var t1 := Vector3(cos(a1)*radius,height,sin(a1)*radius)
        for v in [[b0,0.55],[b1,0.55],[t0,0.0],[t0,0.0],[b1,0.55],[t1,0.0]]:
            st.set_color(Color(0.35,0.95,1.0,float(v[1])))
            st.set_normal(Vector3.UP)
            st.add_vertex(v[0])
    beacon.mesh = st.commit()
    var mat := StandardMaterial3D.new()
    mat.vertex_color_use_as_albedo = true
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    mat.render_priority = 2
    beacon.material_override = mat
    beacon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    beacon.position = Vector3(p.x,0.05,p.y)
    race.add_child(beacon)

func _target_for(l: Dictionary) -> Variant:
    if not l.has("exercise"):
        return null
    var e: Dictionary = LAYOUT.exercise(str(l["exercise"]))
    if e.is_empty():
        return null
    if str(e["kind"]) == "route":
        return LAYOUT.route_path(6.0)[0]
    return e["centre"]

func _pulse_beacon() -> void:
    var k: float = 1.0+0.12*sin(_clock*4.0)
    beacon.scale = Vector3(k,1.0,k)

func _end_beacon() -> void:
    if beacon != null:
        beacon.queue_free()
        beacon = null
    if guide != null:
        guide.target = null
