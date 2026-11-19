extends SceneTree
## Developer capture for the procedural world vertical slice (not in the
## automated suite). Same road layout in the 3D builder and in the race:
##   xvfb-run godot --path game --rendering-driver opengl3 --resolution 720x1600 \
##     --script res://tests/capture_world.gd -- /abs/out prefix [builder|race_top|race_chase|all]
## The layout is fixed (a 16-tile rectangle with a bay) so BEFORE / AFTER and
## builder / race shots show the same place.
const GRID = preload("res://scripts/world/track_grid.gd")
const LAYOUT: Array = [[2,3],[3,3],[4,3],[5,3],[5,4],[5,5],[5,6],[5,7],[5,8],[4,8],[3,8],[3,7],[2,7],[2,6],[2,5],[2,4]]
const SPOT_TILE: Vector2i = Vector2i(5,5)    # the car sits here (right straight, heading north)
var out: String = "user://"
var prefix: String = "shot"
var what: String = "all"

func _initialize() -> void:
    var a: PackedStringArray = OS.get_cmdline_user_args()
    if a.size() > 0: out = a[0]
    if a.size() > 1: prefix = a[1]
    if a.size() > 2: what = a[2]
    DirAccess.make_dir_recursive_absolute(out)
    call_deferred("_run")

func _shot(name: String) -> void:
    for i in range(6):
        await process_frame
    root.get_viewport().get_texture().get_image().save_png(out.path_join(prefix+"_"+name+".png"))

func _write_draft() -> void:
    var tiles: Array = []
    var pairs: Array = []
    for i in range(LAYOUT.size()):
        var a: Array = LAYOUT[i]
        var b: Array = LAYOUT[(i+1)%LAYOUT.size()]
        tiles.append(a)
        pairs.append([a[0],a[1],b[0],b[1]])
    var f := FileAccess.open("user://nitro_builder_draft.json",FileAccess.WRITE)
    f.store_string(JSON.stringify({"version":1,"cols":8,"rows":12,"tiles":tiles,"links":pairs,"world_seed":2106}))
    f.close()

func _run() -> void:
    _write_draft()
    var builder: Node = (load("res://scenes/track_builder.tscn") as PackedScene).instantiate()
    root.add_child(builder)
    await process_frame
    if what in ["builder","all"]:
        await _shot("builder")
    if what in ["builder","zoom","all"]:
        # Close-up of the town along the right-hand straight.
        var g0: NitroTrackGrid = GRID.new(8,12)
        var focus: Vector2 = g0.world_of(SPOT_TILE)+Vector2(22.0,0.0)
        builder.set("cam_goal_target",Vector3(focus.x,0,focus.y))
        builder.set("cam_target",Vector3(focus.x,0,focus.y))
        builder.set("cam_size",150.0)
        builder.set("cam_goal_size",150.0)
        builder.call("_apply_camera")
        await _shot("builder_zoom")
    if what in ["closeup","all"]:
        # 3/4 perspective close-up of the town (review of the modules).
        var w: NitroProceduralWorld = builder.get("world")
        var lots: Array = []
        for c in w.plan_cells.keys():
            if str(w.plan_cells[c]["role"]) == "lot":
                lots.append(c)
        lots.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x*100+a.y < b.x*100+b.y)
        var cam := Camera3D.new()
        cam.fov = 50.0
        builder.add_child(cam)
        for k in range(2):
            var pick: Vector2i = lots[int(lots.size()*(0.35 if k == 0 else 0.7))]
            var centre: Vector2 = w.rules.cell_centre(pick)
            var f := Vector2(w.plan_cells[pick]["f"])
            var eye: Vector2 = centre+f*46.0+Vector2(-f.y,f.x)*30.0
            cam.position = Vector3(eye.x,26.0,eye.y)
            cam.look_at(Vector3(centre.x,2.0,centre.y),Vector3.UP)
            cam.current = true
            await _shot("closeup_%d" % k)
        cam.queue_free()
        (builder.get("camera") as Camera3D).current = true
    builder.call("_write_track","user://nitro_track_world_capture.json","WORLD CAPTURE","world_capture")
    builder.queue_free()
    await process_frame
    if what in ["race_top","race_chase","all"]:
        ProjectSettings.set_setting("nitro/selected_track","user://nitro_track_world_capture.json")
        var race: Node3D = (load("res://scenes/race.tscn") as PackedScene).instantiate()
        root.add_child(race)
        await process_frame
        race.set_physics_process(false)
        var g: NitroTrackGrid = GRID.new(8,12)
        var spot: Vector2 = g.world_of(SPOT_TILE)
        race.get("model").reset(spot,0.0)   # heading 0 = north (-z)
        var touch: Control = race.get("touch")
        if touch != null:
            touch.visible = true
        for i in range(120):
            race.call("_update_camera",1.0/60.0)
        race.call("_update_visuals")
        if what in ["race_top","all"]:
            await _shot("race_top")
        race.call("_toggle_camera")
        for i in range(120):
            race.call("_update_camera",1.0/60.0)
        if what in ["race_chase","all"]:
            await _shot("race_chase")
        if what in ["pair","all"]:
            # Same camera transform in the race and in the builder.
            var chase: Camera3D = race.get("chase")
            var xf: Transform3D = chase.global_transform
            var fov: float = chase.fov
            race.queue_free()
            await process_frame
            await _shot_builder_with_camera(xf,fov)
    if what in ["adjacency","all"]:
        await _adjacency()
    quit(0)

func _shot_builder_with_camera(xf: Transform3D, fov: float) -> void:
    _write_draft()
    var b: Node = (load("res://scenes/track_builder.tscn") as PackedScene).instantiate()
    root.add_child(b)
    await process_frame
    var cam := Camera3D.new()
    cam.fov = fov
    b.add_child(cam)
    cam.global_transform = xf
    cam.current = true
    await _shot("pair_builder")
    b.queue_free()
    await process_frame

## Stand-alone garage -> road grows one tile -> joined 2x1 workshop ->
## UNDO -> stand-alone again (same 3/4 camera for all three).
func _adjacency() -> void:
    var RULES = load("res://scripts/world/scenery_rules.gd")
    var W = load("res://scripts/world/procedural_world.gd")
    var probe: NitroProceduralWorld = W.new()
    root.add_child(probe)
    var found: Dictionary = {}
    for y in range(2,10):
        for x0 in range(1,4):
            for length in range(2,4):
                if not found.is_empty():
                    break
                var g: NitroTrackGrid = GRID.new(8,12)
                var cells: Array = []
                for k in range(length):
                    cells.append(Vector2i(x0+k,y))
                for i in range(cells.size()-1):
                    g.link(cells[i],cells[i+1])
                probe.generate(g.links,8,12,2106)
                var before: Dictionary = probe.plan_cells.duplicate()
                var ext := Vector2i(x0+length,y)
                g.link(cells.back(),ext)
                probe.update(g.links)
                for c in probe.plan_cells.keys():
                    if str(probe.plan_cells[c]["role"]) == "lot" and before.has(c) and str(before[c]["role"]) == "lot" \
                            and RULES.row_of(before,c).size() == 1 and RULES.row_of(probe.plan_cells,c).size() == 2 \
                            and Vector2i(before[c]["f"]) == Vector2i(probe.plan_cells[c]["f"]) \
                            and absf(float(before[c]["v"])-float(probe.plan_cells[c]["v"])) < 0.01:
                        var row: Array = RULES.row_of(probe.plan_cells,c)
                        found = {"cells":cells,"ext":ext,"cell":c,"partner":row[1] if row[0] == c else row[0]}
                        break
    probe.queue_free()
    if found.is_empty():
        return
    var tiles: Array = []
    var pairs: Array = []
    var cells2: Array = found["cells"]
    for i in range(cells2.size()):
        tiles.append([cells2[i].x,cells2[i].y])
        if i+1 < cells2.size():
            pairs.append([cells2[i].x,cells2[i].y,cells2[i+1].x,cells2[i+1].y])
    var f := FileAccess.open("user://nitro_builder_draft.json",FileAccess.WRITE)
    f.store_string(JSON.stringify({"version":1,"cols":8,"rows":12,"tiles":tiles,"links":pairs,"world_seed":2106}))
    f.close()
    var b: Node = (load("res://scenes/track_builder.tscn") as PackedScene).instantiate()
    root.add_child(b)
    await process_frame
    var w: NitroProceduralWorld = b.get("world")
    var c: Vector2i = found["cell"]
    var centre: Vector2 = (w.rules.cell_centre(c)+w.rules.cell_centre(found["partner"]))*0.5
    var fv := Vector2(w.plan_cells[c]["f"])
    var side := Vector2(-fv.y,fv.x)
    var cam := Camera3D.new()
    cam.fov = 46.0
    b.add_child(cam)
    var eye: Vector2 = centre+fv*50.0+side*14.0
    cam.position = Vector3(eye.x,30.0,eye.y)
    cam.look_at(Vector3(centre.x,2.0,centre.y),Vector3.UP)
    cam.current = true
    await _shot("adj_1_standalone")
    b.call("begin_stroke",cells2.back())
    b.call("move_stroke",found["ext"])
    b.call("end_stroke")
    await _shot("adj_2_joined")
    b.call("_undo")
    await _shot("adj_3_undo")
    print("ADJACENCY cell %s, tiles %s + %s" % [str(c),str(cells2),str(found["ext"])])
