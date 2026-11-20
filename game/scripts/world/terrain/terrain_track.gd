extends RefCounted
class_name NitroTerrainTrack
## Glue between the builder grid, the generated terrain, Track DNA and the
## road profile. Builder, race and tests use these functions, so a drawn
## road becomes exactly the same saved data and the same 3D road in all of
## them:
##
##   tiles (drawn order) -> control points -> Track DNA samples
##   -> road heights solved on the terrain (max grade of the archetype)
##   -> knot heights saved in "elevation" -> DNA rebuilds per-sample heights
##      with the same spline in the builder preview AND in the race.
const DNA = preload("res://scripts/world/track_dna.gd")
const GRID = preload("res://scripts/world/track_grid.gd")
const CAT = preload("res://scripts/world/terrain/terrain_catalog.gd")
const FIELD = preload("res://scripts/world/terrain/terrain_field.gd")
const PROFILE = preload("res://scripts/world/terrain/road_profile.gd")

const DATA_VERSION: int = 1

static func new_grid() -> NitroTrackGrid:
    return GRID.new(FIELD.COLS,FIELD.ROWS)

## Ordered tiles of the current drawing: the closed loop, or the single open
## chain in the given preferred direction (first tile = start).
static func route_order(grid: NitroTrackGrid, prefer_start: Vector2i = Vector2i(-1,-1)) -> Dictionary:
    var parts: Array = grid.components()
    if parts.size() != 1:
        return {"order":[],"closed":false,"parts":parts.size()}
    var part: Dictionary = parts[0]
    var cells: Array[Vector2i] = []
    for c in part["cells"]:
        cells.append(c)
    if bool(part["closed"]):
        return {"order":grid.loop(),"closed":true,"parts":1}
    if prefer_start.x >= 0 and cells.size() > 1 and cells[cells.size()-1] == prefer_start:
        cells.reverse()
    return {"order":cells,"closed":false,"parts":1}

## Full saved track (schema 1 + optional world / elevation blocks).
static func track_data(grid: NitroTrackGrid, order: Array[Vector2i], closed: bool, field: NitroTerrainField,
        desc: Dictionary, track_name: String, track_id: String) -> Dictionary:
    var raw: Array = []
    for p in grid.control_points(order,closed):
        raw.append([snappedf(p.x,0.001),snappedf(p.y,0.001)])
    var tiles: Array = []
    for c in order:
        tiles.append([c.x,c.y])
    var arch: String = str(desc.get("archetype","jp_sakura"))
    var data: Dictionary = {"schema_version":1,"id":track_id,"name":track_name,"generator_version":4,
        "seed":int(desc.get("terrain_seed",0)),"closed":closed,"topology":"closed" if closed else "open",
        "width_m":GRID.WIDTH_M,"start_index":0,"theme":"terrain_"+arch,
        "description":"Built on generated terrain with the Nitro Wheelz terrain-first builder.",
        "builder":{"cols":grid.cols,"rows":grid.rows,"cell_m":GRID.CELL_M,"tiles":tiles,"closed":closed,
            "kind":"terrain"},
        "control_points":raw,"world":desc.duplicate(true)}
    if field == null or raw.size() < (8 if closed else 4):
        return data
    var flat: Dictionary = DNA.compile(data)
    if not bool(flat.get("ok",false)):
        return data
    var samples: Array[Vector2] = flat["centerline"]
    var hw: PackedFloat32Array = flat["halfwidths"]
    var grade: float = float(CAT.info(arch)["grade"])
    var h: PackedFloat32Array = PROFILE.solve(field,samples,hw,closed,grade)
    data["elevation"] = {"version":DATA_VERSION,"max_grade":grade,
        "knot_heights":PROFILE.knot_heights(h,raw.size(),DNA.SUBDIVISIONS)}
    return data

## Compile + classify against the terrain. "ok" = geometry valid and no
## unbuildable (red) sample.
static func evaluate(field: NitroTerrainField, data: Dictionary) -> Dictionary:
    var compiled: Dictionary = DNA.compile(data)
    if not bool(compiled.get("ok",false)):
        return {"ok":false,"compiled":compiled,"errors":compiled.get("errors",PackedStringArray()),"class":{}}
    var heights: PackedFloat32Array = compiled["heights"]
    if heights.size() != (compiled["centerline"] as Array).size():
        return {"ok":false,"compiled":compiled,"errors":PackedStringArray(["NO ELEVATION"]),"class":{}}
    var cls: Dictionary = PROFILE.classify(field,compiled["centerline"],compiled["halfwidths"],heights,
        bool(compiled["closed"]))
    var g: PackedFloat32Array = PROFILE.grades(heights,compiled["centerline"],bool(compiled["closed"]))
    var gmax: float = 0.0
    for v in g:
        gmax = maxf(gmax,absf(v))
    var errs := PackedStringArray()
    for r in cls["reasons"]:
        errs.append(str(r))
    return {"ok":int(cls["worst"]) < 2,"compiled":compiled,"class":cls,"errors":errs,"max_grade":gmax}

static func _buildable(map: Dictionary, c: Vector2i) -> bool:
    return map.has(c) and int(map[c]["state"]) < 2

## Random closed loop over buildable tiles (rectangle grown edge by edge).
static func generate_loop(grid: NitroTrackGrid, field: NitroTerrainField, desc: Dictionary, seed_value: int,
        target_tiles: int = 26) -> Dictionary:
    var map: Dictionary = field.build_map()
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_value
    for attempt in range(40):
        var order: Array[Vector2i] = _grow(map,grid,rng,target_tiles)
        if order.size() < 8:
            continue
        grid.clear()
        for i in range(order.size()):
            grid.link(order[i],order[(i+1)%order.size()])
        var ro: Dictionary = route_order(grid)
        if not bool(ro["closed"]):
            continue
        var data: Dictionary = track_data(grid,ro["order"],true,field,desc,"Generated","gen_%d" % seed_value)
        var ev: Dictionary = evaluate(field,data)
        if bool(ev["ok"]):
            return {"ok":true,"data":data,"eval":ev,"attempts":attempt+1}
    grid.clear()
    return {"ok":false,"attempts":40}

static func _grow(map: Dictionary, grid: NitroTrackGrid, rng: RandomNumberGenerator, target: int) -> Array[Vector2i]:
    var empty: Array[Vector2i] = []
    for _try in range(60):
        var w: int = rng.randi_range(2,5)
        var h: int = rng.randi_range(3,7)
        var x0: int = rng.randi_range(1,maxi(1,grid.cols-w-2))
        var y0: int = rng.randi_range(1,maxi(1,grid.rows-h-2))
        var order: Array[Vector2i] = []
        for x in range(x0,x0+w):
            order.append(Vector2i(x,y0))
        for y in range(y0,y0+h):
            order.append(Vector2i(x0+w,y))
        for x in range(x0+w,x0,-1):
            order.append(Vector2i(x,y0+h))
        for y in range(y0+h,y0,-1):
            order.append(Vector2i(x0,y))
        var ok: bool = true
        for c in order:
            if not _buildable(map,c):
                ok = false
                break
        if not ok:
            continue
        var used: Dictionary = {}
        for c2 in order:
            used[c2] = true
        var tries: int = 0
        while order.size() < target and tries < 500:
            tries += 1
            var i: int = rng.randi_range(0,order.size()-1)
            var a: Vector2i = order[i]
            var b: Vector2i = order[(i+1)%order.size()]
            var d: Vector2i = b-a
            var nrm := Vector2i(-d.y,d.x) if rng.randf() < 0.5 else Vector2i(d.y,-d.x)
            var a2: Vector2i = a+nrm
            var b2: Vector2i = b+nrm
            if used.has(a2) or used.has(b2) or not _buildable(map,a2) or not _buildable(map,b2):
                continue
            # Prefer green tiles: amber is accepted less often.
            var amber: int = int(map[a2]["state"])+int(map[b2]["state"])
            if amber > 0 and rng.randf() < 0.45:
                continue
            order.insert(i+1,b2)
            order.insert(i+1,a2)
            used[a2] = true
            used[b2] = true
        return order
    return empty

## Random open point-to-point route over buildable tiles.
static func generate_route(grid: NitroTrackGrid, field: NitroTerrainField, desc: Dictionary, seed_value: int,
        length_tiles: int = 16) -> Dictionary:
    var map: Dictionary = field.build_map()
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_value
    for attempt in range(60):
        var start := Vector2i(rng.randi_range(1,grid.cols-2),rng.randi_range(1,grid.rows-2))
        if not _buildable(map,start):
            continue
        var order: Array[Vector2i] = [start]
        var used: Dictionary = {start:true}
        var dir: Vector2i = [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)][rng.randi_range(0,3)]
        var run: int = 0
        while order.size() < length_tiles:
            var opts: Array = []
            for d in [dir,Vector2i(dir.y,-dir.x),Vector2i(-dir.y,dir.x)]:
                var nxt: Vector2i = order[order.size()-1]+d
                if used.has(nxt) or not _buildable(map,nxt):
                    continue
                # keep one free tile from earlier parts of the route
                var crowded: bool = false
                for e in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
                    var nb: Vector2i = nxt+e
                    if used.has(nb) and nb != order[order.size()-1]:
                        crowded = true
                if crowded:
                    continue
                var wgt: float = 3.0 if d == dir and run < 3 else 1.0
                if int(map[nxt]["state"]) == 1:
                    wgt *= 0.5
                opts.append([d,wgt])
            if opts.is_empty():
                break
            var total: float = 0.0
            for o in opts:
                total += float(o[1])
            var r: float = rng.randf()*total
            var pick: Vector2i = opts[0][0]
            for o2 in opts:
                r -= float(o2[1])
                if r <= 0.0:
                    pick = o2[0]
                    break
            run = run+1 if pick == dir else 0
            dir = pick
            var nc: Vector2i = order[order.size()-1]+dir
            order.append(nc)
            used[nc] = true
        if order.size() < maxi(6,length_tiles-4):
            continue
        grid.clear()
        for i in range(order.size()-1):
            grid.link(order[i],order[i+1])
        var data: Dictionary = track_data(grid,order,false,field,desc,"Generated route","route_%d" % seed_value)
        var ev: Dictionary = evaluate(field,data)
        if bool(ev["ok"]):
            return {"ok":true,"data":data,"eval":ev,"order":order,"attempts":attempt+1}
    grid.clear()
    return {"ok":false,"attempts":60}

## CLOSE LOOP: shortest buildable path between the two ends of an open
## chain (amber tiles cost more), avoiding the chain's own tiles.
static func close_path(grid: NitroTrackGrid, field: NitroTerrainField, order: Array[Vector2i]) -> Array[Vector2i]:
    var out: Array[Vector2i] = []
    if order.size() < 2:
        return out
    var map: Dictionary = field.build_map()
    var a: Vector2i = order[order.size()-1]
    var b: Vector2i = order[0]
    var blocked: Dictionary = {}
    for c in order:
        blocked[c] = true
    blocked.erase(a)
    blocked.erase(b)
    var dist: Dictionary = {a:0.0}
    var prev: Dictionary = {}
    var open: Array = [a]
    while not open.is_empty():
        var best_i: int = 0
        for i in range(open.size()):
            if float(dist[open[i]]) < float(dist[open[best_i]]):
                best_i = i
        var cur: Vector2i = open[best_i]
        open.remove_at(best_i)
        if cur == b:
            break
        for d in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
            var nb: Vector2i = cur+d
            if blocked.has(nb) or not _buildable(map,nb):
                continue
            if cur == a and nb == b and order.size() < 3:
                continue
            var cost: float = float(dist[cur])+(1.0 if int(map[nb]["state"]) == 0 else 2.5)
            if not dist.has(nb) or cost < float(dist[nb]):
                dist[nb] = cost
                prev[nb] = cur
                if not open.has(nb):
                    open.append(nb)
    if not prev.has(b) and not (a-b).abs() in [Vector2i(1,0),Vector2i(0,1)]:
        return out
    var c2: Vector2i = b
    while prev.has(c2) and prev[c2] != a:
        c2 = prev[c2]
        out.push_front(c2)
    return out

## World descriptor of a saved track ({} for legacy flat tracks).
static func world_of(data: Dictionary) -> Dictionary:
    var w: Variant = data.get("world",null)
    if w is Dictionary and str(w.get("kind","")) == "terrain" and CAT.ARCHETYPES.has(str(w.get("archetype",""))):
        return w
    return {}

## Rebuild the builder grid from saved terrain data (open or closed).
static func load_grid(grid: NitroTrackGrid, data: Dictionary) -> Dictionary:
    var b: Variant = data.get("builder",null)
    if not (b is Dictionary):
        return {"ok":false}
    var tiles: Array = b.get("tiles",[])
    var closed: bool = bool(b.get("closed",true))
    grid.clear()
    var order: Array[Vector2i] = []
    for t in tiles:
        order.append(Vector2i(int(t[0]),int(t[1])))
    var links: int = order.size() if closed else order.size()-1
    for i in range(links):
        if grid.link(order[i],order[(i+1)%order.size()]) not in ["ok","linked"]:
            grid.clear()
            return {"ok":false}
    return {"ok":true,"order":order,"closed":closed}
