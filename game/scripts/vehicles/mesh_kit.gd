extends RefCounted
class_name NitroMeshKit
## Small procedural mesh toolkit for smooth, rounded "diecast" geometry.
## Geometry is grouped into material buckets so a whole car body renders in a
## handful of draw calls (important for Android GL Compatibility).
## Winding is derived from the supplied outward normals, so every helper only
## has to provide correct normals; triangles are re-ordered to Godot's
## clockwise front-face convention automatically.

var buckets: Dictionary = {}
var materials: Dictionary = {}
var order: Array[String] = []

func bucket(key: String, material: Material) -> SurfaceTool:
    if not buckets.has(key):
        var st := SurfaceTool.new()
        st.begin(Mesh.PRIMITIVE_TRIANGLES)
        buckets[key] = st
        materials[key] = material
        order.append(key)
    return buckets[key]

func commit() -> ArrayMesh:
    var mesh := ArrayMesh.new()
    for key in order:
        var st: SurfaceTool = buckets[key]
        st.commit(mesh)
        var index: int = mesh.get_surface_count()-1
        if index >= 0:
            mesh.surface_set_material(index,materials[key])
            mesh.surface_set_name(index,key)
    return mesh

static func sgnpow(value: float, exponent: float) -> float:
    return signf(value)*pow(absf(value),exponent)

static func tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
        na: Vector3, nb: Vector3, nc: Vector3) -> void:
    # Godot front faces are clockwise when seen from the normal side.
    var geometric: Vector3 = (b-a).cross(c-a)
    if geometric.dot(na+nb+nc) > 0.0:
        var swap_p: Vector3 = b
        b = c
        c = swap_p
        var swap_n: Vector3 = nb
        nb = nc
        nc = swap_n
    st.set_normal(na)
    st.add_vertex(a)
    st.set_normal(nb)
    st.add_vertex(b)
    st.set_normal(nc)
    st.add_vertex(c)

static func _xn(xf: Transform3D, n: Vector3) -> Vector3:
    return (xf.basis.inverse().transposed()*n).normalized()

## Parametric surface f(u,v)->Vector3 sampled on a grid. Normals are central
## finite differences; `flip` inverts them when the parameterisation runs the
## other way. `offset` pushes the patch along its normal (glass, decals).
## `flat` gives every quad a single normal (faceted low-poly shading).
static func grid(st: SurfaceTool, xf: Transform3D, f: Callable,
        u0: float, u1: float, nu: int, v0: float, v1: float, nv: int,
        flip: bool = false, offset: float = 0.0, flat: bool = false) -> void:
    var pts: Array[PackedVector3Array] = []
    var nrm: Array[PackedVector3Array] = []
    var du: float = (u1-u0)/float(nu)
    var dv: float = (v1-v0)/float(nv)
    var eu: float = maxf(absf(du)*0.25,0.00005)
    var ev: float = maxf(absf(dv)*0.25,0.00005)
    for i in range(nu+1):
        var row_p := PackedVector3Array()
        var row_n := PackedVector3Array()
        var u: float = u0+du*float(i)
        for j in range(nv+1):
            var v: float = v0+dv*float(j)
            var p: Vector3 = f.call(u,v)
            var tu: Vector3 = Vector3(f.call(u+eu,v))-Vector3(f.call(u-eu,v))
            var tv: Vector3 = Vector3(f.call(u,v+ev))-Vector3(f.call(u,v-ev))
            var n: Vector3 = tu.cross(tv)
            if n.length_squared() < 1e-14:
                # Degenerate pole: fall back to a one-sided difference.
                tu = Vector3(f.call(u+eu*4.0,v))-p
                tv = Vector3(f.call(u,v+ev*4.0))-p
                n = tu.cross(tv)
                if n.length_squared() < 1e-14:
                    n = Vector3.UP
            n = n.normalized()
            if flip:
                n = -n
            if offset != 0.0:
                p += n*offset
            row_p.append(xf*p)
            row_n.append(_xn(xf,n))
        pts.append(row_p)
        nrm.append(row_n)
    for i in range(nu):
        for j in range(nv):
            var a: Vector3 = pts[i][j]
            var b: Vector3 = pts[i+1][j]
            var c: Vector3 = pts[i][j+1]
            var d: Vector3 = pts[i+1][j+1]
            if flat:
                # Faceted "low-poly" look: one normal per quad, oriented by
                # the smooth normals so the outside stays outside.
                var fn: Vector3 = (b-a).cross(c-a)+(d-b).cross(c-b)
                var ref: Vector3 = nrm[i][j]+nrm[i+1][j]+nrm[i][j+1]+nrm[i+1][j+1]
                if fn.length_squared() < 1e-14:
                    fn = ref
                if fn.dot(ref) < 0.0:
                    fn = -fn
                fn = fn.normalized()
                tri(st,a,c,b,fn,fn,fn)
                tri(st,b,c,d,fn,fn,fn)
            else:
                tri(st,a,c,b,nrm[i][j],nrm[i][j+1],nrm[i+1][j])
                tri(st,b,c,d,nrm[i+1][j],nrm[i][j+1],nrm[i+1][j+1])

## Rounded box. exponent 2 = ellipsoid, ~0.25 = crisp rounded box.
static func superellipsoid(st: SurfaceTool, xf: Transform3D, half: Vector3,
        exponent: float = 0.3, nu: int = 20, nv: int = 12) -> void:
    var e: float = clampf(exponent,0.05,2.0)
    var ne: float = 2.0-e
    var pts: Array[PackedVector3Array] = []
    var nrm: Array[PackedVector3Array] = []
    for i in range(nu+1):
        var theta: float = -PI+TAU*float(i)/float(nu)
        var row_p := PackedVector3Array()
        var row_n := PackedVector3Array()
        for j in range(nv+1):
            var phi: float = -PI*0.5+PI*float(j)/float(nv)
            var cp: float = cos(phi)
            var sp: float = sin(phi)
            var ct: float = cos(theta)
            var s_t: float = sin(theta)
            var p := Vector3(
                half.x*sgnpow(cp,e)*sgnpow(ct,e),
                half.y*sgnpow(sp,e),
                half.z*sgnpow(cp,e)*sgnpow(s_t,e))
            var n := Vector3(
                sgnpow(cp,ne)*sgnpow(ct,ne)/maxf(half.x,0.0001),
                sgnpow(sp,ne)/maxf(half.y,0.0001),
                sgnpow(cp,ne)*sgnpow(s_t,ne)/maxf(half.z,0.0001))
            if n.length_squared() < 1e-12:
                n = Vector3(0,signf(sp) if sp != 0.0 else 1.0,0)
            row_p.append(xf*p)
            row_n.append(_xn(xf,n.normalized()))
        pts.append(row_p)
        nrm.append(row_n)
    for i in range(nu):
        for j in range(nv):
            tri(st,pts[i][j],pts[i][j+1],pts[i+1][j],nrm[i][j],nrm[i][j+1],nrm[i+1][j])
            tri(st,pts[i+1][j],pts[i][j+1],pts[i+1][j+1],nrm[i+1][j],nrm[i][j+1],nrm[i+1][j+1])

## Surface of revolution around local +X. profile: Vector2(axial, radius).
## Normals point away from the axis-side of the profile direction; pass
## flip if the profile is ordered the other way.
static func lathe(st: SurfaceTool, xf: Transform3D, profile: PackedVector2Array,
        segments: int = 28, flip: bool = false, hard_angle_deg: float = 48.0,
        start_angle: float = 0.0, sweep: float = TAU) -> void:
    var count: int = profile.size()
    if count < 2:
        return
    var seg_n: Array[Vector2] = []
    for k in range(count-1):
        var t: Vector2 = (profile[k+1]-profile[k]).normalized()
        var n2 := Vector2(t.y,-t.x)
        if flip:
            n2 = -n2
        seg_n.append(n2)
    var cos_hard: float = cos(deg_to_rad(hard_angle_deg))
    for k in range(count-1):
        var n_start: Vector2 = seg_n[k]
        var n_end: Vector2 = seg_n[k]
        if k > 0 and seg_n[k-1].dot(seg_n[k]) > cos_hard:
            n_start = (seg_n[k-1]+seg_n[k]).normalized()
        if k < count-2 and seg_n[k+1].dot(seg_n[k]) > cos_hard:
            n_end = (seg_n[k+1]+seg_n[k]).normalized()
        var a: Vector2 = profile[k]
        var b: Vector2 = profile[k+1]
        for s in range(segments):
            var t0: float = start_angle+sweep*float(s)/float(segments)
            var t1: float = start_angle+sweep*float(s+1)/float(segments)
            var c0: float = cos(t0)
            var s0: float = sin(t0)
            var c1: float = cos(t1)
            var s1: float = sin(t1)
            var pa0 := Vector3(a.x,a.y*c0,a.y*s0)
            var pa1 := Vector3(a.x,a.y*c1,a.y*s1)
            var pb0 := Vector3(b.x,b.y*c0,b.y*s0)
            var pb1 := Vector3(b.x,b.y*c1,b.y*s1)
            var na0 := Vector3(n_start.x,n_start.y*c0,n_start.y*s0)
            var na1 := Vector3(n_start.x,n_start.y*c1,n_start.y*s1)
            var nb0 := Vector3(n_end.x,n_end.y*c0,n_end.y*s0)
            var nb1 := Vector3(n_end.x,n_end.y*c1,n_end.y*s1)
            tri(st,xf*pa0,xf*pb0,xf*pa1,_xn(xf,na0),_xn(xf,nb0),_xn(xf,na1))
            tri(st,xf*pa1,xf*pb0,xf*pb1,_xn(xf,na1),_xn(xf,nb0),_xn(xf,nb1))

## Flat-shaded box (sharp details: trims, splitters, lines).
static func box(st: SurfaceTool, xf: Transform3D, size: Vector3) -> void:
    var h: Vector3 = size*0.5
    var faces: Array = [
        [Vector3.RIGHT,Vector3.UP,Vector3.BACK],[Vector3.LEFT,Vector3.UP,Vector3.FORWARD],
        [Vector3.UP,Vector3.BACK,Vector3.RIGHT],[Vector3.DOWN,Vector3.FORWARD,Vector3.RIGHT],
        [Vector3.BACK,Vector3.UP,Vector3.LEFT],[Vector3.FORWARD,Vector3.UP,Vector3.RIGHT]]
    for face in faces:
        var n: Vector3 = face[0]
        var a: Vector3 = face[1]
        var b: Vector3 = face[2]
        var c: Vector3 = n*h.abs().dot(n.abs())
        var ea: Vector3 = a*h.abs().dot(a.abs())
        var eb: Vector3 = b*h.abs().dot(b.abs())
        var p0: Vector3 = xf*(c-ea-eb)
        var p1: Vector3 = xf*(c+ea-eb)
        var p2: Vector3 = xf*(c+ea+eb)
        var p3: Vector3 = xf*(c-ea+eb)
        var wn: Vector3 = _xn(xf,n)
        tri(st,p0,p1,p2,wn,wn,wn)
        tri(st,p0,p2,p3,wn,wn,wn)

## Flat polygon (convex fan) with one normal.
static func fan(st: SurfaceTool, xf: Transform3D, centre: Vector3,
        ring: PackedVector3Array, normal: Vector3) -> void:
    var wn: Vector3 = _xn(xf,normal)
    var wc: Vector3 = xf*centre
    for i in range(ring.size()):
        tri(st,wc,xf*ring[i],xf*ring[(i+1)%ring.size()],wn,wn,wn)
