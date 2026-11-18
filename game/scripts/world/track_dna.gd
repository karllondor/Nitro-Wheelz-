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
    if int(data.get("schema_version",0)) != 1 or not bool(data.get("closed",false)):
        errors.append("Only schema 1 closed loops are accepted")
    var raw_points: Variant = data.get("control_points",[])
    if not (raw_points is Array) or raw_points.size() < 8:
        errors.append("At least eight control points are required")
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
    for i in range(points.size()):
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
    var checked: PackedStringArray = validate_geometry(samples,left,right,halfwidths)
    errors.append_array(checked)
    return {"ok":errors.is_empty(),"errors":errors,
        "centerline":samples,"left_edge":left,"right_edge":right,
        "halfwidths":halfwidths,"arc_lengths":lengths,
        "length_metres":total,"track_id":str(data.get("id","unnamed")),
        "track_name":str(data.get("name",data.get("id","unnamed"))),
        "seed":int(data.get("seed",0)),"control_points":points}

static func validate_geometry(center: Array[Vector2],left: Array[Vector2],
        right: Array[Vector2], halfwidths: PackedFloat32Array) -> PackedStringArray:
    var errors := PackedStringArray()
    var n: int = center.size()
    if n < 8 or left.size()!=n or right.size()!=n or halfwidths.size()!=n:
        errors.append("Invalid sample array dimensions")
        return errors
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
        for i in range(n):
            var a: Vector2 = ring[i]
            var b: Vector2 = ring[(i+1)%n]
            for j in range(i+2,n):
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
    for i in range(n):
        var a: Vector2 = center[i]
        var b: Vector2 = center[(i+1)%n]
        for j in range(i+2,n):
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
