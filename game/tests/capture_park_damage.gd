extends SceneTree
func _initialize() -> void:
    root.add_child.call_deferred(preload("res://tests/park_damage_capture.gd").new())
