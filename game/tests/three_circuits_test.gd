extends SceneTree

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var checks := preload("res://tests/three_circuit_checks.gd").new()
    root.add_child(checks)
    var ok: bool = await checks.complete
    await process_frame
    quit(0 if ok else 1)
