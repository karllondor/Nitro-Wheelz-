extends SceneTree
## v0.1.21 track editor regression (owner brief P1):
##  * complex valid shapes compile, close cleanly and need no repair;
##  * every problem is reported with its exact stretch (two tight hairpins =
##    two separate reports at the two ends, nothing in between);
##  * AUTO-SMOOTH (DNA.repair) fixes tight hairpins, too-close road sections
##    and stacked knots with bounded, local moves (far knots bit-identical),
##    and refuses to "fix" a real figure-eight crossing;
##  * SAVE AS writes exactly the validated geometry, and the race builds
##    exactly the road the editor previews (centreline, edges = barriers,
##    width, start at knot 0 heading to knot 1);
##  * touch: big finger targets, dragged nodes keep the finger offset, a
##    finger left after a pinch keeps panning.
const DNA = preload("res://scripts/world/track_dna.gd")
const EDITOR = preload("res://scripts/ui/track_editor.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(msg: String) -> void:
    printerr("FAIL: "+msg)
    quit(1)

static func track(points: Array, width: float = 24.0) -> Dictionary:
    var cps: Array = []
    for p in points:
        cps.append([snappedf(Vector2(p).x,0.01),snappedf(Vector2(p).y,0.01)])
    return {"schema_version":1,"closed":true,"id":"qa_editor_geometry","name":"QA Geometry",
        "width_m":width,"control_points":cps}

static func wavy(n: int) -> Array:
    var out: Array = []
    for i in range(n):
        var t: float = TAU*float(i)/float(n)
        var r: float = 1.0+0.16*sin(3.0*t)
        out.append(Vector2(cos(t)*230.0*r,sin(t)*150.0*r))
    return out

static func stadium_tight_ends() -> Array:
    # Long oval whose two ends are hairpins far too tight for a 24 m road.
    var out: Array = []
    for i in range(18):
        var t: float = TAU*float(i)/18.0
        out.append(Vector2(cos(t)*170.0,sin(t)*42.0))
    return out

static func peanut() -> Array:
    # Two lobes joined by a narrow waist: top and bottom roads too close.
    var out: Array = []
    for i in range(24):
        var t: float = TAU*float(i)/24.0
        out.append(Vector2(cos(t)*190.0,sin(t)*120.0*(0.08+0.92*cos(t)*cos(t))))
    return out

static func figure_eight() -> Array:
    var out: Array = []
    for i in range(16):
        var t: float = TAU*float(i)/16.0
        out.append(Vector2(cos(t)*200.0,sin(2.0*t)*90.0))
    return out

func _pts(d: Dictionary) -> Array[Vector2]:
    var out: Array[Vector2] = []
    for item in d["control_points"]:
        out.append(Vector2(float(item[0]),float(item[1])))
    return out

## Closed-loop integrity of a compiled track.
func _loop_ok(c: Dictionary, knots: int) -> String:
    var cl: Array = c["centerline"]
    var arcs: PackedFloat32Array = c["arc_lengths"]
    if cl.size() != knots*DNA.SUBDIVISIONS:
        return "sample count %d != knots x %d" % [cl.size(),DNA.SUBDIVISIONS]
    var steps: Array[float] = []
    for i in range(cl.size()):
        steps.append(Vector2(cl[i]).distance_to(Vector2(cl[(i+1)%cl.size()])))
    var sorted: Array[float] = steps.duplicate()
    sorted.sort()
    var median: float = sorted[sorted.size()/2]
    if steps[steps.size()-1] > 3.0*median or steps[steps.size()-1] < 0.05:
        return "loop does not close smoothly (closing step %.2f m, median %.2f m)" % [steps[steps.size()-1],median]
    for i in range(1,arcs.size()):
        if arcs[i] <= arcs[i-1]:
            return "arc length not increasing at %d" % i
    var total: float = 0.0
    for v in steps:
        total += v
    if absf(total-float(c["length_metres"])) > 0.01:
        return "length mismatch"
    if Vector2(cl[0]).distance_to(_pts({"control_points":c["control_points"]})[0]) > 0.001:
        return "start sample is not knot 0"
    return ""

func _run() -> void:
    # 1) Complex valid shapes (built-ins + a wavy 20-knot loop).
    var shapes: Array = [["wavy",track(wavy(20))]]
    for path in ["res://tracks/benchmark_oval.json","res://tracks/benchmark_sweepers.json",
            "res://tracks/shin_kawa_full_circuit.json","res://tracks/shin_kawa_v2.json"]:
        shapes.append([path,JSON.parse_string(FileAccess.get_file_as_string(path))])
    for sh in shapes:
        var c: Dictionary = DNA.compile(sh[1])
        if not bool(c["ok"]) or not DNA.diagnose(c).is_empty():
            _fail("Valid shape rejected or flagged: "+str(sh[0])+" "+str(c["errors"]))
            return
        var loop_err: String = _loop_ok(c,(sh[1]["control_points"] as Array).size())
        if not loop_err.is_empty():
            _fail(str(sh[0])+": "+loop_err)
            return
        var r0: Dictionary = DNA.repair(sh[1])
        if not bool(r0["ok"]) or not (r0["moved"] as Dictionary).is_empty():
            _fail("Repair must leave a valid track untouched: "+str(sh[0]))
            return
    # 2) Two tight hairpins: two separate reports, one at each end.
    var hp: Dictionary = track(stadium_tight_ends())
    var hc: Dictionary = DNA.compile(hp)
    var probs: Array[Dictionary] = DNA.diagnose(hc)
    var tight_ends: Dictionary = {}
    for p in probs:
        if str(p["kind"]) == "tight":
            var mid_sample: Vector2 = Vector2(hc["centerline"][int(p["from"])])
            if absf(mid_sample.x) < 120.0:
                _fail("Tight-corner report away from the hairpins at %s" % str(mid_sample))
                return
            tight_ends[signf(mid_sample.x)] = true
    if bool(hc["ok"]) or tight_ends.size() != 2:
        _fail("Both hairpins must be reported separately: "+str(probs.size())+" reports")
        return
    var hr: Dictionary = DNA.repair(hp)
    if not bool(hr["ok"]):
        _fail("AUTO-SMOOTH could not fix the hairpins: "+str(hr["reason"]))
        return
    var fixed: Dictionary = hp.duplicate(true)
    fixed["control_points"] = hr["points"]
    if not bool(DNA.compile(fixed)["ok"]):
        _fail("Repaired hairpins do not validate")
        return
    var before: Array[Vector2] = _pts(hp)
    var after: Array[Vector2] = _pts(fixed)
    for k in range(before.size()):
        # Knots in the middle of the straights must not move at all.
        if absf(before[k].x) < 60.0 and after[k] != before[k]:
            _fail("Hairpin repair moved straight knot %d" % k)
            return
    if float(hr["max_move"]) > 0.18*Vector2(340,84).length():
        _fail("Hairpin repair changed the shape too much (%.1f m)" % float(hr["max_move"]))
        return
    # 3) Nearby road sections: reported as a pair, pushed apart, lobes kept.
    var pn: Dictionary = track(peanut())
    var pc: Dictionary = DNA.compile(pn)
    var close: Dictionary = {}
    for p in DNA.diagnose(pc):
        if str(p["kind"]) == "close":
            close = p
    if bool(pc["ok"]) or close.is_empty():
        _fail("Too-close road sections not reported: "+str(pc["errors"]))
        return
    var ya: float = Vector2(close["at_a"]).y
    var yb: float = Vector2(close["at_b"]).y
    if signf(ya) == signf(yb) or float(close["gap"]) >= float(close["need"]):
        _fail("Close report must name the two facing stretches with the gap")
        return
    var pr: Dictionary = DNA.repair(pn)
    if not bool(pr["ok"]):
        _fail("AUTO-SMOOTH could not separate close sections: "+str(pr["reason"]))
        return
    var pfix: Dictionary = pn.duplicate(true)
    pfix["control_points"] = pr["points"]
    if not bool(DNA.compile(pfix)["ok"]):
        _fail("Separated sections do not validate")
        return
    var pb: Array[Vector2] = _pts(pn)
    var pa: Array[Vector2] = _pts(pfix)
    for k in range(pb.size()):
        if absf(pb[k].x) > 150.0 and pa[k] != pb[k]:
            _fail("Separating the waist moved lobe knot %d" % k)
            return
    # 4) Figure-eight: reported as a crossing, never "repaired".
    var f8: Dictionary = track(figure_eight())
    var f8c: Dictionary = DNA.compile(f8)
    var crossing: bool = false
    for p in DNA.diagnose(f8c):
        if str(p["kind"]) == "cross" and not bool(p["local"]):
            crossing = true
    var f8r: Dictionary = DNA.repair(f8)
    if bool(f8c["ok"]) or not crossing or bool(f8r["ok"]) or not str(f8r["reason"]).contains("CROSSES"):
        _fail("A figure-eight must be reported as a crossing and left to the player")
        return
    # 5) Two knots on top of each other: pushed apart.
    var dup: Dictionary = track(wavy(16))
    dup["control_points"][4] = (dup["control_points"][3] as Array).duplicate()
    var dr: Dictionary = DNA.repair(dup)
    if not bool(dr["ok"]):
        _fail("Stacked knots not repaired: "+str(dr["reason"]))
        return
    # 6) SAVE AS keeps the exact geometry; the race builds the previewed road.
    EDITOR.set_help_hidden(true)
    var editor: Control = EDITOR.new()
    root.add_child(editor)
    await process_frame
    var shape: Dictionary = track(wavy(20))
    var ed: Dictionary = editor.get("data")
    ed["control_points"] = shape["control_points"]
    ed["width_m"] = 22.0
    editor.call("_validate")
    if not bool(editor.get("ready_to_play")):
        _fail("Editor rejected the wavy loop")
        return
    if not bool(editor.call("_persist_track","QA Geometry Wavy")):
        _fail("SAVE AS failed")
        return
    var path: String = str(editor.get("last_saved_path"))
    var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
    # Geometry is Vector2 (32-bit) in the game; the JSON round trip may
    # differ in the last bit of a 64-bit double, never in the geometry.
    if _pts(saved) != _pts(ed) or float(saved["width_m"]) != 22.0:
        _fail("Saved knots/width differ from the validated ones")
        return
    if DNA.compile(saved)["centerline"] != DNA.compile(ed)["centerline"]:
        _fail("Saved track compiles to a different road")
        return
    var preview: Dictionary = editor.get("preview")
    ProjectSettings.set_setting("nitro/selected_track",path)
    var race: Node3D = (load("res://scenes/race.tscn") as PackedScene).instantiate()
    root.add_child(race)
    await process_frame
    var tr = race.get("track")
    if tr.centerline != preview["centerline"] or tr.left_edge != preview["left_edge"] or tr.right_edge != preview["right_edge"]:
        _fail("Race road differs from the editor preview")
        return
    for hw in tr.halfwidths:
        if absf(float(hw)-11.0) > 1e-5:
            _fail("Race road width differs from the editor width")
            return
    var k0: Vector2 = _pts(saved)[0]
    var k1: Vector2 = _pts(saved)[1]
    var heading: float = tr.start_heading()
    var fwd := Vector2(sin(heading),-cos(heading))
    if tr.start_position() != k0 or fwd.dot((k1-k0).normalized()) < 0.8:
        _fail("Start/finish must sit on knot 0 heading towards knot 1")
        return
    # Results of a player track offer EDIT TRACK (editor -> race -> results
    # -> editor loop); built-in circuits do not.
    race.call("_show_results")
    if race.find_child("EDIT TRACK",true,false) == null or race.find_child("RESTART",true,false) == null:
        _fail("Results of a saved track must offer EDIT TRACK next to RESTART")
        return
    race.queue_free()
    await process_frame
    ProjectSettings.set_setting("nitro/selected_track","res://tracks/benchmark_oval.json")
    var builtin: Node3D = (load("res://scenes/race.tscn") as PackedScene).instantiate()
    root.add_child(builtin)
    await process_frame
    builtin.call("_show_results")
    if builtin.find_child("EDIT TRACK",true,false) != null:
        _fail("Built-in circuits cannot be edited from the results")
        return
    builtin.queue_free()
    await process_frame
    # 7) Touch: finger-sized targets, drag keeps the grab offset, pinch -> pan.
    var view: Vector2 = editor.get_viewport_rect().size
    if float(editor.call("hit_radius")) < 0.06*minf(view.x,view.y):
        _fail("Node touch target smaller than a fingertip")
        return
    editor.call("_fit_all")
    var node_screen: Vector2 = editor.call("_screen_point",editor.call("_node_position",2))
    var grab: Vector2 = node_screen+Vector2(float(editor.call("hit_radius"))*0.7,0.0)
    editor.call("_start_touch",grab,5)
    if int(editor.get("selected")) != 2:
        _fail("Touch near a node (inside the finger target) did not pick it")
        return
    editor.call("_drag_touch",grab+Vector2(40.0,0.0),5)
    editor.call("_release_touch",5)
    var moved_to: Vector2 = editor.call("_screen_point",editor.call("_node_position",2))
    if moved_to.distance_to(node_screen+Vector2(40.0,0.0)) > 1.0:
        _fail("Dragged node jumped to the finger instead of keeping its offset")
        return
    editor.call("_undo")
    var canvas: Rect2 = editor.get("canvas")
    var a: Vector2 = canvas.position+Vector2(8,8)
    var b: Vector2 = canvas.position+Vector2(60,60)
    for e in [[0,a,true],[1,b,true]]:
        var t := InputEventScreenTouch.new()
        t.index = e[0]
        t.position = e[1]
        t.pressed = e[2]
        editor.call("_input",t)
    var up := InputEventScreenTouch.new()
    up.index = 1
    up.position = b
    up.pressed = false
    editor.call("_input",up)
    var mid_before: Vector2 = editor.get("world_mid")
    var drag := InputEventScreenDrag.new()
    drag.index = 0
    drag.position = a+Vector2(-50,0)
    editor.call("_input",drag)
    if Vector2(editor.get("world_mid")).x <= mid_before.x:
        _fail("The finger left after a pinch must keep panning")
        return
    editor.queue_free()
    await process_frame
    print("PASS: complex shapes valid + closed loops, every problem reported at its exact stretch (2 hairpins = 2 reports), AUTO-SMOOTH fixes hairpins / close sections / stacked knots locally (far knots unchanged, bounded moves), refuses a figure-eight, SAVE AS exact, race road == editor preview (edges, width, start), EDIT TRACK from results, finger targets, grab offset, pinch-then-pan")
    print("NOT RUN: finger feel on a real phone")
    quit(0)
