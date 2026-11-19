extends SceneTree
## Regression for the 3D tap-to-build track builder (v0.1.13+).
const GRID = preload("res://scripts/world/track_grid.gd")
const TRACK = preload("res://scripts/world/drift_track.gd")
const DNA = preload("res://scripts/world/track_dna.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    # Pure model: drawn rectangle loop compiles through Track DNA.
    var g: NitroTrackGrid = GRID.new(9,14)
    var path: Array[Vector2i] = [Vector2i(2,2),Vector2i(3,2),Vector2i(4,2),Vector2i(4,3),
        Vector2i(4,4),Vector2i(4,5),Vector2i(3,5),Vector2i(2,5),Vector2i(2,4),Vector2i(2,3)]
    for i in range(path.size()-1):
        if g.link(path[i],path[i+1]) != "ok":
            _fail("Adjacent tiles did not link")
            return
    if not g.loop().is_empty() or g.open_ends().size() != 2:
        _fail("Open chain reported as a loop")
        return
    g.link(path[path.size()-1],path[0])
    var order: Array[Vector2i] = g.loop()
    if order.size() != path.size():
        _fail("Closed rectangle not detected as one loop")
        return
    var check: Dictionary = g.validate()
    if not bool(check.get("ok",false)):
        _fail("Drawn loop rejected by Track DNA: "+str(check.get("errors")))
        return
    if g.link(Vector2i(3,2),Vector2i(3,3)) != "junction":
        _fail("Third link (junction/crossing) must be refused")
        return
    if g.link(Vector2i(0,0),Vector2i(2,0)) != "not_adjacent" or g.link(Vector2i(8,13),Vector2i(9,13)) != "out_of_bounds":
        _fail("Non-adjacent / out-of-bounds links must be refused")
        return
    # Parallel strands are allowed because links are explicit.
    var h: NitroTrackGrid = GRID.new(9,14)
    var hairpin: Array[Vector2i] = [Vector2i(1,1),Vector2i(2,1),Vector2i(3,1),Vector2i(4,1),
        Vector2i(4,2),Vector2i(3,2),Vector2i(2,2),Vector2i(2,3),Vector2i(2,4),Vector2i(1,4),Vector2i(1,3),Vector2i(1,2)]
    for i in range(hairpin.size()):
        h.link(hairpin[i],hairpin[(i+1)%hairpin.size()])
    if not bool(h.validate().get("ok",false)):
        _fail("Hairpin/S-bend loop with adjacent strands should be valid: "+str(h.validate().get("errors")))
        return
    # Procedural generator: deterministic and always valid.
    var lengths: Array[float] = []
    for seed in range(12):
        var a: NitroTrackGrid = GRID.new(9,14)
        var b: NitroTrackGrid = GRID.new(9,14)
        if not a.generate(500+seed,24) or not b.generate(500+seed,24):
            _fail("Generator failed for seed %d" % seed)
            return
        if a.loop() != b.loop():
            _fail("Generator not deterministic for seed %d" % seed)
            return
        lengths.append(float(a.validate()["length_metres"]))
    if lengths.min() < 600.0 or lengths.max() > 2200.0:
        _fail("Generated loops outside compact drift-course length: "+str(lengths))
        return
    # Saved data round-trips into the builder and the race track.
    var data: Dictionary = g.to_track_data("QA BUILT","qa_built")
    var restored: NitroTrackGrid = GRID.new(9,14)
    if not restored.load_builder_data(data) or restored.loop().size() != order.size():
        _fail("Builder tiles do not round-trip")
        return
    var race_track: NitroDriftTrack = TRACK.new()
    if not race_track.rebuild_from_data(data):
        _fail("Race track cannot build the saved builder loop")
        return
    race_track.free()
    # Open-chain preview uses the race visuals without crashing.
    var preview: NitroDriftTrack = TRACK.new()
    var chain: Array[Vector2i] = [Vector2i(1,1),Vector2i(2,1),Vector2i(2,2)]
    var open_grid: NitroTrackGrid = GRID.new(9,14)
    open_grid.link(chain[0],chain[1])
    open_grid.link(chain[1],chain[2])
    preview.build_from_samples(open_grid.preview_samples(chain,false),12.0,false)
    root.add_child(preview)
    await process_frame
    if preview.find_child("Single continuous driving surface",true,false) == null or preview.find_child("Blue white kerbs",true,false) == null:
        _fail("Open-chain preview lacks road or kerbs")
        return
    if preview.find_child("Ground outside track",true,false) != null:
        _fail("Preview pieces must not duplicate the ground/environment")
        return
    preview.queue_free()

    # Scene: tap to place, tap next to the end to extend, undo, erase, drive.
    DirAccess.remove_absolute(ProjectSettings.globalize_path("user://nitro_builder_draft.json"))
    var scene: Node3D = (load("res://scenes/track_builder.tscn") as PackedScene).instantiate()
    root.add_child(scene)
    await process_frame
    var builder_grid: NitroTrackGrid = scene.get("grid")
    builder_grid.clear()
    scene.call("begin_stroke",Vector2i(3,3))
    scene.call("end_stroke")
    scene.call("begin_stroke",Vector2i(4,3))
    scene.call("end_stroke")
    if builder_grid.degree(Vector2i(3,3)) != 1 or builder_grid.degree(Vector2i(4,3)) != 1:
        _fail("Tapping next to a road end must extend it")
        return
    scene.call("begin_stroke",Vector2i(4,3))
    scene.call("move_stroke",Vector2i(4,6))
    scene.call("move_stroke",Vector2i(3,6))
    scene.call("move_stroke",Vector2i(3,4))
    scene.call("end_stroke")
    # 2 tapped + (4,4),(4,5),(4,6) + (3,6) + (3,5),(3,4) = 8
    if builder_grid.tile_count() != 8:
        _fail("Drag did not lay a 4-connected strip (tiles=%d)" % builder_grid.tile_count())
        return
    scene.call("begin_stroke",Vector2i(3,4))
    scene.call("move_stroke",Vector2i(3,3))
    scene.call("end_stroke")
    # (3,3) is the other open end, so this link closes the loop.
    if builder_grid.loop().is_empty() or not bool(scene.get("loop_ok")):
        _fail("Joining the two ends did not close a drivable loop")
        return
    if (scene.get("road_root") as Node3D).get_child_count() != 1:
        _fail("Closed loop should preview as a single road piece")
        return
    scene.call("_undo")
    if not builder_grid.loop().is_empty():
        _fail("UNDO did not reopen the loop")
        return
    scene.call("_set_erase")
    scene.call("begin_stroke",Vector2i(4,5))
    scene.call("end_stroke")
    if builder_grid.is_road(Vector2i(4,5)):
        _fail("ERASE did not remove the tile")
        return
    scene.call("_set_draw")
    scene.call("_generate")
    if not bool(scene.get("loop_ok")):
        _fail("GENERATE did not produce a drivable loop")
        return
    if not bool(scene.call("_write_track","user://nitro_track_qa_builder.json","QA BUILDER","qa_builder")):
        _fail("Builder could not save a validated track")
        return
    if not bool(DNA.read_track("user://nitro_track_qa_builder.json").get("ok",false)):
        _fail("Saved builder track fails Track DNA")
        return
    scene.queue_free()
    await process_frame
    print("PASS: tile links/junction refusal, hairpins, deterministic generator, tap-extend/drag/undo/erase, save -> race geometry")
    print("NOT RUN: finger feel on a phone, preview rebuild time on Android")
    quit(0)

func _fail(msg: String) -> void:
    printerr("FAIL: "+msg)
    quit(1)
