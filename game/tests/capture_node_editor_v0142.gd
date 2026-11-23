extends SceneTree
## v0.1.42 evidence (developer tool, needs a display). Run:
##   OUT_DIR=/abs/dir xvfb-run -a -s "-screen 0 900x2000x24" godot --path game --rendering-driver opengl3 \
##     --resolution 900x2000 --script res://tests/capture_node_editor_v0142.gd
## A Terrain Builder circuit (generated here, saved like the builder saves it) opened in the node editor: landscape, START
## marker, SET START, OPEN list, a road over the sea (red).
const TT = preload("res://scripts/world/terrain/terrain_track.gd")
const FIELD = preload("res://scripts/world/terrain/terrain_field.gd")
const CAT = preload("res://scripts/world/terrain/terrain_catalog.gd")
const EDITOR_SCENE = preload("res://scenes/track_editor.tscn")
const PATH: String = "user://nitro_track_terrain_capture_demo.json"

var out_dir: String = "user://ne/"

func _frames(n: int) -> void:
    for i in range(n):
        await process_frame

func _shot(name: String) -> void:
    await _frames(4)
    root.get_viewport().get_texture().get_image().save_png(out_dir+name+".png")
    print("SHOT ",name)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var env_dir: String = OS.get_environment("OUT_DIR")
    if env_dir != "":
        out_dir = env_dir.trim_suffix("/")+"/"
    DirAccess.make_dir_recursive_absolute(out_dir)
    var arch: String = OS.get_environment("ARCH") if OS.get_environment("ARCH") != "" else "ie_coast"
    var field: NitroTerrainField = FIELD.new(arch,int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 7)
    var grid = TT.new_grid()
    var gen: Dictionary = TT.generate_loop(grid,field,CAT.descriptor(arch,field.terrain_seed),5)
    var data: Dictionary = gen["data"]
    data["name"] = "TESTANDORI TERRAIN"
    var f := FileAccess.open(PATH,FileAccess.WRITE)
    f.store_string(JSON.stringify(data,"  ",false,true))
    f.close()
    var m := FileAccess.open("user://nitro_editor_last_path.txt",FileAccess.WRITE)
    m.store_string(PATH)
    m.close()
    var ed: Control = EDITOR_SCENE.instantiate()
    root.add_child(ed)
    await _frames(6)
    ed.call("_close_help")
    await _frames(3)
    await _shot("01_terrain_circuit_in_node_editor")
    ed.set("selected",24)
    await _frames(2)
    await _shot("02_node_selected")
    ed.call("_set_start")
    await _frames(2)
    await _shot("03_start_moved_to_the_selected_node")
    ed.call("_reverse")
    await _frames(2)
    await _shot("04_direction_reversed")
    ed.call("_undo")
    ed.call("_undo")
    ed.call("_request_open")
    await _frames(3)
    await _shot("05_open_list")
    ed.call("_close_dialog")
    var original: Array = (ed.get("data")["control_points"] as Array).duplicate(true)
    var wet: bool = false
    for shift in [Vector2(200,0),Vector2(-200,0),Vector2(0,200),Vector2(0,-200),Vector2(300,0),Vector2(-300,0),Vector2(0,300),Vector2(0,-300),
            Vector2(120,0),Vector2(-120,0),Vector2(0,120),Vector2(0,-120),Vector2(250,250),Vector2(-250,-250),Vector2(250,-250),Vector2(-250,250)]:
        var slid: Array = []
        for q in original:
            slid.append([float(q[0])+shift.x,float(q[1])+shift.y])
        (ed.get("data") as Dictionary)["control_points"] = slid
        ed.call("_validate")
        for reason in ed.get("terrain_reasons"):
            if str(reason).contains("WATER") or str(reason).contains("SEA"):
                wet = true
        if wet:
            break
    print("wet=",wet," ",str(ed.get("terrain_reasons")))
    ed.call("_fit_all")
    await _frames(2)
    await _shot("06_road_over_water_is_red")
    quit(0)
