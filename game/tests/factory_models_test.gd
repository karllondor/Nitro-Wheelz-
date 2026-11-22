extends SceneTree
## Car Factory migration (v0.1.30): Lada 2106 RED / WHITE as ONE GLB with
## geometry variants, default ON in the player garage (legacy opt-out).
##  * switch OFF: the earlier procedural Lada is available for regression;
##  * switch ON: RED and WHITE build NitroGlbCar from the same GLB with
##    variant slots 1 / 2, their own paint and wheels, 3 body materials;
##  * budget per variant (only the faces that variant shows) and draw calls;
##  * gameplay untouched: handling identical ON / OFF, footprint within the
##    catalog length / width, wheelbase 2.424 m in the GLB;
##  * the garage and the race build the same car.
const CARS = preload("res://scripts/vehicles/car_catalog.gd")
const COSMETICS = preload("res://scripts/vehicles/car_cosmetics.gd")
const GARAGE_SCENE = "res://scenes/garage.tscn"
const BUDGET_TRIANGLES: int = 42000
const BUDGET_DRAW_CALLS: int = 8

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var was_on: bool = CARS.factory_test_models()
    var was_look: String = CARS.factory_test_look()
    var garage_backup := ConfigFile.new()
    var had_garage: bool = garage_backup.load(COSMETICS.GARAGE_PATH) == OK
    var err: String = await _checks()
    CARS.set_factory_test_models(was_on)
    CARS.set_factory_test_look(was_look)
    if had_garage:
        garage_backup.save(COSMETICS.GARAGE_PATH)
    if not err.is_empty():
        printerr("FAIL: "+err)
        quit(1)
        return
    print("PASS: Car Factory GLB models are the DEFAULT (DEVELOPER switch OFF = earlier procedural Lada / RYU-32): Lada one GLB with RED / WHITE geometry variants (slots, own paint + wheels), RYU-32 one GLB, stripes = a PAINT preset (paint material only), FLAME = separate AI-body car (always factory GLB, RYU-32 handling + V8), 3 body materials, budget, footprint + wheelbase, handling + engine profiles identical on / off, garage = race car")
    print("NOT RUN: owner visual acceptance; frame time on a real Android phone")
    for _f in range(3):
        await process_frame
    quit(0)

func _checks() -> String:
    var handling_off: Dictionary = CARS.handling("red").duplicate(true)
    var ryu_off: Dictionary = CARS.handling("blue").duplicate(true)
    var ryu_engine: Dictionary = CARS.engine("blue").duplicate(true)
    CARS.set_factory_test_models(false)
    for v in ["red","white","blue"]:
        var classic: Node3D = CARS.make(v)
        var ok: bool = (classic is NitroLadaLowPoly) if v != "blue" else (classic is NitroCoupeLowPoly)
        classic.free()
        if not ok:
            return "Switch OFF must keep the procedural model (%s)" % v
    CARS.set_factory_test_models(true)
    if CARS.handling("red") != handling_off or str(CARS.profile("red").get("id","")) != "lada_13b":
        return "Factory test models must not touch the Lada handling profile"
    if CARS.handling("blue") != ryu_off or CARS.engine("blue") != ryu_engine or int(ryu_engine["cylinders"]) != 8:
        return "Factory test models must not touch the RYU-32 handling / V8 engine profile"
    if CARS.uses_factory_test_model("e30"):
        return "The E30 is already a factory car (no test switch)"
    var expect: Dictionary = {"red":[1,"wheel_lada_5spoke"],"white":[2,"wheel_lada_mesh"]}
    var glb_path: String = ""
    for v in expect.keys():
        var car: Node3D = CARS.make(v)
        root.add_child(car)
        await process_frame
        if not (car is NitroGlbCar):
            return "Switch ON: %s must be the factory GLB car" % v
        var g: NitroGlbCar = car
        var model: Dictionary = CARS.factory_model(v)["model"]
        if glb_path != "" and str(model["glb"]) != glb_path:
            return "RED and WHITE must share one GLB"
        glb_path = str(model["glb"])
        if g.variant_slot != int(expect[v][0]):
            return "%s must use variant slot %d" % [v,int(expect[v][0])]
        if str(g.cosmetic.get("wheel_asset_id","")) != str(expect[v][1]):
            return "%s wears the wrong wheels" % v
        if g.front_wheels.size() != 2 or g.rolling_wheels.size() != 4:
            return "Factory Lada needs 2 steering hubs and 4 rolling wheels"
        var stats: Dictionary = _stats(car,g.variant_slot)
        print("Lada %s: %d visible triangles (%d in the shared mesh), %d draw calls, shaders %s" % [v.to_upper(),
            stats["visible"],stats["tris"],stats["calls"],str(stats["shaders"])])
        if int(stats["visible"]) > BUDGET_TRIANGLES:
            return "%s over the triangle budget: %d" % [v,stats["visible"]]
        if int(stats["calls"]) > BUDGET_DRAW_CALLS:
            return "%s over the draw-call budget: %d" % [v,stats["calls"]]
        for shader in ["nitro_car_paint","nitro_car_atlas","nitro_car_glass"]:
            if not (stats["shaders"] as Array).has(shader):
                return "Body material not converted to "+shader
        if int(stats["slot_params"]) < 3:
            return "%s: variant_slot not set on the body materials" % v
        if int(stats["hidden"]) <= 0:
            return "%s: the other variant's parts must be masked" % v
        var b: AABB = stats["bounds"]
        print("Lada %s visible bounds: %s" % [v.to_upper(),str(b.size)])
        var info: Dictionary = CARS.info(v)
        if b.size.z > float(info["length"])+0.02 or b.size.z < float(info["length"])-0.08:
            return "%s length %.3f m vs catalog %.3f m" % [v,b.size.z,float(info["length"])]
        if b.size.x > float(info["width"])+0.005:
            return "%s width %.3f m wider than the catalog %.3f m" % [v,b.size.x,float(info["width"])]
        if b.position.y < -0.01 or b.end.y > 1.40:   # cambered tyre edge may touch -2 mm
            return "%s height out of range (%.3f .. %.3f)" % [v,b.position.y,b.end.y]
        var fl: Node3D = g.body.find_child("wheel_FL",true,false)
        var rl: Node3D = g.body.find_child("wheel_RL",true,false)
        if absf(absf(fl.position.z-rl.position.z)-float(info["wheelbase"])) > 0.005:
            return "Wheelbase in the GLB must be %.3f m" % float(info["wheelbase"])
        var w: Dictionary = COSMETICS.wheels().get(str(expect[v][1]),{})
        var outer: float = absf(fl.position.x)+float(w["outer_face_offset_m"])*g.wheel_radius/float(w["tyre_radius_m"])
        if outer > float(info["width"])*0.5+0.005:
            return "%s tyres poke out of the arches (%.3f m)" % [v,outer]
        car.queue_free()
        await process_frame
    # RYU-32: stripes are now a normal PAINT choice in the garage.
    var blue_profile: Dictionary = CARS.cosmetic_profile("blue")
    COSMETICS.reset_to_signature("blue",blue_profile)
    var ryu_glb: String = ""
    for look in ["clean","stripes"]:
        if look == "stripes":
            COSMETICS.next_paint("blue",blue_profile)
        var rc: Node3D = CARS.make("blue")
        root.add_child(rc)
        await process_frame
        if not (rc is NitroGlbCar):
            return "Switch ON: the RYU-32 must be the factory GLB car (%s)" % look
        var rg: NitroGlbCar = rc
        var path: String = str(CARS.factory_model("blue")["model"]["glb"])
        if ryu_glb != "" and path != ryu_glb:
            return "RYU-32 CLEAN and LIVERY must share one GLB"
        ryu_glb = path
        var on: float = float(rg.paint_material.get_shader_parameter("livery_on"))
        if (look == "stripes") != (on > 0.5):
            return "RYU-32 %s look: livery_on = %.1f" % [look,on]
        if look == "stripes" and rg.paint_material.get_shader_parameter("livery_tex") == null:
            return "RYU-32 LIVERY needs its livery texture"
        var st: Dictionary = _stats(rc,0)
        var info: Dictionary = CARS.info("blue")
        var bb: AABB = st["bounds"]
        print("RYU-32 %s: %d triangles, %d draw calls, bounds %s" % [look.to_upper(),st["visible"],st["calls"],str(bb.size)])
        if int(st["visible"]) > BUDGET_TRIANGLES or int(st["calls"]) > BUDGET_DRAW_CALLS:
            return "RYU-32 over budget (%d tris, %d calls)" % [st["visible"],st["calls"]]
        if absf(bb.size.z-float(info["length"])) > 0.02 or bb.size.x > float(info["width"])+0.005:
            return "RYU-32 footprint %s vs catalog %.3f x %.3f" % [str(bb.size),float(info["length"]),float(info["width"])]
        var fl: Node3D = rg.body.find_child("wheel_FL",true,false)
        var rl: Node3D = rg.body.find_child("wheel_RL",true,false)
        if absf(absf(fl.position.z-rl.position.z)-float(info["wheelbase"])) > 0.005:
            return "RYU-32 wheelbase in the GLB must be %.3f m" % float(info["wheelbase"])
        rc.queue_free()
        await process_frame
    # FLAME: a separate car with an AI-generated body, always the factory GLB (no DEVELOPER
    # switch), driving exactly like the RYU-32 (same handling + V8 profile, same footprint).
    CARS.set_factory_test_models(false)
    if not CARS.ORDER.has("flame") or not CARS.uses_factory_test_model("flame"):
        return "FLAME must be a selectable car that is always the factory GLB"
    if CARS.handling("flame") != CARS.handling("blue") or CARS.engine("flame") != CARS.engine("blue"):
        return "FLAME must use the RYU-32 handling and V8 engine profile"
    var fcar: Node3D = CARS.make("flame")
    root.add_child(fcar)
    await process_frame
    if not (fcar is NitroGlbCar):
        return "CARS.make('flame') must build the factory GLB car"
    var fg: NitroGlbCar = fcar
    var fst: Dictionary = _stats(fcar,0)
    var fb: AABB = fst["bounds"]
    var finfo: Dictionary = CARS.info("flame")
    print("FLAME: %d triangles, %d draw calls, bounds %s" % [fst["visible"],fst["calls"],str(fb.size)])
    if int(fst["visible"]) > BUDGET_TRIANGLES or int(fst["calls"]) > BUDGET_DRAW_CALLS:
        return "FLAME over budget (%d tris, %d calls)" % [fst["visible"],fst["calls"]]
    if absf(fb.size.z-float(finfo["length"])) > 0.03 or fb.size.x > float(finfo["width"])+0.005:
        return "FLAME footprint %s vs catalog %.3f x %.3f" % [str(fb.size),float(finfo["length"]),float(finfo["width"])]
    var ffl: Node3D = fg.body.find_child("wheel_FL",true,false)
    var frl: Node3D = fg.body.find_child("wheel_RL",true,false)
    if absf(absf(ffl.position.z-frl.position.z)-float(finfo["wheelbase"])) > 0.005:
        return "FLAME wheelbase in the GLB must be %.3f m" % float(finfo["wheelbase"])
    if fg.front_wheels.size() != 2 or fg.rolling_wheels.size() != 4:
        return "FLAME needs 2 steering hubs and 4 rolling wheels"
    fcar.queue_free()
    await process_frame
    CARS.set_factory_test_models(true)
    # Garage builds the same car the race will drive.
    var garage: Control = (load(GARAGE_SCENE) as PackedScene).instantiate()
    root.add_child(garage)
    await process_frame
    garage.call("_choose","white")
    await process_frame
    var preview: Variant = garage.get("car")
    if not (preview is NitroGlbCar) or (preview as NitroGlbCar).variant_slot != 2:
        return "Garage must show the factory WHITE Lada when the switch is ON"
    if not str((garage.get("version_label") as Label).text).contains("WHEELS"):
        return "Garage must show factory paint and wheel choices"
    if (garage.get_node("Cosmetic paint") as Button).disabled or (garage.get_node("Cosmetic wheels") as Button).disabled:
        return "Lada factory GLB needs PAINT and WHEELS in the player garage"
    garage.queue_free()
    await process_frame
    return ""

## Triangles the given variant shows (UV2.x 0 = shared, n = only slot n),
## draw calls, converted shaders and visible vertex bounds (wheels too).
func _stats(node: Node, slot: int) -> Dictionary:
    var out: Dictionary = {"tris":0,"visible":0,"hidden":0,"calls":0,"shaders":[],"slot_params":0,
        "lo":Vector3.INF,"hi":-Vector3.INF}
    _walk(node,slot,out)
    out["bounds"] = AABB(out["lo"],out["hi"]-out["lo"])
    return out

func _walk(node: Node, slot: int, out: Dictionary) -> void:
    if node is MeshInstance3D and (node as MeshInstance3D).visible:
        var mi := node as MeshInstance3D
        for i in range(mi.mesh.get_surface_count()):
            out["calls"] = int(out["calls"])+1
            var arr: Array = mi.mesh.surface_get_arrays(i)
            var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
            var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
            var uv2: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV2] if arr[Mesh.ARRAY_TEX_UV2] != null else PackedVector2Array()
            if idx.is_empty():
                idx = PackedInt32Array(range(verts.size()))
            for t in range(0,idx.size(),3):
                out["tris"] = int(out["tris"])+1
                var s: float = uv2[idx[t]].x if uv2.size() > 0 else 0.0
                if s > 0.5 and absf(s-float(slot)) > 0.25:
                    out["hidden"] = int(out["hidden"])+1
                    continue
                out["visible"] = int(out["visible"])+1
                if mi.name == "Soft contact shadow":
                    continue
                for k in range(3):
                    var p: Vector3 = mi.global_transform*verts[idx[t+k]]
                    out["lo"] = (out["lo"] as Vector3).min(p)
                    out["hi"] = (out["hi"] as Vector3).max(p)
            var m: Material = mi.get_active_material(i)
            if m is ShaderMaterial:
                var sm := m as ShaderMaterial
                var path: String = sm.shader.resource_path.get_file().get_basename()
                if not (out["shaders"] as Array).has(path):
                    (out["shaders"] as Array).append(path)
                if path != "soft_shadow" and int(round(float(sm.get_shader_parameter("variant_slot")))) == slot \
                        and mi.get_parent() != null and not str(mi.get_path()).contains("Wheel "):
                    out["slot_params"] = int(out["slot_params"])+1
    for c in node.get_children():
        _walk(c,slot,out)
