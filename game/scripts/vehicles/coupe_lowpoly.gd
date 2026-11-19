extends Node3D
class_name NitroCoupeLowPoly
## Nitro Wheelz "RYU-32" drift coupe in the collectible die-cast style.
## Built from the owner's blue 3D reference sheet (2026-11-19): 4,545 mm
## long, 2,615 mm wheelbase, 1,290 mm high, bolt-on wide arches, aggressive
## bumpers and skirts, large fixed rear wing, quad round tail lamps, bonnet
## removed with an inline engine on individual throttle trumpets, silver
## 5-spoke deep-dish wheels. Original procedural geometry, no badges or
## third-party meshes. Same public API as NitroLadaLowPoly.
## Front of vehicle is LOCAL -Z; world heading is applied by the race scene.

const KIT = preload("res://scripts/vehicles/mesh_kit.gd")
const PAINT_SHADER = preload("res://assets/shaders/diecast_paint.gdshader")
const SHADOW_SHADER = preload("res://assets/shaders/soft_shadow.gdshader")

const DISPLAY_NAME: String = "RYU-32 COUPE"
const BODY_LENGTH_M: float = 4.545
const WHEELBASE_M: float = 2.615
const FRONT_AXLE_Z: float = -WHEELBASE_M * 0.5
const REAR_AXLE_Z: float = WHEELBASE_M * 0.5
const DRIFT_BODY_WIDTH_M: float = 1.90
const WHEEL_RADIUS_M: float = 0.36

const SHELL_FRONT: float = -2.18
const SHELL_REAR: float = 2.18
const SHELL_HALF_WIDTH: float = 0.79
const SHELL_BOTTOM: float = 0.22
const CABIN_FRONT: float = -0.78
const CABIN_REAR: float = 1.24
const ROOF_Y: float = 1.29
const WHEEL_TRACK_X: float = 0.80
const FRONT_RAKE: float = 0.80
const REAR_RAKE: float = 0.66
const ARCH_OUTER_X: float = DRIFT_BODY_WIDTH_M * 0.5
const SHELL_EXP: float = 5.2
const PLAN_ROUND: float = 0.20
const ELEV_ROUND: float = 0.09
const ROOF_CORNER: float = 0.10

const BLUE := Color(0.02,0.15,0.70)

var paint_variant: String = "blue"
var shadow_height: float = 0.10
var front_wheels: Array[Node3D] = []
var rolling_wheels: Array[Node3D] = []
var materials: Dictionary = {}
# Kept for API parity with the Lada (tests read it).
var flat_body: bool = false

static var _mesh_cache: Dictionary = {}

func _ready() -> void:
    paint_variant = "blue"
    _make_materials()
    var shell := MeshInstance3D.new()
    shell.name = "Diecast body shell"
    shell.mesh = _cached("shell",Callable(self,"_build_shell"))
    add_child(shell)
    var bay := MeshInstance3D.new()
    bay.name = "Exposed V8 engine bay"
    bay.mesh = _cached("engine",Callable(self,"_build_engine_bay"))
    add_child(bay)
    var wing := MeshInstance3D.new()
    wing.name = "Fixed rear wing"
    wing.mesh = _cached("wing",Callable(self,"_build_wing"))
    add_child(wing)
    _make_wheels()
    _make_shadow()

func _cached(part: String, builder: Callable) -> ArrayMesh:
    var key: String = "coupe:"+part
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
    mat.set_shader_parameter("studio",Color(0.97,0.97,1.0))
    mat.set_shader_parameter("floor_tint",Color(0.11,0.11,0.13))
    return mat

func _make_materials() -> void:
    materials["paint"] = _paint(BLUE,0.22,0.15,0.65,0.42)
    materials["glass"] = _paint(Color(0.06,0.07,0.10),0.08,0.0,1.1,0.8)
    materials["chrome"] = _paint(Color(0.86,0.87,0.89),0.16,1.0,1.35,0.5)
    materials["trim"] = _paint(Color(0.045,0.047,0.055),0.55,0.0,0.30,0.25)
    materials["rubber"] = _paint(Color(0.06,0.06,0.066),0.85,0.0,0.10,0.10)
    materials["rim"] = _paint(Color(0.78,0.79,0.82),0.22,0.7,1.0,0.45)
    materials["lamp"] = _paint(Color(1.0,0.96,0.86),0.10,0.0,0.6,0.3,1.4)
    materials["tail"] = _paint(Color(0.80,0.03,0.05),0.12,0.0,0.8,0.3,1.2)
    materials["amber"] = _paint(Color(1.0,0.45,0.04),0.15,0.0,0.6,0.3,1.0)
    materials["lens"] = _paint(Color(0.70,0.73,0.78),0.06,0.2,1.3,0.7,0.25)
    materials["engine"] = _paint(Color(0.13,0.13,0.145),0.45,0.4,0.5,0.3)
    materials["well"] = _paint(Color(0.015,0.015,0.02),0.9,0.0,0.0,0.0)

# ------------------------------------------------------------- body shape

static func _end_inset(z: float, radius: float) -> float:
    var d: float = minf(z-SHELL_FRONT,SHELL_REAR-z)
    if d >= radius:
        return 0.0
    var t: float = radius-maxf(d,0.0)
    return radius-sqrt(maxf(radius*radius-t*t,0.0))

## Top of the lower body along the car: low wedge nose, bonnet rising to
## the cowl, high short boot with a slight kick at the tail.
static func _deck(z: float) -> float:
    if z < CABIN_FRONT:
        var t: float = clampf((z-SHELL_FRONT)/(CABIN_FRONT-SHELL_FRONT),0.0,1.0)
        return lerpf(0.655,0.835,t*(2.0-t))
    if z > CABIN_REAR:
        var r: float = clampf((z-CABIN_REAR)/(SHELL_REAR-CABIN_REAR),0.0,1.0)
        return lerpf(0.905,0.925,r*r)
    return lerpf(0.835,0.905,(z-CABIN_FRONT)/(CABIN_REAR-CABIN_FRONT))

func _shell_section(z: float) -> Vector4:
    var hw: float = SHELL_HALF_WIDTH-_end_inset(z,PLAN_ROUND)
    var top: float = _deck(z)-_end_inset(z,ELEV_ROUND)
    var bottom: float = SHELL_BOTTOM+_end_inset(z,0.12)*0.8
    return Vector4(hw,bottom,top,0.0)

static func _z_warp(u: float) -> float:
    return lerpf(u,0.5-0.5*cos(PI*u),0.62)

func _shell_point(u: float, v: float) -> Vector3:
    var z: float = lerpf(SHELL_FRONT,SHELL_REAR,_z_warp(clampf(u,0.0,1.0)))
    var sec: Vector4 = _shell_section(z)
    var theta: float = lerpf(PI*1.25,-PI*0.25,v)
    var e: float = 2.0/SHELL_EXP
    var yc: float = (sec.y+sec.z)*0.5
    var hh: float = (sec.z-sec.y)*0.5
    return Vector3(sec.x*KIT.sgnpow(cos(theta),e),yc+hh*KIT.sgnpow(sin(theta),e),z)

func deck_top(x: float, z: float) -> float:
    var sec: Vector4 = _shell_section(z)
    var yc: float = (sec.y+sec.z)*0.5
    var hh: float = (sec.z-sec.y)*0.5
    var q: float = clampf(absf(x)/sec.x,0.0,1.0)
    return yc+hh*pow(maxf(1.0-pow(q,SHELL_EXP),0.0),1.0/SHELL_EXP)

# ------------------------------------------------------------ greenhouse

static func _smin(a: float, b: float, k: float) -> float:
    var h: float = clampf(0.5+0.5*(b-a)/k,0.0,1.0)
    return lerpf(b,a,h)-k*h*(1.0-h)

## Coupe roofline: raked windscreen, short roof, long sloping rear glass.
static func _cabin_top(z: float, belt: float) -> float:
    var front_ramp: float = belt+(z-CABIN_FRONT)*FRONT_RAKE
    var rear_ramp: float = belt+(CABIN_REAR-z)*REAR_RAKE
    return maxf(_smin(_smin(front_ramp,ROOF_Y,0.14),rear_ramp,0.14),belt)

static func _cabin_half_width(y: float, belt: float) -> float:
    # Strong tumblehome: narrow glasshouse on a wide body.
    return lerpf(0.735,0.585,clampf((y-belt)/(ROOF_Y-belt),0.0,1.0))

func _cabin_point(u: float, v: float) -> Vector3:
    var z: float = lerpf(CABIN_FRONT,CABIN_REAR,clampf(u,0.0,1.0))
    var belt: float = _deck(z)-0.004
    var top: float = _cabin_top(z,belt)
    var h: float = top-belt
    var r: float = minf(ROOF_CORNER,h*0.55)
    var ys: float = top-r
    var hws: float = _cabin_half_width(ys,belt)
    var crown: float = 0.022*clampf(h/(ROOF_Y-belt),0.0,1.0)
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
        var t2: float = (w-0.30)/0.20
        var x: float = lerpf(-hws+r,0.0,t2)
        p = Vector2(x,top+crown*(1.0-(1.0-t2)*(1.0-t2)))
    return Vector3(p.x*(-side) if side > 0.0 else p.x,p.y,z)

# ------------------------------------------------------------ wheel arches

func _arch_point(u: float, v: float, side: float, axle_z: float) -> Vector3:
    var a: float = lerpf(-0.12,PI+0.12,u)
    var taper: float = sqrt(clampf(minf(u,1.0-u)/0.10,0.0,1.0))
    var psi: float = v*TAU
    var lat_in: float = SHELL_HALF_WIDTH-0.03
    var lat_c: float = (lat_in+ARCH_OUTER_X)*0.5
    var lat_h: float = (ARCH_OUTER_X-lat_in)*0.5*taper
    var rad_c: float = 0.448
    var rad_h: float = 0.05*maxf(taper,0.05)
    var lateral: float = lat_c+lat_h*KIT.sgnpow(cos(psi),0.55)
    var radial: float = rad_c+rad_h*KIT.sgnpow(sin(psi),0.55)
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
    kit.bucket("lamp",materials["lamp"])
    kit.bucket("tail",materials["tail"])
    kit.bucket("amber",materials["amber"])
    kit.bucket("lens",materials["lens"])

    KIT.grid(paint,id,Callable(self,"_shell_point"),0.0,1.0,64,0.0,1.0,40)
    for end_u in [0.0,1.0]:
        var ring := PackedVector3Array()
        for k in range(41):
            ring.append(_shell_point(end_u,float(k)/40.0))
        var centre: Vector3 = (ring[0]+ring[40])*0.5
        centre.y = (ring[0].y+ring[20].y)*0.5
        KIT.fan(paint,id,centre,ring,Vector3(0,0,-1.0 if end_u == 0.0 else 1.0))
    KIT.box(trim,Transform3D(Basis.IDENTITY,Vector3(0,SHELL_BOTTOM+0.01,0)),Vector3(1.48,0.02,4.20))

    # Greenhouse: windscreen, rear glass, door glass + rear quarter glass.
    var cab := Callable(self,"_cabin_point")
    KIT.grid(paint,id,cab,0.0,1.0,56,0.0,1.0,44)
    var span: float = CABIN_REAR-CABIN_FRONT
    var ws_end: float = ((ROOF_Y-0.06-_deck(-0.5))/FRONT_RAKE)/span
    var bl_start: float = (span-(ROOF_Y-0.06-_deck(0.9))/REAR_RAKE)/span
    KIT.grid(glass,id,cab,0.03/span,ws_end,16,0.205,0.795,26,false,0.006)
    KIT.grid(glass,id,cab,bl_start,1.0-0.03/span,16,0.205,0.795,26,false,0.006)
    for window in [[-0.60,0.30],[0.40,0.88]]:
        var u0: float = (float(window[0])-CABIN_FRONT)/span
        var u1: float = (float(window[1])-CABIN_FRONT)/span
        KIT.grid(trim,id,cab,u0-0.012/span,u1+0.012/span,14,0.012,0.158,6,false,0.004)
        KIT.grid(trim,id,cab,u0-0.012/span,u1+0.012/span,14,0.842,0.988,6,false,0.004)
        KIT.grid(glass,id,cab,u0,u1,14,0.024,0.146,6,false,0.007)
        KIT.grid(glass,id,cab,u0,u1,14,0.854,0.976,6,false,0.007)

    for side in [-1.0,1.0]:
        for axle_z in [FRONT_AXLE_Z,REAR_AXLE_Z]:
            KIT.grid(paint,id,Callable(self,"_arch_point").bind(side,axle_z),
                0.0,1.0,26,0.0,1.0,14,side > 0.0)
            var ring := PackedVector3Array()
            for k in range(25):
                var a: float = lerpf(-0.25,PI+0.25,float(k)/24.0)
                var y: float = maxf(WHEEL_RADIUS_M+sin(a)*0.415,SHELL_BOTTOM+0.005)
                ring.append(Vector3(side*(SHELL_HALF_WIDTH+0.002),y,axle_z-cos(a)*0.415))
            KIT.fan(well,id,Vector3(side*(SHELL_HALF_WIDTH+0.002),SHELL_BOTTOM+0.06,axle_z),
                ring,Vector3(side,0,0))
        # Aero side skirt spanning the arches.
        KIT.superellipsoid(paint,Transform3D(Basis.IDENTITY,
            Vector3(side*(SHELL_HALF_WIDTH+0.045),0.255,0.0)),Vector3(0.075,0.05,0.86),0.3,14,6)
        KIT.box(trim,Transform3D(Basis.IDENTITY,Vector3(side*(SHELL_HALF_WIDTH+0.05),0.205,0.0)),
            Vector3(0.10,0.02,1.70))
        # Door shut lines and handle.
        for gap_z in [-0.66,0.36]:
            KIT.box(trim,Transform3D(Basis.IDENTITY,Vector3(side*(SHELL_HALF_WIDTH+0.002),0.56,gap_z)),
                Vector3(0.008,0.56,0.012))
        KIT.superellipsoid(trim,Transform3D(Basis.IDENTITY,Vector3(side*(SHELL_HALF_WIDTH+0.008),0.78,0.22)),
            Vector3(0.012,0.016,0.07),0.35,10,6)
        # Body-colour aero mirror.
        KIT.box(trim,Transform3D(Basis.IDENTITY,Vector3(side*0.80,0.95,-0.52)),Vector3(0.10,0.03,0.05))
        KIT.superellipsoid(paint,Transform3D(Basis.IDENTITY,Vector3(side*0.875,0.985,-0.52)),
            Vector3(0.07,0.045,0.085),0.4,12,8)
        KIT.box(glass,Transform3D(Basis.IDENTITY,Vector3(side*0.875,0.985,-0.44)),Vector3(0.11,0.065,0.01))

    _build_front(kit)
    _build_rear(kit)
    return kit.commit()

func _build_front(kit: KIT) -> void:
    var paint: SurfaceTool = kit.buckets["paint"]
    var chrome: SurfaceTool = kit.buckets["chrome"]
    var trim: SurfaceTool = kit.buckets["trim"]
    var lamp: SurfaceTool = kit.buckets["lamp"]
    var amber: SurfaceTool = kit.buckets["amber"]
    var face_z: float = SHELL_FRONT-0.004
    var fwd := Basis(Vector3.UP,PI*0.5)
    # Slim black grille between rectangular lamp units.
    KIT.superellipsoid(trim,Transform3D(Basis.IDENTITY,Vector3(0,0.585,face_z+0.004)),
        Vector3(0.30,0.035,0.02),0.25,16,6)
    var lens: SurfaceTool = kit.buckets["lens"]
    for side in [-1.0,1.0]:
        # Rectangular headlamp: dark housing, clear lens, twin projectors.
        KIT.superellipsoid(trim,Transform3D(Basis.IDENTITY,Vector3(side*0.50,0.585,face_z+0.004)),
            Vector3(0.20,0.062,0.026),0.18,14,8)
        KIT.superellipsoid(lens,Transform3D(Basis.IDENTITY,Vector3(side*0.50,0.585,face_z-0.014)),
            Vector3(0.185,0.050,0.012),0.15,14,8)
        for col in [0.43,0.575]:
            var at := Vector3(side*col,0.583,face_z-0.022)
            KIT.lathe(chrome,Transform3D(fwd,at),PackedVector2Array([Vector2(0.0,0.040),
                Vector2(0.010,0.038),Vector2(0.012,0.030)]),20,true)
            KIT.lathe(lamp,Transform3D(fwd,at),PackedVector2Array([Vector2(0.004,0.031),
                Vector2(0.014,0.020),Vector2(0.018,0.0)]),20,true)
        # Amber corner light wrapping round the nose.
        KIT.superellipsoid(amber,Transform3D(Basis.IDENTITY,Vector3(side*0.725,0.58,face_z+0.06)),
            Vector3(0.05,0.042,0.07),0.3,10,6)
    # Front bumper: body colour with a big black intake and side vents.
    KIT.superellipsoid(paint,Transform3D(Basis.IDENTITY,Vector3(0,0.40,face_z+0.02)),
        Vector3(0.84,0.15,0.07),0.28,30,10)
    KIT.superellipsoid(trim,Transform3D(Basis.IDENTITY,Vector3(0,0.37,face_z-0.035)),
        Vector3(0.42,0.068,0.02),0.25,18,6)
    for side in [-1.0,1.0]:
        KIT.superellipsoid(trim,Transform3D(Basis.IDENTITY,Vector3(side*0.64,0.36,face_z-0.03)),
            Vector3(0.10,0.05,0.02),0.25,12,6)
    # Splitter lip.
    KIT.superellipsoid(paint,Transform3D(Basis.IDENTITY,Vector3(0,0.245,face_z+0.03)),
        Vector3(0.88,0.022,0.14),0.3,26,6)
    KIT.box(trim,Transform3D(Basis.IDENTITY,Vector3(0,0.222,face_z+0.03)),Vector3(1.70,0.012,0.26))

func _build_rear(kit: KIT) -> void:
    var paint: SurfaceTool = kit.buckets["paint"]
    var chrome: SurfaceTool = kit.buckets["chrome"]
    var trim: SurfaceTool = kit.buckets["trim"]
    var tail: SurfaceTool = kit.buckets["tail"]
    var face_z: float = SHELL_REAR+0.004
    var back := Basis(Vector3.UP,-PI*0.5)
    # Black tail panel with four round lamps.
    KIT.superellipsoid(trim,Transform3D(Basis.IDENTITY,Vector3(0,0.73,face_z)),
        Vector3(0.74,0.085,0.016),0.22,26,8)
    for side in [-1.0,1.0]:
        for col in [0.33,0.57]:
            var at := Vector3(side*col,0.73,face_z+0.004)
            KIT.lathe(chrome,Transform3D(back,at),PackedVector2Array([Vector2(0.0,0.078),
                Vector2(0.014,0.076),Vector2(0.018,0.064)]),24,true)
            KIT.lathe(tail,Transform3D(back,at),PackedVector2Array([Vector2(0.01,0.066),
                Vector2(0.024,0.040),Vector2(0.03,0.0)]),24,true)
    # Rear bumper, plate recess, diffuser and big single exhaust.
    KIT.superellipsoid(paint,Transform3D(Basis.IDENTITY,Vector3(0,0.43,face_z-0.01)),
        Vector3(0.84,0.15,0.07),0.28,30,10)
    KIT.superellipsoid(trim,Transform3D(Basis.IDENTITY,Vector3(0,0.50,face_z+0.05)),
        Vector3(0.22,0.06,0.01),0.3,12,6)
    KIT.box(trim,Transform3D(Basis.IDENTITY,Vector3(0,0.255,face_z-0.02)),Vector3(1.40,0.07,0.12))
    var at2 := Vector3(-0.46,0.29,face_z-0.08)
    KIT.lathe(chrome,Transform3D(back,at2),PackedVector2Array([
        Vector2(0.0,0.07),Vector2(0.15,0.07),Vector2(0.16,0.063),Vector2(0.155,0.052)]),20,true)
    KIT.lathe(trim,Transform3D(back,at2),PackedVector2Array([Vector2(0.15,0.052),Vector2(0.14,0.0)]),20,true)

## Large fixed wing on two uprights with end plates.
func _build_wing() -> ArrayMesh:
    var kit := KIT.new()
    var paint: SurfaceTool = kit.bucket("paint",materials["paint"])
    var trim: SurfaceTool = kit.bucket("trim",materials["trim"])
    var z: float = 1.98
    var base: float = deck_top(0.45,z)
    var h: float = base+0.30
    for side in [-1.0,1.0]:
        KIT.box(trim,Transform3D(Basis(Vector3.RIGHT,deg_to_rad(-12.0)),
            Vector3(side*0.45,(base+h)*0.5,z+0.02)),Vector3(0.03,h-base,0.12))
        KIT.superellipsoid(paint,Transform3D(Basis.IDENTITY,Vector3(side*0.86,h+0.02,z)),
            Vector3(0.012,0.085,0.22),0.3,8,8)
    var tilt := Basis(Vector3.RIGHT,deg_to_rad(-8.0))
    KIT.superellipsoid(paint,Transform3D(tilt,Vector3(0,h,z)),Vector3(0.85,0.022,0.18),0.25,30,8)
    KIT.box(trim,Transform3D(tilt,Vector3(0,h+0.015,z+0.17)),Vector3(1.66,0.02,0.03))
    return kit.commit()

func _deck_strip(st: SurfaceTool, a: Vector2, b: Vector2, width: float, lift: float = 0.004) -> void:
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

## Bonnet removed: dark bay, 4.0 V8 (owner's reference car) with two cam
## covers and eight individual throttle trumpets standing in two rows of
## four in the valley, strut towers with a brace and an X-brace in front.
func _build_engine_bay() -> ArrayMesh:
    var kit := KIT.new()
    var well: SurfaceTool = kit.bucket("well",materials["well"])
    var engine: SurfaceTool = kit.bucket("engine",materials["engine"])
    var chrome: SurfaceTool = kit.bucket("chrome",materials["chrome"])
    var paint: SurfaceTool = kit.bucket("paint",materials["paint"])
    var trim: SurfaceTool = kit.bucket("trim",materials["trim"])
    for k in range(12):
        var z0: float = lerpf(-2.10,-0.86,float(k)/12.0)
        var z1: float = lerpf(-2.10,-0.86,float(k+1)/12.0)
        _deck_strip(well,Vector2(0.0,z0),Vector2(0.0,z1),1.26,0.005)
    var top: float = deck_top(0.0,-1.45)
    # V8 block and the two cylinder banks with their cam covers.
    KIT.superellipsoid(engine,Transform3D(Basis.IDENTITY,Vector3(0,top-0.04,-1.45)),
        Vector3(0.30,0.05,0.40),0.3,16,8)
    for bank in [-1.0,1.0]:
        var tilt := Basis(Vector3.BACK,bank*deg_to_rad(-30.0))
        KIT.superellipsoid(engine,Transform3D(tilt,Vector3(bank*0.21,top+0.02,-1.45)),
            Vector3(0.075,0.03,0.38),0.25,12,8)
        for i in range(4):
            KIT.superellipsoid(chrome,Transform3D(tilt,Vector3(bank*0.215,top+0.05,-1.72+float(i)*0.18)),
                Vector3(0.018,0.007,0.018),0.6,8,6)
    # Eight throttle trumpets: two rows of four in the valley, leaning out.
    for bank in [-1.0,1.0]:
        var lean := Basis(Vector3.BACK,PI*0.5-bank*deg_to_rad(12.0))
        for i in range(4):
            var at := Vector3(bank*0.075,top+0.03,-1.72+float(i)*0.18)
            var bell := PackedVector2Array([Vector2(0.0,0.036),Vector2(0.10,0.038),
                Vector2(0.15,0.046),Vector2(0.172,0.060),Vector2(0.177,0.064),Vector2(0.173,0.050)])
            KIT.lathe(chrome,Transform3D(lean,at),bell,18,true)
            KIT.lathe(well,Transform3D(lean,at),PackedVector2Array([Vector2(0.167,0.050),Vector2(0.157,0.0)]),14,true)
    # Strut towers (body colour) with a brace, and the front X-brace.
    for side in [-1.0,1.0]:
        KIT.superellipsoid(paint,Transform3D(Basis.IDENTITY,Vector3(side*0.60,top+0.0,-1.02)),
            Vector3(0.10,0.06,0.10),0.4,12,8)
    KIT.box(chrome,Transform3D(Basis.IDENTITY,Vector3(0,top+0.07,-1.02)),Vector3(1.18,0.03,0.04))
    # X-brace in front of the engine, kept inside the narrowing nose.
    for s2 in [-1.0,1.0]:
        var basis := Basis(Vector3.UP,s2*deg_to_rad(20.0))
        KIT.box(chrome,Transform3D(basis,Vector3(0,top-0.015,-1.92)),Vector3(0.96,0.022,0.022))
    KIT.box(trim,Transform3D(Basis.IDENTITY,Vector3(0,top-0.07,-2.06)),Vector3(0.96,0.08,0.05))
    # Coolant / intake pipes.
    KIT.box(chrome,Transform3D(Basis.IDENTITY,Vector3(0.36,top+0.01,-1.55)),Vector3(0.035,0.035,0.70))
    KIT.box(chrome,Transform3D(Basis.IDENTITY,Vector3(-0.42,top-0.01,-1.30)),Vector3(0.03,0.03,0.40))
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
        Vector2(-0.14,0.262),Vector2(-0.143,0.295),Vector2(-0.139,0.322),Vector2(-0.126,0.343),
        Vector2(-0.104,r-0.004),Vector2(-0.075,r),Vector2(0.075,r),Vector2(0.104,r-0.004),
        Vector2(0.126,0.343),Vector2(0.139,0.322),Vector2(0.143,0.295),Vector2(0.14,0.262)])
    KIT.lathe(rubber,xf,tyre,32,true)
    # Polished stepped lip, deep dish and a silver 5-spoke face.
    KIT.lathe(chrome,xf,PackedVector2Array([Vector2(0.128,0.290),Vector2(0.142,0.286),
        Vector2(0.150,0.274),Vector2(0.147,0.256),Vector2(0.136,0.250)]),32,true)
    var dish: float = 0.11
    KIT.lathe(chrome,xf,PackedVector2Array([Vector2(0.136,0.250),Vector2(0.136-dish,0.205)]),32,true)
    KIT.lathe(rim,xf,PackedVector2Array([Vector2(0.136-dish,0.205),Vector2(0.136-dish,0.0)]),32,true)
    KIT.lathe(dark,xf,PackedVector2Array([Vector2(-0.07,0.26),Vector2(-0.07,0.0)]),20,true)
    var face: float = 0.136-dish
    for k in range(5):
        var basis := Basis(Vector3.RIGHT,TAU*float(k)/5.0)
        KIT.superellipsoid(rim,xf*Transform3D(basis,Vector3(face+0.02,0,0)+basis*Vector3(0,0.115,0)),
            Vector3(0.02,0.10,0.045),0.25,10,8)
    KIT.superellipsoid(rim,xf*Transform3D(Basis.IDENTITY,Vector3(face+0.028,0,0)),
        Vector3(0.032,0.07,0.07),0.55,16,8)
    KIT.superellipsoid(chrome,xf*Transform3D(Basis.IDENTITY,Vector3(face+0.055,0,0)),
        Vector3(0.012,0.032,0.032),0.7,12,6)
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
    plane.size = Vector2(2.80,5.80)
    shadow.mesh = plane
    var mat := ShaderMaterial.new()
    mat.shader = SHADOW_SHADER
    mat.set_shader_parameter("core",Vector2(0.30,0.37))
    mat.set_shader_parameter("softness",0.13)
    mat.set_shader_parameter("corner",0.12)
    mat.set_shader_parameter("opacity",0.72)
    shadow.material_override = mat
    shadow.position = Vector3(0.10,shadow_height,0.12)
    shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(shadow)

func set_motion(steer_rad: float, speed_mps: float, dt: float) -> void:
    for wheel in front_wheels:
        wheel.rotation.y = -steer_rad
    for roll in rolling_wheels:
        roll.rotation.x += speed_mps*dt/WHEEL_RADIUS_M
