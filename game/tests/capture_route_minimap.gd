extends SceneTree
## Issue #18 evidence (developer tool, needs a display):
##   OUT_DIR=/abs/dir xvfb-run -s "-screen 0 720x1560x24" godot --path game \
##     --rendering-driver opengl3 --resolution 720x1560 --script res://tests/capture_route_minimap.gd
## Generates the same open route (Japan touge, seed 7) and shows the race HUD
## with the car at the start, in the middle and at the finish line. Works with
## the v0.1.33 code too (the new HUD fields are only set when they exist), so
## the same script gives the BEFORE and the AFTER frames. Every frame also
## writes the HUD numbers to <out>/minimap_<tag>.txt.
const CAT = preload("res://scripts/world/terrain/terrain_catalog.gd")
const FIELD = preload("res://scripts/world/terrain/terrain_field.gd")
const TT = preload("res://scripts/world/terrain/terrain_track.gd")
const RACE = preload("res://scenes/race.tscn")
const ROUTE_PATH: String = "user://nitro_minimap_capture_route.json"

var out_dir: String = "user://minimap/"

func _initialize() -> void:
    call_deferred("_run")

func _shot(name: String) -> void:
    for i in range(8):
        await process_frame
    root.get_viewport().get_texture().get_image().save_png(out_dir+name+".png")

func _run() -> void:
    var env_dir: String = OS.get_environment("OUT_DIR")
    if env_dir != "":
        out_dir = env_dir.trim_suffix("/")+"/"
    var tag: String = OS.get_environment("TAG") if OS.get_environment("TAG") != "" else "run"
    DirAccess.make_dir_recursive_absolute(out_dir)
    var desc: Dictionary = CAT.descriptor("jp_touge",7)
    var field: NitroTerrainField = FIELD.new("jp_touge",7)
    field.bake()
    var grid: NitroTrackGrid = TT.new_grid()
    var route: Dictionary = TT.generate_route(grid,field,desc,7)
    if not bool(route.get("ok",false)):
        printerr("route generation failed")
        quit(1)
        return
    var f := FileAccess.open(ROUTE_PATH,FileAccess.WRITE)
    f.store_string(JSON.stringify(route["data"]))
    f.close()
    ProjectSettings.set_setting("nitro/selected_track",ROUTE_PATH)
    ProjectSettings.set_setting("nitro/car_variant","red")
    var race: Node3D = RACE.instantiate()
    root.add_child(race)
    for i in range(30):
        await process_frame
    race.set_physics_process(false)
    race.race_started = true
    var track: NitroDriftTrack = race.track
    var notes := PackedStringArray()
    notes.append("closed_loop(track)=%s centerline=%d length=%.1f start_index=%d finish_index=%d finish_progress=%.4f" % [
        track.closed_loop,track.centerline.size(),track.length_metres,track.start_index,track.finish_index,track.finish_progress])
    notes.append("hud.closed_loop=%s" % str(race.hud.get("closed_loop")))
    var stops: Array = [["start",track.start_index],["mid",track.centerline.size()/2],
        ["finish",track.finish_index],["end",track.centerline.size()-1]]
    for st in stops:
        var i: int = int(st[1])
        var p: Vector2 = track.centerline[i]
        var t: Vector2 = (track.centerline[mini(i+1,track.centerline.size()-1)]-track.centerline[maxi(i-1,0)]).normalized()
        race.model.reset(p,atan2(t.x,-t.y))
        race._physics_process(1.0/120.0)
        race._update_visuals()
        for k in range(20):
            race.call("_update_camera",1.0/60.0)
        notes.append("%s: progress=%.4f dot=%s" % [st[0],race.hud.track_progress,race.hud.point_at_progress(race.hud.track_progress)])
        await _shot("minimap_%s_%s" % [tag,st[0]])
    var nf := FileAccess.open(out_dir+"minimap_"+tag+".txt",FileAccess.WRITE)
    nf.store_string("\n".join(notes)+"\n")
    nf.close()
    print("\n".join(notes))
    DirAccess.remove_absolute(ROUTE_PATH)
    print("MINIMAP CAPTURED to %s" % ProjectSettings.globalize_path(out_dir))
    quit(0)
