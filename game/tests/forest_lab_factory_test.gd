extends SceneTree
## FOREST LAB (issue #54): the eight procedural tree species. Standalone (no race, no terrain).
##  * 8 species x 2 LOD x 5 seasons = 80 meshes: one surface, triangles within the budget (NEAR <= 520 / FAR <= 160, shrub 200 / 70),
##    finite vertices, vertex colours, UV.x foliage mask (1) AND wood (0) where a species has wood, a plausible height;
##  * deterministic (same inputs = identical mesh), a season changes COLOURS only (never the geometry), NEAR and FAR share one
##    crown plan (similar bounds), the shape knobs of the Tree Designer move the geometry in the right direction and are clamped;
##  * every crown faces OUTWARD (normals): the first version wound its triangles the wrong way round and rendered inside out;
##  * the one shared material is a ShaderMaterial with the DEVELOPER > VEGETATION WIND factor (`sway`);
##  * presets: JSON round trip, a name that exists is never overwritten silently, a bad file is ignored, CLASSIC is the default.
## NOT proven here: how it looks (captures) or what it costs on a phone (see the handoff).
const F = preload("res://scripts/world/forest_lab/nitro_tree_factory.gd")
const S = preload("res://scripts/world/forest_lab/forest_lab_settings.gd")
const DEV = preload("res://scripts/dev_settings.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    printerr("FAIL: "+message)
    quit(1)

func _hash(mesh: ArrayMesh, with_colours: bool) -> int:
    var arr: Array = mesh.surface_get_arrays(0)
    var h: int = hash(arr[Mesh.ARRAY_VERTEX])
    if with_colours:
        h = h ^ (hash(arr[Mesh.ARRAY_COLOR])*31)
    return h

func _run() -> void:
    var summary: PackedStringArray = []
    for t in range(8):
        var near_tris: int = 0
        var far_tris: int = 0
        for season in range(5):
            for lod in range(2):
                var m: ArrayMesh = F.make_mesh(t,lod,season)
                var name: String = "%s %s %s" % [F.species_name(t),"NEAR" if lod == F.LOD.NEAR else "FAR",F.SEASON_NAMES[season]]
                if m == null or m.get_surface_count() != 1:
                    _fail(name+": one surface expected (one draw call per MultiMesh)")
                    return
                var tris: int = F.tri_count(m)
                if tris < 8 or tris > F.tri_budget(t,lod):
                    _fail("%s: %d triangles, budget %d" % [name,tris,F.tri_budget(t,lod)])
                    return
                var arr: Array = m.surface_get_arrays(0)
                var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
                var cs: PackedColorArray = arr[Mesh.ARRAY_COLOR]
                var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
                if vs.size()%3 != 0 or cs.size() != vs.size() or uv.size() != vs.size():
                    _fail(name+": vertex / colour / UV arrays disagree")
                    return
                var foliage: int = 0
                var wood: int = 0
                for i in range(vs.size()):
                    if not (is_finite(vs[i].x) and is_finite(vs[i].y) and is_finite(vs[i].z)):
                        _fail(name+": non-finite vertex")
                        return
                    if uv[i].x > 0.5:
                        foliage += 1
                    else:
                        wood += 1
                if foliage == 0:
                    _fail(name+": no foliage (UV.x = 1) vertices")
                    return
                if t != F.Type.SHRUB and wood == 0:
                    _fail(name+": no wood (UV.x = 0) vertices: the trunk would sway")
                    return
                var aabb: AABB = m.get_aabb()
                var want: float = F.BASE_HEIGHT[t]
                if aabb.size.y < want*0.55 or aabb.size.y > want*1.5 or aabb.position.y < -0.6:
                    _fail("%s: height %.2f m for a %.1f m species (root at y %.2f)" % [name,aabb.size.y,want,aabb.position.y])
                    return
                if season == F.Season.SUMMER:
                    if lod == F.LOD.NEAR:
                        near_tris = tris
                    else:
                        far_tris = tris
        summary.append("%s %d/%d" % [F.species_name(t),near_tris,far_tris])
    # ------------------------------------------------------------ determinism, seasons, LOD plan
    for t in range(8):
        var a: ArrayMesh = F.make_mesh(t,F.LOD.NEAR,F.Season.SUMMER)
        var b: ArrayMesh = F.make_mesh(t,F.LOD.NEAR,F.Season.SUMMER)
        if _hash(a,true) != _hash(b,true):
            _fail(F.species_name(t)+": the mesh must be deterministic")
            return
        var gold: ArrayMesh = F.make_mesh(t,F.LOD.NEAR,F.Season.AUTUMN_GOLD)
        if _hash(a,false) != _hash(gold,false):
            _fail(F.species_name(t)+": a season must change colours only, never the geometry (roots would move)")
            return
        if t != F.Type.LAYERED_PINE and t != F.Type.TALL_FIR and _hash(a,true) == _hash(gold,true):
            _fail(F.species_name(t)+": the autumn palette must differ from summer")
            return
        var far: ArrayMesh = F.make_mesh(t,F.LOD.FAR,F.Season.SUMMER)
        var sa: Vector3 = a.get_aabb().size
        var sf: Vector3 = far.get_aabb().size
        if absf(sf.y-sa.y) > sa.y*0.30 or absf(sf.x-sa.x) > maxf(sa.x*0.55,1.0):
            _fail("%s: NEAR and FAR must share one silhouette (NEAR %s, FAR %s)" % [F.species_name(t),str(sa),str(sf)])
            return
    # --------------------------------------------------------------------------- crowns face outward
    for t in [F.Type.OAK,F.Type.SAKURA,F.Type.BIRCH,F.Type.JAPANESE_MAPLE,F.Type.ROWAN,F.Type.LAYERED_PINE]:
        var m2: ArrayMesh = F.make_mesh(t,F.LOD.NEAR,F.Season.SUMMER)
        var arr2: Array = m2.surface_get_arrays(0)
        var vs2: PackedVector3Array = arr2[Mesh.ARRAY_VERTEX]
        var ns: PackedVector3Array = arr2[Mesh.ARRAY_NORMAL]
        var uv2: PackedVector2Array = arr2[Mesh.ARRAY_TEX_UV]
        var centre := Vector3(0.0,m2.get_aabb().position.y+m2.get_aabb().size.y*0.6,0.0)
        var outward: float = 0.0
        var count: int = 0
        for i in range(vs2.size()):
            if uv2[i].x > 0.5:
                var d: Vector3 = vs2[i]-centre
                d.y *= 0.4
                if d.length() > 0.1:
                    outward += ns[i].dot(d.normalized())
                    count += 1
        if count == 0 or outward/float(count) < 0.15:
            _fail("%s: crown normals must point outward (mean %.2f): wrong triangle winding renders the tree inside out" % [F.species_name(t),outward/float(maxi(count,1))])
            return
    # --------------------------------------------------------------------- Tree Designer knobs
    var base_oak: AABB = F.make_mesh(F.Type.OAK,F.LOD.NEAR,F.Season.SUMMER).get_aabb()
    var tall_oak: AABB = F.make_mesh(F.Type.OAK,F.LOD.NEAR,F.Season.SUMMER,{"height":1.3}).get_aabb()
    var wide_oak: AABB = F.make_mesh(F.Type.OAK,F.LOD.NEAR,F.Season.SUMMER,{"crown":1.4}).get_aabb()
    if tall_oak.size.y < base_oak.size.y*1.12 or wide_oak.size.x < base_oak.size.x*1.12:
        _fail("height / crown knobs must move the geometry (height %.2f -> %.2f, width %.2f -> %.2f)" % [base_oak.size.y,tall_oak.size.y,base_oak.size.x,wide_oak.size.x])
        return
    var sparse: int = F.tri_count(F.make_mesh(F.Type.OAK,F.LOD.NEAR,F.Season.SUMMER,{"density":0.6}))
    var dense: int = F.tri_count(F.make_mesh(F.Type.OAK,F.LOD.NEAR,F.Season.SUMMER,{"density":1.5}))
    if dense <= sparse:
        _fail("foliage density must add / remove crown lumps (%d vs %d triangles)" % [sparse,dense])
        return
    var tiers_a: int = F.tri_count(F.make_mesh(F.Type.TALL_FIR,F.LOD.NEAR,F.Season.SUMMER,{"tiers":5}))
    var tiers_b: int = F.tri_count(F.make_mesh(F.Type.TALL_FIR,F.LOD.NEAR,F.Season.SUMMER,{"tiers":10}))
    if tiers_b <= tiers_a:
        _fail("the conifer tier count must change the geometry")
        return
    if _hash(F.make_mesh(F.Type.OAK,F.LOD.NEAR,F.Season.SUMMER,{"variant":0}),false) == _hash(F.make_mesh(F.Type.OAK,F.LOD.NEAR,F.Season.SUMMER,{"variant":1}),false):
        _fail("shape variants must differ")
        return
    var wild: Dictionary = F.clamp_params({"height":99,"crown":-4,"density":50,"trunk":0.0,"lean":9,"variant":99,"blossom":-1,"saturation":9,"brightness":0,"tiers":99})
    if float(wild["height"]) != 1.6 or float(wild["crown"]) != 0.6 or float(wild["density"]) != 1.6 or int(wild["variant"]) != 7 or int(wild["tiers"]) != 12:
        _fail("out-of-range knobs must be clamped: "+str(wild))
        return
    var worst: int = F.tri_count(F.make_mesh(F.Type.OAK,F.LOD.NEAR,F.Season.SUMMER,{"density":1.6,"crown":1.6,"height":1.6}))
    if worst > F.NEAR_TRI_BUDGET*1.4:
        _fail("the densest legal Designer settings must stay bounded (%d triangles)" % worst)
        return
    # ----------------------------------------------------------------------------------- material
    var mat: ShaderMaterial = F.make_material(0.5)
    if mat == null or mat.shader == null or absf(float(mat.get_shader_parameter("sway"))-0.5) > 0.001:
        _fail("the shared tree material must be a ShaderMaterial carrying the vegetation-wind factor")
        return
    var code: String = FileAccess.get_file_as_string(F.SHADER_PATH)
    if code.contains("ALPHA") or code.contains("discard"):
        _fail("the tree shader must stay opaque (no alpha, no discard)")
        return
    # ---------------------------------------------------------------------------------- settings
    var was: Dictionary = {"mode":DEV.get_value(S.SECTION,"mode","classic"),"preset":DEV.get_value(S.SECTION,"preset","")}
    DEV.set_value(S.SECTION,"mode","classic")
    DEV.set_value(S.SECTION,"preset","")
    if str(S.read()["mode"]) != "classic":
        _fail("the default must be CLASSIC")
        return
    var pname: String = "unit_test_preset_54"
    S.delete_preset(pname)
    var data: Dictionary = {"season":F.Season.AUTUMN_RED,"density":2,"scale":1.2,"mix":{"0":0.5,"2":0.5},"species":{"2":{"height":1.2,"crown":1.3,"variant":1}}}
    var err: String = S.save_preset(pname,data)
    if err != "":
        _fail("saving a preset: "+err)
        return
    if S.save_preset(pname,data) == "":
        _fail("a preset name that exists must never be overwritten silently")
        return
    if S.save_preset(pname,data,true) != "":
        _fail("an explicit overwrite must work")
        return
    var back: Dictionary = S.load_preset(pname)
    if str(back.get("name","")) != pname or int(back.get("version",0)) != 1:
        _fail("preset round trip failed: "+str(back))
        return
    var cfg: Dictionary = S.apply_preset(S.defaults(),back)
    if int(cfg["season"]) != F.Season.AUTUMN_RED or int(cfg["density"]) != 2 or absf(float(cfg["scale"])-1.2) > 0.001 \
            or absf(float((cfg["mix"] as Dictionary)[0])-0.5) > 0.001 or absf(float(S.params_for(cfg,2)["height"])-1.2) > 0.001:
        _fail("a loaded preset must reach the config: "+str(cfg))
        return
    if not S.list_presets().has(pname):
        _fail("the preset must be listed")
        return
    if S.save_preset("   ",data) == "" or S.save_preset("../evil",data) != "" and not FileAccess.file_exists(S.preset_path("evil")):
        _fail("preset names are sanitised (empty refused, no path tricks)")
        return
    if FileAccess.file_exists("user://forest_lab_presets/../evil.json"):
        _fail("a preset name must never escape the preset folder")
        return
    S.delete_preset("evil")
    S.delete_preset(pname)
    if not S.load_preset(pname).is_empty() or S.list_presets().has(pname):
        _fail("deleting a preset must remove it")
        return
    if not S.parse_json_text("{\"version\":2}").is_empty() or not S.parse_json_text("not json").is_empty():
        _fail("a foreign or broken preset text must be refused")
        return
    DEV.set_value(S.SECTION,"mode",was["mode"])
    DEV.set_value(S.SECTION,"preset",was["preset"])
    print("PASS: FOREST LAB tree factory - 8 species x 2 LOD x 5 seasons = 80 meshes (triangles NEAR/FAR, summer: %s), one surface / one shared opaque material, foliage / wood mask, deterministic, seasons change colours only, NEAR and FAR share a silhouette, crowns face outward, Designer knobs move and clamp, presets round trip without silent overwrite, CLASSIC is the default; NOT proven: how it looks on a phone" % ", ".join(summary))
    quit(0)
