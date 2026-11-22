extends Node3D
class_name NitroParkGhost
## DEMONSTRATION GHOST of the Park tutorial (issue #27): a translucent car that drives
## the intended line of the current exercise with a drifting attitude (nose pointing
## into the turn), over and over, so the player sees the line and the action before
## and while practising. It is NOT a Personal Best ghost and it is NOT a physics car:
## it replays an ideal path at a fixed speed, so it repeats identically every time.
## Cheap: about 100 triangles, one unshaded material, visible only while it plays.
const BODY_LENGTH: float = 4.2
const BODY_WIDTH: float = 1.8

var path: PackedVector2Array = PackedVector2Array()
var closed: bool = true
var speed_mps: float = 10.0
var slip_deg: float = 28.0
var travelled: float = 0.0
var total: float = 0.0
var playing: bool = false
var _along: PackedFloat32Array = PackedFloat32Array()
var _mesh: MeshInstance3D

func _ready() -> void:
    name = "Demonstration ghost"
    visible = false
    _mesh = MeshInstance3D.new()
    _mesh.mesh = _build_mesh()
    var mat := StandardMaterial3D.new()
    mat.vertex_color_use_as_albedo = true
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    mat.render_priority = 1
    _mesh.material_override = mat
    _mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(_mesh)

## Replay `p` (a closed or open polyline, metres, planar x / z) at `speed` m/s with
## the body turned `slip` degrees into the turn.
func play(p: PackedVector2Array, is_closed: bool, speed: float, slip: float) -> void:
    path = p
    closed = is_closed
    speed_mps = speed
    slip_deg = slip
    _along.clear()
    var acc: float = 0.0
    _along.append(0.0)
    for i in range(1,path.size()):
        acc += path[i-1].distance_to(path[i])
        _along.append(acc)
    total = acc+(path[path.size()-1].distance_to(path[0]) if closed else 0.0)
    travelled = 0.0
    playing = path.size() >= 3 and total > 1.0
    visible = playing
    if playing:
        _place()

func stop() -> void:
    playing = false
    visible = false

func advance(dt: float) -> void:
    if not playing:
        return
    travelled += speed_mps*dt
    if travelled >= total:
        if closed:
            travelled = fposmod(travelled,total)
        else:
            travelled = 0.0
    _place()

## Position + heading of the ghost at the current arc length.
func pose_at(s: float) -> Dictionary:
    var n: int = path.size()
    var idx: int = 0
    for i in range(n):
        if _along[i] <= s:
            idx = i
        else:
            break
    var j: int = (idx+1)%n
    var seg: float = maxf(path[idx].distance_to(path[j]),0.0001)
    var t: float = clampf((s-_along[idx])/seg,0.0,1.0)
    var pos: Vector2 = path[idx].lerp(path[j],t)
    var dir: Vector2 = (path[j]-path[idx]).normalized()
    # curvature sign from the next segment: positive = turning clockwise (right)
    var k: int = (j+1)%n
    var dir2: Vector2 = (path[k]-path[j]).normalized()
    var turn: float = signf(dir.x*dir2.y-dir.y*dir2.x)         # z south: + = clockwise
    var heading: float = atan2(dir.x,-dir.y)+deg_to_rad(slip_deg)*turn
    return {"pos":pos,"heading":heading,"turn":turn}

func _place() -> void:
    var pose: Dictionary = pose_at(travelled)
    var p: Vector2 = pose["pos"]
    position = Vector3(p.x,0.12,p.y)
    rotation = Vector3(0.0,-float(pose["heading"]),0.0)

# ---------------------------------------------------------------------- mesh

func _build_mesh() -> ArrayMesh:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var body := Color(0.25,0.95,1.0,0.34)
    var roof := Color(0.55,1.0,1.0,0.42)
    var wheel := Color(0.1,0.5,0.6,0.5)
    # body + cabin + four wheels, the car nose toward -z (the model's forward)
    _box(st,Vector3(-BODY_WIDTH*0.5,0.18,-BODY_LENGTH*0.5),Vector3(BODY_WIDTH*0.5,0.78,BODY_LENGTH*0.5),body)
    _box(st,Vector3(-BODY_WIDTH*0.40,0.78,-BODY_LENGTH*0.18),Vector3(BODY_WIDTH*0.40,1.28,BODY_LENGTH*0.30),roof)
    for sx in [-1.0,1.0]:
        for z in [-1.35,1.30]:
            _box(st,Vector3(sx*BODY_WIDTH*0.5-0.13,0.0,z-0.34),Vector3(sx*BODY_WIDTH*0.5+0.13,0.64,z+0.34),wheel)
    # a bright nose stripe so the heading reads at a glance
    _box(st,Vector3(-0.5,0.78,-BODY_LENGTH*0.5-0.02),Vector3(0.5,0.84,-BODY_LENGTH*0.5+0.5),Color(1.0,1.0,1.0,0.65))
    return st.commit()

static func _box(st: SurfaceTool, lo: Vector3, hi: Vector3, col: Color) -> void:
    var c: Array = [Vector3(lo.x,lo.y,lo.z),Vector3(hi.x,lo.y,lo.z),Vector3(hi.x,lo.y,hi.z),Vector3(lo.x,lo.y,hi.z),
        Vector3(lo.x,hi.y,lo.z),Vector3(hi.x,hi.y,lo.z),Vector3(hi.x,hi.y,hi.z),Vector3(lo.x,hi.y,hi.z)]
    var faces: Array = [[4,5,6,7],[0,1,5,4],[1,2,6,5],[2,3,7,6],[3,0,4,7],[0,3,2,1]]
    for f in faces:
        for idx in [0,1,2,0,2,3]:
            st.set_color(col)
            st.set_normal(Vector3.UP)
            st.add_vertex(c[int(f[idx])])
