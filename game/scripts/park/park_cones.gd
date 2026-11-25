extends Node3D
class_name NitroParkCones
## Orange traffic cones of the Park (issue #27): lightweight, MOVABLE props, never
## obstacles. One MultiMesh (one draw call). Each cone is a tiny 2D simulation in
## script: when the car's body touches it, it is pushed away along the car's motion,
## tips over and slides to a stop. The car is NEVER affected: no physics body, no
## collision response, no sound that stops anything. reset_all() puts every cone
## back to its guide position (lesson start / retry / restart).
signal cone_hit(index: int, speed: float)

const CONE_RADIUS: float = 0.20         # contact radius around the cone (m)
const VISUAL_SCALE: float = 1.25        # readable from the top-down camera
const TIP_SPEED: float = 9.0            # rad/s while falling over
const SLIDE_DAMP: float = 2.6           # 1/s, exponential slow-down of a sliding cone
const MIN_PUSH: float = 1.6             # m/s a touched cone always gets
const MAX_SPEED: float = 20.0

var homes: PackedVector2Array = PackedVector2Array()
var groups: PackedStringArray = PackedStringArray()
var positions: PackedVector2Array = PackedVector2Array()
var velocities: PackedVector2Array = PackedVector2Array()
var fall_dir: PackedVector2Array = PackedVector2Array()
var tilt: PackedFloat32Array = PackedFloat32Array()
var tilt_vel: PackedFloat32Array = PackedFloat32Array()
var touched: PackedByteArray = PackedByteArray()
var awake: Dictionary = {}
var _network_displaced: Dictionary = {}
var multimesh: MultiMesh
var hits_total: int = 0

func count() -> int:
    return homes.size()

func build(list: Array[Dictionary]) -> void:
    homes.clear()
    groups.clear()
    for c in list:
        homes.append(Vector2(c["pos"]))
        groups.append(str(c["group"]))
    var n: int = homes.size()
    positions = homes.duplicate()
    velocities.resize(n)
    fall_dir.resize(n)
    tilt.resize(n)
    tilt_vel.resize(n)
    touched.resize(n)
    multimesh = MultiMesh.new()
    multimesh.transform_format = MultiMesh.TRANSFORM_3D
    multimesh.mesh = _cone_mesh()
    multimesh.instance_count = n
    var inst := MultiMeshInstance3D.new()
    inst.name = "Orange traffic cones"
    inst.multimesh = multimesh
    var mat := StandardMaterial3D.new()
    mat.vertex_color_use_as_albedo = true
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    inst.material_override = mat
    inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(inst)
    for i in range(n):
        _write(i)

## Back to the guide positions, upright, at rest.
func reset_all() -> void:
    for i in range(homes.size()):
        positions[i] = homes[i]
        velocities[i] = Vector2.ZERO
        tilt[i] = 0.0
        tilt_vel[i] = 0.0
        touched[i] = 0
        _write(i)
    awake.clear()
    _network_displaced.clear()

func displaced_count() -> int:
    var n: int = 0
    for i in range(homes.size()):
        if tilt[i] > 0.05 or positions[i].distance_to(homes[i]) > 0.05:
            n += 1
    return n

## One physics tick. `car_pos` / `heading` / `car_vel` describe the car (planar),
## `half_len` / `half_wid` its body half sizes. Touches only the cones; reads the
## car, never writes it.
func step(delta: float, car_pos: Vector2, heading: float, car_vel: Vector2,
        half_len: float, half_wid: float) -> void:
    contact(car_pos,heading,car_vel,half_len,half_wid)
    advance(delta)

func contact(car_pos: Vector2, heading: float, car_vel: Vector2, half_len: float, half_wid: float) -> void:
    var fwd := Vector2(sin(heading),-cos(heading))
    var right := Vector2(cos(heading),sin(heading))
    var near: float = half_len+half_wid+1.0
    var near_sq: float = near*near
    var speed: float = car_vel.length()
    for i in range(positions.size()):
        var dx: Vector2 = positions[i]-car_pos
        if dx.length_squared() > near_sq:
            continue
        var lx: float = dx.dot(fwd)
        var ly: float = dx.dot(right)
        if absf(lx) < half_len+CONE_RADIUS and absf(ly) < half_wid+CONE_RADIUS:
            _hit(i,dx,car_vel,speed)

func advance(delta: float) -> void:
    var done: Array = []
    for key in awake.keys():
        var i2: int = int(key)
        var v: Vector2 = velocities[i2]
        if v.length_squared() > 0.0064:
            positions[i2] += v*delta
            velocities[i2] = v*exp(-SLIDE_DAMP*delta)
        else:
            velocities[i2] = Vector2.ZERO
        if tilt[i2] < PI*0.5 and tilt_vel[i2] > 0.0:
            tilt[i2] = minf(tilt[i2]+tilt_vel[i2]*delta,PI*0.5)
            if tilt[i2] >= PI*0.5:
                tilt_vel[i2] = 0.0
        _write(i2)
        if velocities[i2] == Vector2.ZERO and (tilt_vel[i2] == 0.0):
            done.append(key)
    for k in done:
        awake.erase(k)

## Complete sparse state, including already settled cones for a late joiner.
func network_poses() -> Array:
    var poses := []
    for i in range(homes.size()):
        if tilt[i] > 0.001 or positions[i].distance_squared_to(homes[i]) > 0.0001:
            poses.append({"index":i,"pos":positions[i],"tilt":tilt[i],"angle":fall_dir[i].angle()})
    return poses

func apply_network_poses(poses: Array) -> void:
    var displaced := {}
    for pose in poses:
        var i: int = pose.index
        if i >= homes.size():
            continue
        displaced[i] = true
        positions[i] = pose.pos
        tilt[i] = pose.tilt
        fall_dir[i] = Vector2.from_angle(pose.angle)
        _write(i)
    for i in _network_displaced:
        if not displaced.has(i):
            positions[i] = homes[i]
            tilt[i] = 0.0
            _write(i)
    _network_displaced = displaced

func _hit(i: int, dx: Vector2, car_vel: Vector2, speed: float) -> void:
    var radial: Vector2 = dx.normalized() if dx.length_squared() > 0.0001 else Vector2(0,-1)
    var dir: Vector2 = radial
    if speed > 1.5:
        dir = (car_vel.normalized()*0.65+radial*0.35).normalized()
    var push: float = minf(maxf(speed*0.95,MIN_PUSH)+1.2,MAX_SPEED)
    var along: float = velocities[i].dot(dir)
    if along < push:
        velocities[i] = dir*push
    if tilt[i] < 0.05 and tilt_vel[i] == 0.0:
        fall_dir[i] = dir
        tilt_vel[i] = TIP_SPEED
    if touched[i] == 0:
        touched[i] = 1
        hits_total += 1
        cone_hit.emit(i,speed)
    awake[i] = true

func _write(i: int) -> void:
    if multimesh == null:
        return
    var p: Vector2 = positions[i]
    var basis := Basis.IDENTITY
    var lift: float = 0.0
    if tilt[i] > 0.0:
        var d: Vector2 = fall_dir[i]
        var axis := Vector3(d.y,0.0,-d.x)
        if axis.length_squared() > 0.0001:
            basis = Basis(axis.normalized(),tilt[i])
        lift = 0.22*sin(tilt[i])
    basis = basis.scaled(Vector3.ONE*VISUAL_SCALE)
    multimesh.set_instance_transform(i,Transform3D(basis,Vector3(p.x,0.058+lift*VISUAL_SCALE,p.y)))

# ---------------------------------------------------------------------- mesh

## Low-poly cone with vertex colours: orange body, two white bands, a darker
## square base plate and a light / dark side shading baked into the colours.
func _cone_mesh() -> ArrayMesh:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var orange := Color(1.0,0.42,0.06)
    var white := Color(0.96,0.96,0.94)
    var base := Color(0.62,0.24,0.04)
    # base plate (a flat box, top face + sides)
    var hb: float = 0.23
    var th: float = 0.04
    _box(st,Vector3(-hb,0,-hb),Vector3(hb,th,hb),base)
    # body: stacked rings
    var rings: Array = [[th,0.172,orange],[0.28,0.118,orange],[0.28,0.118,white],[0.38,0.096,white],
        [0.38,0.096,orange],[0.44,0.083,orange],[0.44,0.083,white],[0.54,0.064,white],
        [0.54,0.064,orange],[0.70,0.034,orange]]
    var sides: int = 8
    for k in range(rings.size()-1):
        var a: Array = rings[k]
        var b: Array = rings[k+1]
        if absf(float(a[0])-float(b[0])) < 0.0001:
            continue   # a colour change at the same height
        var col: Color = b[2] if float(a[0]) == float(b[0]) else a[2]
        # the colour of a band is the colour of the ring it starts from, except at a step
        col = a[2]
        for s in range(sides):
            var a0: float = TAU*float(s)/float(sides)
            var a1: float = TAU*float(s+1)/float(sides)
            var p00 := Vector3(cos(a0)*float(a[1]),float(a[0]),sin(a0)*float(a[1]))
            var p01 := Vector3(cos(a1)*float(a[1]),float(a[0]),sin(a1)*float(a[1]))
            var p10 := Vector3(cos(a0)*float(b[1]),float(b[0]),sin(a0)*float(b[1]))
            var p11 := Vector3(cos(a1)*float(b[1]),float(b[0]),sin(a1)*float(b[1]))
            var shade: float = 0.74+0.26*clampf(cos((a0+a1)*0.5+0.6)*0.5+0.5,0.0,1.0)
            var c2: Color = Color(col.r*shade,col.g*shade,col.b*shade,1.0)
            for p in [p00,p01,p10,p01,p11,p10]:
                st.set_color(c2)
                st.set_normal(Vector3.UP)
                st.add_vertex(p)
    # top cap
    for s2 in range(sides):
        var t0: float = TAU*float(s2)/float(sides)
        var t1: float = TAU*float(s2+1)/float(sides)
        for p2 in [Vector3(0,0.70,0),Vector3(cos(t0)*0.034,0.70,sin(t0)*0.034),Vector3(cos(t1)*0.034,0.70,sin(t1)*0.034)]:
            st.set_color(orange)
            st.set_normal(Vector3.UP)
            st.add_vertex(p2)
    return st.commit()

static func _box(st: SurfaceTool, lo: Vector3, hi: Vector3, col: Color) -> void:
    var c: Array = [Vector3(lo.x,lo.y,lo.z),Vector3(hi.x,lo.y,lo.z),Vector3(hi.x,lo.y,hi.z),Vector3(lo.x,lo.y,hi.z),
        Vector3(lo.x,hi.y,lo.z),Vector3(hi.x,hi.y,lo.z),Vector3(hi.x,hi.y,hi.z),Vector3(lo.x,hi.y,hi.z)]
    var faces: Array = [[4,5,6,7,1.0],[0,1,5,4,0.7],[1,2,6,5,0.8],[2,3,7,6,0.7],[3,0,4,7,0.6]]
    for f in faces:
        var shade: float = float(f[4])
        var cc := Color(col.r*shade,col.g*shade,col.b*shade,1.0)
        for idx in [0,1,2,0,2,3]:
            st.set_color(cc)
            st.set_normal(Vector3.UP)
            st.add_vertex(c[int(f[idx])])
