extends RefCounted
class_name NitroParkLayout
## NITRO WHEELZ PARK (issue #27): ONE large flat open paved surface. Everything
## the player can practise on coexists on it: two donut rings, a large and a
## small figure-eight, one longer FLATTENED figure-eight (a miniature drift
## circuit for weak starter cars) and the orange cones. The big NITRO WHEELZ
## logo is painted flat at the centre.
##
## PROVISIONAL (owner has NOT approved the outline, the dimensions or the
## positions - issue #27 "explicitly not decided"): every number below lives in
## this ONE file so it can be changed without touching code. Units: metres,
## x east, z south (the planar coordinates of the drive model), start heading 0
## = north (-z).
const PROVISIONAL: bool = true
const TRACK_PATH: String = "res://tracks/nitro_wheelz_park.json"

## Paved surface: a rounded rectangle centred on the origin (full size).
const PAD_SIZE: Vector2 = Vector2(340.0,260.0)
const PAD_CORNER: float = 40.0
## The car starts south of the logo, facing it.
const START_POS: Vector2 = Vector2(0.0,30.0)
const START_HEADING: float = 0.0

## Painted logo (centre of the surface). Width in metres; the height follows the
## artwork's proportion. "Up" of the artwork = north, so it reads from the start.
const LOGO_CENTRE: Vector2 = Vector2(0.0,0.0)
const LOGO_WIDTH: float = 36.0
const LOGO_ASPECT: float = 349.0/620.0       # nitro_wheelz_logo.svg viewBox

## Donut rings (a single circle around a centre cone).
const DONUT_RADIUS: float = 10.0          # measured: a starter car holds a donut at r = 5 .. 9 m
const DONUT_LEFT: Vector2 = Vector2(-105.0,0.0)    # turn LEFT (counter-clockwise from above)
const DONUT_RIGHT: Vector2 = Vector2(105.0,0.0)    # turn RIGHT (clockwise)

## Figure-eights: two circles of radius R whose centres are spread*R apart on
## the x axis; the path runs around one circle, through the crossing point on a
## straight internal tangent, around the other circle the other way and back.
const EIGHT_LARGE_CENTRE: Vector2 = Vector2(-70.0,80.0)
const EIGHT_LARGE_RADIUS: float = 19.0
const EIGHT_SMALL_CENTRE: Vector2 = Vector2(70.0,80.0)
const EIGHT_SMALL_RADIUS: float = 9.0
const EIGHT_SPREAD: float = 1.35

## The longer flattened eight ("a simple miniature drift circuit"): wide, forgiving
## curves (radius 18 m) joined by long straights that cross at a shallow angle.
const ROUTE_CENTRE: Vector2 = Vector2(0.0,-80.0)
const ROUTE_RADIUS: float = 18.0
const ROUTE_SPREAD: float = 2.6
const ROUTE_WIDTH: float = 7.0                # corridor between the two cone lines

const CONE_SPACING_M: float = 9.0
const CONE_ROUTE_CLEARANCE_M: float = 5.2     # a route cone never sits in the other strand

# ---------------------------------------------------------------- the eights

## Circle centres of an eight built from `radius` and `spread`.
static func eight_centres(centre: Vector2, radius: float, spread: float) -> Array[Vector2]:
    var c: float = radius*spread
    return [centre+Vector2(-c,0.0),centre+Vector2(c,0.0)]

## Closed path of a figure-eight (polyline, step_m apart), starting on the upper
## tangent point of the LEFT circle. Direction: LEFT circle counter-clockwise on
## screen... see `lobe_turn` for which way each lobe turns.
static func eight_path(centre: Vector2, radius: float, spread: float, step_m: float = 1.5) -> PackedVector2Array:
    var c: float = radius*spread
    var phi: float = acos(clampf(radius/c,-1.0,1.0))
    var pts := PackedVector2Array()
    var left: Vector2 = centre+Vector2(-c,0.0)
    var right: Vector2 = centre+Vector2(c,0.0)
    # 1) left circle, from +phi round to 360-phi (the lobe turns one way)
    var a0: float = phi
    var a1: float = TAU-phi
    var n1: int = maxi(8,int(ceil(radius*(a1-a0)/step_m)))
    for k in range(n1+1):
        var a: float = lerpf(a0,a1,float(k)/float(n1))
        pts.append(left+Vector2(cos(a),-sin(a))*radius)      # -sin: z points south
    # 2) straight through the crossing point to the right circle
    var p_end: Vector2 = pts[pts.size()-1]
    var q_start: Vector2 = centre*2.0-p_end                   # point reflection through the centre
    var n2: int = maxi(2,int(ceil(p_end.distance_to(q_start)/step_m)))
    for k in range(1,n2+1):
        pts.append(p_end.lerp(q_start,float(k)/float(n2)))
    # 3) right circle the other way round
    var b0: float = PI-phi
    var b1: float = -(PI-phi)
    var n3: int = maxi(8,int(ceil(radius*absf(b0-b1)/step_m)))
    for k in range(1,n3+1):
        var b: float = lerpf(b0,b1,float(k)/float(n3))
        pts.append(right+Vector2(cos(b),-sin(b))*radius)
    # 4) straight back through the crossing point to the start
    var p2: Vector2 = pts[pts.size()-1]
    var q2: Vector2 = pts[0]
    var n4: int = maxi(2,int(ceil(p2.distance_to(q2)/step_m)))
    for k in range(1,n4):
        pts.append(p2.lerp(q2,float(k)/float(n4)))
    return pts

## +1 = the lobe is driven counter-clockwise seen from above (a LEFT turn),
## -1 = clockwise (a RIGHT turn); index 0 = the lobe west of the crossing.
static func lobe_turn(lobe: int) -> int:
    # eight_path() runs the left circle with a growing angle in (x, -z), which is
    # counter-clockwise seen from above (x east, z south); the right one clockwise.
    return 1 if lobe == 0 else -1

static func path_length(path: PackedVector2Array, closed: bool = true) -> float:
    var total: float = 0.0
    for i in range(path.size()-1):
        total += path[i].distance_to(path[i+1])
    if closed and path.size() > 1:
        total += path[path.size()-1].distance_to(path[0])
    return total

# -------------------------------------------------------------------- lookups

## Every named exercise area: {id, kind, centre, radius, lobes?}.
static func exercises() -> Array[Dictionary]:
    var out: Array[Dictionary] = []
    out.append({"id":"donut_left","kind":"donut","centre":DONUT_LEFT,"radius":DONUT_RADIUS,"turn":1})
    out.append({"id":"donut_right","kind":"donut","centre":DONUT_RIGHT,"radius":DONUT_RADIUS,"turn":-1})
    out.append({"id":"eight_large","kind":"eight","centre":EIGHT_LARGE_CENTRE,"radius":EIGHT_LARGE_RADIUS,
        "lobes":eight_centres(EIGHT_LARGE_CENTRE,EIGHT_LARGE_RADIUS,EIGHT_SPREAD)})
    out.append({"id":"eight_small","kind":"eight","centre":EIGHT_SMALL_CENTRE,"radius":EIGHT_SMALL_RADIUS,
        "lobes":eight_centres(EIGHT_SMALL_CENTRE,EIGHT_SMALL_RADIUS,EIGHT_SPREAD)})
    out.append({"id":"route","kind":"route","centre":ROUTE_CENTRE,"radius":ROUTE_RADIUS,
        "lobes":eight_centres(ROUTE_CENTRE,ROUTE_RADIUS,ROUTE_SPREAD),"width":ROUTE_WIDTH})
    return out

static func exercise(id: String) -> Dictionary:
    for e in exercises():
        if str(e["id"]) == id:
            return e
    return {}

static func route_path(step_m: float = 1.5) -> PackedVector2Array:
    return eight_path(ROUTE_CENTRE,ROUTE_RADIUS,ROUTE_SPREAD,step_m)

# ---------------------------------------------------------------------- pad

## Outline of the paved rounded rectangle, grown by `grow` metres, with `segments` per corner.
static func pad_outline(grow: float = 0.0, segments: int = 10) -> PackedVector2Array:
    var half: Vector2 = PAD_SIZE*0.5+Vector2(grow,grow)
    var r: float = PAD_CORNER+grow
    var out := PackedVector2Array()
    var corners: Array = [
        [Vector2(half.x-r,-half.y+r),-PI*0.5],[Vector2(half.x-r,half.y-r),0.0],
        [Vector2(-half.x+r,half.y-r),PI*0.5],[Vector2(-half.x+r,-half.y+r),PI]]
    for corner in corners:
        var cc: Vector2 = corner[0]
        var a0: float = corner[1]
        for k in range(segments+1):
            var a: float = a0+PI*0.5*float(k)/float(segments)
            out.append(cc+Vector2(cos(a),sin(a))*r)
    return out

## Signed distance to the paved rounded rectangle grown by `grow` (negative =
## inside). Used for the invisible soft edge.
static func pad_distance(p: Vector2, grow: float = 0.0) -> float:
    var half: Vector2 = PAD_SIZE*0.5+Vector2(grow,grow)
    var r: float = PAD_CORNER+grow
    var q: Vector2 = p.abs()-(half-Vector2(r,r))
    return Vector2(maxf(q.x,0.0),maxf(q.y,0.0)).length()+minf(maxf(q.x,q.y),0.0)-r

# ---------------------------------------------------------------------- cones

## All cones: [{"pos": Vector2, "group": String}]. Groups: "route", "donut_left",
## "donut_right", "eight_large", "eight_small" (centre cones, the thing you
## circle around) and "route_lobe".
static func cones() -> Array[Dictionary]:
    var out: Array[Dictionary] = []
    # Donuts: a centre cone and four cones just outside the painted ring.
    for d in [["donut_left",DONUT_LEFT],["donut_right",DONUT_RIGHT]]:
        var centre: Vector2 = d[1]
        out.append({"pos":centre,"group":str(d[0])})
        for k in range(4):
            var a: float = TAU*float(k)/4.0+PI*0.25
            out.append({"pos":centre+Vector2(cos(a),sin(a))*(DONUT_RADIUS+3.5),"group":str(d[0])})
    # Eights: one cone in the middle of each lobe (the point to circle).
    for e in [["eight_large",EIGHT_LARGE_CENTRE,EIGHT_LARGE_RADIUS],["eight_small",EIGHT_SMALL_CENTRE,EIGHT_SMALL_RADIUS]]:
        for c in eight_centres(e[1],float(e[2]),EIGHT_SPREAD):
            out.append({"pos":c,"group":str(e[0])})
    # Route: a cone in the middle of each loop and two cone lines along the corridor.
    for c2 in eight_centres(ROUTE_CENTRE,ROUTE_RADIUS,ROUTE_SPREAD):
        out.append({"pos":c2,"group":"route_lobe"})
    var path: PackedVector2Array = route_path(3.0)
    var along: PackedFloat32Array = PackedFloat32Array()
    var acc: float = 0.0
    along.append(0.0)
    for i in range(1,path.size()):
        acc += path[i-1].distance_to(path[i])
        along.append(acc)
    var total: float = acc+path[path.size()-1].distance_to(path[0])
    var next_at: float = 0.0
    var half_w: float = ROUTE_WIDTH*0.5
    for i2 in range(path.size()):
        if along[i2] < next_at:
            continue
        next_at += CONE_SPACING_M
        var a_i: Vector2 = path[(i2+path.size()-1)%path.size()]
        var b_i: Vector2 = path[(i2+1)%path.size()]
        var tangent: Vector2 = (b_i-a_i).normalized()
        var normal := Vector2(-tangent.y,tangent.x)
        for side in [-1.0,1.0]:
            var cand: Vector2 = path[i2]+normal*half_w*side
            if _near_other_strand(cand,path,along,total,along[i2],CONE_ROUTE_CLEARANCE_M):
                continue
            out.append({"pos":cand,"group":"route"})
    return out

## True when `p` is closer than `clearance` to a part of the path that is far away
## along the path (the other strand of the eight): a cone there would sit in the
## driving line of the crossing.
static func _near_other_strand(p: Vector2, path: PackedVector2Array, along: PackedFloat32Array,
        total: float, my_along: float, clearance: float) -> bool:
    for j in range(path.size()):
        var d: float = absf(along[j]-my_along)
        d = minf(d,total-d)
        if d > 22.0 and p.distance_to(path[j]) < clearance:
            return true
    return false
