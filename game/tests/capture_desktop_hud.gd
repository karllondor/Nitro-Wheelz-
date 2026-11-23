extends SceneTree
## Launch under xvfb, with --resolution 1280x720 and OUT_FILE absolute path.
const PREVIEW = preload("res://tests/desktop_hud_preview.tscn")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    if OS.get_environment("HUD_FULLSCREEN") == "1":
        root.mode = Window.MODE_FULLSCREEN
    root.add_child(PREVIEW.instantiate())
    for i in range(24):
        await process_frame
    await RenderingServer.frame_post_draw
    var image: Image = root.get_viewport().get_texture().get_image()
    var output: String = OS.get_environment("OUT_FILE")
    if output.is_empty():
        output = "user://desktop_hud_preview.png"
    var result: Error = image.save_png(output)
    if result != OK:
        printerr("FAIL: HUD screenshot cannot save: "+str(result))
        quit(1)
        return
    print("CAPTURED: "+output)
    quit(0)
