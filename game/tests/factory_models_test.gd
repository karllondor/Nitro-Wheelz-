extends SceneTree
## Car Factory migration (v0.1.30): Lada 2106 RED / WHITE as ONE GLB with
## geometry variants, shown only with DEVELOPER > CAR FACTORY TEST MODELS.
##  * switch OFF (default): the approved procedural Lada stays;
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
    var garage_backup := ConfigFile.new()
    var had_garage: bool = garage_backup.load(COSMETICS.GARAGE_PATH) == OK
    var err: String = await _checks()
    CARS.set_factory_test_models(was_on)
    if had_garage:
        garage_backup.save(COSMETICS.GARAGE_PATH)
    if not err.is_empty():
        printerr("FAIL: "+err)
        quit(1)
        return
    print("PASS: Car Factory Lada 2106 - one GLB with RED / WHITE geometry variants behind DEVELOPER > CAR FACTORY TEST MODELS (off = procedural Lada), variant slots, own paint + wheels, 3 body materials, budget per variant, footprint + wheelbase, handling identical on / off, garage = race car")
    print("NOT RUN: owner visual acceptance; frame time on a real Android phone")
    for _f in range(3):
        await process_frame
    quit(0)

func _checks() -> String:
    var handling_off: Dictionary = CARS.handling("red").duplicate(true)
    CARS.set_factory_test_models(false)
    for v in ["red","white"]:
        var classic: Node3D = CARS.make(v)
        var ok: bool = classic is NitroLadaLowPoly
        classic.free()
        if not ok:
            return "Switch OFF must keep the procedural Lada (%s)" % v
    CARS.set_factory_test_models(true)
    if CARS.handling("red") != handling_off or str(CARS.profile("red").get("id","")) != "lada_baseline":
        return "Factory test models must not touch the Lada handling profile"
    if CARS.uses_factory_test_model("blue") or CARS.uses_factory_test_model("e30"):
        return "Only the Lada has a factory test model in this build"
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
    # Garage builds the same car the race will drive.
    var garage: Control = (load(GARAGE_SCENE) as PackedScene).instantiate()
    root.add_child(garage)
    await process_frame
    garage.call("_choose","white")
    await process_frame
    var preview: Variant = garage.get("car")
    if not (preview is NitroGlbCar) or (preview as NitroGlbCar).variant_slot != 2:
        return "Garage must show the factory WHITE Lada when the switch is ON"
    if not str((garage.get("version_label") as Label).text).contains("FACTORY TEST MODEL"):
        return "Garage must label the factory test model"
    if not (garage.get_node("Cosmetic paint") as Button).disabled:
        return "The Lada keeps its fixed looks (no PAINT / WHEELS menu)"
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
