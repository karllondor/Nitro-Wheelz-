extends Node3D
class_name NitroLadaLowPoly
## Nitro Wheelz VAZ-2106 "drift spec" in a collectible die-cast toy style.
## Original procedural geometry (no third-party mesh/texture): smooth lofted
## body shell and greenhouse, inset tinted glass, chrome trim, quad lamps,
## bolt-on wide arches, deep-dish wheels and a glossy toy-paint shader.
## Visual targets: approved red Lada 2106 drift-spec sheet (red, exposed
## engine, quad round lamps, white 5-spoke dish wheels) and the pearl-white
## sheet (clean bonnet, rectangular lamps, mesh wheels).
## Front of vehicle is LOCAL -Z; world heading is applied by the race scene.

const KIT = preload("res://scripts/vehicles/mesh_kit.gd")
const PAINT_SHADER = preload("res://assets/shaders/diecast_paint.gdshader")
const SHADOW_SHADER = preload("res://assets/shaders/soft_shadow.gdshader")

# Stock VAZ-2106 dimensions, 1 Godot unit = 1 metre. Bolt-on arches widen
# the 1.611 m stock shell to 1.91 m.
const BODY_LENGTH_M: float = 4.166
const WHEELBASE_M: float = 2.424
const FRONT_AXLE_Z: float = -WHEELBASE_M * 0.5
const REAR_AXLE_Z: float = WHEELBASE_M * 0.5
const DRIFT_BODY_WIDTH_M: float = 1.91
const WHEEL_RADIUS_M: float = 0.39

# Shell layout (metres).
const SHELL_FRONT: float = -2.02
const SHELL_REAR: float = 2.02
const SHELL_HALF_WIDTH: float = 0.805
const SHELL_BOTTOM: float = 0.25
const SHELL_EXPONENT: float = 6.0
const CABIN_FRONT: float = -0.93
const CABIN_REAR: float = 0.98
const ROOF_Y: float = 1.415
const WHEEL_TRACK_X: float = 0.812
const FRONT_RAKE: float = 1.18
const REAR_RAKE: float = 1.12
const ARCH_OUTER_X: float = DRIFT_BODY_WIDTH_M * 0.5

const RED := Color(0.80,0.035,0.055)
const PEARL := Color(0.86,0.855,0.89)

var paint_variant: String = "red"   # red exposed-engine / pearl-white clean hood
var shadow_height: float = 0.10     # race road sits at ~0.05 m

var front_wheels: Array[Node3D] = []
var rolling_wheels: Array[Node3D] = []
var materials: Dictionary = {}

static var _mesh_cache: Dictionary = {}

func _ready() -> void:
    if paint_variant != "white":
        paint_variant = "red"
    _make_materials()
    var shell := MeshInstance3D.new()
    shell.name = "Diecast body shell"
    shell.mesh = _cached("shell",Callable(self,"_build_shell"))
    add_child(shell)
    var boot := MeshInstance3D.new()
    boot.name = "Long rear boot lid"
    boot.mesh = _cached("boot",Callable(self,"_build_boot_lid"))
    add_child(boot)
    var front := MeshInstance3D.new()
    if paint_variant == "white":
        front.name = "White variant closed long bonnet"
        front.mesh = _cached("bonnet",Callable(self,"_build_closed_bonnet"))
    else:
        front.name = "Exposed drift engine bay"
        front.mesh = _cached("engine",Callable(self,"_build_engine_bay"))
    add_child(front)
    _make_wheels()
    _make_shadow()
    _make_badge()

func _cached(part: String, builder: Callable) -> ArrayMesh:
    var key: String = paint_variant+":"+part
    if not _mesh_cache.has(key):
        _mesh_cache[key] = builder.call()
    return _mesh_cache[key]

# ---------------------------------------------------------------- materials

func _paint(col: Color, roughness: float, metallic: float, gloss: float,
        rim: float, glow: float = 0.0) -> ShaderMaterial:
    var mat := ShaderMaterial.new()
    mat.shader = PAINT_SHADER
    mat.set_shader_parameter("paint",col)
    mat.set_shader_parameter("roughness",roughness)
    mat.set_shader_parameter("metallic",metallic)
    mat.set_shader_parameter("gloss",gloss)
    mat.set_shader_parameter("rim",rim)
    mat.set_shader_parameter("glow",glow)
    return mat

func _make_materials() -> void:
    var body_col: Color = PEARL if paint_variant == "white" else RED
    materials["paint"] = _paint(body_col,0.22,0.0,
        0.45 if paint_variant == "white" else 1.0,0.6 if paint_variant == "white" else 0.85)
    materials["glass"] = _paint(Color(0.035,0.045,0.075),0.06,0.0,1.35,1.0)
    materials["chrome"] = _paint(Color(0.88,0.90,0.94),0.14,1.0,1.7,0.7)
    materials["trim"] = _paint(Color(0.045,0.047,0.055),0.55,0.0,0.30,0.25)
    materials["rubber"] = _paint(Color(0.055,0.055,0.062),0.85,0.0,0.10,0.10)
    materials["rim"] = _paint(Color(0.96,0.96,0.97) if paint_variant == "red"
        else Color(0.40,0.41,0.47),0.22,0.0,0.9,0.5,0.18 if paint_variant == "red" else 0.0)
    materials["lamp"] = _paint(Color(1.0,0.95,0.78),0.10,0.0,0.6,0.3,1.6)
    materials["tail"] = _paint(Color(0.85,0.03,0.05),0.12,0.0,0.7,0.3,1.25)
    materials["amber"] = _paint(Color(1.0,0.45,0.04),0.15,0.0,0.6,0.3,1.0)
    materials["engine"] = _paint(Color(0.10,0.10,0.115),0.45,0.4,0.5,0.3)
    materials["well"] = _paint(Color(0.015,0.015,0.02),0.9,0.0,0.0,0.0)

# ------------------------------------------------------------- body shape

static func _end_inset(z: float, radius: float) -> float:
    var d: float = minf(z-SHELL_FRONT,SHELL_REAR-z)
    if d >= radius:
        return 0.0
    var t: float = radius-maxf(d,0.0)
    return radius-sqrt(maxf(radius*radius-t*t,0.0))

static func _deck(z: float) -> float:
    # Long flat bonnet gently falling to the nose; boot nearly flat.
    if z < CABIN_FRONT:
        var t: float = clampf((z-SHELL_FRONT)/(CABIN_FRONT-SHELL_FRONT),0.0,1.0)
        return lerpf(0.875,0.948,t*(2.0-t))
    if z > CABIN_REAR:
        var r: float = clampf((z-CABIN_REAR)/(SHELL_REAR-CABIN_REAR),0.0,1.0)
        return lerpf(0.956,0.938,r)
    return lerpf(0.948,0.956,(z-CABIN_FRONT)/(CABIN_REAR-CABIN_FRONT))

static func _shell_section(z: float) -> Vector4:
    # x: half width, y: bottom, z: top, w: unused
    var hw: float = SHELL_HALF_WIDTH-_end_inset(z,0.09)
    var top: float = _deck(z)-_end_inset(z,0.11)
    var bottom: float = SHELL_BOTTOM+_end_inset(z,0.10)*0.7
    return Vector4(hw,bottom,top,0.0)

static func _z_warp(u: float) -> float:
    # Denser sampling near the rounded nose/tail.
    return lerpf(u,0.5-0.5*cos(PI*u),0.62)

func _shell_point(u: float, v: float) -> Vector3:
    var z: float = lerpf(SHELL_FRONT,SHELL_REAR,_z_warp(clampf(u,0.0,1.0)))
    var sec: Vector4 = _shell_section(z)
    var theta: float = lerpf(PI*1.25,-PI*0.25,v)
    var e: float = 2.0/SHELL_EXPONENT
    var yc: float = (sec.y+sec.z)*0.5
    var hh: float = (sec.z-sec.y)*0.5
    return Vector3(sec.x*KIT.sgnpow(cos(theta),e),yc+hh*KIT.sgnpow(sin(theta),e),z)

static func deck_top(x: float, z: float) -> float:
    var sec: Vector4 = _shell_section(z)
    var yc: float = (sec.y+sec.z)*0.5
    var hh: float = (sec.z-sec.y)*0.5
    var q: float = clampf(absf(x)/sec.x,0.0,1.0)
    return yc+hh*pow(maxf(1.0-pow(q,SHELL_EXPONENT),0.0),1.0/SHELL_EXPONENT)

# ------------------------------------------------------------ greenhouse

static func _smin(a: float, b: float, k: float) -> float:
    var h: float = clampf(0.5+0.5*(b-a)/k,0.0,1.0)
    return lerpf(b,a,h)-k*h*(1.0-h)

static func _cabin_top(z: float, belt: float) -> float:
    var front_ramp: float = belt+(z-CABIN_FRONT)*FRONT_RAKE
    var rear_ramp: float = belt+(CABIN_REAR-z)*REAR_RAKE
    return maxf(_smin(_smin(front_ramp,ROOF_Y,0.08),rear_ramp,0.08),belt)

static func _cabin_half_width(y: float, belt: float) -> float:
    return lerpf(0.778,0.700,clampf((y-belt)/(ROOF_Y-belt),0.0,1.0))

func _cabin_point(u: float, v: float) -> Vector3:
    var z: float = lerpf(CABIN_FRONT,CABIN_REAR,clampf(u,0.0,1.0))
    var belt: float = _deck(z)-0.004
    var top: float = _cabin_top(z,belt)
    var h: float = top-belt
    var r: float = minf(0.13,h*0.55)
    var ys: float = top-r
    var hws: float = _cabin_half_width(ys,belt)
    var crown: float = 0.018*clampf(h/(ROOF_Y-belt),0.0,1.0)
    var side: float = -1.0
    var w: float = clampf(v,0.0,1.0)
    if w > 0.5:
        side = 1.0
        w = 1.0-w
    var p := Vector2.ZERO
    if w <= 0.16:
        var t: float = w/0.16
        var y: float = lerpf(belt,ys,t)
        p = Vector2(-_cabin_half_width(y,belt),y)
    elif w <= 0.30:
        var a: float = lerpf(PI,PI*0.5,(w-0.16)/0.14)
        p = Vector2(-hws+r,ys)+Vector2(cos(a),sin(a))*r
    else:
        var t2: float = (w-0.30)/0.20  # 0 at corner end, 1 at roof centre
        var x: float = lerpf(-hws+r,0.0,t2)
        p = Vector2(x,top+crown*(1.0-(1.0-t2)*(1.0-t2)))
    return Vector3(p.x*(-side) if side > 0.0 else p.x,p.y,z)

# ------------------------------------------------------------ wheel arches

func _arch_point(u: float, v: float, side: float, axle_z: float) -> Vector3:
    # u: angle around the wheel (front -> over -> rear), v: tube section.
    var a: float = lerpf(-0.10,PI+0.10,u)
    var taper: float = clampf(minf(u,1.0-u)/0.08,0.0,1.0)
    taper = sqrt(taper)
    var psi: float = v*TAU
    var e: float = 0.5
    var lat_in: float = SHELL_HALF_WIDTH-0.035
    var lat_c: float = (lat_in+ARCH_OUTER_X)*0.5
    var lat_h: float = (ARCH_OUTER_X-lat_in)*0.5*taper
    var rad_c: float = 0.485
    var rad_h: float = 0.056*maxf(taper,0.05)
    var lateral: float = lat_c+lat_h*KIT.sgnpow(cos(psi),e)
    var radial: float = rad_c+rad_h*KIT.sgnpow(sin(psi),e)
    return Vector3(side*lateral,WHEEL_RADIUS_M+radial*sin(a),axle_z-radial*cos(a))

# ------------------------------------------------------------ build shell

func _build_shell() -> ArrayMesh:
    var kit := KIT.new()
    var id := Transform3D.IDENTITY
    var paint: SurfaceTool = kit.bucket("paint",materials["paint"])
    var glass: SurfaceTool = kit.bucket("glass",materials["glass"])
    var chrome: SurfaceTool = kit.bucket("chrome",materials["chrome"])
    var trim: SurfaceTool = kit.bucket("trim",materials["trim"])
    var well: SurfaceTool = kit.bucket("well",materials["well"])
    var lamp: SurfaceTool = kit.bucket("lamp",materials["lamp"])
    var tail: SurfaceTool = kit.bucket("tail",materials["tail"])
    var amber: SurfaceTool = kit.bucket("amber",materials["amber"])
    var white: bool = paint_variant == "white"

    # Lower shell (one smooth lofted surface) and flat end caps.
    KIT.grid(paint,id,Callable(self,"_shell_point"),0.0,1.0,60,0.0,1.0,40,false)
    for end_u in [0.0,1.0]:
        var ring := PackedVector3Array()
        for k in range(41):
            ring.append(_shell_point(end_u,float(k)/40.0))
        var centre: Vector3 = (ring[0]+ring[40])*0.5
        centre.y = (ring[0].y+ring[20].y)*0.5
        KIT.fan(paint,id,centre,ring,Vector3(0,0,-1.0 if end_u == 0.0 else 1.0))
    # Underside.
    KIT.box(trim,Transform3D(Basis.IDENTITY,Vector3(0,SHELL_BOTTOM+0.01,0)),
        Vector3(1.50,0.02,3.86))

    # Greenhouse with inset glass: windscreen, backlight, four side windows.
    var cab := Callable(self,"_cabin_point")
    KIT.grid(paint,id,cab,0.0,1.0,52,0.0,1.0,44,false)
    var span: float = CABIN_REAR-CABIN_FRONT
    var ws_end: float = (CABIN_FRONT+(ROOF_Y-0.035-_deck(-0.6))/FRONT_RAKE-CABIN_FRONT)/span
    var bl_start: float = (CABIN_REAR-(ROOF_Y-0.035-_deck(0.8))/REAR_RAKE-CABIN_FRONT)/span
    KIT.grid(glass,id,cab,0.035/span,ws_end,16,0.205,0.795,26,false,0.006)
    KIT.grid(glass,id,cab,bl_start,1.0-0.035/span,14,0.205,0.795,26,false,0.006)
    for window in [[-0.56,-0.02],[0.07,0.64]]:
        var u0: float = (float(window[0])-CABIN_FRONT)/span
        var u1: float = (float(window[1])-CABIN_FRONT)/span
        KIT.grid(glass,id,cab,u0,u1,14,0.022,0.148,6,false,0.006)
        KIT.grid(glass,id,cab,u0,u1,14,0.852,0.978,6,false,0.006)
    # Chrome drip rails along the roof edge.
    var rail0: float = (-0.60-CABIN_FRONT)/span
    var rail1: float = (0.70-CABIN_FRONT)/span
    KIT.grid(chrome,id,cab,rail0,rail1,20,0.17,0.182,1,false,0.009)
    KIT.grid(chrome,id,cab,rail0,rail1,20,0.818,0.83,1,false,0.009)

    # Wheel arches, dark wells and side skirts.
    for side in [-1.0,1.0]:
        for axle_z in [FRONT_AXLE_Z,REAR_AXLE_Z]:
            KIT.grid(paint,id,Callable(self,"_arch_point").bind(side,axle_z),
                0.0,1.0,26,0.0,1.0,14,side > 0.0)
            var ring := PackedVector3Array()
            for k in range(25):
                var a: float = lerpf(-0.25,PI+0.25,float(k)/24.0)
                var y: float = maxf(WHEEL_RADIUS_M+sin(a)*0.445,SHELL_BOTTOM+0.005)
                ring.append(Vector3(side*(SHELL_HALF_WIDTH+0.002),y,axle_z-cos(a)*0.445))
            KIT.fan(well,id,Vector3(side*(SHELL_HALF_WIDTH+0.002),SHELL_BOTTOM+0.06,axle_z),
                ring,Vector3(side,0,0))
        KIT.superellipsoid(paint,Transform3D(Basis.IDENTITY,
            Vector3(side*(SHELL_HALF_WIDTH+0.045),0.30,0.0)),Vector3(0.085,0.06,0.70),0.35,16,8)
        # Chrome belt moulding, door shut lines and handles.
        KIT.box(chrome,Transform3D(Basis.IDENTITY,Vector3(side*(SHELL_HALF_WIDTH+0.004),0.79,0.02)),
            Vector3(0.014,0.024,3.62))
        for gap_z in [-0.64,0.04,0.74]:
            KIT.box(trim,Transform3D(Basis.IDENTITY,Vector3(side*(SHELL_HALF_WIDTH+0.002),0.60,gap_z)),
                Vector3(0.008,0.62,0.012))
        for handle_z in [-0.22,0.52]:
            KIT.superellipsoid(chrome,Transform3D(Basis.IDENTITY,
                Vector3(side*(SHELL_HALF_WIDTH+0.012),0.86,handle_z)),Vector3(0.014,0.018,0.075),0.35,10,6)
        # Door mirror on a small stalk.
        KIT.box(trim,Transform3D(Basis.IDENTITY,Vector3(side*0.82,1.0,-0.66)),Vector3(0.10,0.035,0.05))
        KIT.superellipsoid(paint,Transform3D(Basis.IDENTITY,Vector3(side*0.895,1.03,-0.66)),
            Vector3(0.065,0.05,0.075),0.45,12,8)
        KIT.box(glass,Transform3D(Basis.IDENTITY,Vector3(side*0.895,1.03,-0.585)),Vector3(0.10,0.07,0.01))

    _build_front(kit,white)
    _build_rear(kit,white)
    return kit.commit()

func _forward_axis() -> Basis:
    # Lathe axis +X -> local -Z (pointing out of the nose).
    return Basis(Vector3.UP,PI*0.5)

func _build_front(kit: KIT, white: bool) -> void:
    var paint: SurfaceTool = kit.buckets["paint"]
    var chrome: SurfaceTool = kit.buckets["chrome"]
    var trim: SurfaceTool = kit.buckets["trim"]
    var lamp: SurfaceTool = kit.buckets["lamp"]
    var amber: SurfaceTool = kit.buckets["amber"]
    var face_z: float = SHELL_FRONT-0.004
    # Black fascia panel carrying the lamps and grille.
    KIT.superellipsoid(trim,Transform3D(Basis.IDENTITY,Vector3(0,0.745,face_z+0.004)),
        Vector3(0.725,0.112,0.022),0.25,20,8)
    if white:
        # Pearl-white sheet: rectangular lamps and a slim grille.
        for side in [-1.0,1.0]:
            KIT.superellipsoid(chrome,Transform3D(Basis.IDENTITY,Vector3(side*0.535,0.745,face_z-0.012)),
                Vector3(0.175,0.095,0.016),0.25,14,8)
            KIT.superellipsoid(lamp,Transform3D(Basis.IDENTITY,Vector3(side*0.535,0.745,face_z-0.024)),
                Vector3(0.155,0.077,0.012),0.3,14,8)
        for row in range(4):
            KIT.box(chrome,Transform3D(Basis.IDENTITY,Vector3(0,0.69+row*0.038,face_z-0.022)),
                Vector3(0.66,0.010,0.012))
    else:
        # Red drift-spec: four round lamps with chrome bezels.
        var fwd: Basis = _forward_axis()
        for side in [-1.0,1.0]:
            for column in [0.40,0.605]:
                var at := Vector3(side*column,0.745,face_z)
                var bezel := PackedVector2Array([Vector2(0.0,0.102),Vector2(0.018,0.100),
                    Vector2(0.026,0.091),Vector2(0.024,0.078),Vector2(0.012,0.073)])
                KIT.lathe(chrome,Transform3D(fwd,at),bezel,28,true)
                var lens := PackedVector2Array([Vector2(0.012,0.075),Vector2(0.026,0.055),
                    Vector2(0.032,0.0)])
                KIT.lathe(lamp,Transform3D(fwd,at),lens,28,true)
        for row in range(5):
            KIT.box(chrome,Transform3D(Basis.IDENTITY,Vector3(0,0.66+row*0.042,face_z-0.022)),
                Vector3(0.44,0.012,0.014))
        KIT.superellipsoid(chrome,Transform3D(Basis.IDENTITY,Vector3(0,0.745,face_z-0.036)),
            Vector3(0.045,0.055,0.012),0.6,12,8)
    for side in [-1.0,1.0]:
        KIT.superellipsoid(amber,Transform3D(Basis.IDENTITY,Vector3(side*0.60,0.585,face_z-0.02)),
            Vector3(0.08,0.03,0.02),0.3,12,6)
    # Bumper: chrome on the red car, colour-matched on the white car.
    var bumper: SurfaceTool = paint if white else chrome
    KIT.superellipsoid(bumper,Transform3D(Basis.IDENTITY,Vector3(0,0.50,-2.013)),
        Vector3(0.87,0.058,0.07),0.32,28,10)
    KIT.box(trim,Transform3D(Basis.IDENTITY,Vector3(0,0.385,-2.03)),Vector3(1.50,0.13,0.05))
    # Drift splitter.
    KIT.superellipsoid(trim,Transform3D(Basis.IDENTITY,Vector3(0,0.272,-1.96)),
        Vector3(0.90,0.022,0.12),0.3,24,6)

func _build_rear(kit: KIT, white: bool) -> void:
    var paint: SurfaceTool = kit.buckets["paint"]
    var chrome: SurfaceTool = kit.buckets["chrome"]
    var trim: SurfaceTool = kit.buckets["trim"]
    var tail: SurfaceTool = kit.buckets["tail"]
    var amber: SurfaceTool = kit.buckets["amber"]
    var lamp: SurfaceTool = kit.buckets["lamp"]
    var face_z: float = SHELL_REAR+0.004
    for side in [-1.0,1.0]:
        KIT.superellipsoid(trim,Transform3D(Basis.IDENTITY,Vector3(side*0.495,0.76,face_z)),
            Vector3(0.235,0.102,0.016),0.25,14,8)
        KIT.superellipsoid(tail,Transform3D(Basis.IDENTITY,Vector3(side*0.45,0.76,face_z+0.012)),
            Vector3(0.17,0.082,0.012),0.3,14,8)
        KIT.superellipsoid(amber,Transform3D(Basis.IDENTITY,Vector3(side*0.672,0.76,face_z+0.012)),
            Vector3(0.045,0.082,0.012),0.3,10,8)
        KIT.superellipsoid(lamp,Transform3D(Basis.IDENTITY,Vector3(side*0.24,0.715,face_z+0.014)),
            Vector3(0.035,0.035,0.01),0.4,8,6)
    KIT.superellipsoid(trim,Transform3D(Basis.IDENTITY,Vector3(0,0.62,face_z+0.002)),
        Vector3(0.22,0.06,0.008),0.3,10,6)
    var bumper: SurfaceTool = paint if white else chrome
    KIT.superellipsoid(bumper,Transform3D(Basis.IDENTITY,Vector3(0,0.49,2.013)),
        Vector3(0.87,0.058,0.07),0.32,28,10)
    KIT.box(trim,Transform3D(Basis.IDENTITY,Vector3(0,0.36,2.0)),Vector3(1.46,0.10,0.07))
    # Ducktail spoiler on the boot edge.
    var tilt := Basis(Vector3.RIGHT,deg_to_rad(-14.0))
    KIT.superellipsoid(paint,Transform3D(tilt,Vector3(0,deck_top(0.0,1.93)+0.03,1.93)),
        Vector3(0.77,0.028,0.10),0.35,24,8)
    # Exhaust.
    var back: Basis = Basis(Vector3.UP,-PI*0.5)
    var at := Vector3(0.50 if not white else -0.50,0.31,1.94)
    KIT.lathe(chrome,Transform3D(back,at),PackedVector2Array([
        Vector2(0.0,0.052),Vector2(0.13,0.052),Vector2(0.14,0.046),Vector2(0.135,0.038)]),18,true)
    KIT.lathe(trim,Transform3D(back,at),PackedVector2Array([
        Vector2(0.13,0.038),Vector2(0.12,0.0)]),18,true)

func _deck_strip(st: SurfaceTool, a: Vector2, b: Vector2, width: float, lift: float = 0.004) -> void:
    # Thin line conforming to the bonnet/boot surface (a/b are x,z).
    var steps: int = maxi(2,int(a.distance_to(b)/0.08))
    var dir: Vector2 = (b-a).normalized()
    var across := Vector2(-dir.y,dir.x)*width*0.5
    for k in range(steps):
        var p0: Vector2 = a.lerp(b,float(k)/float(steps))
        var p1: Vector2 = a.lerp(b,float(k+1)/float(steps))
        var q: Array[Vector3] = []
        for p in [p0-across,p0+across,p1-across,p1+across]:
            q.append(Vector3(p.x,deck_top(p.x,p.y)+lift,p.y))
        KIT.tri(st,q[0],q[1],q[2],Vector3.UP,Vector3.UP,Vector3.UP)
        KIT.tri(st,q[2],q[1],q[3],Vector3.UP,Vector3.UP,Vector3.UP)

func _build_boot_lid() -> ArrayMesh:
    var kit := KIT.new()
    var line: SurfaceTool = kit.bucket("trim",materials["trim"])
    _deck_strip(line,Vector2(-0.68,1.05),Vector2(0.68,1.05),0.012)
    for side in [-1.0,1.0]:
        _deck_strip(line,Vector2(side*0.68,1.05),Vector2(side*0.68,1.84),0.012)
    var badge: SurfaceTool = kit.bucket("chrome",materials["chrome"])
    _deck_strip(badge,Vector2(-0.10,1.80),Vector2(0.10,1.80),0.022,0.006)
    return kit.commit()

func _build_closed_bonnet() -> ArrayMesh:
    var kit := KIT.new()
    var line: SurfaceTool = kit.bucket("trim",materials["trim"])
    _deck_strip(line,Vector2(-0.72,-1.0),Vector2(0.72,-1.0),0.012)
    for side in [-1.0,1.0]:
        _deck_strip(line,Vector2(side*0.72,-1.0),Vector2(side*0.72,-1.93),0.012)
    var crease: SurfaceTool = kit.bucket("paint",materials["paint"])
    for side in [-1.0,1.0]:
        _deck_strip(crease,Vector2(side*0.33,-1.06),Vector2(side*0.33,-1.90),0.05,0.006)
    return kit.commit()

func _build_engine_bay() -> ArrayMesh:
    var kit := KIT.new()
    var well: SurfaceTool = kit.bucket("well",materials["well"])
    var engine: SurfaceTool = kit.bucket("engine",materials["engine"])
    var chrome: SurfaceTool = kit.bucket("chrome",materials["chrome"])
    var paint: SurfaceTool = kit.bucket("paint",materials["paint"])
    # Open bay conforming to the bonnet surface.
    for k in range(10):
        var z0: float = lerpf(-1.90,-1.02,float(k)/10.0)
        var z1: float = lerpf(-1.90,-1.02,float(k+1)/10.0)
        _deck_strip(well,Vector2(0.0,z0),Vector2(0.0,z1),1.08,0.005)
    var top: float = deck_top(0.0,-1.45)
    KIT.superellipsoid(engine,Transform3D(Basis.IDENTITY,Vector3(0,top+0.02,-1.47)),
        Vector3(0.31,0.07,0.36),0.35,16,8)
    KIT.superellipsoid(paint,Transform3D(Basis.IDENTITY,Vector3(-0.12,top+0.085,-1.47)),
        Vector3(0.09,0.035,0.30),0.4,12,8)
    # Strut brace.
    KIT.box(chrome,Transform3D(Basis.IDENTITY,Vector3(0,top+0.03,-1.10)),Vector3(0.98,0.03,0.05))
    var up := Basis(Vector3.BACK,PI*0.5)
    for i in range(3):
        var at := Vector3(0.12+0.0,top+0.07,-1.72+float(i)*0.25)
        var bell := PackedVector2Array([Vector2(0.0,0.050),Vector2(0.10,0.054),
            Vector2(0.15,0.068),Vector2(0.175,0.088),Vector2(0.182,0.092),Vector2(0.178,0.070)])
        KIT.lathe(chrome,Transform3D(up,at),bell,22,true)
        KIT.lathe(kit.bucket("well",materials["well"]),Transform3D(up,at),
            PackedVector2Array([Vector2(0.17,0.07),Vector2(0.16,0.0)]),18,true)
    return kit.commit()

# ------------------------------------------------------------------ wheels

func _build_wheel(side: float) -> ArrayMesh:
    var kit := KIT.new()
    var xf := Transform3D(Basis.from_scale(Vector3(side,1.0,1.0)),Vector3.ZERO)
    var rubber: SurfaceTool = kit.bucket("rubber",materials["rubber"])
    var rim: SurfaceTool = kit.bucket("rim",materials["rim"])
    var chrome: SurfaceTool = kit.bucket("chrome",materials["chrome"])
    var dark: SurfaceTool = kit.bucket("well",materials["well"])
    var r: float = WHEEL_RADIUS_M
    var tyre := PackedVector2Array([
        Vector2(-0.14,0.268),Vector2(-0.143,0.31),Vector2(-0.139,0.344),Vector2(-0.126,0.370),
        Vector2(-0.104,r-0.004),Vector2(-0.075,r),Vector2(0.075,r),Vector2(0.104,r-0.004),
        Vector2(0.126,0.370),Vector2(0.139,0.344),Vector2(0.143,0.31),Vector2(0.14,0.268)])
    KIT.lathe(rubber,xf,tyre,32,true)
    # Polished stepped lip and deep dish.
    KIT.lathe(chrome,xf,PackedVector2Array([Vector2(0.128,0.300),Vector2(0.142,0.296),
        Vector2(0.150,0.284),Vector2(0.147,0.266),Vector2(0.136,0.258)]),32,true)
    var white: bool = paint_variant == "white"
    var dish_depth: float = 0.05 if white else 0.10
    KIT.lathe(chrome,xf,PackedVector2Array([Vector2(0.136,0.258),
        Vector2(0.136-dish_depth,0.212)]),32,true)
    KIT.lathe(rim,xf,PackedVector2Array([Vector2(0.136-dish_depth,0.212),
        Vector2(0.136-dish_depth,0.0)]),32,true)
    KIT.lathe(dark,xf,PackedVector2Array([Vector2(-0.07,0.27),Vector2(-0.07,0.0)]),20,true)
    var face: float = 0.136-dish_depth
    if white:
        # Cross-laced mesh wheel.
        for k in range(14):
            var phi: float = TAU*float(k)/14.0
            for lean in [-0.22,0.22]:
                var basis := Basis(Vector3.RIGHT,phi+lean)
                KIT.box(rim,xf*Transform3D(basis,Vector3(face+0.016,0.0,0.0)+basis*Vector3(0,0.135,0)),
                    Vector3(0.018,0.15,0.016))
        KIT.superellipsoid(chrome,xf*Transform3D(Basis.IDENTITY,Vector3(face+0.025,0,0)),
            Vector3(0.03,0.065,0.065),0.6,14,8)
    else:
        # Five fat spokes on a white deep dish.
        for k in range(5):
            var phi2: float = TAU*float(k)/5.0
            var basis2 := Basis(Vector3.RIGHT,phi2)
            KIT.superellipsoid(rim,xf*Transform3D(basis2,Vector3(face+0.022,0,0)+basis2*Vector3(0,0.12,0)),
                Vector3(0.024,0.10,0.034),0.4,10,8)
        KIT.superellipsoid(rim,xf*Transform3D(Basis.IDENTITY,Vector3(face+0.03,0,0)),
            Vector3(0.035,0.075,0.075),0.55,16,8)
        KIT.superellipsoid(chrome,xf*Transform3D(Basis.IDENTITY,Vector3(face+0.06,0,0)),
            Vector3(0.012,0.035,0.035),0.7,12,6)
    return kit.commit()

func _make_wheels() -> void:
    for side in [-1.0,1.0]:
        var wheel_mesh: ArrayMesh = _cached("wheel_"+("l" if side < 0.0 else "r"),
            Callable(self,"_build_wheel").bind(side))
        for axle_z in [FRONT_AXLE_Z,REAR_AXLE_Z]:
            var pivot := Node3D.new()
            pivot.name = "Front steer pivot" if axle_z < 0.0 else "Rear fixed axle"
            pivot.position = Vector3(side*WHEEL_TRACK_X,WHEEL_RADIUS_M,axle_z)
            add_child(pivot)
            if axle_z < 0.0:
                front_wheels.append(pivot)
            var roll := Node3D.new()
            roll.name = "Rolling deep dish wheel"
            pivot.add_child(roll)
            rolling_wheels.append(roll)
            var wheel := MeshInstance3D.new()
            wheel.name = "Diecast wheel"
            wheel.mesh = wheel_mesh
            roll.add_child(wheel)

func _make_shadow() -> void:
    var shadow := MeshInstance3D.new()
    shadow.name = "Soft contact shadow"
    var plane := PlaneMesh.new()
    plane.size = Vector2(2.75,5.35)
    shadow.mesh = plane
    var mat := ShaderMaterial.new()
    mat.shader = SHADOW_SHADER
    mat.set_shader_parameter("core",Vector2(0.30,0.36))
    mat.set_shader_parameter("softness",0.13)
    mat.set_shader_parameter("corner",0.12)
    mat.set_shader_parameter("opacity",0.72)
    shadow.material_override = mat
    shadow.position = Vector3(0.10,shadow_height,0.12)
    shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(shadow)

func _make_badge() -> void:
    # "NW" banner on the rear screen, as on the approved gameplay render.
    var badge := Label3D.new()
    badge.name = "NW rear screen banner"
    badge.text = "NW"
    badge.font_size = 64
    badge.outline_size = 0
    badge.pixel_size = 0.0042
    badge.modulate = Color(0.96,0.96,1.0)
    badge.double_sided = false
    badge.shaded = false
    var slope: float = atan2(REAR_RAKE,1.0)
    var bz: float = 0.80
    badge.position = Vector3(0.0,_deck(bz)+(CABIN_REAR-bz)*REAR_RAKE+0.03,bz+0.02)
    badge.rotation = Vector3(-(PI*0.5-slope),0.0,0.0)
    add_child(badge)

func set_motion(steer_rad: float, speed_mps: float, dt: float) -> void:
    # Godot +Y rotation maps local -Z to -X; invert to match +steer/right.
    for wheel in front_wheels:
        wheel.rotation.y = -steer_rad
    for roll in rolling_wheels:
        roll.rotation.x += speed_mps*dt/WHEEL_RADIUS_M
