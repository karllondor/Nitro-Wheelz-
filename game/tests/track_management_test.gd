extends SceneTree

func _initialize() -> void:
    _run.call_deferred()

func _run() -> void:
    var checks := preload("res://tests/track_management_checks.gd").new()
    root.add_child(checks)
    var passed: bool = await checks.complete
    await process_frame
    quit(0 if passed else 1)
