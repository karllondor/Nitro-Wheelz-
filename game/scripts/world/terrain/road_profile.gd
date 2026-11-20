extends RefCounted
class_name NitroRoadProfile
## Height-aware road on generated terrain (terrain-first builder + race).
##
## solve(): terrain sampled across the FULL road width + verges, then a
## Lipschitz (max-grade) projection that balances cut and fill: the average
## of the lowest g-Lipschitz profile above the terrain and the highest one
## below it, then a light smoothing (vertical curvature). Closed loops are
## periodic, so h(0) = h(L) and the grade matches across the start line;
## open routes keep different start/finish heights.
##
## classify(): every sample gets an engineering class from the real terrain
## under both road edges and beyond the verges:
##   0 GRADE (green)  1 CUT/FILL slopes (green)  2 CUT WALL  3 FILL WALL
##   4 BRIDGE  5 CLIFF BARRIER  6 UNBUILDABLE (red, with a reason)
const VERGE: float = 3.6
const MARGIN: float = 4.4           # barrier + maintenance strip
## v0.1.27: more than 6 m of fill under the road becomes a bridge (the
## owner prefers bridges to high embankments; the valley stays natural).
const BRIDGE_FILL_M: float = 6.0
const MAX_PIER_M: float = 42.0
const FILL_WALL_M: float = 4.5
const CUT_WALL_M: float = 7.0
const MAX_CUT_M: float = 32.0
const CLIFF_CLEAR_M: float = 2.0    # road edge + verge + barrier margin must stay on land
const SMOOTH_M: float = 34.0
const NAMES: Array[String] = ["GRADE","CUT/FILL","CUT WALL","FILL WALL","BRIDGE","CLIFF BARRIER","UNBUILDABLE"]
const SEVERITY: Array[int] = [0,0,1,1,1,1,2]
## Half-width of the stream channel (bed + banks) that a road must bridge.
const STREAM_CHANNEL_M: float = 11.0

static func arc(samples: Array[Vector2], closed: bool) -> PackedFloat32Array:
    var s := PackedFloat32Array()
    var total: float = 0.0
    for i in range(samples.size()):
        s.append(total)
        if i < samples.size()-1 or closed:
            total += samples[i].distance_to(samples[(i+1)%samples.size()])
    s.append(total)  # last entry = full length (loop includes the closing segment)
    return s

static func _normal(samples: Array[Vector2], i: int, closed: bool) -> Vector2:
    var n: int = samples.size()
    var a: Vector2 = samples[(i-1+n)%n] if (closed or i > 0) else samples[i]
    var b: Vector2 = samples[(i+1)%n] if (closed or i < n-1) else samples[i]
    var t: Vector2 = (b-a).normalized()
    return Vector2(-t.y,t.x)

## Target height per sample: terrain under the road core and both edges.
static func terrain_target(field, samples: Array[Vector2], halfwidths: PackedFloat32Array, closed: bool) -> PackedFloat32Array:
    var out := PackedFloat32Array()
    out.resize(samples.size())
    var last: float = 0.0
    for i in range(samples.size()):
        var p: Vector2 = samples[i]
        var nrm: Vector2 = _normal(samples,i,closed)
        var hw: float = halfwidths[i]
        var acc: float = 0.0
        var w: float = 0.0
        for o in [[0.0,0.40],[-0.6,0.15],[0.6,0.15],[-1.0,0.15],[1.0,0.15]]:
            var q: Vector2 = p+nrm*float(o[0])*hw
            if field.is_water(q.x,q.y):
                continue
            acc += field.base_at(q.x,q.y)*float(o[1])
            w += float(o[1])
        var hh: float = acc/w if w > 0.0 else last
        out[i] = hh
        last = hh
    return out

static func _envelope(h: PackedFloat32Array, s: PackedFloat32Array, g: float, closed: bool, upper: bool) -> PackedFloat32Array:
    # upper=false: lowest g-Lipschitz profile >= h; upper=true: highest <= h.
    var n: int = h.size()
    var out: PackedFloat32Array = h.duplicate()
    var rounds: int = 2 if closed else 1
    for _r in range(rounds):
        for k in range(1,n+(n if closed else 0)):
            var i: int = k%n
            var j: int = (k-1)%n
            var ds: float = _ds(s,j,i,n,closed)
            out[i] = minf(out[i],out[j]+g*ds) if upper else maxf(out[i],out[j]-g*ds)
        for k in range(n-2+(n if closed else 0),-1,-1):
            var i2: int = k%n
            var j2: int = (k+1)%n
            var ds2: float = _ds(s,i2,j2,n,closed)
            out[i2] = minf(out[i2],out[j2]+g*ds2) if upper else maxf(out[i2],out[j2]-g*ds2)
    return out

static func _ds(s: PackedFloat32Array, a: int, b: int, n: int, closed: bool) -> float:
    # Arc distance from sample a to the next sample b (b = a+1, wrapping on loops).
    if b == 0 and closed:
        return s[n]-s[a]
    return absf(s[b]-s[a])

static func _smooth(h: PackedFloat32Array, s: PackedFloat32Array, radius_m: float, closed: bool) -> PackedFloat32Array:
    var n: int = h.size()
    var out := PackedFloat32Array()
    out.resize(n)
    var total: float = s[n]
    for i in range(n):
        var acc: float = h[i]
        var w: float = 1.0
        for dir in [-1,1]:
            var k: int = i
            var dist: float = 0.0
            for _step in range(n):
                var nk: int = k+dir
                if not closed and (nk < 0 or nk >= n):
                    break
                nk = posmod(nk,n)
                var d: float = absf(s[nk]-s[k])
                if closed and absf(nk-k) > 1:
                    d = total-absf(s[nk]-s[k])
                dist += d
                if dist > radius_m:
                    break
                var ww: float = 1.0-dist/radius_m
                acc += h[nk]*ww
                w += ww
                k = nk
        out[i] = acc/w
    return out

## Road heights for the samples (one value per centreline sample).
static func solve(field, samples: Array[Vector2], halfwidths: PackedFloat32Array, closed: bool,
        max_grade: float) -> PackedFloat32Array:
    var n: int = samples.size()
    if n < 2:
        return PackedFloat32Array()
    var s: PackedFloat32Array = arc(samples,closed)
    var target: PackedFloat32Array = terrain_target(field,samples,halfwidths,closed)
    target = _smooth(target,s,SMOOTH_M,closed)
    var g: float = maxf(max_grade,0.005)*0.92
    var lo: PackedFloat32Array = _envelope(target,s,g,closed,false)
    var hi: PackedFloat32Array = _envelope(target,s,g,closed,true)
    var h := PackedFloat32Array()
    h.resize(n)
    for i in range(n):
        h[i] = (lo[i]+hi[i])*0.5
    h = _smooth(h,s,18.0,closed)
    if field.relief == "coast" or bool(field.info.get("sea",false)):
        for i in range(n):
            h[i] = maxf(h[i],1.5)
    return h

## Per-sample grade (rise / run, signed in the direction of travel).
static func grades(h: PackedFloat32Array, samples: Array[Vector2], closed: bool) -> PackedFloat32Array:
    var n: int = h.size()
    var out := PackedFloat32Array()
    out.resize(n)
    for i in range(n):
        var a: int = i-1
        var b: int = i+1
        if closed:
            a = posmod(a,n)
            b = posmod(b,n)
        else:
            a = maxi(a,0)
            b = mini(b,n-1)
        var run: float = samples[a].distance_to(samples[i])+samples[i].distance_to(samples[b])
        out[i] = (h[b]-h[a])/maxf(run,0.01)
    return out

## Engineering class of every sample (see header) + a summary.
static func classify(field, samples: Array[Vector2], halfwidths: PackedFloat32Array, h: PackedFloat32Array,
        closed: bool) -> Dictionary:
    var n: int = samples.size()
    var cls := PackedInt32Array()
    cls.resize(n)
    var reasons: Dictionary = {}
    var worst: int = 0
    var cut_max: float = 0.0
    var fill_max: float = 0.0
    for i in range(n):
        var p: Vector2 = samples[i]
        var nrm: Vector2 = _normal(samples,i,closed)
        var hw: float = halfwidths[i]
        var under_lo: float = INF
        var beyond_hi: float = -INF
        var wet: bool = false
        var over_cliff: bool = false
        var near_cliff: bool = false
        for o in [-1.0,-0.5,0.0,0.5,1.0]:
            var q: Vector2 = p+nrm*o*hw
            under_lo = minf(under_lo,field.base_at(q.x,q.y))
            if field.is_water(q.x,q.y):
                wet = true
            elif field.relief == "canyon" and absf(field.stream_offset(q.x,q.y)) < STREAM_CHANNEL_M:
                wet = true      # v0.1.27: the whole stream channel is bridged, never filled
        for side in [-1.0,1.0]:
            var e: Vector2 = p+nrm*side*(hw+VERGE+MARGIN)
            beyond_hi = maxf(beyond_hi,field.base_at(e.x,e.y))
            if field.relief == "coast":
                var d: float = field.coast_distance(e.x,e.y)
                if d < 0.0:
                    over_cliff = true
                elif d < 10.0:
                    near_cliff = true
        var fill: float = h[i]-under_lo
        var cut: float = beyond_hi-h[i]
        cut_max = maxf(cut_max,cut)
        fill_max = maxf(fill_max,fill)
        var c: int = 0
        if over_cliff or (wet and field.relief == "coast"):
            c = 6
            reasons["ROAD EDGE OVER THE CLIFF / SEA"] = true
        elif wet and field.relief != "canyon":
            c = 6
            reasons["WATER UNDER THE ROAD"] = true
        elif fill > MAX_PIER_M:
            c = 6
            reasons["DROP UNDER THE ROAD > %d m" % int(MAX_PIER_M)] = true
        elif cut > MAX_CUT_M:
            c = 6
            reasons["CUTTING DEEPER THAN %d m" % int(MAX_CUT_M)] = true
        elif wet or fill > BRIDGE_FILL_M:
            c = 4
        elif near_cliff:
            c = 5
        elif fill > FILL_WALL_M:
            c = 3
        elif cut > CUT_WALL_M:
            c = 2
        elif fill > 0.6 or cut > 0.6:
            c = 1
        cls[i] = c
        worst = maxi(worst,SEVERITY[c])
    return {"class":cls,"worst":worst,"reasons":reasons.keys(),"cut_max":cut_max,"fill_max":fill_max}

## Heights at the control points (knot k = sample k*SUB) for saving.
static func knot_heights(h: PackedFloat32Array, knots: int, sub: int) -> Array:
    var out: Array = []
    for k in range(knots):
        out.append(snappedf(h[mini(k*sub,h.size()-1)],0.01))
    return out

## Per-sample heights rebuilt from knot heights with the same uniform
## Catmull-Rom (and the same open-end clamping) as the 2D centreline, so the
## builder preview and the race read identical heights from a saved track.
static func from_knots(kh: Array, closed: bool, sub: int) -> PackedFloat32Array:
    var n: int = kh.size()
    var out := PackedFloat32Array()
    if n == 0:
        return out
    var segs: int = n if closed else n-1
    for i in range(segs):
        var p0: float = float(kh[(i-1+n)%n]) if (closed or i > 0) else float(kh[0])
        var p1: float = float(kh[i])
        var p2: float = float(kh[(i+1)%n])
        var p3: float = float(kh[(i+2)%n]) if (closed or i+2 < n) else float(kh[n-1])
        for j in range(sub):
            var t: float = float(j)/float(sub)
            out.append(0.5*(2.0*p1+(-p0+p2)*t+(2.0*p0-5.0*p1+4.0*p2-p3)*t*t+(-p0+3.0*p1-3.0*p2+p3)*t*t*t))
    if not closed:
        out.append(float(kh[n-1]))
    return out
