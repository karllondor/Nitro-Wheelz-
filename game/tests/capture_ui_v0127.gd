extends SceneTree
## v0.1.27 evidence: the new interface states at phone size - loading card
## (full + compact), pause menu with EDIT TRACK, SAVE TRACK name dialog,
## MY TRACKS list, builder with the MOVE button. Output: OUT_DIR (env).
const BUILDER = preload("res://scenes/terrain_builder.tscn")
const RACE = preload("res://scenes/race.tscn")
const BUSY = preload("res://scripts/ui/busy_overlay.gd")
const TT = preload("res://scripts/world/terrain/terrain_track.gd")

var out_dir: String = "user://ui_captures/"

func _initialize() -> void:
    call_deferred("_run")

func _shot(name: String) -> void:
    for i in range(4):
        await process_frame
    root.get_viewport().get_texture().get_image().save_png(out_dir+name+".png")

func _run() -> void:
    var env_dir: String = OS.get_environment("OUT_DIR")
    if env_dir != "":
        out_dir = env_dir.trim_suffix("/")+"/"
    DirAccess.make_dir_recursive_absolute(out_dir)
    DirAccess.remove_absolute("user://nitro_terrain_builder_draft.json")
    var b: Node3D = BUILDER.instantiate()
    root.add_child(b)
    await process_frame
    b._pick_country("poland")
    b._pick_landscape("pl_tatry")
    b.terrain_seed = 3
    b.generate_terrain(false)
    b._enter_build()
    TT.generate_loop(b.grid,b.world.field,b.descriptor(),5)
    b.route_start = TT.route_order(b.grid)["order"][0]
    b._after_edit()
    b._fit()
    b.cam_target = b.goal_target
    b.cam_dist = b.goal_dist
    b._apply_camera()
    var busy: NitroBusy = BUSY.open(b,"GENERATING TERRAIN")
    busy.set_text("GENERATING TERRAIN","TATRY MOUNTAIN • POLAND")
    busy.set_progress(0.45)
    await _shot("ui_loading_full")
    busy.close()
    var small: NitroBusy = BUSY.open(b,"UPDATING TERRAIN",true)
    await _shot("ui_loading_compact")
    small.close()
    b._toggle_pan()
    await _shot("ui_builder_move")
    b._toggle_pan()
    b._name_dialog()
    await _shot("ui_save_name")
    b._close_dialog()
    b._persist_track("TATRY SUNSET ROUTE")
    b._open_tracks()
    await _shot("ui_my_tracks")
    b._close_dialog()
    var path: String = b.loaded_path
    root.remove_child(b)
    b.free()
    ProjectSettings.set_setting("nitro/selected_track",path)
    var race: Node3D = RACE.instantiate()
    race.set_physics_process(false)
    root.add_child(race)
    await process_frame
    race._toggle_pause()
    await _shot("ui_pause_menu")
    root.remove_child(race)
    race.free()
    DirAccess.remove_absolute(path)
    print("UI CAPTURED to %s" % ProjectSettings.globalize_path(out_dir))
    quit(0)
