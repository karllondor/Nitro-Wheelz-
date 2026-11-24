extends SceneTree
## Portrait display evidence, not a substitute for physical Android QA.
const LAB = preload("res://scenes/visual_lab.tscn")
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var lab: NitroVisualLab = LAB.instantiate() as NitroVisualLab
    root.add_child(lab)
    for i in range(24):
        await process_frame
    if lab.panel == null or lab.mode_label == null:
        printerr("FAIL: lab UI not created")
        quit(1)
        return
    var dims: Vector2 = root.get_viewport().get_visible_rect().size
    if dims.y <= dims.x:
        printerr("FAIL: portrait test requires portrait viewport")
        quit(1)
        return
    var folder: String = OS.get_environment("OUT_DIR")
    if folder == "":
        printerr("FAIL: OUT_DIR required")
        quit(1)
        return
    DirAccess.make_dir_recursive_absolute(folder)
    lab._set_panel_open(true)
    for tab in ["STYLE","LIGHTS","TOOLS"]:
        lab._set_tab(tab)
        for i in range(5):
            await process_frame
        var filename: String = folder.trim_suffix("/") + "/UI-PORTRAIT-" + tab + ".png"
        var err: Error = root.get_viewport().get_texture().get_image().save_png(filename)
        if err != OK:
            printerr("FAIL: screenshot " + filename)
            quit(1)
            return
    lab._set_panel_open(false)
    if lab.panel.visible:
        printerr("FAIL: panel did not close")
        quit(1)
        return
    print("PASS: portrait visual lab UI captured in 3 tabs")
    quit(0)
