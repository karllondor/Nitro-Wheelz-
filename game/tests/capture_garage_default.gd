extends SceneTree
## Issue #22 evidence (developer tool, needs a display):
##   OUT_DIR=/abs/dir xvfb-run -a -s "-screen 0 720x1560x24" godot --path game \
##     --rendering-driver opengl3 --resolution 720x1560 --script res://tests/capture_garage_default.gd
## The player garage with the DEFAULT settings (nothing stored): every car, then
## PAINT + WHEELS on the Lada RED and the RYU-32 stripes preset. Restores the
## garage file. Needs the `legacy_procedural_cars` default (v0.1.34); with the
## v0.1.33 code it shows the procedural cars.
const GARAGE = preload("res://scenes/garage.tscn")
const COSMETICS = preload("res://scripts/vehicles/car_cosmetics.gd")
const CARS = preload("res://scripts/vehicles/car_catalog.gd")

func _initialize() -> void:
    call_deferred("_run")

func _shot(name: String, out: String) -> void:
    for i in range(10):
        await process_frame
    root.get_viewport().get_texture().get_image().save_png(out+name+".png")

func _run() -> void:
    var out: String = OS.get_environment("OUT_DIR")
    out = (out if out != "" else "user://garage").trim_suffix("/")+"/"
    DirAccess.make_dir_recursive_absolute(out)
    var backup := ConfigFile.new()
    var had: bool = backup.load(COSMETICS.GARAGE_PATH) == OK
    var garage: Control = GARAGE.instantiate()
    root.add_child(garage)
    await process_frame
    for v in ["red","white","blue","e30","flame"]:
        garage.call("_choose",v)
        await _shot("garage_"+v,out)
    garage.call("_choose","red")
    garage.call("_next_paint")
    garage.call("_next_wheels")
    await _shot("garage_red_paint_wheels",out)
    garage.call("_choose","blue")
    for k in range(COSMETICS.paints(CARS.cosmetic_profile("blue")).size()):
        garage.call("_next_paint")
        var txt: String = (garage.get("version_label") as Label).text
        if txt.contains("STRIPES"):
            await _shot("garage_blue_stripes",out)
            break
    if had:
        backup.save(COSMETICS.GARAGE_PATH)
    elif FileAccess.file_exists(COSMETICS.GARAGE_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(COSMETICS.GARAGE_PATH))
    print("GARAGE CAPTURED to %s" % ProjectSettings.globalize_path(out))
    quit(0)
