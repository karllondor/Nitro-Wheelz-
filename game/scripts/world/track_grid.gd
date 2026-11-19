extends RefCounted
class_name NitroTrackGrid
## Tile model behind the 3D "tap to build" track builder.
## Each road tile is one CELL_M square. Tiles are joined by explicit links
## made while dragging, never by mere adjacency, so parallel strands may sit
## side by side. A tile accepts at most two links: the result is always a
## set of simple chains/loops and the drivable track is exactly one closed
## loop. The loop is converted to Track DNA control points (straights through
## tile centres, quarter arcs of radius CELL_M/2 in corner tiles), so the
## racing geometry is validated by the same fail-closed compiler as every
## other circuit.

const DNA = preload("res://scripts/world/track_dna.gd")
const CELL_M: float = 56.0
const WIDTH_M: float = 24.0
const MIN_LOOP_TILES: int = 4

var cols: int = 9
var rows: int = 14
var links: Dictionary = {}   # Vector2i -> Array[Vector2i]

func _init(columns: int = 9, row_count: int = 14) -> void:
    cols = columns
    rows = row_count

# ----------------------------------------------------------------- basics

func in_bounds(c: Vector2i) -> bool:
    return c.x >= 0 and c.y >= 0 and c.x < cols and c.y < rows

func is_road(c: Vector2i) -> bool:
    return links.has(c)

func neighbours(c: Vector2i) -> Array:
    return links.get(c,[])

func degree(c: Vector2i) -> int:
    return (links.get(c,[]) as Array).size()

func tile_count() -> int:
    return links.size()

func world_of(c: Vector2i) -> Vector2:
    return Vector2((float(c.x)-float(cols-1)*0.5)*CELL_M,(float(c.y)-float(rows-1)*0.5)*CELL_M)

func cell_at(p: Vector2) -> Vector2i:
    return Vector2i(int(round(p.x/CELL_M+float(cols-1)*0.5)),int(round(p.y/CELL_M+float(rows-1)*0.5)))

func size_metres() -> Vector2:
    return Vector2(float(cols)*CELL_M,float(rows)*CELL_M)

func snapshot() -> Dictionary:
    var copy: Dictionary = {}
    for key in links.keys():
        copy[key] = (links[key] as Array).duplicate()
    return copy

func restore(state: Dictionary) -> void:
    links = {}
    for key in state.keys():
        links[key] = (state[key] as Array).duplicate()

func clear() -> void:
    links = {}

# ---------------------------------------------------------------- editing

func add_tile(c: Vector2i) -> String:
    if not in_bounds(c):
        return "out_of_bounds"
    if not links.has(c):
        links[c] = []
    return "ok"

## Join two 4-adjacent tiles. Returns "ok", "linked" (already joined),
## "out_of_bounds", "not_adjacent" or "junction" (a tile already has two).
func link(a: Vector2i, b: Vector2i) -> String:
    if not in_bounds(a) or not in_bounds(b):
        return "out_of_bounds"
    var d: Vector2i = b-a
    if absi(d.x)+absi(d.y) != 1:
        return "not_adjacent"
    if links.has(a) and (links[a] as Array).has(b):
        return "linked"
    if degree(a) >= 2 or degree(b) >= 2:
        return "junction"
    add_tile(a)
    add_tile(b)
    (links[a] as Array).append(b)
    (links[b] as Array).append(a)
    return "ok"

func erase(c: Vector2i) -> bool:
    if not links.has(c):
        return false
    for other in links[c]:
        (links[other] as Array).erase(c)
    links.erase(c)
    return true

# ------------------------------------------------------------- structure

## Ordered chains and loops: [{"cells": Array[Vector2i], "closed": bool}]
func components() -> Array:
    var seen: Dictionary = {}
    var out: Array = []
    var keys: Array = links.keys()
    keys.sort()
    # Chains first (start at an end), then the remaining loops.
    for pass_index in range(2):
        for start in keys:
            if seen.has(start):
                continue
            if pass_index == 0 and degree(start) == 2:
                continue
            var order: Array[Vector2i] = [start]
            seen[start] = true
            var prev: Vector2i = start
            var current: Vector2i = start
            var closed: bool = false
            while true:
                var step: Vector2i = Vector2i(-99999,-99999)
                for n in links[current]:
                    if n != prev and not seen.has(n):
                        step = n
                        break
                if step.x == -99999:
                    if degree(current) == 2 and order.size() >= MIN_LOOP_TILES and (links[current] as Array).has(start):
                        closed = true
                    break
                order.append(step)
                seen[step] = true
                prev = current
                current = step
            out.append({"cells":order,"closed":closed})
    return out

## The drivable loop (ordered, starting on the longest straight) or [].
func loop() -> Array[Vector2i]:
    var parts: Array = components()
    if parts.size() != 1 or not bool(parts[0]["closed"]):
        return []
    return _start_on_straight(parts[0]["cells"])

func open_ends() -> Array[Vector2i]:
    var ends: Array[Vector2i] = []
    for c in links.keys():
        if degree(c) < 2:
            ends.append(c)
    return ends

func _is_straight(prev: Vector2i, c: Vector2i, next: Vector2i) -> bool:
    return (c-prev) == (next-c)

func _start_on_straight(order: Array[Vector2i]) -> Array[Vector2i]:
    var n: int = order.size()
    var best_start: int = 0
    var best_run: int = -1
    for i in range(n):
        var run: int = 0
        while run < n and _is_straight(order[(i+run-1+n)%n],order[(i+run)%n],order[(i+run+1)%n]):
            run += 1
        if run > best_run:
            best_run = run
            best_start = i
    var rotated: Array[Vector2i] = []
    for k in range(n):
        rotated.append(order[(best_start+k)%n])
    return rotated

# ------------------------------------------------------- geometry output

## Points on the quarter arc of a corner tile at the given fractions of 90°.
func _corner_arc(prev: Vector2i, c: Vector2i, next: Vector2i, fractions: Array) -> Array[Vector2]:
    var centre: Vector2 = world_of(c)
    var entry: Vector2 = (world_of(prev)+centre)*0.5
    var exit: Vector2 = (world_of(next)+centre)*0.5
    var pivot: Vector2 = entry+exit-centre
    var r: float = CELL_M*0.5
    var u: Vector2 = (entry-pivot)/r
    var v: Vector2 = (exit-pivot)/r
    var out: Array[Vector2] = []
    for f in fractions:
        var theta: float = float(f)*PI*0.5
        out.append(pivot+(u*cos(theta)+v*sin(theta))*r)
    return out

## Control points for a closed loop: tile entry midpoints plus either the
## tile centre (straight) or the 30/60-degree points of its quarter arc.
func control_points(order: Array[Vector2i], closed: bool = true) -> Array[Vector2]:
    var pts: Array[Vector2] = []
    var n: int = order.size()
    if n == 0:
        return pts
    if n == 1:
        var c: Vector2 = world_of(order[0])
        pts.append(c-Vector2(CELL_M*0.4,0))
        pts.append(c)
        pts.append(c+Vector2(CELL_M*0.4,0))
        return pts
    for i in range(n):
        var c2: Vector2i = order[i]
        if not closed and i == 0:
            pts.append(world_of(c2))
            continue
        var prev: Vector2i = order[(i-1+n)%n]
        pts.append((world_of(prev)+world_of(c2))*0.5)
        if not closed and i == n-1:
            pts.append(world_of(c2))
            continue
        var next: Vector2i = order[(i+1)%n]
        if _is_straight(prev,c2,next):
            pts.append(world_of(c2))
        else:
            # 30/60-degree points. The uniform Catmull-Rom tightens the 28 m
            # arc to ~22 m at straight joints and ~18 m inside S-bends, above
            # the 16 m Track DNA minimum (which is never relaxed here).
            pts.append_array(_corner_arc(prev,c2,next,[1.0/3.0,2.0/3.0]))
    return pts

## Dense centreline for the live preview, using the same uniform
## Catmull-Rom as Track DNA (open chains clamp their end points).
func preview_samples(order: Array[Vector2i], closed: bool, per_segment: int = 8) -> Array[Vector2]:
    var pts: Array[Vector2] = control_points(order,closed)
    var out: Array[Vector2] = []
    var n: int = pts.size()
    if n < 2:
        return pts
    var segs: int = n if closed else n-1
    for i in range(segs):
        var p0: Vector2 = pts[(i-1+n)%n] if (closed or i > 0) else pts[0]
        var p1: Vector2 = pts[i]
        var p2: Vector2 = pts[(i+1)%n]
        var p3: Vector2 = pts[(i+2)%n] if (closed or i+2 < n) else pts[n-1]
        for j in range(per_segment):
            var t: float = float(j)/float(per_segment)
            out.append(0.5*(2.0*p1+(-p0+p2)*t+(2.0*p0-5.0*p1+4.0*p2-p3)*t*t+(-p0+3.0*p1-3.0*p2+p3)*t*t*t))
    if not closed:
        out.append(pts[n-1])
    return out

func to_track_data(track_name: String, track_id: String, seed: int = 0) -> Dictionary:
    var order: Array[Vector2i] = loop()
    var raw: Array = []
    for p in control_points(order,true):
        raw.append([snappedf(p.x,0.001),snappedf(p.y,0.001)])
    var tiles: Array = []
    for c in order:
        tiles.append([c.x,c.y])
    return {"schema_version":1,"id":track_id,"name":track_name,"generator_version":3,
        "seed":seed,"closed":true,"width_m":WIDTH_M,"start_index":0,"theme":"japan_drift_night",
        "description":"Built with the Nitro Wheelz 3D track builder.",
        "builder":{"cols":cols,"rows":rows,"cell_m":CELL_M,"tiles":tiles},
        "control_points":raw}

func load_builder_data(data: Dictionary) -> bool:
    var builder: Variant = data.get("builder",null)
    if not (builder is Dictionary):
        return false
    var tiles: Variant = builder.get("tiles",[])
    if not (tiles is Array) or tiles.size() < MIN_LOOP_TILES:
        return false
    cols = int(builder.get("cols",cols))
    rows = int(builder.get("rows",rows))
    clear()
    var order: Array[Vector2i] = []
    for t in tiles:
        order.append(Vector2i(int(t[0]),int(t[1])))
    for i in range(order.size()):
        if link(order[i],order[(i+1)%order.size()]) not in ["ok","linked"]:
            clear()
            return false
    return true

func validate() -> Dictionary:
    var order: Array[Vector2i] = loop()
    if order.is_empty():
        return {"ok":false,"errors":PackedStringArray(["Track is not one closed loop yet"])}
    return DNA.compile(to_track_data("check","builder_check"))

# ------------------------------------------------------------- generator

## Procedural loop: start from a rectangle and repeatedly push random
## edges outward/inward by one tile (always a simple closed loop).
func generate(seed: int, target_tiles: int = 30) -> bool:
    var rng := RandomNumberGenerator.new()
    rng.seed = seed
    for attempt in range(12):
        var order: Array[Vector2i] = _grow_loop(rng,target_tiles)
        clear()
        for i in range(order.size()):
            link(order[i],order[(i+1)%order.size()])
        if bool(validate().get("ok",false)):
            return true
    clear()
    return false

func _grow_loop(rng: RandomNumberGenerator, target_tiles: int) -> Array[Vector2i]:
    var w: int = rng.randi_range(2,maxi(2,cols-5))
    var h: int = rng.randi_range(3,maxi(3,rows-6))
    var x0: int = rng.randi_range(1,maxi(1,cols-w-2))
    var y0: int = rng.randi_range(1,maxi(1,rows-h-2))
    var order: Array[Vector2i] = []
    for x in range(x0,x0+w):
        order.append(Vector2i(x,y0))
    for y in range(y0,y0+h):
        order.append(Vector2i(x0+w,y))
    for x in range(x0+w,x0,-1):
        order.append(Vector2i(x,y0+h))
    for y in range(y0+h,y0,-1):
        order.append(Vector2i(x0,y))
    var used: Dictionary = {}
    for c in order:
        used[c] = true
    var tries: int = 0
    while order.size() < target_tiles and tries < 600:
        tries += 1
        var i: int = rng.randi_range(0,order.size()-1)
        var a: Vector2i = order[i]
        var b: Vector2i = order[(i+1)%order.size()]
        var d: Vector2i = b-a
        var normal := Vector2i(-d.y,d.x) if rng.randf() < 0.5 else Vector2i(d.y,-d.x)
        var a2: Vector2i = a+normal
        var b2: Vector2i = b+normal
        if not in_bounds(a2) or not in_bounds(b2) or used.has(a2) or used.has(b2):
            continue
        order.insert(i+1,b2)
        order.insert(i+1,a2)
        used[a2] = true
        used[b2] = true
    return order
