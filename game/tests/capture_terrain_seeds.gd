extends SceneTree
## v0.1.25 evidence: 8 archetypes x 10 fixed terrain seeds, generated
## landscape only (before any road), same oblique camera. Run under a
## display; OUT_DIR env = output folder. Thumbnails are composed into one
## sheet per archetype afterwards (tools or by hand).
const CAT = preload("res://scripts/world/terrain/terrain_catalog.gd")
const FIELD = preload("res://scripts/world/terrain/terrain_field.gd")
const WORLD = preload("res://scripts/world/terrain/terrain_world.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var out: String = OS.get_environment("OUT_DIR").trim_suffix("/")+"/"
    if out == "/":
        out = "user://terrain_seeds/"
    DirAccess.make_dir_recursive_absolute(out)
    var vp := SubViewport.new()
    vp.size = Vector2i(480,320)
    vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(vp)
    var cam := Camera3D.new()
    cam.fov = 50.0
    cam.far = 9000.0
    vp.add_child(cam)
    cam.current = true
    var rows: Array = []
    for a in CAT.ORDER:
        for s in range(1,11):
            var t0: int = Time.get_ticks_usec()
            var w := WORLD.new()
            w.setup(CAT.descriptor(a,s))
            w.field.bake()
            vp.add_child(w)
            w.build()
            w.set_fog_scale(0.0)
            var ms: float = float(Time.get_ticks_usec()-t0)/1000.0
            cam.position = Vector3(0.0,760.0,980.0)
            cam.look_at(Vector3(0.0,w.height_at(0.0,0.0),40.0))
            for i in range(3):
                await process_frame
            vp.get_texture().get_image().save_png(out+"%s_seed%02d.png" % [a,s])
            var m: Dictionary = w.field.build_map()
            var cnt: Array = [0,0,0]
            for c in m.keys():
                cnt[int(m[c]["state"])] += 1
            rows.append({"archetype":a,"seed":s,"fingerprint":w.field.fingerprint(),"build_ms":ms,
                "green":cnt[0],"amber":cnt[1],"red":cnt[2]})
            vp.remove_child(w)
            w.free()
    var f := FileAccess.open(out+"terrain_seeds.json",FileAccess.WRITE)
    f.store_string(JSON.stringify(rows,"  "))
    f.close()
    print("SEEDS CAPTURED %d" % rows.size())
    quit(0)
