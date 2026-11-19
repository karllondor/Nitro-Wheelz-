extends SceneTree
## On-device generator beta: deterministic, validated and never publishes bad road.
const GENERATOR = preload("res://scripts/world/track_generator.gd")
const DNA = preload("res://scripts/world/track_dna.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var seed: int = 812345
    var first: Dictionary = GENERATOR.generate(seed)
    if not bool(first.get("ok",false)):
        _fail("Generator rejected first seed: "+str(first))
        return
    var path: String = str(first["path"])
    var content: String = FileAccess.get_file_as_string(path)
    var compiled: Dictionary = DNA.read_track(path)
    if not bool(compiled.get("ok",false)):
        _fail("Generator saved invalid Track DNA: "+str(compiled.get("errors",[])))
        return
    if float(compiled["length_metres"]) < 1000.0:
        _fail("Generated track unexpectedly short")
        return
    var repeat: Dictionary = GENERATOR.generate(seed)
    if not bool(repeat.get("ok",false)) or FileAccess.get_file_as_string(path) != content:
        _fail("Same seed produces different track geometry")
        return
    var second: Dictionary = GENERATOR.generate(seed+1)
    if not bool(second.get("ok",false)) or FileAccess.get_file_as_string(path) == content:
        _fail("Different seed did not create a distinct valid circuit")
        return
    print("PASS: Track Creator beta generates distinct deterministic validated closed loops")
    print("NOT RUN: interactive track editing, save sharing or Android device hardware")
    quit(0)

func _fail(msg: String) -> void:
    printerr("FAIL: "+msg)
    quit(1)
