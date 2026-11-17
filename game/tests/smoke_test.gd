extends SceneTree
func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var paths := [
        "res://scenes/boot.tscn",
        "res://scenes/prototype.tscn",
        "res://scenes/dev/input_monitor.tscn",
    ]
    for path in paths:
        var packed := load(path)
        if not (packed is PackedScene):
            _fail("Not a PackedScene: " + path)
            return
        var node: Node = packed.instantiate()
        if node == null:
            _fail("Could not instantiate: " + path)
            return
        root.add_child(node)
        await process_frame
        if not is_instance_valid(node) or not node.is_inside_tree():
            _fail("_ready tree entry failed: " + path)
            return
        node.queue_free()
        await process_frame
    print("PASS: all starter scenes entered tree and ran _ready")
    quit(0)

func _fail(message: String) -> void:
    printerr("FAIL: " + message)
    quit(1)

