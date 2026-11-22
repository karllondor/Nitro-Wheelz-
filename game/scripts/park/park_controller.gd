extends Node
class_name NitroParkController
## Glue of NITRO WHEELZ PARK inside the normal race scene (issue #27). race.gd creates
## one of these when the selected track is the Park and calls three hooks:
##   freezes()   - the car stands still while a lesson schematic is up
##   after_step()- once per physics tick with the real input
##   restart()   - RESTART from the pause menu
## Everything else (cones, soft edge, tutorial, ghost, guide, beacon) lives here, so
## the circuits and the drive model are untouched. FREE DRIVE = mode "free": no
## tutorial object, no guide, no ghost - just the pad, the paint and the cones.
const LAYOUT = preload("res://scripts/park/park_layout.gd")
const CONES = preload("res://scripts/park/park_cones.gd")
const TUTORIAL = preload("res://scripts/park/park_tutorial.gd")
const PROGRESS = preload("res://scripts/park/park_progress.gd")
const GHOST = preload("res://scripts/park/park_ghost.gd")
const GUIDE = preload("res://scripts/park/park_guide.gd")

## nitro/park_mode: "free" (FREE DRIVE = SKIP TUTORIAL) or "tutorial".
const SETTING_MODE: String = "nitro/park_mode"
## RESTART TUTORIAL from the menu: forget the saved progress before starting.
const SETTING_RESET: String = "nitro/park_reset"

var race: Node3D
var mode: String = "free"
var cones: NitroParkCones
var tutorial: NitroParkTutorial = null
var ghost: NitroParkGhost
var guide: NitroParkGuide = null
var beacon: MeshInstance3D
var _toast_clock: float = 0.0
var _cone_hint_clock: float = 99.0
var _clock: float = 0.0

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
    _start_ghost(l)
    var touch: Variant = race.get("touch")
    if touch != null:
        # while a schematic is up the touch layer must not see taps
        touch.set_process_input(not tutorial.freezes_car())

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
    if tutorial != null and tutorial.is_active():
        tutorial.repeat_lesson()
    elif tutorial != null and tutorial.phase == "finished":
        pass

# --------------------------------------------------------------------- per tick

func after_step(dt: float, steer: float, gas: float, braking: float, handbrake: float) -> void:
    _clock += dt
    _cone_hint_clock += dt
    var model: NitroDriveModel = race.get("model")
    var track: NitroDriftTrack = race.get("track")
    cones.step(dt,model.position,model.heading,model.velocity,track.body_half_length,track.body_half_width)
    _soft_edge(model)
    if tutorial != null:
        tutorial.update(dt,{"pos":model.position,"speed_kmh":model.speed_kmh(),"drift_angle":model.drift_angle,
            "steer":steer,"gas":gas,"brake":braking,"handbrake":handbrake})
    if ghost != null and ghost.playing and guide != null and guide.ghost_on and tutorial != null and tutorial.phase == "active":
        ghost.advance(dt)
    if beacon != null:
        _pulse_beacon()
    if guide != null:
        guide.target = _target()
        if guide.target != null:
            guide.target_dist = model.position.distance_to(Vector2(guide.target))

## The far invisible edge: not a wall - no sound, no shake, no scoring. The car just
## cannot leave the world; it slides along the edge.
func _soft_edge(model: NitroDriveModel) -> void:
    var d: float = LAYOUT.pad_distance(model.position,0.0)
    if d <= LAYOUT.SOFT_EDGE_M:
        return
    var e: float = 0.5
    var p: Vector2 = model.position
    var n := Vector2(LAYOUT.pad_distance(p+Vector2(e,0),0.0)-LAYOUT.pad_distance(p-Vector2(e,0),0.0),
        LAYOUT.pad_distance(p+Vector2(0,e),0.0)-LAYOUT.pad_distance(p-Vector2(0,e),0.0))
    if n.length_squared() < 0.0001:
        return
    n = n.normalized()
    model.position = p-n*(d-LAYOUT.SOFT_EDGE_M)
    var out: float = model.velocity.dot(n)
    if out > 0.0:
        model.velocity -= n*out

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
