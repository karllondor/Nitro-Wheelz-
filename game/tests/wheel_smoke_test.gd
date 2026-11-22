extends SceneTree
## Issue #16 (rear wheel looks rotated / "detached" on the first drift, Android).
## The earlier wheel_visual_test only reads the rear hub yaw (0.00 deg). This test
## looks at what is actually drawn:
##  * wheel GEOMETRY of every car at rest (procedural Lada / RYU-32, E30, Car
##    Factory models, AI test body): left / right mirror exactly, front and rear
##    tyres are the same size, axles sit on the catalog wheelbase, the tyre
##    bottom touches the ground, the outer face stays within the body width;
##  * the tyre SMOKE at the rear wheels: a billboard with keep_scale = false plus
##    vertex colour draws the youngest particles with an undefined colour (black
##    in a clean scene, opaque white in the race - the black wheel-sized discs on
##    the phone, reproduced by tests/capture_smoke_probe.gd), so the material keeps
##    the scale; the quad has an explicit white colour array and clockwise faces,
##    and the puff texture is baked at creation (white, radial alpha);
##  * every CPUParticles3D / mesh in a race whose material uses the vertex colour
##    carries a colour array;
##  * DEVELOPER > DRIFT LAYER ISOLATION hides exactly one layer (smoke / skid
##    marks / contact shadow / wheels) and the diagnostics line says so.
const CARS = preload("res://scripts/vehicles/car_catalog.gd")
const RACE = preload("res://scenes/race.tscn")
const DEV = preload("res://scripts/dev_settings.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var was_factory: bool = CARS.factory_test_models()
    var was_layer: Variant = DEV.get_value("developer","hide_layer","off")
    var err: String = await _checks()
    CARS.set_factory_test_models(was_factory)
    DEV.set_value("developer","hide_layer",was_layer)
    if not err.is_empty():
        printerr("FAIL: "+err)
        quit(1)
        return
    print("PASS: wheel geometry on every car (mirror-symmetric, equal front / rear tyres, catalog wheelbase, on the ground, inside the body width), tyre smoke quad has explicit white vertex colours + baked radial puff, no vertex-colour material without a colour array, DRIFT LAYER ISOLATION hides exactly one layer")
    for _f in range(3):
        await process_frame
    quit(0)

func _bounds(n: Node3D, car: Node3D) -> AABB:
    var best := AABB()
    var first: bool = true
    for m in n.find_children("*","MeshInstance3D",true,false):
        var mi: MeshInstance3D = m
        if mi.mesh == null:
            continue
        var a: AABB = (car.global_transform.affine_inverse()*mi.global_transform)*mi.mesh.get_aabb()
        best = a if first else best.merge(a)
        first = false
    return best

func _geometry(variant: String, factory: bool) -> String:
    CARS.set_factory_test_models(factory)
    var car: Node3D = CARS.make(variant)
    root.add_child(car)
    await process_frame
    var info: Dictionary = CARS.info(variant)
    var label: String = "%s%s" % [variant,(" (factory)" if factory else "")]
    var ws: Array = car.get("rolling_wheels")
    if ws.size() != 4:
        return "%s: expected 4 rolling wheels, found %d" % [label,ws.size()]
    var fl := AABB()
    var fr := AABB()
    var rl := AABB()
    var rr := AABB()
    var all: Array = []
    for w in ws:
        all.append(_bounds(w,car))
    # Identify by position: z < 0 front, x < 0 left.
    for b in all:
        var c: Vector3 = (b as AABB).get_center()
        if c.z < 0.0 and c.x < 0.0:
            fl = b
        elif c.z < 0.0:
            fr = b
        elif c.x < 0.0:
            rl = b
        else:
            rr = b
    if fl.size == Vector3.ZERO or fr.size == Vector3.ZERO or rl.size == Vector3.ZERO or rr.size == Vector3.ZERO:
        return "%s: the four wheels must sit on four corners" % label
    for pair in [[fl,fr,"front"],[rl,rr,"rear"]]:
        var a: AABB = pair[0]
        var b2: AABB = pair[1]
        if absf(a.get_center().x+b2.get_center().x) > 0.002 or absf(a.get_center().z-b2.get_center().z) > 0.002 \
                or absf(a.get_center().y-b2.get_center().y) > 0.002 or a.size.distance_to(b2.size) > 0.002:
            return "%s: %s left / right wheels do not mirror (%s vs %s)" % [label,str(pair[2]),str(a),str(b2)]
    if absf(fl.size.y-rl.size.y) > 0.03 or absf(fl.size.x-rl.size.x) > 0.04:
        return "%s: front and rear tyres differ in size (front %s, rear %s)" % [label,str(fl.size),str(rl.size)]
    var wheelbase: float = rl.get_center().z-fl.get_center().z
    if absf(wheelbase-float(info["wheelbase"])) > 0.03:
        return "%s: axles are %.3f m apart, catalog wheelbase %.3f m" % [label,wheelbase,float(info["wheelbase"])]
    for b3 in [fl,rl]:
        var bottom: float = (b3 as AABB).get_center().y-(b3 as AABB).size.y*0.5
        if absf(bottom) > 0.015:
            return "%s: tyre bottom is %.3f m from the ground plane" % [label,bottom]
    var half: float = float(info["width"])*0.5
    for b4 in [fl,rl]:
        var outer: float = absf((b4 as AABB).get_center().x)+(b4 as AABB).size.x*0.5
        if outer > half+0.03:
            return "%s: a wheel's outer face is %.3f m from the centre, the body is %.3f m half-width" % [label,outer,half]
    root.remove_child(car)
    car.free()
    return ""

func _checks() -> String:
    for spec in [["red",false],["red",true],["white",false],["white",true],["blue",false],["blue",true],["e30",false],["flame",false]]:
        var e: String = await _geometry(str(spec[0]),bool(spec[1]))
        if not e.is_empty():
            return e
    CARS.set_factory_test_models(false)
    # ---- smoke quad / puff texture
    var script: GDScript = load("res://scripts/race/race.gd")
    var tex: ImageTexture = script.smoke_puff_texture()
    var img: Image = tex.get_image()
    if img.get_size() != Vector2i(64,64) or img.get_pixel(32,32).a < 0.95 or img.get_pixel(0,0).a > 0.01:
        return "Puff texture must be a 64x64 radial alpha (centre opaque, corner clear)"
    var c: Color = img.get_pixel(20,32)
    if c.r < 0.99 or c.g < 0.99 or c.b < 0.99:
        return "Puff texture RGB must be white everywhere (got %s)" % str(c)
    var mat := StandardMaterial3D.new()
    var quad: ArrayMesh = script.smoke_quad(mat)
    var arrays: Array = quad.surface_get_arrays(0)
    var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
    if cols.size() != 4:
        return "Smoke quad needs an explicit vertex colour array (got %d)" % cols.size()
    for col in cols:
        if col != Color.WHITE:
            return "Smoke quad vertex colours must be white"
    if quad.surface_get_material(0) != mat or (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() != 6:
        return "Smoke quad: one material, two triangles"
    var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
    var ix: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
    for t in range(2):
        var va: Vector3 = vs[ix[t*3]]
        var vb: Vector3 = vs[ix[t*3+1]]
        var vc: Vector3 = vs[ix[t*3+2]]
        if (vb-va).cross(vc-va).z >= 0.0:
            return "Smoke quad triangles must be clockwise seen from +Z (Godot front faces); otherwise the puffs are culled"
    # Control (the v0.1.33 smoke): a plain QuadMesh has no colour array at all.
    var old := QuadMesh.new()
    if old.get_mesh_arrays()[Mesh.ARRAY_COLOR] != null:
        return "Control: the old QuadMesh smoke had no vertex colour array; the check is blind"
    # ---- a race: smoke emitters and every vertex-colour material
    DEV.set_value("developer","hide_layer","off")
    ProjectSettings.set_setting("nitro/car_variant","blue")
    ProjectSettings.set_setting("nitro/selected_track","res://tracks/shin_kawa_v2.json")
    var race: Node3D = RACE.instantiate()
    race.set_physics_process(false)
    race.set_process(false)
    root.add_child(race)
    await process_frame
    if race.tyre_smoke.size() != 2:
        return "Expected a tyre smoke emitter on each rear wheel"
    for em in race.tyre_smoke:
        var cp: CPUParticles3D = em
        var m: Mesh = cp.mesh
        if not (m is ArrayMesh) or not ((m as ArrayMesh).surface_get_format(0) & Mesh.ARRAY_FORMAT_COLOR):
            return "Smoke emitter mesh must carry a vertex colour array"
        var sm: BaseMaterial3D = (m as ArrayMesh).surface_get_material(0) as BaseMaterial3D
        if sm == null or not sm.vertex_color_use_as_albedo or not (sm.albedo_texture is ImageTexture):
            return "Smoke material must use the baked puff texture with vertex colours"
        if sm.billboard_mode != BaseMaterial3D.BILLBOARD_ENABLED or not sm.billboard_keep_scale:
            return "Smoke material must keep the billboard scale (billboard_keep_scale = false + vertex colour draws the youngest particles black)"
    var missing: Array[String] = []
    _scan_colour_meshes(race,missing)
    if not missing.is_empty():
        return "Vertex-colour material on a mesh without a colour array: "+", ".join(missing)
    if race.isolated_layer != "off" or not race.tyre_smoke[0].visible:
        return "Isolation must be off by default"
    root.remove_child(race)
    race.free()
    # ---- isolation hides exactly one layer
    for layer in ["smoke","skid","shadow","wheels"]:
        DEV.set_value("developer","hide_layer",layer)
        var r2: Node3D = RACE.instantiate()
        r2.set_physics_process(false)
        r2.set_process(false)
        root.add_child(r2)
        await process_frame
        var hidden: Array[String] = []
        if not r2.tyre_smoke[0].visible:
            hidden.append("smoke")
        if not r2.skid_node.visible:
            hidden.append("skid")
        var shadow: Node3D = r2.car_root.find_child("Soft contact shadow",true,false) as Node3D
        if shadow != null and not shadow.visible:
            hidden.append("shadow")
        var wheels: Array = r2.car_root.get("rolling_wheels")
        if not (wheels[0] as Node3D).visible:
            hidden.append("wheels")
        if hidden != [layer]:
            return "Isolation '%s' must hide exactly that layer (hidden: %s)" % [layer,str(hidden)]
        if not str(r2.diag_text()).contains("LAYER HIDDEN: "+layer.to_upper()):
            return "Diagnostics must say which layer is hidden"
        root.remove_child(r2)
        r2.free()
    DEV.set_value("developer","hide_layer","bogus")
    var r3: Node3D = RACE.instantiate()
    r3.set_physics_process(false)
    r3.set_process(false)
    root.add_child(r3)
    await process_frame
    var ok: bool = r3.isolated_layer == "off" and r3.tyre_smoke[0].visible and r3.skid_node.visible
    root.remove_child(r3)
    r3.free()
    if not ok:
        return "An unknown isolation value must behave like OFF"
    return ""

func _scan_colour_meshes(n: Node, missing: Array[String]) -> void:
    var mesh: Mesh = null
    if n is MeshInstance3D:
        mesh = (n as MeshInstance3D).mesh
    elif n is CPUParticles3D:
        mesh = (n as CPUParticles3D).mesh
    if mesh is ArrayMesh:
        for i in range((mesh as ArrayMesh).get_surface_count()):
            var mat: Material = (mesh as ArrayMesh).surface_get_material(i)
            if n is MeshInstance3D and (n as MeshInstance3D).material_override != null:
                mat = (n as MeshInstance3D).material_override
            if mat is BaseMaterial3D and (mat as BaseMaterial3D).vertex_color_use_as_albedo:
                if not ((mesh as ArrayMesh).surface_get_format(i) & Mesh.ARRAY_FORMAT_COLOR):
                    missing.append(str(n.name))
    for ch in n.get_children():
        _scan_colour_meshes(ch,missing)
