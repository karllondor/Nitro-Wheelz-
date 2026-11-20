extends SceneTree
## v0.1.25 terrain-first evidence captures (run under a display, e.g.
## xvfb-run ... --resolution 720x1280 --script res://tests/capture_terrain.gd).
## For every archetype (seed 1, generated loop): the builder before the road
## (generated landscape), the builder with the road (terrain adapted), and
## the race on the SAME saved track (top-down + chase). Plus a paddock
## close-up and the Irish cliff shelf. Output: OUT_DIR (env) or user://.
const CAT = preload("res://scripts/world/terrain/terrain_catalog.gd")
const TT = preload("res://scripts/world/terrain/terrain_track.gd")
const BUILDER = preload("res://scenes/terrain_builder.tscn")
const RACE = preload("res://scenes/race.tscn")
const DT: float = 1.0/120.0

var out_dir: String = "user://terrain_captures/"
var stats: Array = []

func _initialize() -> void:
    call_deferred("_run")

func _shot(name: String) -> void:
    for i in range(3):
        await process_frame
    root.get_viewport().get_texture().get_image().save_png(out_dir+name+".png")

func _run() -> void:
    var env_dir: String = OS.get_environment("OUT_DIR")
    if env_dir != "":
        out_dir = env_dir.trim_suffix("/")+"/"
    DirAccess.make_dir_recursive_absolute(out_dir)
    DirAccess.remove_absolute("user://nitro_terrain_builder_draft.json")
    var only: String = OS.get_environment("ARCH")
    for a in CAT.ORDER:
        if only != "" and a != only:
            continue
        DirAccess.remove_absolute("user://nitro_terrain_builder_draft.json")
        var b: Node3D = BUILDER.instantiate()
        root.add_child(b)
        await process_frame
        b._pick_country(str(CAT.info(a)["country"]))
        b._pick_landscape(a)
        b.terrain_seed = 1
        b.event_mode = "pro" if a in ["pl_tatry","jp_sakura"] else "club"
        var t0: int = Time.get_ticks_usec()
        b.generate_terrain(false)
        var gen_ms: float = float(Time.get_ticks_usec()-t0)/1000.0
        b._refresh_titles()
        b._fit()
        b.cam_target = b.goal_target
        b.cam_dist = b.goal_dist
        b.cam_pitch = b.goal_pitch
        b._apply_camera()
        await _shot("%s_1_terrain" % a)
        b._enter_build()
        var t1: int = Time.get_ticks_usec()
        var res: Dictionary = TT.generate_loop(b.grid,b.world.field,b.descriptor(),7)
        b.route_start = TT.route_order(b.grid)["order"][0]
        b._after_edit()
        var adapt_ms: float = float(Time.get_ticks_usec()-t1)/1000.0
        b._set_view("3D")
        b._fit()
        b.cam_target = b.goal_target
        b.cam_dist = b.goal_dist
        b.cam_pitch = b.goal_pitch
        b.cam_yaw = 20.0
        b.goal_yaw = 20.0
        await _shot("%s_2_builder_road" % a)
        var vi: Dictionary = b.world.scenery.venue_info
        if vi.get("pad",null) != null:
            var pad: Array = vi["pad"]
            b.goal_target = Vector3(float(pad[0]),b.world.height_at(float(pad[0]),float(pad[1])),float(pad[1]))
            b.cam_target = b.goal_target
            b.cam_dist = 150.0
            b.goal_dist = 150.0
            b.cam_pitch = 30.0
            b.goal_pitch = 30.0
            await _shot("%s_3_paddock" % a)
        var ms: Dictionary = b.world.mesh_stats()
        var path: String = "user://nitro_track_capture_%s.json" % a
        if not b._write(path,"capture "+a,"capture_"+a):
            print("capture: could not write %s (%s)" % [a,b.status_label.text])
            root.remove_child(b)
            b.free()
            continue
        stats.append({"archetype":a,"generate_ms":gen_ms,"adapt_ms":adapt_ms,"length_m":float(b.last_eval["compiled"]["length_metres"]),
            "max_grade":float(b.last_eval.get("max_grade",0.0)),"structures":b.world.structure_counts(),
            "scenery":b.world.scenery.summary()["counts"],"mesh":ms,"venue":vi.get("pad",null) != null})
        root.remove_child(b)
        b.free()
        # Race on the same saved track.
        ProjectSettings.set_setting("nitro/selected_track",path)
        var t2: int = Time.get_ticks_usec()
        var race: Node3D = RACE.instantiate()
        race.set_physics_process(false)
        root.add_child(race)
        var load_ms: float = float(Time.get_ticks_usec()-t2)/1000.0
        stats[stats.size()-1]["race_load_ms"] = load_ms
        var tr: NitroDriftTrack = race.track
        var n: int = tr.centerline.size()
        var steep: int = 0
        var best: float = -1.0
        for i in range(0,n,3):
            var g: float = absf(tr.heights[(i+3)%n]-tr.heights[i])
            if g > best:
                best = g
                steep = i
        var p: Vector2 = tr.centerline[steep]
        var t: Vector2 = (tr.centerline[(steep+1)%n]-p).normalized()
        race.model.reset(p-t*20.0,atan2(t.x,-t.y))
        race.model.velocity = t*14.0
        race.race_started = true
        for k in range(150):
            race._physics_process(DT)
            race._process(DT)
        await _shot("%s_4_race_topdown" % a)
        race._toggle_camera()
        for k2 in range(90):
            race._physics_process(DT)
            race._process(DT)
        await _shot("%s_5_race_chase" % a)
        root.remove_child(race)
        race.free()
        DirAccess.remove_absolute(path)
    var f := FileAccess.open(out_dir+"terrain_capture_stats.json",FileAccess.WRITE)
    f.store_string(JSON.stringify(stats,"  "))
    f.close()
    print("CAPTURED %d archetypes to %s" % [stats.size(),ProjectSettings.globalize_path(out_dir)])
    quit(0)
