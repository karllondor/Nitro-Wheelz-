extends SceneTree
## P0: fail-closed Track DNA validation, negative controls, and shared contact
## geometry. No GPU screenshots or human driving claims are inferred here.
const DNA = preload("res://scripts/world/track_dna.gd")
const TRACK = preload("res://scripts/world/drift_track.gd")
const PATH: String = "res://tracks/shin_kawa_v2.json"

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
    if not (raw is Dictionary):
        _fail("Track JSON missing or invalid")
        return
    var compiled: Dictionary = DNA.compile(raw)
    if not bool(compiled["ok"]):
        _fail("Valid Shin-Kawa rejected: "+str(compiled["errors"]))
        return
    var points: Array[Vector2] = compiled["centerline"]
    var left: Array[Vector2] = compiled["left_edge"]
    var right: Array[Vector2] = compiled["right_edge"]
    if points.size() < 150 or points.size() != left.size() or points.size()!=right.size():
        _fail("Sample arrays have inconsistent lengths")
        return
    if (points[0]-points[points.size()-1]).length() > 12.0:
        _fail("Last spline sample does not close to the first")
        return
    if (points[1]-points[points.size()-1]).normalized().distance_to(Vector2(0,-1)) > 0.03:
        _fail("Starting tangent must point straight up the portrait screen")
        return
    var too_close: Dictionary = raw.duplicate(true)
    too_close["control_points"][2] = too_close["control_points"][1].duplicate()
    if bool(DNA.compile(too_close)["ok"]):
        _fail("Negative control: repeated knots incorrectly accepted")
        return
    var bad_width: Dictionary = raw.duplicate(true)
    bad_width["widths_m"][3] = 2.0
    if bool(DNA.compile(bad_width)["ok"]):
        _fail("Negative control: unplayably narrow surface accepted")
        return
    var crossed: Dictionary = raw.duplicate(true)
    crossed["control_points"] = [
        [-110,-95],[110,100],[-110,100],[110,-95],
        [125,-30],[160,20],[135,100],[0,150],
        [-115,160],[-160,65]
    ]
    crossed["widths_m"] = []
    if bool(DNA.compile(crossed)["ok"]):
        _fail("Negative control: self-intersecting figure-eight accepted")
        return
    var t: NitroDriftTrack = TRACK.new()
    root.add_child(t)
    await process_frame
    if not t.track_valid or t.centerline.size()!=points.size():
        _fail("Scene did not build validated Track DNA geometry")
        return
    # Creator proof-of-concept: modify one geometric control and a width,
    # rebuild the SAME scene without hand-modelling any mesh.
    var edited: Dictionary = raw.duplicate(true)
    edited["control_points"][6][0] = float(edited["control_points"][6][0])+3.0
    edited["widths_m"][4] = 27.0
    var alternate: Dictionary = DNA.compile(edited)
    if not bool(alternate["ok"]):
        _fail("Harmless creator edit was rejected: "+str(alternate["errors"]))
        return
    if not t.rebuild_from_data(edited):
        _fail("In-memory Track Creator rebuild failed")
        return
    if absf(t.halfwidths[4*DNA.SUBDIVISIONS]-13.5) > 0.01:
        _fail("Edited width did not regenerate road geometry")
        return
    var remembered_length: float = t.length_metres
    var invalid_edit: Dictionary = edited.duplicate(true)
    invalid_edit["widths_m"][4] = 1.0
    if t.rebuild_from_data(invalid_edit):
        _fail("Invalid creator edit incorrectly replaced playable track")
        return
    if not t.track_valid or absf(t.length_metres-remembered_length)>0.001:
        _fail("Rejected edit destroyed the previous validated track")
        return
    if not t.rebuild_from_data(raw):
        _fail("Cannot restore original authored track after creator edit")
        return
    var body: StaticBody3D = t.get_node_or_null(
        "Exactly matched wall triangle collision mesh") as StaticBody3D
    var visual: MeshInstance3D = t.get_node_or_null("Walls from Track DNA edges") as MeshInstance3D
    if body == null or visual == null:
        _fail("Visible walls and matching Godot static collider missing")
        return
    var collision: CollisionShape3D = body.get_child(0) as CollisionShape3D
    if collision == null or not (collision.shape is ConcavePolygonShape3D):
        _fail("Wall collision mesh is not a concave polygon shape")
        return
    var actual_faces: PackedVector3Array = (collision.shape as ConcavePolygonShape3D).get_faces()
    var visible_faces: PackedVector3Array = visual.mesh.get_faces()
    if actual_faces.size()!=visible_faces.size() or actual_faces.size() < 300:
        _fail("Collider faces diverge from visible barrier")
        return
    for i in range(0,actual_faces.size(),29):
        if actual_faces[i].distance_to(visible_faces[i]) > 0.0001:
            _fail("Wall visual and physics triangles do not match")
            return
    var start: Vector2 = t.start_position()
    var tangent: Vector2 = Vector2(t.sample_info(start)["tangent"])
    var across: Vector2 = (t.right_edge[0]-t.left_edge[0]).normalized()
    var left_collision: Dictionary = t.resolve_wall(start-across*16.0,-across*10.0+tangent*4.0)
    var right_collision: Dictionary = t.resolve_wall(start+across*16.0,across*10.0+tangent*4.0)
    if not bool(left_collision["hit"]) or not bool(right_collision["hit"]):
        _fail("Barrier collision missing on one or both sides")
        return
    if not (Vector2(left_collision["velocity"]).dot(-across) < 0.0 and
            Vector2(right_collision["velocity"]).dot(across) < 0.0):
        _fail("Barrier did not rebound inward")
        return
    var on_surface: Dictionary = t.resolve_wall(start+across*2.0,tangent*8.0)
    if bool(on_surface["hit"]):
        _fail("Invisible barrier inside the road surface")
        return

    # Sample the entire drivable centreline, including the closure, as a
    # geometry-only lap traversal. This is NOT player-driven lap validation.
    for sample in t.centerline:
        if bool(t.resolve_wall(sample,Vector2.ZERO)["hit"]):
            _fail("A segment of the nominal centreline hits a barrier")
            return
    print("PASS: Track DNA positive/negative validation, clean closed loop, walls == static colliders, both-side bounce, centreline traversal")
    print("NOT RUN: human-driven full three laps / mobile screenshot comparison")
    t.queue_free()
    quit(0)

func _fail(reason: String) -> void:
    printerr("FAIL: "+reason)
    quit(1)
