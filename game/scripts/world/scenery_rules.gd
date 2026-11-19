extends RefCounted
class_name NitroSceneryRules
## Procedural world, phase A: the RULES (no meshes here).
##
## Input: the 3D builder's road tiles (links), exactly what a saved built
## track stores in its "builder" block, plus a world seed. Output: a plan per
## scenery cell (role, facing, offsets) and per-cell MODULE KEYS that say
## which hand-authored piece to show there given its neighbours.
##
## * Road field: the road through each tile is analytic - a straight through
##   the tile centre, a quarter arc of radius CELL_M/2 in corner tiles - the
##   same shape Track DNA control points follow. clearance(p) = distance to
##   that centreline minus the half width. Track DNA stays authoritative for
##   driving; this field only keeps scenery away from it (generous setbacks,
##   and a test checks every footprint against the compiled race road).
## * Scenery lattice: 4 x 4 cells per road tile (14 m), one tile of margin.
## * Lots: a cell whose road-facing front (snapped to N/E/S/W) can hold a
##   building at SETBACK metres from the road edge, with the road close in
##   front (frontage) and no other frontage cell in front of it. A per-cell
##   hash of the world seed turns lots into buildings or fenced yards.
## * Adjacency: side-by-side buildings with the same facing and setback join
##   into one row (shared roof, no inner walls, continuous fascia); fences
##   join into one run. Keys change only where neighbours change, so an edit
##   rebuilds only the chunks whose keys changed.

const GRID = preload("res://scripts/world/track_grid.gd")
const CELL_M: float = 56.0
const SUB: int = 4
const S: float = 14.0                 # scenery cell size (CELL_M / SUB)
const HALF_ROAD: float = 12.0         # GRID.WIDTH_M / 2
const SETBACK: float = 7.5            # building front >= this from the road edge
const FENCE_SETBACK: float = 5.6      # fence line (beyond the 3.6 m verge)
const PAD_SETBACK: float = 4.4        # concrete apron
const FRONT_MAX: float = 21.0         # frontage: road edge within this of the front
const MIN_DEPTH: float = 7.0
const MAX_DEPTH: float = 9.6
const BACK_GAP: float = 0.8           # roof overhang stays inside the cell
const TREE_CLEAR: float = 3.2         # same rule as the race tree props
const CHUNK_TILES: int = 2            # mesh chunk = 2 x 2 road tiles

var cols: int = 8
var rows: int = 12
var seed: int = 1
var lot_density: float = 0.66
var links: Dictionary = {}            # Vector2i tile -> Array[Vector2i]
var _prims: Dictionary = {}           # tile -> Array of primitives

func _init(columns: int = 8, row_count: int = 12, world_seed: int = 1) -> void:
    cols = columns
    rows = row_count
    seed = world_seed

# ------------------------------------------------------------ deterministic

## Integer hash (same on every platform): world seed, cell, role salt.
static func hash4(a: int, b: int, c: int, d: int) -> int:
    var h: int = 0x2545F491
    for v in [a,b,c,d]:
        h = (h ^ (v & 0xffffffff)) & 0xffffffff
        h = (h*0x01000193) & 0xffffffff
        h = (h ^ (h >> 15)) & 0xffffffff
        h = (h*0x2C1B3C6D) & 0xffffffff
        h = (h ^ (h >> 12)) & 0xffffffff
    return h & 0x7fffffff

func rand01(i: int, j: int, salt: int) -> float:
    return float(hash4(seed,i,j,salt))/2147483647.0

# --------------------------------------------------------------- road field

func world_of(t: Vector2i) -> Vector2:
    return Vector2((float(t.x)-float(cols-1)*0.5)*CELL_M,(float(t.y)-float(rows-1)*0.5)*CELL_M)

func tile_at(p: Vector2) -> Vector2i:
    return Vector2i(int(round(p.x/CELL_M+float(cols-1)*0.5)),int(round(p.y/CELL_M+float(rows-1)*0.5)))

## Road tiles and their links (the builder grid's links dictionary).
func set_links(new_links: Dictionary) -> void:
    links = {}
    for k in new_links.keys():
        links[k] = (new_links[k] as Array).duplicate()
    _prims.clear()
    for t in links.keys():
        _prims[t] = _tile_primitives(t)

## Primitives of the road centreline inside one tile:
## ["p", centre] | ["s", a, b] | ["a", corner, radius, axis_a, axis_b].
func _tile_primitives(t: Vector2i) -> Array:
    var c: Vector2 = world_of(t)
    var ns: Array = links.get(t,[])
    if ns.is_empty():
        return [["p",c]]
    var dirs: Array[Vector2] = []
    for n in ns:
        dirs.append(Vector2(Vector2i(n)-t))
    if dirs.size() == 1:
        return [["s",c,c+dirs[0]*CELL_M*0.5]]
    if dirs[0].dot(dirs[1]) < -0.5:
        return [["s",c+dirs[0]*CELL_M*0.5,c+dirs[1]*CELL_M*0.5]]
    var corner: Vector2 = c+(dirs[0]+dirs[1])*CELL_M*0.5
    # Quarter arc between the two edge midpoints, centred on the tile corner.
    return [["a",corner,CELL_M*0.5,-dirs[1],-dirs[0]]]

## Distance from p to the road centreline (search the 3 x 3 tiles around).
func centre_distance(p: Vector2) -> float:
    var t: Vector2i = tile_at(p)
    var best: float = INF
    for dx in [-1,0,1]:
        for dy in [-1,0,1]:
            var k := Vector2i(t.x+dx,t.y+dy)
            if not _prims.has(k):
                continue
            for prim in _prims[k]:
                best = minf(best,_prim_distance(prim,p))
    return best

static func _prim_distance(prim: Array, p: Vector2) -> float:
    match str(prim[0]):
        "p":
            return p.distance_to(Vector2(prim[1]))
        "s":
            var a: Vector2 = prim[1]
            var b: Vector2 = prim[2]
            var ab: Vector2 = b-a
            var t: float = clampf((p-a).dot(ab)/maxf(ab.length_squared(),0.000001),0.0,1.0)
            return p.distance_to(a+ab*t)
        _:
            var k: Vector2 = prim[1]
            var r: float = float(prim[2])
            var ax: Vector2 = prim[3]
            var bx: Vector2 = prim[4]
            var q: Vector2 = p-k
            if q.dot(ax) >= 0.0 and q.dot(bx) >= 0.0:
                return absf(q.length()-r)
            return minf(p.distance_to(k+ax*r),p.distance_to(k+bx*r))

## Clearance from the road edge (negative on the asphalt).
func clearance(p: Vector2) -> float:
    return centre_distance(p)-HALF_ROAD

# ------------------------------------------------------------ cell geometry

func cell_min() -> Vector2i:
    return Vector2i(-SUB,-SUB)

func cell_max() -> Vector2i:
    return Vector2i(cols*SUB+SUB-1,rows*SUB+SUB-1)

func cell_origin(c: Vector2i) -> Vector2:
    return Vector2(-float(cols)*CELL_M*0.5+float(c.x)*S,-float(rows)*CELL_M*0.5+float(c.y)*S)

func cell_centre(c: Vector2i) -> Vector2:
    return cell_origin(c)+Vector2(S,S)*0.5

## Local frame of a cell facing f (unit axis toward the road): origin at the
## front-left corner, u along the street (right), v into the lot.
func frame(c: Vector2i, f: Vector2i) -> Array:
    var fv := Vector2(f)
    var r := Vector2(-fv.y,fv.x)
    var o: Vector2 = cell_centre(c)+fv*S*0.5-r*S*0.5
    return [o,r,-fv]

static func local_to_world(fr: Array, u: float, v: float) -> Vector2:
    return Vector2(fr[0])+Vector2(fr[1])*u+Vector2(fr[2])*v

func _line_clear(fr: Array, v: float, need: float, u0: float = 0.6, u1: float = S-0.6) -> bool:
    for k in range(5):
        var u: float = lerpf(u0,u1,float(k)/4.0)
        if clearance(local_to_world(fr,u,v)) < need:
            return false
    return true

## Smallest depth v (0.5 m steps) whose street-parallel line clears `need`.
## Coarse 2 m search first, then refine (fewer clearance probes).
func _front_offset(fr: Array, need: float, vmax: float) -> float:
    var v: float = 0.0
    while v <= vmax+0.001:
        if _line_clear(fr,v,need):
            var lo: float = maxf(0.0,v-1.5)
            while lo < v:
                if _line_clear(fr,lo,need):
                    return lo
                lo += 0.5
            return v
        v += 2.0
    if vmax-floor(vmax/2.0)*2.0 > 0.001 and _line_clear(fr,vmax,need):
        var lo2: float = floor(vmax/2.0)*2.0+0.5
        while lo2 <= vmax+0.001:
            if _line_clear(fr,lo2,need):
                return lo2
            lo2 += 0.5
    return -1.0

func _facing(c: Vector2i) -> Vector2i:
    var p: Vector2 = cell_centre(c)
    var e: float = 2.0
    var gx: float = centre_distance(p+Vector2(e,0))-centre_distance(p-Vector2(e,0))
    var gy: float = centre_distance(p+Vector2(0,e))-centre_distance(p-Vector2(0,e))
    # Facing = toward the road = against the distance gradient.
    if absf(gx) >= absf(gy):
        return Vector2i(-int(signf(gx)) if gx != 0.0 else 1,0)
    return Vector2i(0,-int(signf(gy)))

# -------------------------------------------------------------------- plan

## Candidate building lot of a cell (before neighbours): {} when none.
func lot_candidate(c: Vector2i) -> Dictionary:
    var p: Vector2 = cell_centre(c)
    var cd: float = clearance(p)
    if cd > FRONT_MAX+S or cd < -S:
        return {}
    var f: Vector2i = _facing(c)
    var fr: Array = frame(c,f)
    var v: float = _front_offset(fr,SETBACK,S-MIN_DEPTH-BACK_GAP)
    if v < 0.0:
        return {}
    # Frontage: the road edge must be close in front of the facade.
    if clearance(local_to_world(fr,S*0.5,v)) > FRONT_MAX:
        return {}
    var d: float = minf(MAX_DEPTH,S-v-BACK_GAP)
    if d < MIN_DEPTH:
        return {}
    # Whole footprint clear (sides and back may face other roads).
    for vv in [v+d*0.5,v+d]:
        if not _line_clear(fr,vv,SETBACK,0.4,S-0.4):
            return {}
    return {"f":f,"v":v,"d":snappedf(d,0.1)}

## Plan of one cell: role + parameters. Needs the candidates of the cell and
## of the cell in front of it (a second row behind frontage is a yard).
func plan_cell(c: Vector2i, cand: Dictionary) -> Dictionary:
    var mine: Dictionary = cand.get(c,{})
    if not mine.is_empty():
        var f: Vector2i = mine["f"]
        var ahead: Dictionary = cand.get(c+f,{})
        if ahead.is_empty() or Vector2i(ahead["f"]) != f:
            if rand01(c.x,c.y,11) < lot_density:
                return {"role":"lot","f":f,"v":float(mine["v"]),"d":float(mine["d"])}
            var frf: Array = frame(c,f)
            var vf: float = _front_offset(frf,FENCE_SETBACK,9.0)
            if vf >= 0.0:
                return {"role":"fence","f":f,"v":vf,"tree":rand01(c.x,c.y,17) < 0.55}
    # Fence along non-lot frontage of road tiles' side bands too.
    var cd: float = clearance(cell_centre(c))
    if cd > -S and cd < 12.0 and mine.is_empty():
        var f2: Vector2i = _facing(c)
        var fr2: Array = frame(c,f2)
        var v2: float = _front_offset(fr2,FENCE_SETBACK,9.0)
        if v2 >= 0.0 and clearance(local_to_world(fr2,S*0.5,v2)) < FENCE_SETBACK+2.5:
            return {"role":"fence","f":f2,"v":v2,"tree":false}
    return _greenery(c)

const GREEN_REACH: float = 46.0       # trees only this close to the road edge

func _greenery(c: Vector2i) -> Dictionary:
    var cd: float = clearance(cell_centre(c))
    if cd > GREEN_REACH:
        return {"role":"none"}
    var roll: float = rand01(c.x,c.y,23)
    # Denser right behind the frontage, thinning out further back.
    if roll > lerpf(0.62,0.28,clampf((cd-14.0)/(GREEN_REACH-14.0),0.0,1.0)):
        return {"role":"none"}
    var cherry: bool = roll < 0.40
    var radius: float = lerpf(2.3,3.3,rand01(c.x,c.y,29)) if cherry else lerpf(1.9,2.6,rand01(c.x,c.y,29))
    var jitter := Vector2(rand01(c.x,c.y,31)-0.5,rand01(c.x,c.y,37)-0.5)*(S-2.0*radius-1.0)
    var pos: Vector2 = cell_centre(c)+jitter
    if clearance(pos) < radius+TREE_CLEAR:
        return {"role":"none"}
    return {"role":"tree","pos":pos,"cherry":cherry,"radius":radius,
        "height":lerpf(0.9,1.2,rand01(c.x,c.y,41)),"seed":hash4(seed,c.x,c.y,43)}

## Full plan for a set of cells (or the whole lattice when cells is empty).
func plan(cells: Array = []) -> Dictionary:
    var todo: Array = cells
    if todo.is_empty():
        var lo: Vector2i = cell_min()
        var hi: Vector2i = cell_max()
        for x in range(lo.x,hi.x+1):
            for y in range(lo.y,hi.y+1):
                todo.append(Vector2i(x,y))
    # Candidates for the cells and their front neighbours (ring of 1).
    var need: Dictionary = {}
    for c in todo:
        for dx in [-1,0,1]:
            for dy in [-1,0,1]:
                need[Vector2i(c.x+dx,c.y+dy)] = true
    var cand: Dictionary = {}
    for c in need.keys():
        var lc: Dictionary = lot_candidate(c)
        if not lc.is_empty():
            cand[c] = lc
    var out: Dictionary = {}
    for c in todo:
        out[c] = plan_cell(c,cand)
    return out

# ------------------------------------------------------------- module keys

static func _row_axis(f: Vector2i) -> Vector2i:
    return Vector2i(-f.y,f.x)

## Joined to the neighbour on side s (-1 left, +1 right) in the row?
static func joined(pl: Dictionary, c: Vector2i, s: int) -> bool:
    var me: Dictionary = pl.get(c,{})
    if me.is_empty() or not (str(me["role"]) in ["lot","fence"]):
        return false
    var f: Vector2i = me["f"]
    var other: Dictionary = pl.get(c+_row_axis(f)*s,{})
    if other.is_empty() or str(other["role"]) != str(me["role"]) or Vector2i(other["f"]) != f:
        return false
    if absf(float(other["v"])-float(me["v"])) > 0.01:
        return false
    return str(me["role"]) == "fence" or absf(float(other["d"])-float(me["d"])) < 0.01

## Row of joined lots containing c: ordered cells from left to right.
static func row_of(pl: Dictionary, c: Vector2i) -> Array:
    var f: Vector2i = pl[c]["f"]
    var ax: Vector2i = _row_axis(f)
    var left: Vector2i = c
    var guard: int = 0
    while joined(pl,left,-1) and guard < 64:
        left -= ax
        guard += 1
    var row: Array = [left]
    var cur: Vector2i = left
    guard = 0
    while joined(pl,cur,1) and guard < 64:
        cur += ax
        row.append(cur)
        guard += 1
    return row

## Module key of a cell: everything its mesh depends on. Equal keys = the
## identical mesh, so a chunk is rebuilt only if one of its keys changed.
func module_key(pl: Dictionary, c: Vector2i) -> String:
    var me: Dictionary = pl.get(c,{})
    if me.is_empty():
        return ""
    match str(me["role"]):
        "lot":
            var row: Array = row_of(pl,c)
            var idx: int = row.find(c)
            var first: Vector2i = row[0]
            return "lot|%s|%.2f|%.2f|%d|%d|%d|%d|%d|%d" % [str(me["f"]),float(me["v"]),float(me["d"]),
                int(joined(pl,c,-1)),int(joined(pl,c,1)),row.size(),idx,
                hash4(seed,first.x,first.y,53)%5,hash4(seed,c.x,c.y,59)%7]
        "fence":
            return "fence|%s|%.2f|%d|%d|%d|%d" % [str(me["f"]),float(me["v"]),int(joined(pl,c,-1)),
                int(joined(pl,c,1)),int(bool(me["tree"])),hash4(seed,c.x,c.y,61)%4]
        "tree":
            return "tree|%d|%.2f" % [int(me["seed"]),float(me["radius"])]
    return ""

static func chunk_of(c: Vector2i) -> Vector2i:
    var n: int = SUB*CHUNK_TILES
    return Vector2i(int(floor(float(c.x)/float(n))),int(floor(float(c.y)/float(n))))
