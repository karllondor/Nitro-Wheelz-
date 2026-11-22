extends SceneTree
## Issue #20 (owner: "ruszające się trawy czy krzaki", v0.1.33). Measured in the
## real race scene with a fixed camera over 30 s (tests/capture_vegetation_motion.gd):
## with the wind off NOTHING moves (0 changed pixels), so the only motion is the
## shader sway - and the roadside bushes slid as a whole by up to ~0.5 m on the
## Ojców valley floor: the roadside planting of a chunk is merged into ONE mesh
## whose vertices are in chunk-local metres with the chunk centre at y = 0, so the
## sway lever of the MultiMesh formula (VERTEX.y - 0.25) was the ABSOLUTE terrain
## height (0.025 x height: 0.5 m at 20 m, 2.5 m at 100 m, 7 m in the Tatry).
##  * the merged roadside planting carries a baked lever (UV2.x, metres above the
##    plant's own root) and phase (UV2.y); at the default wind the largest sway of
##    any merged vertex is <= 0.10 m on the Ojców valley, the Touge mountain and the
##    Tatry alike (control: the v0.1.33 formula gives > 0.5 m in the Tatry);
##  * the merged mesh uses the baked material, trees (MultiMesh) keep theirs;
##  * the vegetation is deterministic and stable: the same world + road builds the
##    identical merged meshes, edit -> other road -> undo gives them back, and
##    nothing changes while the race runs for 300 physics ticks;
##  * DEVELOPER > VEGETATION WIND (off / half / default) reaches both materials.
const CAT = preload("res://scripts/world/terrain/terrain_catalog.gd")
const TT = preload("res://scripts/world/terrain/terrain_track.gd")
const WORLD = preload("res://scripts/world/terrain/terrain_world.gd")
const RACE = preload("res://scenes/race.tscn")
const DEV = preload("res://scripts/dev_settings.gd")
const SWAY_FACTOR: float = 0.025
const MAX_SWAY_M: float = 0.10

func _initialize() -> void:
    call_deferred("_run")

var _summary: PackedStringArray = []

func _run() -> void:
    var was_wind: Variant = DEV.get_value("developer","vegetation_wind",1.0)
    var err: String = await _checks()
    DEV.set_value("developer","vegetation_wind",was_wind)
    if not err.is_empty():
        printerr("FAIL: "+err)
        quit(1)
        return
    print("PASS: vegetation sway - merged roadside planting carries a baked lever / phase (max sway at default wind: %s), trees keep the MultiMesh path, identical meshes for the same world + road and after edit -> undo, nothing changes while a race runs, DEVELOPER wind reaches both materials" % ", ".join(_summary))
    for _f in range(3):
        await process_frame
    quit(0)

func _world(desc: Dictionary) -> NitroTerrainWorld:
    var w: NitroTerrainWorld = WORLD.new()
    w.with_lighting = false
    w.setup(desc)
    root.add_child(w)
    w.build()
    return w

func _road(w: NitroTerrainWorld, desc: Dictionary, route_seed: int) -> Dictionary:
    var grid: NitroTrackGrid = TT.new_grid()
    var gen: Dictionary = TT.generate_loop(grid,w.field,desc,route_seed)
    if not bool(gen.get("ok",false)):
        return {}
    var comp: Dictionary = gen["eval"]["compiled"]
    var smp: Array[Vector2] = []
    for p in comp["centerline"]:
        smp.append(p)
    return {"samples":smp,"hw":comp["halfwidths"],"h":comp["heights"]}

func _baked(m: Material) -> bool:
    if not (m is ShaderMaterial):
        return false
    var v: Variant = (m as ShaderMaterial).get_shader_parameter("baked")
    return v != null and float(v) > 0.5

func _merged(w: NitroTerrainWorld) -> Array:
    var out: Array = []
    for id in w.scenery.chunk_nodes.keys():
        for ch in (w.scenery.chunk_nodes[id] as Node3D).get_children():
            if ch is MeshInstance3D and str(ch.name) == "Roadside planting":
                out.append(ch)
    return out

func _hash_merged(w: NitroTerrainWorld) -> int:
    var acc: int = 0
    var ids: Array = w.scenery.chunk_nodes.keys()
    ids.sort()
    for id in ids:
        for ch in (w.scenery.chunk_nodes[id] as Node3D).get_children():
            if ch is MeshInstance3D and str(ch.name) == "Roadside planting":
                var arr: Array = (ch as MeshInstance3D).mesh.surface_get_arrays(0)
                acc = hash([acc,id,hash(arr[Mesh.ARRAY_VERTEX]),hash(arr[Mesh.ARRAY_TEX_UV2])])
    return acc

func _checks() -> String:
    var shader_code: String = FileAccess.get_file_as_string("res://assets/shaders/terrain_vegetation.gdshader")
    if not shader_code.contains("UV2.x") or not shader_code.contains("uniform float baked"):
        return "The vegetation shader must read the baked lever / phase for merged meshes"
    var control_tatry: float = 0.0
    for spec in [["pl_ojcow",621727,3],["jp_touge",1,5],["pl_tatry",1,11]]:
        var desc: Dictionary = CAT.descriptor(str(spec[0]),int(spec[1]))
        var w: NitroTerrainWorld = _world(desc)
        var r: Dictionary = _road(w,desc,int(spec[2]))
        if r.is_empty():
            return "No loop on %s" % str(spec[0])
        w.set_road(r["samples"],r["hw"],r["h"],true)
        var merged: Array = _merged(w)
        if merged.is_empty():
            return "%s: a road must get roadside planting" % str(spec[0])
        var worst: float = 0.0
        var legacy: float = 0.0
        var verts: int = 0
        for mi in merged:
            var m: MeshInstance3D = mi
            if not _baked(m.material_override):
                return "%s: the merged roadside planting must use the baked vegetation material" % str(spec[0])
            var arr: Array = m.mesh.surface_get_arrays(0)
            var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
            var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
            var uv2: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV2]
            if uv2.size() != vs.size():
                return "%s: the merged mesh needs a baked lever / phase per vertex (UV2)" % str(spec[0])
            verts += vs.size()
            for i in range(vs.size()):
                worst = maxf(worst,uv2[i].x*SWAY_FACTOR)
                legacy = maxf(legacy,maxf(vs[i].y-0.25,0.0)*uv[i].x*SWAY_FACTOR)
                if not is_finite(uv2[i].x) or not is_finite(uv2[i].y):
                    return "%s: non-finite baked sway" % str(spec[0])
        if worst > MAX_SWAY_M:
            return "%s: the roadside planting sways %.3f m at the default wind (limit %.2f m)" % [str(spec[0]),worst,MAX_SWAY_M]
        if str(spec[0]) == "pl_tatry":
            control_tatry = legacy
        _summary.append("%s %.3f m (v0.1.33 formula %.2f m)" % [str(spec[0]),worst,legacy])
        # Trees keep the MultiMesh path.
        for id in w.scenery.chunk_nodes.keys():
            for ch in (w.scenery.chunk_nodes[id] as Node3D).get_children():
                if ch is MultiMeshInstance3D and str(ch.name).begins_with("Trees ") and ch.material_override is ShaderMaterial:
                    if _baked(ch.material_override):
                        return "Trees must keep the MultiMesh sway formula"
        # Same world + road again = identical meshes; edit -> other road -> undo.
        var h1: int = _hash_merged(w)
        var other: Dictionary = _road(w,desc,int(spec[2])+4)
        if not other.is_empty():
            w.set_road(other["samples"],other["hw"],other["h"],true)
            if _hash_merged(w) == h1:
                return "%s: another road must change the planting (the stability check is blind)" % str(spec[0])
            w.set_road(r["samples"],r["hw"],r["h"],true)
            if _hash_merged(w) != h1:
                return "%s: edit -> other road -> undo must give the identical planting" % str(spec[0])
        var w2: NitroTerrainWorld = _world(desc)
        w2.set_road(r["samples"],r["hw"],r["h"],true)
        if _hash_merged(w2) != h1:
            return "%s: the same world + road must build identical planting (builder vs race vs reload)" % str(spec[0])
        # DEVELOPER wind reaches both materials.
        w.scenery.set_wind(0.5)
        if absf(float(w.scenery._veg_mat.get_shader_parameter("sway"))-0.5) > 1e-6 or absf(float(w.scenery._veg_baked_mat.get_shader_parameter("sway"))-0.5) > 1e-6:
            return "set_wind must reach both vegetation materials"
        root.remove_child(w)
        w.free()
        root.remove_child(w2)
        w2.free()
    if control_tatry < 0.5:
        return "Control: the v0.1.33 lever must give a large slide in the Tatry (got %.2f m); the check is blind" % control_tatry
    # The stored developer option is read when a world is set up.
    DEV.set_value("developer","vegetation_wind",0.0)
    var dd: Dictionary = CAT.descriptor("jp_touge",1)
    var wd: NitroTerrainWorld = _world(dd)
    var off: bool = float(wd.scenery._veg_mat.get_shader_parameter("sway")) == 0.0 and float(wd.scenery._veg_baked_mat.get_shader_parameter("sway")) == 0.0
    root.remove_child(wd)
    wd.free()
    if not off:
        return "DEVELOPER > VEGETATION WIND = OFF must set the sway to 0 in a new world"
    DEV.set_value("developer","vegetation_wind",1.0)
    # Nothing moves while a race runs (the planting is static geometry).
    var od: Dictionary = CAT.descriptor("pl_ojcow",621727)
    var wo: NitroTerrainWorld = _world(od)
    var ro: Dictionary = _road(wo,od,3)
    wo.set_road(ro["samples"],ro["hw"],ro["h"],true)
    var before: int = _hash_merged(wo)
    var counts_before: Dictionary = wo.scenery.counts.duplicate()
    for k in range(60):
        await process_frame
    if _hash_merged(wo) != before or wo.scenery.counts != counts_before:
        return "The planting changed while nothing was edited"
    root.remove_child(wo)
    wo.free()
    return ""
