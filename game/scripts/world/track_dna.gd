extends RefCounted
class_name NitroTrackDNA
## Deterministic curve compiler and fail-closed circuit validator.
## Tracks are data, not handcrafted mesh geometry. No randomness without
## an explicitly versioned seed. Edges, walls and contact use these samples.
const SUBDIVISIONS: int = 12
const MIN_RADIUS_M: float = 16.0
const MIN_SEGMENT_M: float = 0.06
const MIN_CLEARANCE_M: float = 3.0
const LOCAL_ARC_NEIGHBOURHOOD_M: float = 55.0

static func read_track(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {"ok":false,"errors":PackedStringArray(["Missing track JSON: "+path])}
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    if not (raw is Dictionary):
        return {"ok":false,"errors":PackedStringArray(["Invalid JSON object: "+path])}
    return compile(raw)

static func compile(data: Dictionary) -> Dictionary:
    var errors := PackedStringArray()
    # v0.1.25: point-to-point routes (closed = false, topology "open") are
    # accepted with their own open-chain sampling and validation; closed
    # loops are compiled exactly as before.
    var open_route: bool = not bool(data.get("closed",false)) and str(data.get("topology","")) == "open"
    if int(data.get("schema_version",0)) != 1 or (not bool(data.get("closed",false)) and not open_route):
        errors.append("Only schema 1 closed loops are accepted")
    var raw_points: Variant = data.get("control_points",[])
    var min_points: int = 4 if open_route else 8
    if not (raw_points is Array) or raw_points.size() < min_points:
        errors.append("At least %s control points are required" % ("four" if open_route else "eight"))
        return {"ok":false,"errors":errors}
    var points: Array[Vector2] = []
    for item in raw_points:
        if not (item is Array) or item.size() != 2:
            errors.append("Each knot must contain exactly two coordinates")
            break
        var x: float = float(item[0])
        var y: float = float(item[1])
        if not is_finite(x) or not is_finite(y):
            errors.append("Non-finite knot")
            break
        points.append(Vector2(x,y))
    if not errors.is_empty():
        return {"ok":false,"errors":errors}
    for i in range(points.size()-(1 if open_route else 0)):
        if points[i].distance_to(points[(i+1)%points.size()]) < 8.0:
            errors.append("Duplicate or too-close control points at %d" % i)
            return {"ok":false,"errors":errors}

    var raw_widths: Variant = data.get("widths_m",[])
    var widths: PackedFloat32Array = PackedFloat32Array()
    var default_width: float = float(data.get("width_m",24.0))
    if not (raw_widths is Array) or (not raw_widths.is_empty() and raw_widths.size()!=points.size()):
        errors.append("Width profile must be empty or equal control point count")
        return {"ok":false,"errors":errors}
    for i in range(points.size()):
        var w: float = float(raw_widths[i]) if not raw_widths.is_empty() else default_width
        if not is_finite(w) or w < 12.0 or w > 34.0:
            errors.append("Road width outside 12–34 m at knot %d" % i)
            return {"ok":false,"errors":errors}
        widths.append(w)

    var curve: Dictionary = sample_curve_open(points,widths) if open_route else sample_curve(points,widths)
    var samples: Array[Vector2] = curve["centerline"]
    var left: Array[Vector2] = curve["left_edge"]
    var right: Array[Vector2] = curve["right_edge"]
    var halfwidths: PackedFloat32Array = curve["halfwidths"]
    var checked: PackedStringArray = validate_geometry(samples,left,right,halfwidths,not open_route)
    errors.append_array(checked)
    if open_route and float(curve["length_metres"]) < 150.0:
        errors.append("Open route shorter than 150 m")
    # Optional elevation (terrain worlds): one height per control point,
    # expanded with the same spline as the centreline. Legacy tracks: flat.
    var heights := PackedFloat32Array()
    var elev: Variant = data.get("elevation",null)
    if elev is Dictionary and (elev.get("knot_heights",[]) as Array).size() == points.size():
        heights = load("res://scripts/world/terrain/road_profile.gd").from_knots(
            elev["knot_heights"],not open_route,SUBDIVISIONS)
        for hv in heights:
            if not is_finite(hv) or absf(hv) > 2000.0:
                errors.append("Invalid elevation profile")
                heights = PackedFloat32Array()
                break
    return {"ok":errors.is_empty(),"errors":errors,
        "centerline":samples,"left_edge":left,"right_edge":right,
        "halfwidths":halfwidths,"arc_lengths":curve["arc_lengths"],
        "length_metres":float(curve["length_metres"]),"track_id":str(data.get("id","unnamed")),
        "track_name":str(data.get("name",data.get("id","unnamed"))),
        "seed":int(data.get("seed",0)),"control_points":points,
        "closed":not open_route,"heights":heights}

## Closed Catmull-Rom centreline + road edges, no validation. compile() and
## the editor preview both use this, so the editor draws exactly the road
## (width, edges = barrier lines, start at knot 0) that the race builds.
static func sample_curve(points: Array[Vector2], widths: PackedFloat32Array) -> Dictionary:
    var samples: Array[Vector2] = []
    var halfwidths: PackedFloat32Array = PackedFloat32Array()
    var count: int = points.size()
    for i in range(count):
        var p0: Vector2 = points[(i-1+count)%count]
        var p1: Vector2 = points[i]
        var p2: Vector2 = points[(i+1)%count]
        var p3: Vector2 = points[(i+2)%count]
        for j in range(SUBDIVISIONS):
            var t: float = float(j)/float(SUBDIVISIONS)
            var point: Vector2 = 0.5*(
                2.0*p1 + (-p0+p2)*t +
                (2.0*p0-5.0*p1+4.0*p2-p3)*t*t +
                (-p0+3.0*p1-3.0*p2+p3)*t*t*t)
            samples.append(point)
            halfwidths.append(0.5*lerpf(widths[i],widths[(i+1)%count],t))
    var left: Array[Vector2] = []
    var right: Array[Vector2] = []
    var lengths: PackedFloat32Array = PackedFloat32Array()
    var total: float = 0.0
    for i in range(samples.size()):
        var last: Vector2 = samples[(i-1+samples.size())%samples.size()]
        var next: Vector2 = samples[(i+1)%samples.size()]
        var tangent: Vector2 = (next-last).normalized()
        var normal: Vector2 = Vector2(-tangent.y,tangent.x)
        left.append(samples[i]-normal*halfwidths[i])
        right.append(samples[i]+normal*halfwidths[i])
        lengths.append(total)
        total += samples[i].distance_to(next)
    return {"centerline":samples,"left_edge":left,"right_edge":right,
        "halfwidths":halfwidths,"arc_lengths":lengths,"length_metres":total}

## Open point-to-point route: same uniform Catmull-Rom with clamped end
## knots (exactly like the builder preview), no wrap-around segment.
static func sample_curve_open(points: Array[Vector2], widths: PackedFloat32Array) -> Dictionary:
    var samples: Array[Vector2] = []
    var halfwidths: PackedFloat32Array = PackedFloat32Array()
    var count: int = points.size()
    for i in range(count-1):
        var p0: Vector2 = points[i-1] if i > 0 else points[0]
        var p1: Vector2 = points[i]
        var p2: Vector2 = points[i+1]
        var p3: Vector2 = points[i+2] if i+2 < count else points[count-1]
        for j in range(SUBDIVISIONS):
            var t: float = float(j)/float(SUBDIVISIONS)
            samples.append(0.5*(2.0*p1+(-p0+p2)*t+(2.0*p0-5.0*p1+4.0*p2-p3)*t*t+(-p0+3.0*p1-3.0*p2+p3)*t*t*t))
            halfwidths.append(0.5*lerpf(widths[i],widths[i+1],t))
    samples.append(points[count-1])
    halfwidths.append(0.5*widths[count-1])
    var left: Array[Vector2] = []
    var right: Array[Vector2] = []
    var lengths: PackedFloat32Array = PackedFloat32Array()
    var total: float = 0.0
    var n: int = samples.size()
    for i in range(n):
        var a: Vector2 = samples[maxi(i-1,0)]
        var b: Vector2 = samples[mini(i+1,n-1)]
        var tangent: Vector2 = (b-a).normalized()
        var normal: Vector2 = Vector2(-tangent.y,tangent.x)
        left.append(samples[i]-normal*halfwidths[i])
        right.append(samples[i]+normal*halfwidths[i])
        lengths.append(total)
        if i < n-1:
            total += samples[i].distance_to(samples[i+1])
    return {"centerline":samples,"left_edge":left,"right_edge":right,
        "halfwidths":halfwidths,"arc_lengths":lengths,"length_metres":total}

## Every geometry problem of a sampled loop (validate_geometry() stops at the
## first one). Each entry names the exact sample stretch(es) and the knots
## that shape them, so the editor can highlight precisely what is wrong:
##   {"kind":"tight","from":i,"to":j,"radius":r,"need":m,"knots":[...]}
##   {"kind":"close","a":Vector2i,"b":Vector2i,"gap":g,"need":m,"at_a":p,"at_b":q,"knots":[...]}
##   {"kind":"cross","a":Vector2i,"b":Vector2i,"at":p,"local":bool,"knots":[...]}
## Sample i lies on the spline segment from knot i/SUBDIVISIONS to the next.
static func diagnose(compiled: Dictionary) -> Array[Dictionary]:
    var out: Array[Dictionary] = []
    var center: Array[Vector2] = []
    center.assign(compiled.get("centerline",[]))
    var n: int = center.size()
    if n < 8:
        return out
    var left: Array[Vector2] = []
    left.assign(compiled["left_edge"])
    var right: Array[Vector2] = []
    right.assign(compiled["right_edge"])
    var halfwidths: PackedFloat32Array = compiled["halfwidths"]
    var knots: int = maxi(n/SUBDIVISIONS,1)
    # 1) Corners tighter than the minimum radius, merged into stretches.
    var tight := PackedFloat32Array()
    tight.resize(n)
    for i in range(n):
        tight[i] = -1.0
        var a: Vector2 = center[(i-2+n)%n]
        var b: Vector2 = center[i]
        var c: Vector2 = center[(i+2)%n]
        var cross: float = absf((b-a).cross(c-a))
        if cross > 0.00001:
            var radius: float = a.distance_to(b)*b.distance_to(c)*c.distance_to(a)/(2.0*cross)
            if radius < maxf(MIN_RADIUS_M,halfwidths[i]+2.0):
                tight[i] = radius
    var start: int = 0
    while start < n and tight[start] >= 0.0:
        start += 1
    if start >= n:
        out.append({"kind":"tight","from":0,"to":n-1,"radius":0.0,"need":MIN_RADIUS_M,"knots":range(knots)})
        return out
    var k: int = 1
    while k <= n:
        var i: int = (start+k)%n
        if tight[i] >= 0.0:
            var first: int = start+k
            var worst: float = INF
            var need: float = MIN_RADIUS_M
            while k <= n and tight[(start+k)%n] >= 0.0:
                worst = minf(worst,tight[(start+k)%n])
                need = maxf(need,halfwidths[(start+k)%n]+2.0)
                k += 1
            var last: int = start+k-1
            out.append({"kind":"tight","from":first%n,"to":last%n,"radius":worst,"need":need,
                "knots":_knots_for(first,last,n,knots)})
        k += 1
    # 2) Different parts of the loop too close together (overlapping roads).
    var progress := PackedFloat32Array()
    var perimeter: float = 0.0
    for q in range(n):
        progress.append(perimeter)
        perimeter += center[q].distance_to(center[(q+1)%n])
    var closes: Array[Dictionary] = []
    for i in range(n):
        var a2: Vector2 = center[i]
        var b2: Vector2 = center[(i+1)%n]
        for j in range(i+2,n):
            var along: float = progress[j]-progress[i]
            if minf(along,perimeter-along) <= LOCAL_ARC_NEIGHBOURHOOD_M:
                continue
            var c2: Vector2 = center[j]
            var d2: Vector2 = center[(j+1)%n]
            var gap: float = _segment_distance(a2,b2,c2,d2)
            var safe: float = halfwidths[i]+halfwidths[j]+MIN_CLEARANCE_M
            if gap < safe:
                _merge_pair(closes,i,j,gap,safe,a2.lerp(b2,0.5),c2.lerp(d2,0.5))
    for cl in closes:
        var ra: Vector2i = cl["a"]
        var rb: Vector2i = cl["b"]
        cl["kind"] = "close"
        cl["knots_a"] = _knots_for(ra.x,ra.y+1,n,knots)
        cl["knots_b"] = _knots_for(rb.x,rb.y+1,n,knots)
        cl["knots"] = (cl["knots_a"] as Array)+(cl["knots_b"] as Array)
        out.append(cl)
    # 3) Road or wall rings crossing themselves. Wall rings of two distant
    # stretches only cross when those roads overlap, which (2) already
    # reports as "close"; a real crossing is the centreline itself crossing.
    var crosses: Array[Dictionary] = []
    for r in range(3):
        var ring: Array[Vector2] = center if r == 0 else (left if r == 1 else right)
        for i in range(n):
            var a3: Vector2 = ring[i]
            var b3: Vector2 = ring[(i+1)%n]
            for j in range(i+2,n):
                if i==0 and j==n-1:
                    continue
                var hit: Variant = Geometry2D.segment_intersects_segment(a3,b3,ring[j],ring[(j+1)%n])
                if hit == null:
                    continue
                if r > 0:
                    var along3: float = absf(progress[j]-progress[i])
                    if minf(along3,perimeter-along3) > LOCAL_ARC_NEIGHBOURHOOD_M:
                        continue
                _merge_pair(crosses,i,j,0.0,0.0,hit,hit)
    for cr in crosses:
        var ca: Vector2i = cr["a"]
        var cb: Vector2i = cr["b"]
        var along2: float = absf(progress[cb.x]-progress[ca.x])
        cr["kind"] = "cross"
        cr["at"] = cr["at_a"]
        # A crossing within one corner is an over-tight corner folding its
        # inner wall; a crossing between distant parts is a figure-eight.
        cr["local"] = minf(along2,perimeter-along2) <= LOCAL_ARC_NEIGHBOURHOOD_M
        cr["knots"] = _knots_for(ca.x,ca.y+1,n,knots)+_knots_for(cb.x,cb.y+1,n,knots)
        out.append(cr)
    return out

## Knots that shape samples first..last (unwrapped indices allowed): the
## start knot of every spline segment touched, plus the knot ending the last.
static func _knots_for(first: int, last: int, n: int, knots: int) -> Array:
    var ks: Array = []
    for s in range(first,maxi(last,first)+1):
        var kk: int = int(posmod(s,n)/SUBDIVISIONS)%knots
        if not ks.has(kk):
            ks.append(kk)
    var after: int = (int(posmod(last,n)/SUBDIVISIONS)+1)%knots
    if not ks.has(after):
        ks.append(after)
    return ks

## Groups sample pairs (i, j) into stretch pairs: a pair joins a group when
## both samples are within 3 samples of that group's stretches.
static func _merge_pair(groups: Array[Dictionary], i: int, j: int, gap: float, need: float, pa: Vector2, pb: Vector2) -> void:
    for g in groups:
        var a: Vector2i = g["a"]
        var b: Vector2i = g["b"]
        if i >= a.x-3 and i <= a.y+3 and j >= b.x-3 and j <= b.y+3:
            g["a"] = Vector2i(mini(a.x,i),maxi(a.y,i))
            g["b"] = Vector2i(mini(b.x,j),maxi(b.y,j))
            if gap < float(g["gap"]):
                g["gap"] = gap
                g["at_a"] = pa
                g["at_b"] = pb
            g["need"] = maxf(float(g["need"]),need)
            return
    groups.append({"a":Vector2i(i,i),"b":Vector2i(j,j),"gap":gap,"need":need,"at_a":pa,"at_b":pb})

static func validate_geometry(center: Array[Vector2],left: Array[Vector2],
        right: Array[Vector2], halfwidths: PackedFloat32Array, closed: bool = true) -> PackedStringArray:
    var errors := PackedStringArray()
    var n: int = center.size()
    if n < 8 or left.size()!=n or right.size()!=n or halfwidths.size()!=n:
        errors.append("Invalid sample array dimensions")
        return errors
    if not closed:
        return _validate_open(center,left,right,halfwidths)
    for i in range(n):
        var next_i: int = (i+1)%n
        if center[i].distance_to(center[next_i]) < MIN_SEGMENT_M:
            errors.append("Zero-length edge at %d" % i)
            return errors
        var a: Vector2 = center[(i-2+n)%n]
        var b: Vector2 = center[i]
        var c: Vector2 = center[(i+2)%n]
        var cross: float = absf((b-a).cross(c-a))
        if cross > 0.00001:
            var radius: float = a.distance_to(b)*b.distance_to(c)*c.distance_to(a)/(2.0*cross)
            if radius < maxf(MIN_RADIUS_M,halfwidths[i]+2.0):
                errors.append("Curve radius %.1f m too small at sample %d" % [radius,i])
                return errors
    # Do not test only the centre: unsafe offset meshes can intersect even
    # when a centreline looks superficially acceptable.
    for ring in [center,left,right]:
        var near: Array = _pair_candidates(ring,true,0.01)
        for i in range(n):
            var a: Vector2 = ring[i]
            var b: Vector2 = ring[(i+1)%n]
            for j in near[i]:
                if i==0 and j==n-1:
                    continue
                if Geometry2D.segment_intersects_segment(
                        a,b,ring[j],ring[(j+1)%n]) != null:
                    errors.append("Self-intersecting road / wall ring at segments %d and %d" % [i,j])
                    return errors
    # Neighbourhood is measured in METRES along the loop, not in sample
    # indices. A 271m benchmark and a 1097m circuit have very different
    # sample spacing; a fixed 12-index skip falsely rejects small sweepers.
    # This does not disable intersection tests of centre/left/right rings.
    var progress := PackedFloat32Array()
    var perimeter: float = 0.0
    for k in range(n):
        progress.append(perimeter)
        perimeter += center[k].distance_to(center[(k+1)%n])
    var max_hw: float = 0.0
    for w in halfwidths:
        max_hw = maxf(max_hw,w)
    var near_c: Array = _pair_candidates(center,true,2.0*max_hw+MIN_CLEARANCE_M+0.01)
    for i in range(n):
        var a: Vector2 = center[i]
        var b: Vector2 = center[(i+1)%n]
        for j in near_c[i]:
            var along: float = progress[j]-progress[i]
            if minf(along,perimeter-along) <= LOCAL_ARC_NEIGHBOURHOOD_M:
                continue
            var c: Vector2 = center[j]
            var d: Vector2 = center[(j+1)%n]
            var clearance: float = _segment_distance(a,b,c,d)
            var safe: float = halfwidths[i]+halfwidths[j]+MIN_CLEARANCE_M
            if clearance < safe:
                errors.append("Road corridors overlap near samples %d/%d (%.1fm vs %.1fm)" % [i,j,clearance,safe])
                return errors
    return errors

## Open chain: the same radius, ring-crossing and corridor-overlap rules
## as a loop, without the closing segment (ends are free).
static func _validate_open(center: Array[Vector2],left: Array[Vector2],
        right: Array[Vector2], halfwidths: PackedFloat32Array) -> PackedStringArray:
    var errors := PackedStringArray()
    var n: int = center.size()
    for i in range(n-1):
        if center[i].distance_to(center[i+1]) < MIN_SEGMENT_M:
            errors.append("Zero-length edge at %d" % i)
            return errors
    for i in range(2,n-2):
        var a: Vector2 = center[i-2]
        var b: Vector2 = center[i]
        var c: Vector2 = center[i+2]
        var cross: float = absf((b-a).cross(c-a))
        if cross > 0.00001:
            var radius: float = a.distance_to(b)*b.distance_to(c)*c.distance_to(a)/(2.0*cross)
            if radius < maxf(MIN_RADIUS_M,halfwidths[i]+2.0):
                errors.append("Curve radius %.1f m too small at sample %d" % [radius,i])
                return errors
    for ring in [center,left,right]:
        var near: Array = _pair_candidates(ring,false,0.01)
        for i in range(n-1):
            for j in near[i]:
                if Geometry2D.segment_intersects_segment(ring[i],ring[i+1],ring[j],ring[j+1]) != null:
                    errors.append("Self-intersecting road / wall ring at segments %d and %d" % [i,j])
                    return errors
    var progress := PackedFloat32Array()
    var total: float = 0.0
    for k in range(n):
        progress.append(total)
        if k < n-1:
            total += center[k].distance_to(center[k+1])
    var max_hw2: float = 0.0
    for w2 in halfwidths:
        max_hw2 = maxf(max_hw2,w2)
    var near_o: Array = _pair_candidates(center,false,2.0*max_hw2+MIN_CLEARANCE_M+0.01)
    for i in range(n-1):
        for j in near_o[i]:
            if progress[j]-progress[i] <= LOCAL_ARC_NEIGHBOURHOOD_M:
                continue
            var gap: float = _segment_distance(center[i],center[i+1],center[j],center[j+1])
            var safe: float = halfwidths[i]+halfwidths[j]+MIN_CLEARANCE_M
            if gap < safe:
                errors.append("Road corridors overlap near samples %d/%d (%.1fm vs %.1fm)" % [i,j,gap,safe])
                return errors
    return errors

## Broad phase for the pair tests above (v0.1.25): for every segment i the
## ascending list of segments j >= i+2 whose bounding boxes come within
## `reach` metres. Pairs further apart can neither intersect nor violate the
## corridor clearance, so iterating only these candidates in the same (i, j)
## order gives exactly the same result (and the same first error) as the
## full O(n^2) scan, in a fraction of the time on long tracks.
const PAIR_CELL_M: float = 40.0

static func _pair_candidates(ring: Array[Vector2], closed: bool, reach: float) -> Array:
    var n: int = ring.size()
    var segs: int = n if closed else n-1
    var lo: Array[Vector2] = []
    var hi: Array[Vector2] = []
    var grid: Dictionary = {}
    for i in range(segs):
        var a: Vector2 = ring[i]
        var b: Vector2 = ring[(i+1)%n]
        var l := Vector2(minf(a.x,b.x),minf(a.y,b.y))
        var h := Vector2(maxf(a.x,b.x),maxf(a.y,b.y))
        lo.append(l)
        hi.append(h)
        for cy in range(int(floor(l.y/PAIR_CELL_M)),int(floor(h.y/PAIR_CELL_M))+1):
            for cx in range(int(floor(l.x/PAIR_CELL_M)),int(floor(h.x/PAIR_CELL_M))+1):
                var key := Vector2i(cx,cy)
                if not grid.has(key):
                    grid[key] = PackedInt32Array()
                var list: PackedInt32Array = grid[key]
                list.append(i)
                grid[key] = list
    var out: Array = []
    out.resize(segs)
    for i2 in range(segs):
        var l2: Vector2 = lo[i2]-Vector2.ONE*reach
        var h2: Vector2 = hi[i2]+Vector2.ONE*reach
        var seen: Dictionary = {}
        for cy2 in range(int(floor(l2.y/PAIR_CELL_M)),int(floor(h2.y/PAIR_CELL_M))+1):
            for cx2 in range(int(floor(l2.x/PAIR_CELL_M)),int(floor(h2.x/PAIR_CELL_M))+1):
                var key2 := Vector2i(cx2,cy2)
                if not grid.has(key2):
                    continue
                for j in grid[key2]:
                    if j < i2+2 or seen.has(j):
                        continue
                    if lo[j].x > h2.x or hi[j].x < l2.x or lo[j].y > h2.y or hi[j].y < l2.y:
                        continue
                    seen[j] = true
        var js := PackedInt32Array(seen.keys())
        js.sort()
        out[i2] = js
    return out

static func _segment_distance(a: Vector2,b: Vector2,c: Vector2,d: Vector2) -> float:
    if Geometry2D.segment_intersects_segment(a,b,c,d) != null:
        return 0.0
    return minf(
        minf(_point_to_segment(a,c,d),_point_to_segment(b,c,d)),
        minf(_point_to_segment(c,a,b),_point_to_segment(d,a,b)))

static func _point_to_segment(p: Vector2,a: Vector2,b: Vector2) -> float:
    var v: Vector2 = b-a
    var t: float = clampf((p-a).dot(v)/maxf(v.length_squared(),0.0000001),0.0,1.0)
    return p.distance_to(a+v*t)

## AUTO-SMOOTH core (editor button): repairs invalid geometry with small,
## local moves so the drawn shape stays the player's:
##  * a corner that is too tight: only the knots shaping that corner relax a
##    little towards their neighbours, pass by pass, until it is wide enough;
##  * two parts of the loop too close: the two stretches are pushed apart
##    along the line joining them (each side half the missing gap);
##  * knots on top of each other: pushed apart along their own line;
##  * a real crossing (figure-eight) is not "fixed" - that would redesign the
##    track - and is reported instead.
## No knot may move further than max_move (default: 18% of the track's size,
## at least 20 m). Returns {"ok", "points", "moved" (knot -> metres),
## "max_move", "passes", "reason"}; the input data is not modified.
static func repair(data: Dictionary, max_move: float = -1.0) -> Dictionary:
    var raw: Array = data.get("control_points",[])
    if raw.size() < 8:
        return {"ok":false,"reason":"PLACE AT LEAST 8 NODES FIRST","moved":{},"passes":0}
    var base: Array[Vector2] = []
    for item in raw:
        base.append(Vector2(float(item[0]),float(item[1])))
    var lo := Vector2(INF,INF)
    var hi := Vector2(-INF,-INF)
    for p in base:
        lo = lo.min(p)
        hi = hi.max(p)
    var cap: float = max_move if max_move > 0.0 else maxf(20.0,0.18*lo.distance_to(hi))
    var pts: Array[Vector2] = base.duplicate()
    var work: Dictionary = data.duplicate(true)
    var count: int = pts.size()
    for pass_i in range(160):
        # Untouched knots keep their exact coordinates; moved ones snap to 1 cm.
        var cps: Array = []
        for k in range(count):
            var p: Vector2 = pts[k]
            cps.append(raw[k].duplicate() if p == base[k] else [snappedf(p.x,0.01),snappedf(p.y,0.01)])
        work["control_points"] = cps
        var c: Dictionary = compile(work)
        if bool(c.get("ok",false)):
            var moved: Dictionary = {}
            var worst: float = 0.0
            for k in range(count):
                var d: float = Vector2(float(cps[k][0]),float(cps[k][1])).distance_to(base[k])
                if d > 0.0:
                    moved[k] = d
                    worst = maxf(worst,d)
            return {"ok":true,"points":cps,"moved":moved,"max_move":worst,"passes":pass_i,"reason":""}
        var disp: Array[Vector2] = []
        disp.resize(count)
        for k in range(count):
            disp[k] = Vector2.ZERO
        var errors: PackedStringArray = c.get("errors",PackedStringArray())
        if not c.has("centerline"):
            var first: String = str(errors[0]) if not errors.is_empty() else ""
            var rx := RegEx.new()
            rx.compile("control points at ([0-9]+)")
            var m: RegExMatch = rx.search(first)
            if m == null:
                return {"ok":false,"reason":first,"moved":{},"passes":pass_i}
            var a: int = int(m.get_string(1))%count
            var b: int = (a+1)%count
            var dir: Vector2 = pts[b]-pts[a]
            dir = dir.normalized() if dir.length() > 0.01 else (pts[(b+1)%count]-pts[(a-1+count)%count]).normalized()
            var missing: float = 8.6-pts[a].distance_to(pts[b])
            disp[a] -= dir*missing*0.5
            disp[b] += dir*missing*0.5
        else:
            var probs: Array[Dictionary] = diagnose(c)
            if probs.is_empty():
                return {"ok":false,"reason":str(errors[0]) if not errors.is_empty() else "unknown","moved":{},"passes":pass_i}
            # One relaxation step per knot per pass (several overlapping
            # reports of the same corner must not add up), pushes averaged.
            var relax: Dictionary = {}
            var pushes: Dictionary = {}
            for prob in probs:
                var kind: String = str(prob["kind"])
                if kind == "cross" and not bool(prob["local"]):
                    return {"ok":false,"reason":"TRACK CROSSES ITSELF • move that part away by hand",
                        "moved":{},"passes":pass_i}
                if kind == "close":
                    var dir2: Vector2 = Vector2(prob["at_a"])-Vector2(prob["at_b"])
                    if dir2.length() < 0.01:
                        dir2 = Vector2(1,0)
                    dir2 = dir2.normalized()
                    var push: float = clampf((float(prob["need"])-float(prob["gap"]))*0.5+0.4,0.3,2.5)
                    for side in [["knots_a",1.0],["knots_b",-1.0]]:
                        for k in prob[side[0]]:
                            var acc: Array = pushes.get(int(k),[Vector2.ZERO,0])
                            pushes[int(k)] = [Vector2(acc[0])+dir2*push*float(side[1]),int(acc[1])+1]
                else:
                    for k in prob["knots"]:
                        relax[int(k)] = true
            for kk in relax.keys():
                var mid: Vector2 = (pts[(kk-1+count)%count]+pts[(kk+1)%count])*0.5
                disp[kk] += (mid-pts[kk])*0.22
            for kk in pushes.keys():
                disp[kk] += Vector2(pushes[kk][0])/float(pushes[kk][1])
        for k in range(count):
            pts[k] += disp[k]
            if pts[k].distance_to(base[k]) > cap:
                return {"ok":false,"reason":"FIXING IT WOULD MOVE A NODE MORE THAN %.0f m • reshape by hand" % cap,
                    "moved":{},"passes":pass_i}
    return {"ok":false,"reason":"COULD NOT FIX AUTOMATICALLY • drag the red nodes","moved":{},"passes":160}
