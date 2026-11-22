extends SceneTree
## Loading screen evidence (developer tool, needs a display):
##   OUT_DIR=/abs/dir TAG=phone xvfb-run -s "-screen 0 720x1560x24" godot --path game \
##     --rendering-driver opengl3 --resolution 720x1560 --script res://tests/capture_loading_screen.gd
## Draws the poster loading screen (LOADING TRACK, 40 %) and the plain loading
## card (for comparison) at the window size.
const BUSY = preload("res://scripts/ui/busy_overlay.gd")

func _initialize() -> void:
    call_deferred("_run")

func _shot(path: String) -> void:
    for i in range(6):
        await process_frame
    root.get_viewport().get_texture().get_image().save_png(path)

func _run() -> void:
    var out_dir: String = OS.get_environment("OUT_DIR") if OS.get_environment("OUT_DIR") != "" else "user://loading/"
    var tag: String = OS.get_environment("TAG") if OS.get_environment("TAG") != "" else "run"
    DirAccess.make_dir_recursive_absolute(out_dir)
    out_dir = out_dir.trim_suffix("/")+"/"
    var holder := Node.new()
    root.add_child(holder)
    var b: NitroBusy = BUSY.open(holder,"LOADING TRACK",false,true)
    b.set_text("LOADING TRACK","TOUGE ROUTE • TOUGE MOUNTAIN")
    b.set_progress(0.4)
    await _shot(out_dir+"loading_poster_"+tag+".png")
    b.close()
    var p: NitroBusy = BUSY.open(holder,"LOADING TRACK")
    p.set_text("LOADING TRACK","TOUGE ROUTE • TOUGE MOUNTAIN")
    p.set_progress(0.4)
    await _shot(out_dir+"loading_card_"+tag+".png")
    print("LOADING SCREEN CAPTURED to %s" % ProjectSettings.globalize_path(out_dir))
    quit(0)
