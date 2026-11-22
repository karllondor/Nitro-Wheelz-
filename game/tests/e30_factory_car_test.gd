extends SceneTree
## Car Factory prototype (v0.1.24): the E30 Blessed GLB car.
##  * catalog + profile: E30 selectable, Lada/RYU-32 profiles untouched,
##    E30 handling = Lada baseline except the confirmed factory wheelbase,
##    proposed tuning recorded but NOT applied;
##  * model: GLB loads, 3 body materials (paint / atlas / glass) converted
##    to the Nitro shaders, 4 wheel hubs (2 steer), draw-call and triangle
##    budget, factory dimensions within tolerance;
##  * wheels: both wheel assets load; tyre stays inside the body side and
##    under the arch (static clearance);
##  * cosmetics: SIGNATURE default, PAINT / WHEELS change only the look and
##    persist, SIGNATURE resets, handling identical before/after, garage and
##    race build the same car;
##  * sound: the I6 profile renders an even 6-cylinder pulse train.
const CARS = preload("res://scripts/vehicles/car_catalog.gd")
const COSMETICS = preload("res://scripts/vehicles/car_cosmetics.gd")
const SYNTH = preload("res://scripts/audio/engine_synth.gd")
const GARAGE_SCENE = "res://scenes/garage.tscn"
const BUDGET_DRAW_CALLS: int = 10
const BUDGET_TRIANGLES: int = 42000

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var cfg_backup := ConfigFile.new()
    var had_cfg: bool = cfg_backup.load(COSMETICS.GARAGE_PATH) == OK
    var err: String = await _checks()
    # Leave the player's garage file as it was.
    if had_cfg:
        cfg_backup.save(COSMETICS.GARAGE_PATH)
    else:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(COSMETICS.GARAGE_PATH))
    if not err.is_empty():
        printerr("FAIL: "+err)
        quit(1)
        return
    print("PASS: E30 Blessed factory car (GLB) in the catalog, Lada/RYU-32 profiles untouched, E30 handling = Lada baseline + confirmed wheelbase (proposed tuning not applied), 3 body materials converted, 4 hubs, budget held, factory dimensions, wheel clearance, cosmetics persist without touching handling, garage = race car, I6 sound")
    print("NOT RUN: frame time / GPU cost on a real Android phone and in a mobile browser; visual approval by the owner")
    quit(0)

func _checks() -> String:
    # --- catalog and profiles
    if not CARS.ORDER.has("e30") or CARS.valid("e30") != "e30":
        return "E30 missing from the car catalog"
    var lada: Dictionary = CARS.profile("red")
    var e30: Dictionary = CARS.profile("e30")
    if str(CARS.profile("blue").get("id","")) != "ryu32_v8" or str(lada.get("id","")) != "lada_baseline":
        return "Existing car profiles changed"
    var lh: Dictionary = lada["handling"]
    var eh: Dictionary = e30["handling"]
    for key in lh.keys():
        if key == "wheelbase":
            continue
        if not eh.has(key) or float(eh[key]) != float(lh[key]):
            return "E30 handling must copy the Lada baseline (%s)" % key
    if eh.size() != lh.size() or absf(float(eh["wheelbase"])-2.570) > 1e-6:
        return "E30 wheelbase must be the confirmed factory 2.570 m"
    if not (e30.get("handling_notes",{}) as Dictionary).has("proposed_tuning_not_applied"):
        return "Proposed (untested) tuning must be recorded as not applied"
    if int(e30["engine"]["cylinders"]) != 6 or (e30["engine"]["bank"] as Array).size() != 6:
        return "E30 engine must be an inline six"
    var info: Dictionary = CARS.info("e30")
    if absf(float(info["length"])-4.325) > 1e-6 or absf(float(info["width"])-1.645) > 1e-6:
        return "E30 footprint must use the factory length/width"

    # --- model
    COSMETICS.reset_to_signature("e30",e30)
    var car: Node3D = CARS.make("e30")
    root.add_child(car)
    await process_frame
    if not (car is NitroGlbCar):
        return "CARS.make('e30') must build the GLB factory car"
    var glb: NitroGlbCar = car
    if glb.front_wheels.size() != 2 or glb.rolling_wheels.size() != 4:
        return "Factory car needs 2 steering hubs and 4 rolling wheels"
    var stats: Dictionary = _mesh_stats(car)
    print("E30 model: %d triangles, %d draw calls (surfaces), shaders %s" % [stats["tris"],stats["calls"],str(stats["shaders"])])
    if int(stats["calls"]) > BUDGET_DRAW_CALLS:
        return "Draw calls over budget: %d" % stats["calls"]
    if int(stats["tris"]) > BUDGET_TRIANGLES:
        return "Triangles over budget: %d" % stats["tris"]
    for shader in ["nitro_car_paint","nitro_car_atlas","nitro_car_glass"]:
        if not (stats["shaders"] as Array).has(shader):
            return "Body material not converted to "+shader
    # Vertex bounds (Godot pads the AABB of compressed imported meshes).
    var body: AABB = _vertex_bounds(glb.body)
    print("E30 body vertex bounds: %s" % str(body.size))
    if absf(body.size.z-4.325) > 0.03:
        return "Length %.3f m, factory 4.325 m" % body.size.z
    if body.end.y > 1.380 or body.end.y < 1.25:
        return "Roof height %.3f m must be below the stock 1.380 m (lowered) and plausible" % body.end.y
    if body.position.y < 0.0:
        return "Geometry below the ground plane"
    var lower_w: float = _body_width_below(glb.body,0.80)
    if absf(lower_w-1.645) > 0.03:
        return "Body width %.3f m, factory 1.645 m" % lower_w
    var fl: Node3D = glb.body.find_child("wheel_FL",true,false)
    var rl: Node3D = glb.body.find_child("wheel_RL",true,false)
    if absf(absf(fl.position.z-rl.position.z)-2.570) > 0.005:
        return "Wheelbase in the GLB must be 2.570 m"

    # --- wheels: both assets load, static clearance
    for wid in e30["cosmetics"]["wheels"]:
        var w: Dictionary = COSMETICS.wheels().get(wid,{})
        if w.is_empty() or load("res://assets/cars/wheels/"+str(w["file"])) == null:
            return "Wheel asset missing: "+str(wid)
        var outer: float = absf(fl.position.x)+float(w["outer_face_offset_m"])
        if outer > 1.645*0.5+0.01:
            return "%s pokes out of the body: outer face %.3f m" % [wid,outer]
        if float(w["tyre_radius_m"]) > glb.wheel_radius+1e-4:
            return "%s tyre larger than the arch allows" % wid

    # --- cosmetics: change look only, persist, reset
    var before: Dictionary = CARS.handling("e30").duplicate()
    var sig: Dictionary = COSMETICS.current("e30",e30)
    if not COSMETICS.is_signature(sig,e30) or str(sig["wheel_asset_id"]) != "wheel_signature_e30":
        return "Default look must be the SIGNATURE preset"
    var painted: Dictionary = COSMETICS.next_paint("e30",e30)
    var wheeled: Dictionary = COSMETICS.next_wheel("e30",e30)
    var now: Dictionary = COSMETICS.current("e30",e30)
    if str(now["paint_color_hex"]) == str(sig["paint_color_hex"]) or str(now["wheel_asset_id"]) != "wheel_nw_deep_dish":
        return "PAINT / WHEELS choice not saved"
    if str(painted["paint_color_hex"]) != str(now["paint_color_hex"]) or str(wheeled["wheel_asset_id"]) != str(now["wheel_asset_id"]):
        return "Cosmetic choice changed while saving"
    if CARS.handling("e30") != before:
        return "Cosmetics changed the handling profile"
    var custom_car: NitroGlbCar = CARS.make("e30")
    root.add_child(custom_car)
    await process_frame
    var paint_now: Color = custom_car.paint_material.get_shader_parameter("paint")
    if not paint_now.is_equal_approx(Color.html(str(now["paint_color_hex"]))):
        return "Race/garage car does not wear the saved paint"
    if custom_car.find_child("Wheel wheel_nw_deep_dish",true,false) == null:
        return "Race/garage car does not wear the saved wheels"
    custom_car.queue_free()
    if not COSMETICS.is_signature(COSMETICS.reset_to_signature("e30",e30),e30) \
            or not COSMETICS.is_signature(COSMETICS.current("e30",e30),e30):
        return "SIGNATURE must restore the original look"
    car.queue_free()

    # --- garage prototype: SIGNATURE / PAINT / WHEELS on the E30
    var old_size: Vector2i = root.size
    root.size = Vector2i(900,2000)     # portrait phone card, as on the device
    var garage: Control = (load(GARAGE_SCENE) as PackedScene).instantiate()
    root.add_child(garage)
    await process_frame
    garage.call("_choose","e30")
    if not (garage.get("car") is NitroGlbCar):
        return "Garage did not spawn the E30"
    var preview: NitroGlbCar = garage.get("car")
    garage.call("_next_paint")
    garage.call("_next_wheels")
    await process_frame
    if preview != garage.get("car"):
        return "Cosmetic change must not rebuild the car node"
    if preview.find_child("Wheel wheel_nw_deep_dish",true,false) == null:
        return "Garage wheel swap not applied to the preview"
    if not str((garage.get("version_label") as Label).text).contains("CUSTOM"):
        return "Garage must show the custom state"
    garage.call("_signature")
    if not str((garage.get("version_label") as Label).text).contains("ORIGINAL"):
        return "Garage SIGNATURE must show the original state"
    # v0.3: controlled framing fitted to the real car, still inside the card
    # at every angle (the garage re-fits the lens every frame).
    var cam: Camera3D = garage.get("camera")
    var tt: Node3D = garage.get("turntable")
    var vp_size: Vector2 = Vector2((garage.get("preview") as SubViewport).size)
    var worst: float = 1.0
    var probe: Array[Vector3] = []
    for deg in range(0,360,15):
        tt.rotation.y = deg_to_rad(float(deg))
        garage.call("_frame_camera",1.0)
        probe = _car_corners(preview)
        for corner in probe:
            var sp: Vector2 = cam.unproject_position(corner)
            worst = minf(worst,minf(minf(sp.x,vp_size.x-sp.x)/vp_size.x,minf(sp.y,vp_size.y-sp.y)/vp_size.y))
    print("E30 garage framing: fov %.1f deg, smallest margin to the card edge over a full turn %.1f %%" % [cam.fov,worst*100.0])
    if worst > 0.12:
        return "Garage framing leaves too much empty card around the car (smallest margin %.3f)" % worst
    if worst < 0.01:
        return "Zoomed E30 leaves the garage card during the turn (margin %.3f)" % worst
    garage.call("_choose","red")
    if (garage.get_node("Cosmetic paint") as Button).disabled:
        return "All player-visible factory GLB cars must have PAINT controls"
    garage.queue_free()
    await process_frame
    root.size = old_size

    # --- sound: inline six
    var s: NitroEngineSynth = SYNTH.new()
    s.apply_profile(CARS.engine("e30"))
    s.rpm = 3000.0
    if absf(s.firing_hz()-150.0) > 0.01:
        return "I6 firing frequency at 3000 rpm must be 150 Hz"
    s.set_state(60.0,1.0,0.0,1.0/60.0)
    var buf: PackedVector2Array = s.render(4096)
    var e: float = 0.0
    for v in buf:
        if is_nan(v.x) or is_nan(v.y):
            return "I6 synth produced NaN"
        e += v.x*v.x
    if e <= 0.0:
        return "I6 synth is silent"
    return ""

## Sample of the car's real mesh vertices in world space (body + wheels).
func _car_corners(car: Node3D) -> Array[Vector3]:
    var out: Array[Vector3] = []
    for mi in car.find_children("*","MeshInstance3D",true,false):
        var m: MeshInstance3D = mi
        if m.mesh == null or not m.visible or str(m.name).to_lower().contains("shadow"):
            continue
        for si in range(m.mesh.get_surface_count()):
            var verts: PackedVector3Array = m.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]
            for k in range(0,verts.size(),7):
                out.append(m.global_transform*verts[k])
    return out

func _mesh_stats(node: Node) -> Dictionary:
    var out: Dictionary = {"tris":0,"calls":0,"shaders":[]}
    _walk(node,out)
    return out

func _walk(node: Node, out: Dictionary) -> void:
    if node is MeshInstance3D and (node as MeshInstance3D).visible:
        var mi := node as MeshInstance3D
        for i in range(mi.mesh.get_surface_count()):
            out["calls"] = int(out["calls"])+1
            var arr: Array = mi.mesh.surface_get_arrays(i)
            var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
            var n: int = idx.size() if idx.size() > 0 else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
            out["tris"] = int(out["tris"])+n/3
            var m: Material = mi.get_active_material(i)
            if m is ShaderMaterial:
                var path: String = (m as ShaderMaterial).shader.resource_path.get_file().get_basename()
                if not (out["shaders"] as Array).has(path):
                    (out["shaders"] as Array).append(path)
    for c in node.get_children():
        _walk(c,out)

func _vertex_bounds(node: Node) -> AABB:
    var lo := Vector3.INF
    var hi := -Vector3.INF
    for mi in _meshes(node):
        if str(mi.get_path()).contains("Wheel "):
            continue
        var m: MeshInstance3D = mi
        for i in range(m.mesh.get_surface_count()):
            for v in m.mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX]:
                var p: Vector3 = m.global_transform*v
                lo = lo.min(p)
                hi = hi.max(p)
    return AABB(lo,hi-lo)

func _meshes(node: Node) -> Array:
    var out: Array = []
    if node is MeshInstance3D:
        out.append(node)
    for c in node.get_children():
        out += _meshes(c)
    return out

## Body width from vertices below a height (excludes the door mirrors).
func _body_width_below(node: Node, max_y: float) -> float:
    var lo: float = 0.0
    var hi: float = 0.0
    for mi in _meshes(node):
        if str(mi.get_path()).contains("Wheel "):
            continue
        var m: MeshInstance3D = mi
        for i in range(m.mesh.get_surface_count()):
            for v in m.mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX]:
                var p: Vector3 = m.global_transform*v
                if p.y < max_y and p.y > 0.3:
                    lo = minf(lo,p.x)
                    hi = maxf(hi,p.x)
    return hi-lo
