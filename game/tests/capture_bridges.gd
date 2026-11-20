extends SceneTree
## v0.1.27 evidence: side views of road bridges per landscape. For each
## archetype a straight road is laid across the deepest dip found in the
## play area (heights = a straight grade between the two ends), so the
## terrain-first rules turn the valley crossing into a bridge (stone arches
## in Poland / Ireland, concrete in Japan). Output: OUT_DIR (env).
const CAT = preload("res://scripts/world/terrain/terrain_catalog.gd")
const FIELD = preload("res://scripts/world/terrain/terrain_field.gd")
const WORLD = preload("res://scripts/world/terrain/terrain_world.gd")
const PROFILE = preload("res://scripts/world/terrain/road_profile.gd")

var out_dir: String = "user://bridge_captures/"

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var env_dir: String = OS.get_environment("OUT_DIR")
    if env_dir != "":
        out_dir = env_dir.trim_suffix("/")+"/"
    DirAccess.make_dir_recursive_absolute(out_dir)
    var report: Array = []
    for a in ["pl_tatry","pl_ojcow","ie_hills","jp_touge"]:
        var f: NitroTerrainField = FIELD.new(a,1)
        f.bake()
        # Deepest straight crossing (x direction) with a moderate end grade.
        var best: Dictionary = {}
        var z: float = -FIELD.PLAY_HALF_Z+60.0
        while z < FIELD.PLAY_HALF_Z-60.0:
            for x0 in [-300.0,-220.0,-140.0]:
                var x1: float = x0+260.0
                var h0: float = f.height_at(x0,z)
                var h1: float = f.height_at(x1,z)
                if absf(h1-h0)/260.0 > 0.05:
                    continue
                var dip: float = 0.0
                var cut: float = 0.0
                var x: float = x0
                while x <= x1:
                    var line: float = lerpf(h0,h1,(x-x0)/260.0)
                    dip = maxf(dip,line-f.base_at(x,z))
                    cut = maxf(cut,f.base_at(x,z)-line)
                    x += 8.0
                if cut < 6.0 and dip > float(best.get("dip",0.0)) and dip < PROFILE.MAX_PIER_M-4.0:
                    best = {"z":z,"x0":x0,"x1":x1,"h0":h0+0.5,"h1":h1+0.5,"dip":dip}
            z += 16.0
        if best.is_empty():
            report.append({"archetype":a,"bridge":"no dip found"})
            continue
        var samples: Array[Vector2] = []
        var heights := PackedFloat32Array()
        var hw := PackedFloat32Array()
        var xs: float = float(best["x0"])
        while xs <= float(best["x1"])+0.01:
            samples.append(Vector2(xs,float(best["z"])))
            heights.append(lerpf(float(best["h0"]),float(best["h1"]),(xs-float(best["x0"]))/260.0))
            hw.append(12.0)
            xs += 4.6
        var w := WORLD.new()
        w.setup(CAT.descriptor(a,1))
        w.field = f
        root.add_child(w)
        w.build()
        w.set_road(samples,hw,heights,false)
        # A flat ribbon stands in for the race road surface.
        var st := SurfaceTool.new()
        st.begin(Mesh.PRIMITIVE_TRIANGLES)
        for i in range(samples.size()-1):
            var p0: Vector2 = samples[i]
            var p1: Vector2 = samples[i+1]
            var q: Array = [Vector3(p0.x,heights[i]+0.05,p0.y-12.0),Vector3(p1.x,heights[i+1]+0.05,p1.y-12.0),
                Vector3(p1.x,heights[i+1]+0.05,p1.y+12.0),Vector3(p0.x,heights[i]+0.05,p0.y+12.0)]
            for k in [0,1,2,0,2,3]:
                st.set_normal(Vector3.UP)
                st.set_color(Color(0.16,0.16,0.18))
                st.add_vertex(q[k])
        var road_mi := MeshInstance3D.new()
        road_mi.mesh = st.commit()
        var rm := StandardMaterial3D.new()
        rm.vertex_color_use_as_albedo = true
        rm.cull_mode = BaseMaterial3D.CULL_DISABLED
        road_mi.material_override = rm
        w.add_child(road_mi)
        var cam := Camera3D.new()
        cam.fov = 55.0
        cam.far = 4000.0
        w.add_child(cam)
        var mid := Vector3((float(best["x0"])+float(best["x1"]))*0.5,(float(best["h0"])+float(best["h1"]))*0.5,float(best["z"]))
        var side: float = 1.0
        if f.height_at(mid.x,mid.z+150.0) > f.height_at(mid.x,mid.z-150.0):
            side = -1.0
        cam.position = mid+Vector3(-40.0,-float(best["dip"])*0.45+6.0,side*170.0)
        cam.look_at(mid+Vector3(0,-float(best["dip"])*0.45,0),Vector3.UP)
        cam.current = true
        for _i in range(4):
            await process_frame
        root.get_viewport().get_texture().get_image().save_png(out_dir+"%s_bridge_side.png" % a)
        report.append({"archetype":a,"dip_m":snappedf(float(best["dip"]),0.1),"structures":w.structure_counts()})
        root.remove_child(w)
        w.free()
    var file := FileAccess.open(out_dir+"bridges.json",FileAccess.WRITE)
    file.store_string(JSON.stringify(report,"  "))
    file.close()
    print("BRIDGES %s" % JSON.stringify(report))
    quit(0)
