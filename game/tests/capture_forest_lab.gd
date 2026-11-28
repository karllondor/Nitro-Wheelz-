extends SceneTree
## FOREST LAB (issue #54) evidence tool - developer only, needs a display (xvfb-run is fine). NOT part of the test suite.
##   MODE=species OUT_DIR=/abs/dir xvfb-run -a -s "-screen 0 800x800x24"   godot --path game --rendering-driver opengl3 --resolution 800x800   --script res://tests/capture_forest_lab.gd
##   MODE=touge   OUT_DIR=/abs/dir xvfb-run -a -s "-screen 0 1280x720x24"  godot --path game --rendering-driver opengl3 --resolution 1280x720  --script res://tests/capture_forest_lab.gd
##   MODE=designer OUT_DIR=/abs/dir ...                                     (the Tree Designer at the resolution given)
##   env DENSITY=0|1|2 (LOW / MEDIUM / HIGH) and TODS=DAY,GOLDEN_HOUR,NIGHT narrow the touge run.
## species : neutral-background close-ups of the eight species (NEAR), the FAR twins and the seasons, with real triangle counts;
## touge   : the REAL race scene on a seeded Touge loop (the same world, road, car positions and cameras for both), CLASSIC then
##           FOREST LAB, chase + top-down, DAY / GOLDEN HOUR / NIGHT, and per frame the engine's own draw calls / primitives /
##           objects (RenderingServer render info) plus the world rebuild time. A container renderer (llvmpipe) is NOT a phone:
##           draw calls and primitives are renderer independent, milliseconds are not and are not reported as frame times.
const F = preload("res://scripts/world/forest_lab/nitro_tree_factory.gd")
const S = preload("res://scripts/world/forest_lab/forest_lab_settings.gd")
const LAB = preload("res://scripts/world/forest_lab/forest_lab_scatter.gd")
const CAT = preload("res://scripts/world/terrain/terrain_catalog.gd")
const FIELD = preload("res://scripts/world/terrain/terrain_field.gd")
const TT = preload("res://scripts/world/terrain/terrain_track.gd")
const TIME = preload("res://scripts/lighting/time_of_day.gd")
const RACE = preload("res://scenes/race.tscn")
const DESIGNER = preload("res://scenes/forest_lab_designer.tscn")
const PATH: String = "user://nitro_forest_capture.json"

var out_dir: String = ""

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    out_dir = (OS.get_environment("OUT_DIR") if OS.get_environment("OUT_DIR") != "" else "user://forest/").trim_suffix("/")+"/"
    DirAccess.make_dir_recursive_absolute(out_dir)
    var mode: String = OS.get_environment("MODE") if OS.get_environment("MODE") != "" else "species"
    match mode:
        "species":
            await _species()
        "touge":
            await _touge()
        "designer":
            await _designer()
    quit(0)

func _shot(name: String, settle: int = 3) -> void:
    for i in range(settle):
        await process_frame
    await create_timer(0.25).timeout
    root.get_viewport().get_texture().get_image().save_jpg(out_dir+name+".jpg",0.93)

func _info() -> String:
    var dc: int = int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
    var pr: int = int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
    var ob: int = int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME))
    return "draw_calls=%d primitives=%d objects=%d" % [dc,pr,ob]

# ----------------------------------------------------------------------------------------------- species

func _studio() -> Camera3D:
    var e := Environment.new()
    e.background_mode = Environment.BG_COLOR
    e.background_color = Color("2b2740")
    e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    e.ambient_light_color = Color("a99fc4")
    e.ambient_light_energy = 0.95
    var we := WorldEnvironment.new()
    we.environment = e
    root.add_child(we)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-38,38,0)
    sun.light_energy = 1.55
    root.add_child(sun)
    var m := MeshInstance3D.new()
    var c := CylinderMesh.new()
    c.top_radius = 9.0
    c.bottom_radius = 9.0
    c.height = 0.1
    m.mesh = c
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color("3a3550")
    m.material_override = mat
    m.position.y = -0.06
    root.add_child(m)
    var cam := Camera3D.new()
    cam.fov = 32.0
    root.add_child(cam)
    cam.current = true
    return cam

func _species() -> void:
    var cam: Camera3D = _studio()
    var mat: ShaderMaterial = F.make_material(0.0)
    var order: Array[int] = [F.Type.LAYERED_PINE,F.Type.TALL_FIR,F.Type.BIRCH,F.Type.OAK,F.Type.SAKURA,F.Type.JAPANESE_MAPLE,F.Type.ROWAN,F.Type.SHRUB]
    var showcase: Array[int] = [F.Season.SUMMER,F.Season.SUMMER,F.Season.AUTUMN_GOLD,F.Season.SUMMER,F.Season.SPRING,F.Season.AUTUMN_RED,F.Season.SUMMER,F.Season.SPRING]
    var lines: PackedStringArray = []
    for pass_i in range(3):             # 0 = NEAR showcase, 1 = FAR, 2 = season strip (oak, sakura, maple, rowan)
        var items: Array = []
        if pass_i < 2:
            for i in range(8):
                items.append([order[i],showcase[i],F.LOD.NEAR if pass_i == 0 else F.LOD.FAR])
        else:
            for t in [F.Type.BIRCH,F.Type.OAK,F.Type.JAPANESE_MAPLE,F.Type.ROWAN]:
                for s in [F.Season.SPRING,F.Season.SUMMER,F.Season.AUTUMN_GOLD,F.Season.AUTUMN_ORANGE,F.Season.AUTUMN_RED]:
                    items.append([t,s,F.LOD.NEAR])
        for k in range(items.size()):
            var t: int = items[k][0]
            var mi := MeshInstance3D.new()
            mi.mesh = F.make_mesh(t,items[k][2],items[k][1])
            mi.material_override = mat
            root.add_child(mi)
            var h: float = F.BASE_HEIGHT[t]
            var d: float = maxf(h,5.0)*2.9
            cam.position = Vector3(d*0.55,h*0.52,d*0.85)
            cam.look_at(Vector3(0,h*0.48,0))
            var tag: String = ["near","far","season"][pass_i]
            await _shot("species_%s_%d_%s_%s" % [tag,k,F.species_name(t).replace(" ","_"),F.SEASON_NAMES[items[k][1]].replace(" ","_")])
            if pass_i < 2:
                lines.append("%s %s %s: %d triangles" % [F.species_name(t),"NEAR" if pass_i == 0 else "FAR",F.SEASON_NAMES[items[k][1]],F.tri_count(mi.mesh)])
            mi.queue_free()
    print("TRIS\n"+"\n".join(lines))

# ------------------------------------------------------------------------------------------------ touge

func _touge() -> void:
    var desc: Dictionary = CAT.descriptor("jp_touge",1)
    var field: NitroTerrainField = FIELD.new("jp_touge",1)
    field.bake()
    var grid: NitroTrackGrid = TT.new_grid()
    var gen: Dictionary = TT.generate_loop(grid,field,desc,5)
    var f := FileAccess.open(PATH,FileAccess.WRITE)
    f.store_string(JSON.stringify(gen["data"]))
    f.close()
    var density: int = int(OS.get_environment("DENSITY")) if OS.get_environment("DENSITY") != "" else 1
    var picks: Array[float] = [0.12,0.37,0.61]
    var rows: PackedStringArray = []
    var tods: Array = [TIME.Preset.DAY,TIME.Preset.GOLDEN_HOUR,TIME.Preset.NIGHT]
    if OS.get_environment("TODS") != "":                 # e.g. TODS=DAY: fewer runs for the density comparison
        tods = []
        for nm in OS.get_environment("TODS").split(","):
            tods.append(TIME.LABELS.find(nm.strip_edges().replace("_"," ")))
    for tod in tods:
        ProjectSettings.set_setting("nitro/selected_track",PATH)
        ProjectSettings.set_setting("nitro/car_variant","red")
        ProjectSettings.set_setting(TIME.SETTING,tod)
        var race: Node3D = RACE.instantiate()
        root.add_child(race)
        for i in range(10):
            await process_frame
        race.set_physics_process(false)
        race.race_started = false
        var track: NitroDriftTrack = race.track
        var scenery = track.terrain.scenery
        var n: int = track.centerline.size()
        for lab in [false,true]:
            var t0: int = Time.get_ticks_msec()
            var cfg: Dictionary = {}
            if lab:
                cfg = S.defaults()
                cfg["mode"] = "lab"
                cfg["density"] = density
            scenery.set_forest_config(cfg)
            scenery.rebuild_all()
            var rebuild_ms: int = Time.get_ticks_msec()-t0
            var trees: int = 0
            var tris_near: int = 0
            var tris_far: int = 0
            var mmi: int = 0
            for id in scenery.lab_stats.keys():
                trees += int(scenery.lab_stats[id]["trees"])
                tris_near += int(scenery.lab_stats[id]["tris_near"])
                tris_far += int(scenery.lab_stats[id]["tris_far"])
                mmi += int(scenery.lab_stats[id]["mmi"])
            var classic_trees: int = 0
            for id in scenery.chunk_nodes.keys():
                for ch in (scenery.chunk_nodes[id] as Node3D).get_children():
                    if ch is MultiMeshInstance3D and str(ch.name).begins_with("Trees "):
                        classic_trees += (ch as MultiMeshInstance3D).multimesh.instance_count
            rows.append("WORLD %s %s: rebuild %d ms, trees classic %d / lab %d, lab MultiMeshes %d, lab mesh generation total %.1f ms (cached)" % [
                TIME.LABELS[tod],"LAB" if lab else "CLASSIC",rebuild_ms,classic_trees,trees,mmi,LAB.gen_ms])
            for cam_i in range(2):
                var want_mode: int = 0 if cam_i == 1 else 1
                if int(race.camera_mode) != want_mode:
                    race._toggle_camera()
                for k in range(picks.size()):
                    var at: int = int(float(n)*picks[k])
                    var p: Vector2 = track.centerline[at]
                    var tn: Vector2 = (track.centerline[(at+1)%n]-p).normalized()
                    race.model.reset(p,atan2(tn.x,-tn.y))
                    race._physics_process(1.0/120.0)
                    race._update_visuals()
                    for s2 in range(60):
                        race.call("_update_camera",1.0/60.0)
                    var tag: String = "%s_%s_%s_%d" % ["lab" if lab else "classic",TIME.LABELS[tod].replace(" ","").to_lower(),"top" if cam_i == 1 else "chase",k]
                    await _shot("touge_"+tag,4)
                    rows.append("FRAME %s %s" % [tag,_info()])
        race.queue_free()
        await process_frame
    DirAccess.remove_absolute(PATH)
    print("\n".join(rows))
    # A dense hillside seen from above the road (DAY): CLASSIC, then FOREST LAB at the density given.
    ProjectSettings.set_setting("nitro/selected_track",PATH)
    var f2 := FileAccess.open(PATH,FileAccess.WRITE)
    f2.store_string(JSON.stringify(gen["data"]))
    f2.close()
    ProjectSettings.set_setting(TIME.SETTING,TIME.Preset.DAY)
    var race2: Node3D = RACE.instantiate()
    root.add_child(race2)
    for i2 in range(10):
        await process_frame
    race2.set_physics_process(false)
    race2.race_started = false
    var tr2: NitroDriftTrack = race2.track
    var sc2 = tr2.terrain.scenery
    var n2: int = tr2.centerline.size()
    for lab2 in [false,true]:
        var cfg2: Dictionary = {}
        if lab2:
            cfg2 = S.defaults()
            cfg2["mode"] = "lab"
            cfg2["density"] = density
        sc2.set_forest_config(cfg2)
        sc2.rebuild_all()
        for k2 in range(2):
            var at2: int = int(float(n2)*[0.20,0.52][k2])
            var p2: Vector2 = tr2.centerline[at2]
            var t2: Vector2 = (tr2.centerline[(at2+1)%n2]-p2).normalized()
            var nrm2 := Vector2(-t2.y,t2.x)
            var best_side: float = 1.0
            var best_cnt: int = -1
            for side in [-1.0,1.0]:
                var cnt: int = 0
                for id in sc2.chunk_nodes.keys():
                    for ch in (sc2.chunk_nodes[id] as Node3D).get_children():
                        pass
                var probe: Vector2 = p2+nrm2*side*45.0
                cnt = int(tr2.terrain.field.mask_at(tr2.terrain.field.forest,probe.x,probe.y)*100.0)
                if cnt > best_cnt:
                    best_cnt = cnt
                    best_side = side
            var gy: float = float(tr2.terrain.field.height_at(p2.x,p2.y))
            var from3 := Vector3(p2.x-nrm2.x*best_side*10.0,gy+14.0,p2.y-nrm2.y*best_side*10.0)
            var look := Vector3(p2.x+nrm2.x*best_side*70.0,gy+4.0,p2.y+nrm2.y*best_side*70.0)
            race2.race_started = false
            race2.chase.fov = 62.0
            race2.chase.far = 900.0
            race2.chase.current = true
            race2.chase.global_position = from3
            race2.chase.look_at(look)
            await _shot("touge_hillside_%s_%d" % ["lab" if lab2 else "classic",k2],5)
            rows.append("FRAME hillside_%s_%d %s" % ["lab" if lab2 else "classic",k2,_info()])
    DirAccess.remove_absolute(PATH)
    print("\n".join(rows.slice(rows.size()-4)))

# ---------------------------------------------------------------------------------------------- designer

func _designer() -> void:
    var d: Control = DESIGNER.instantiate()
    d.set("navigate_enabled",false)
    root.add_child(d)
    for i in range(6):
        await process_frame
    await _shot("designer_edited",6)
    d.set("view",2)
    d.set("_dirty",true)
    await _shot("designer_gallery",8)
    d.set("view",1)
    d.set("_dirty",true)
    await _shot("designer_compare",8)
    print("DESIGNER captured")
