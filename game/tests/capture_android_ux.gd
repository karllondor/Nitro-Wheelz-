extends SceneTree
## Issue #65 / #59 evidence (developer tool, needs a display). Phone-portrait screenshots of the screens the owner
## reported: DEVELOPER (top + scrolled to the bottom), MY TRACKS list, the RENAME / DELETE dialogs, the GARAGE.
##   OUT_DIR=/abs/dir TAG=before xvfb-run -a -s "-screen 0 540x1200x24" godot --path game \
##     --rendering-driver opengl3 --resolution 540x1200 --script res://tests/capture_android_ux.gd
## Never writes to the player's saves: it only reads tracks and restores nothing because it changes nothing
## (dialogs are opened and cancelled, no button that saves is pressed).
const BOOT = preload("res://scenes/boot.tscn")
const GARAGE = preload("res://scenes/garage.tscn")

func _initialize() -> void:
    call_deferred("_run")

func _shot(name: String, out: String, tag: String) -> void:
    for i in range(8):
        await process_frame
    root.get_viewport().get_texture().get_image().save_png(out+tag+"_"+name+".png")

func _scrolls(n: Node) -> Array:
    return n.find_children("*","ScrollContainer",true,false)

func _run() -> void:
    var out: String = OS.get_environment("OUT_DIR")
    out = (out if out != "" else "user://android_ux").trim_suffix("/")+"/"
    var tag: String = OS.get_environment("TAG")
    tag = tag if tag != "" else "shot"
    DirAccess.make_dir_recursive_absolute(out)
    var boot: Control = BOOT.instantiate()
    boot.set("navigate_enabled",false)
    root.add_child(boot)
    await process_frame
    boot.call("show_page","dev")
    await _shot("developer_top",out,tag)
    for sc in _scrolls(boot):
        (sc as ScrollContainer).scroll_vertical = 100000
    await _shot("developer_bottom",out,tag)
    boot.call("show_page","drive")
    await _shot("tracks_top",out,tag)
    for sc in _scrolls(boot):
        (sc as ScrollContainer).scroll_vertical = 100000
    await _shot("tracks_bottom",out,tag)
    var mine: Array = boot.call("saved_tracks")
    if not mine.is_empty():
        boot.call("_rename_saved_track",str(mine[0]["path"]))
        await _shot("rename_dialog",out,tag)
        for n in boot.find_children("Track file dialog","",true,false):
            n.queue_free()
        boot.call("_delete_saved_track",str(mine[0]["path"]))
        await _shot("delete_dialog",out,tag)
        for n in boot.find_children("Track file dialog","",true,false):
            n.queue_free()
    boot.queue_free()
    await process_frame
    var garage: Control = GARAGE.instantiate()
    root.add_child(garage)
    await _shot("garage",out,tag)
    print("ANDROID UX CAPTURED to %s" % ProjectSettings.globalize_path(out))
    quit(0)
