extends SceneTree
## Issue #19 evidence (developer tool, needs a display):
##   OUT_DIR=/abs/dir TAG=after xvfb-run -a -s "-screen 0 720x1560x24" godot --path game \
##     --rendering-driver opengl3 --resolution 720x1560 --script res://tests/capture_stream_crossing.gd
## A generated loop on the Ojców valley (seed 621727, route seed 3) is driven by
## the real race scene; the car is parked where the road crosses the stream
## (three places: 14 m before, on, 14 m after the crossing) and both race cameras
## are captured. Works with the v0.1.33 code too (BEFORE) - it only uses the
## public race / track API. Also writes the water / road numbers.
const CAT = preload("res://scripts/world/terrain/terrain_catalog.gd")
const FIELD = preload("res://scripts/world/terrain/terrain_field.gd")
const TT = preload("res://scripts/world/terrain/terrain_track.gd")
const RACE = preload("res://scenes/race.tscn")
const PATH: String = "user://nitro_stream_capture.json"

var out_dir: String = "user://stream/"

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
    DirAccess.make_dir_recursive_absolute(out_dir)
    var tag: String = OS.get_environment("TAG") if OS.get_environment("TAG") != "" else "run"
    var route_seed: int = int(OS.get_environment("ROUTE")) if OS.get_environment("ROUTE") != "" else 3
    var desc: Dictionary = CAT.descriptor("pl_ojcow",621727)
    var field: NitroTerrainField = FIELD.new("pl_ojcow",621727)
    field.bake()
    var grid: NitroTrackGrid = TT.new_grid()
    var gen: Dictionary = TT.generate_loop(grid,field,desc,route_seed)
    if not bool(gen.get("ok",false)):
        printerr("loop generation failed")
        quit(1)
        return
    var f := FileAccess.open(PATH,FileAccess.WRITE)
    f.store_string(JSON.stringify(gen["data"]))
    f.close()
    ProjectSettings.set_setting("nitro/selected_track",PATH)
    ProjectSettings.set_setting("nitro/car_variant","red")
    var race: Node3D = RACE.instantiate()
    root.add_child(race)
    for i in range(30):
        await process_frame
    race.set_physics_process(false)
    race.race_started = true
    var track: NitroDriftTrack = race.track
    var tw: NitroTerrainWorld = track.terrain
    var n: int = track.centerline.size()
    # The sample where the road is closest to the stream axis.
    var best: int = 0
    var best_off: float = INF
    for i2 in range(n):
        var l: Vector2 = tw.field.to_local(track.centerline[i2].x,track.centerline[i2].y)
        var off: float = absf(l.x-tw.field.stream_x(l.y))
        if off < best_off:
            best_off = off
            best = i2
    var notes := PackedStringArray()
    notes.append("tag=%s loop route seed %d, %d samples, crossing at sample %d (%.1f m from the stream axis)" % [tag,route_seed,n,best,best_off])
    var places: Array = [["before",-5],["on",0],["after",5]]
    for place in places:
        var i3: int = posmod(best+int(place[1]),n)
        var p: Vector2 = track.centerline[i3]
        var q: Vector2 = track.centerline[(i3+1)%n]
        var t: Vector2 = (q-p).normalized()
        race.model.reset(p,atan2(t.x,-t.y))
        race._physics_process(1.0/120.0)
        race._update_visuals()
        var l3: Vector2 = tw.field.to_local(p.x,p.y)
        var natural: float = tw.field.base_at(tw.field.to_world(tw.field.stream_x(l3.y),l3.y).x,tw.field.to_world(tw.field.stream_x(l3.y),l3.y).y)+1.0
        var level: float = tw.stream_level(l3.y) if tw.has_method("stream_level") else natural
        notes.append("%s (sample %d): road height %.2f m, water level %.2f m (natural %.2f m) -> water is %.2f m %s the road surface" % [
            place[0],i3,track.heights[i3],level,natural,absf(track.heights[i3]-level),"BELOW" if track.heights[i3] > level else "ABOVE"])
        for mode in [1,0]:
            if int(race.camera_mode) != mode:
                race._toggle_camera()
            for k in range(60):
                race.call("_update_camera",1.0/60.0)
            await _shot("stream_%s_%s_%s" % [tag,"chase" if mode == 1 else "top",place[0]])
    var nf := FileAccess.open(out_dir+"stream_"+tag+".txt",FileAccess.WRITE)
    nf.store_string("\n".join(notes)+"\n")
    nf.close()
    print("\n".join(notes))
    DirAccess.remove_absolute(PATH)
    print("STREAM CAPTURED to %s" % ProjectSettings.globalize_path(out_dir))
    quit(0)
