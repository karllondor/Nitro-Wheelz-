extends Node3D
class_name NitroProceduralWorld
## Procedural world, phase A (Japan Drift Town): the coordinator shared by
## the 3D track builder and the race. Same road tiles + same seed = the same
## world in both (NitroSceneryRules decides, NitroSceneryModules draws).
##
## Incremental: after an edit only the tiles that changed (and the ring
## around them, the reach of a road on its scenery) are re-planned; module
## keys are recomputed there and along the affected rows; only chunks
## (2 x 2 road tiles) holding a changed key are rebuilt. Untouched chunks
## keep their nodes.

const RULES = preload("res://scripts/world/scenery_rules.gd")
const MODS = preload("res://scripts/world/scenery_modules.gd")
const THEME: String = "japan_drift_town"
const VERSION: int = 1

var rules: NitroSceneryRules
var plan_cells: Dictionary = {}     # Vector2i cell -> plan
var keys: Dictionary = {}           # Vector2i cell -> module key
var chunk_nodes: Dictionary = {}    # Vector2i chunk -> Node3D
var world_seed: int = 1
var cols: int = 8
var rows: int = 12
var last_stats: Dictionary = {}
var _mats: Array = []
var _links: Dictionary = {}

## Saved-track block describing this world.
func descriptor() -> Dictionary:
    return {"theme":THEME,"seed":world_seed,"version":VERSION}

## Full build (first time, or a different seed / grid size).
func generate(links: Dictionary, grid_cols: int, grid_rows: int, seed: int) -> Dictionary:
    var t0: int = Time.get_ticks_usec()
    cols = grid_cols
    rows = grid_rows
    world_seed = seed
    rules = RULES.new(cols,rows,seed)
    rules.set_links(links)
    _links = _copy(links)
    if _mats.is_empty():
        _mats = MODS.materials()
    plan_cells = rules.plan()
    keys.clear()
    for c in plan_cells.keys():
        keys[c] = rules.module_key(plan_cells,c)
    for k in chunk_nodes.keys():
        (chunk_nodes[k] as Node).queue_free()
    chunk_nodes.clear()
    var chunks: Dictionary = {}
    for c in plan_cells.keys():
        if not str(keys[c]).is_empty():
            chunks[RULES.chunk_of(c)] = true
    for k in chunks.keys():
        _build_chunk(k)
    last_stats = {"full":true,"changed_tiles":-1,"planned_cells":plan_cells.size(),
        "rebuilt_chunks":chunks.size(),"ms":float(Time.get_ticks_usec()-t0)/1000.0}
    return last_stats

## Incremental update after road tiles changed.
func update(links: Dictionary) -> Dictionary:
    if rules == null:
        return generate(links,cols,rows,world_seed)
    var t0: int = Time.get_ticks_usec()
    var changed: Dictionary = {}
    for t in _links.keys():
        if not links.has(t) or not _same_links(_links[t],links[t]):
            changed[t] = true
    for t in links.keys():
        if not _links.has(t):
            changed[t] = true
    if changed.is_empty():
        last_stats = {"full":false,"changed_tiles":0,"planned_cells":0,"rebuilt_chunks":0,"ms":0.0}
        return last_stats
    rules.set_links(links)
    _links = _copy(links)
    # Cells whose plan can depend on the changed tiles: their tile +- 1.
    var region: Dictionary = {}
    for t in changed.keys():
        for dx in [-1,0,1]:
            for dy in [-1,0,1]:
                var tt := Vector2i(t.x+dx,t.y+dy)
                for sx in range(RULES.SUB):
                    for sy in range(RULES.SUB):
                        var c := Vector2i((tt.x)*RULES.SUB+sx,(tt.y)*RULES.SUB+sy)
                        if c.x >= rules.cell_min().x and c.y >= rules.cell_min().y and c.x <= rules.cell_max().x and c.y <= rules.cell_max().y:
                            region[c] = true
    # Rows touching the region before the change (they may shrink).
    var key_cells: Dictionary = {}
    for c in region.keys():
        _add_ring_and_rows(c,key_cells)
    var fresh: Dictionary = rules.plan(region.keys())
    for c in fresh.keys():
        plan_cells[c] = fresh[c]
    for c in region.keys():
        _add_ring_and_rows(c,key_cells)
    var dirty: Dictionary = {}
    for c in key_cells.keys():
        var k: String = rules.module_key(plan_cells,c)
        if str(keys.get(c,"")) != k:
            keys[c] = k
            dirty[RULES.chunk_of(c)] = true
    for k in dirty.keys():
        _build_chunk(k)
    last_stats = {"full":false,"changed_tiles":changed.size(),"planned_cells":region.size(),
        "rebuilt_chunks":dirty.size(),"ms":float(Time.get_ticks_usec()-t0)/1000.0}
    return last_stats

func _add_ring_and_rows(c: Vector2i, into: Dictionary) -> void:
    for dx in [-1,0,1]:
        for dy in [-1,0,1]:
            var n := Vector2i(c.x+dx,c.y+dy)
            if not plan_cells.has(n):
                continue
            into[n] = true
            var p: Dictionary = plan_cells[n]
            if str(p["role"]) in ["lot","fence"]:
                for m in RULES.row_of(plan_cells,n):
                    into[m] = true

static func _same_links(a: Array, b: Array) -> bool:
    if a.size() != b.size():
        return false
    for x in a:
        if not b.has(x):
            return false
    return true

static func _copy(links: Dictionary) -> Dictionary:
    var out: Dictionary = {}
    for k in links.keys():
        out[k] = (links[k] as Array).duplicate()
    return out

# -------------------------------------------------------------- placement

## Everything placed in the world (for tests and reproducibility checks):
## [{"id", "kind", "cell", "footprint": PackedVector2Array}] in cell order.
func placements() -> Array:
    var out: Array = []
    var cells: Array = plan_cells.keys()
    cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
    for c in cells:
        var p: Dictionary = plan_cells[c]
        var role: String = str(p["role"])
        if role == "lot":
            var fr: Array = rules.frame(c,p["f"])
            var jl: bool = RULES.joined(plan_cells,c,-1)
            var jr: bool = RULES.joined(plan_cells,c,1)
            var u0: float = 0.0 if jl else 0.9
            var u1: float = RULES.S if jr else RULES.S-0.9
            var v0: float = float(p["v"])
            var v1: float = v0+float(p["d"])
            out.append({"id":str(keys.get(c,"")),"kind":"building","cell":c,
                "footprint":_quad(fr,u0-(0.0 if jl else 0.45),u1+(0.0 if jr else 0.45),v0-0.6,v1+0.55)})
        elif role == "fence":
            var fr2: Array = rules.frame(c,p["f"])
            var v: float = float(p["v"])
            out.append({"id":str(keys.get(c,"")),"kind":"fence","cell":c,"footprint":_quad(fr2,0.0,RULES.S,v-0.2,v+0.2)})
            var tree: Dictionary = fence_tree(c)
            if not tree.is_empty():
                out.append({"id":"tree|%d" % int(tree["seed"]),"kind":"tree","cell":c,"footprint":_disc(tree["pos"],float(tree["radius"]))})
        elif role == "tree":
            out.append({"id":str(keys.get(c,"")),"kind":"tree","cell":c,"footprint":_disc(p["pos"],float(p["radius"]))})
    return out

static func _quad(fr: Array, u0: float, u1: float, v0: float, v1: float) -> PackedVector2Array:
    return PackedVector2Array([RULES.local_to_world(fr,u0,v0),RULES.local_to_world(fr,u1,v0),
        RULES.local_to_world(fr,u1,v1),RULES.local_to_world(fr,u0,v1)])

static func _disc(c: Vector2, r: float) -> PackedVector2Array:
    var out := PackedVector2Array()
    for k in range(8):
        out.append(c+Vector2(cos(TAU*float(k)/8.0),sin(TAU*float(k)/8.0))*r)
    return out

## Tree standing behind a fence (or {}).
func fence_tree(c: Vector2i) -> Dictionary:
    var p: Dictionary = plan_cells.get(c,{})
    if p.is_empty() or str(p["role"]) != "fence" or not bool(p["tree"]):
        return {}
    var fr: Array = rules.frame(c,p["f"])
    var radius: float = lerpf(2.2,2.9,rules.rand01(c.x,c.y,71))
    var v: float = float(p["v"])+2.2+radius
    if v+radius > RULES.S+1.0:
        return {}
    var pos: Vector2 = RULES.local_to_world(fr,lerpf(4.0,10.0,rules.rand01(c.x,c.y,73)),v)
    if rules.clearance(pos) < radius+RULES.TREE_CLEAR:
        return {}
    return {"pos":pos,"cherry":rules.rand01(c.x,c.y,79) < 0.7,"radius":radius,
        "height":lerpf(0.9,1.15,rules.rand01(c.x,c.y,83)),"seed":RULES.hash4(world_seed,c.x,c.y,89)}

# ------------------------------------------------------------------ meshes

func _build_chunk(k: Vector2i) -> void:
    if chunk_nodes.has(k):
        var old: Node = chunk_nodes[k]
        remove_child(old)
        old.queue_free()
        chunk_nodes.erase(k)
    var a = MODS.Acc.new()
    var trees: Array = []
    var n: int = RULES.SUB*RULES.CHUNK_TILES
    for x in range(k.x*n,k.x*n+n):
        for y in range(k.y*n,k.y*n+n):
            var c := Vector2i(x,y)
            if not plan_cells.has(c):
                continue
            var p: Dictionary = plan_cells[c]
            match str(p["role"]):
                "lot":
                    _draw_lot(a,c,p)
                "fence":
                    _draw_fence(a,c,p)
                    var ft: Dictionary = fence_tree(c)
                    if not ft.is_empty():
                        trees.append(ft)
                "tree":
                    trees.append(p)
    if a.idx.is_empty() and a.eidx.is_empty() and trees.is_empty():
        return
    var node := Node3D.new()
    node.name = "World chunk %d,%d" % [k.x,k.y]
    add_child(node)
    chunk_nodes[k] = node
    if not (a.idx.is_empty() and a.eidx.is_empty()):
        var mi := MeshInstance3D.new()
        mi.name = "Modules"
        mi.mesh = a.commit(_mats[0],_mats[1])
        mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        node.add_child(mi)
    if not trees.is_empty():
        MODS.build_trees(node,trees)

func _draw_lot(a, c: Vector2i, p: Dictionary) -> void:
    var f: Vector2i = p["f"]
    var fr: Array = rules.frame(c,f)
    a.set_frame(fr)
    var row: Array = RULES.row_of(plan_cells,c)
    var idx: int = row.find(c)
    var first: Vector2i = row[0]
    var palette: int = RULES.hash4(world_seed,first.x,first.y,53)%5
    var variant: int = RULES.hash4(world_seed,c.x,c.y,59)%7
    var jl: bool = RULES.joined(plan_cells,c,-1)
    var jr: bool = RULES.joined(plan_cells,c,1)
    var v: float = float(p["v"])
    var vp: float = rules._front_offset(fr,RULES.PAD_SETBACK,v)
    if vp < 0.0:
        vp = v
    MODS.apron(a,minf(vp,v-0.8) if v-0.8 >= vp else vp,jl,jr)
    if row.size() == 1:
        MODS.garage(a,v,float(p["d"]),palette,variant)
    else:
        MODS.workshop(a,v,float(p["d"]),jl,jr,row.size(),idx,palette,variant)
    if idx%2 == 0 and not jl:
        MODS.lamp(a,0.7,vp+0.35)

func _draw_fence(a, c: Vector2i, p: Dictionary) -> void:
    var fr: Array = rules.frame(c,p["f"])
    a.set_frame(fr)
    var jl: bool = RULES.joined(plan_cells,c,-1)
    var jr: bool = RULES.joined(plan_cells,c,1)
    MODS.fence(a,float(p["v"]),jl,jr)
    if RULES.hash4(world_seed,c.x,c.y,97)%3 == 0:
        MODS.lamp(a,7.0,float(p["v"])+0.6)

## Vertex / chunk counts (performance report).
func mesh_stats() -> Dictionary:
    var verts: int = 0
    var tris: int = 0
    var multimeshes: int = 0
    var instances: int = 0
    for node in chunk_nodes.values():
        for ch in (node as Node).get_children():
            if ch is MeshInstance3D:
                var m: ArrayMesh = (ch as MeshInstance3D).mesh
                for s in range(m.get_surface_count()):
                    var arr: Array = m.surface_get_arrays(s)
                    verts += (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
                    tris += (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size()/3
            elif ch is MultiMeshInstance3D:
                multimeshes += 1
                instances += (ch as MultiMeshInstance3D).multimesh.instance_count
    return {"chunks":chunk_nodes.size(),"vertices":verts,"triangles":tris,
        "multimeshes":multimeshes,"tree_instances":instances}
