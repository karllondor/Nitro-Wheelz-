extends SceneTree
## Benchmark geometry gate. This is NOT a real Android three-lap test.
const DNA = preload("res://scripts/world/track_dna.gd")
const TRACK = preload("res://scripts/world/drift_track.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var cases: Array = [
        ["res://tracks/benchmark_oval.json",271.0,24.0],
        ["res://tracks/benchmark_sweepers.json",295.0,23.0],
        ["res://tracks/shin_kawa_full_circuit.json",2156.0,25.0]
    ]
    for scenario in cases:
        var path: String = str(scenario[0])
        var compiled: Dictionary = DNA.read_track(path)
        if not bool(compiled.get("ok",false)):
            _fail(path+" rejected: "+str(compiled.get("errors",[])))
            return
        if absf(float(compiled["length_metres"])-float(scenario[1]))>3.0:
            _fail(path+" perimeter outside tolerance")
            return
        var widths: PackedFloat32Array = compiled["halfwidths"]
        for halfwidth in widths:
            if absf(2.0*halfwidth-float(scenario[2]))>0.001:
                _fail(path+" width mismatch")
                return
        var track: NitroDriftTrack = TRACK.new()
        track.track_data_path = path
        root.add_child(track)
        await process_frame
        if not track.track_valid:
            _fail(path+" scene was not built")
            return
        for centre in track.centerline:
            if bool(track.resolve_wall(centre,Vector2.ZERO)["hit"]):
                _fail(path+" has a centreline collision")
                return
        track.queue_free()
        await process_frame
    print("PASS: Oval, Sweepers and Full Circuit corridors compile with no invisible centre walls")
    print("NOT RUN: exact DRIFTIT route match, human driving, hardware speed perception")
    quit(0)

func _fail(message: String) -> void:
    printerr("FAIL: "+message)
    quit(1)
