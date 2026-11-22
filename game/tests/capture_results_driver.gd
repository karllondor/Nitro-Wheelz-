extends SceneTree
## Issue #23 evidence (developer tool, needs a display):
##   OUT_DIR=/abs/dir xvfb-run -a -s "-screen 0 720x1560x24" godot --path game \
##     --rendering-driver opengl3 --resolution 720x1560 --script res://tests/capture_results_driver.gd
## The finish screen with a TOP RUNS table of mixed rows (older runs without a
## driver / car = UNKNOWN, new runs with both). Backs up and restores the local runs.
const RESULTS = preload("res://scripts/ui/race_results.gd")
const DRIVER = preload("res://scripts/player/driver_profile.gd")
const CARS = preload("res://scripts/vehicles/car_catalog.gd")
const ID: String = "capture_results_driver_track"

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var out: String = OS.get_environment("OUT_DIR")
    out = (out if out != "" else "user://results").trim_suffix("/")+"/"
    DirAccess.make_dir_recursive_absolute(out)
    var had := FileAccess.file_exists(RESULTS.STORAGE)
    var backup: String = FileAccess.get_file_as_string(RESULTS.STORAGE) if had else ""
    var had_d := FileAccess.file_exists(DRIVER.PATH)
    var backup_d: String = FileAccess.get_file_as_string(DRIVER.PATH) if had_d else ""
    var rows: Array = [
        {"track_id":ID,"seconds":71.2,"score":28400,"stars":3,"date":"2026-11-19T10:00:00"},
        {"track_id":ID,"seconds":66.9,"score":22100,"stars":2,"date":"2026-11-20T18:10:00","driver":"KARLL","car":"e30"},
        {"track_id":ID,"seconds":69.4,"score":19800,"stars":2,"date":"2026-11-21T09:30:00","driver":"ZED ONE","car":"white"},
        {"track_id":ID,"seconds":75.0,"score":12050,"stars":1,"date":"2026-11-21T09:50:00","driver":"A VERY LONG NAME","car":"flame"}]
    var f := FileAccess.open(RESULTS.STORAGE,FileAccess.WRITE)
    f.store_string(JSON.stringify(rows))
    f.close()
    DRIVER.set_driver_name("KARLL")
    CARS.select("blue")
    var view: NitroRaceResults = RESULTS.new()
    root.add_child(view)
    view.show_race(ID,"OJCÓW CIRCUIT",64.3,25600,70.0,func(): pass,func(): pass,{"length_m":860.0,"laps":[{"time":21.4,"score":8300},{"time":21.5,"score":8700},{"time":21.4,"score":8600}]})
    for i in range(10):
        await process_frame
    root.get_viewport().get_texture().get_image().save_png(out+"results_driver_"+(OS.get_environment("TAG") if OS.get_environment("TAG") != "" else "phone")+".png")
    for p in [[RESULTS.STORAGE,had,backup],[DRIVER.PATH,had_d,backup_d]]:
        if p[1]:
            var w := FileAccess.open(p[0],FileAccess.WRITE)
            w.store_string(p[2])
            w.close()
        elif FileAccess.file_exists(p[0]):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(p[0]))
    print("RESULTS CAPTURED to %s" % ProjectSettings.globalize_path(out))
    quit(0)
