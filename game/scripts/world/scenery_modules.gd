extends RefCounted
class_name NitroSceneryModules
## Procedural world, phase A: hand-authored modules, Japan Drift Town.
## Every piece is modelled here in code (original Nitro Wheelz designs,
## nothing copied): a stand-alone corner garage, row workshop pieces that
## join (left end / middle / right end) under one continuous roof, a
## block-and-mesh fence that runs on across cells, concrete aprons and
## street lamps. Each builder takes the cell's local frame (origin at the
## front-left corner, u along the street, v into the lot) and the module
## parameters from NitroSceneryRules.module_key(); pieces are written into a
## shared accumulator so one chunk is one opaque + one emissive surface.

const SHADOW_SHADER = preload("res://assets/shaders/soft_shadow.gdshader")
const S: float = 14.0

# Japan Drift Town palette (night): walls, roofs, shutters, neon signs.
# Brighter / warmer than "true" colours: the night scene's violet ambient
# would otherwise turn every facade the same dull purple.
const WALLS: Array[Color] = [Color(0.95,0.90,0.78),Color(0.70,0.82,0.92),Color(0.88,0.42,0.32),
    Color(0.48,0.70,0.60),Color(0.97,0.95,0.92)]
const ROOFS: Array[Color] = [Color(0.28,0.32,0.42),Color(0.58,0.20,0.18),Color(0.20,0.36,0.55),
    Color(0.36,0.34,0.32),Color(0.24,0.42,0.34)]
const SHUTTERS: Array[Color] = [Color(0.84,0.86,0.88),Color(0.62,0.70,0.78),Color(0.92,0.86,0.66)]
const NEON: Array[Color] = [Color(1.0,0.20,0.58),Color(0.20,0.92,1.0),Color(1.0,0.72,0.22),
    Color(0.62,1.0,0.32),Color(0.80,0.40,1.0)]
const CONCRETE := Color(0.60,0.60,0.62)
const TRIM := Color(0.14,0.14,0.16)
const LAMP_WARM := Color(1.0,0.84,0.56)
const WINDOW_WARM := Color(1.0,0.72,0.40)

## Geometry accumulator (one chunk): opaque lit + emissive unlit surfaces.
class Acc:
    var pos := PackedVector3Array()
    var nrm := PackedVector3Array()
    var col := PackedColorArray()
    var idx := PackedInt32Array()
    var epos := PackedVector3Array()
    var enrm := PackedVector3Array()
    var ecol := PackedColorArray()
    var eidx := PackedInt32Array()
    var o := Vector2.ZERO          # current frame origin
    var r := Vector2.RIGHT         # u axis
    var b := Vector2.DOWN          # v axis

    func set_frame(fr: Array) -> void:
        o = fr[0]
        r = fr[1]
        b = fr[2]

    func w(u: float, v: float, y: float) -> Vector3:
        var p: Vector2 = o+r*u+b*v
        return Vector3(p.x,y,p.y)

    func quad(a: Vector3, bb: Vector3, c: Vector3, d: Vector3, colour: Color, glow: bool = false) -> void:
        var n: Vector3 = (bb-a).cross(c-a)
        n = n.normalized() if n.length() > 0.0000001 else Vector3.UP
        if glow:
            var base: int = epos.size()
            for p in [a,bb,c,d]:
                epos.append(p)
                enrm.append(n)
                ecol.append(colour)
            eidx.append_array([base,base+2,base+1,base,base+3,base+2])
            return
        var base2: int = pos.size()
        for p in [a,bb,c,d]:
            pos.append(p)
            nrm.append(n)
            col.append(colour)
        # Godot front faces wind clockwise seen from outside.
        idx.append_array([base2,base2+2,base2+1,base2,base2+3,base2+2])

    func tri(a: Vector3, bb: Vector3, c: Vector3, colour: Color) -> void:
        var n: Vector3 = (bb-a).cross(c-a).normalized()
        var base: int = pos.size()
        for p in [a,bb,c]:
            pos.append(p)
            nrm.append(n)
            col.append(colour)
        idx.append_array([base,base+2,base+1])

    ## Box aligned with the cell frame (u0..u1, v0..v1, y0..y1). Faces wind
    ## outward whatever the frame's handedness.
    func box(u0: float, u1: float, v0: float, v1: float, y0: float, y1: float, colour: Color,
            glow: bool = false, top_colour: Color = Color(0,0,0,0)) -> void:
        var c: Array[Vector3] = [w(u0,v0,y0),w(u1,v0,y0),w(u1,v1,y0),w(u0,v1,y0),
            w(u0,v0,y1),w(u1,v0,y1),w(u1,v1,y1),w(u0,v1,y1)]
        var centre: Vector3 = (c[0]+c[6])*0.5
        var faces: Array = [[4,5,6,7],[0,3,2,1],[0,1,5,4],[1,2,6,5],[2,3,7,6],[3,0,4,7]]
        for fi in range(faces.size()):
            if fi == 1:
                continue    # bottom faces are never seen (everything stands on the ground)
            var fc: Array = faces[fi]
            var tint: Color = top_colour if fi == 0 and top_colour.a > 0.0 else colour
            if fi > 1 and not glow:
                tint = tint.darkened(0.06*float(fi%2))
            _face(c[fc[0]],c[fc[1]],c[fc[2]],c[fc[3]],centre,tint,glow)

    func _face(a: Vector3, bb: Vector3, c: Vector3, d: Vector3, centre: Vector3, colour: Color, glow: bool) -> void:
        var n: Vector3 = (bb-a).cross(c-a)
        if n.dot((a+c)*0.5-centre) < 0.0:
            quad(d,c,bb,a,colour,glow)
        else:
            quad(a,bb,c,d,colour,glow)

    ## Closed prism between two parallel polygons (e.g. a gable wall).
    func prism(front: Array[Vector3], back: Array[Vector3], colour: Color) -> void:
        var centre := Vector3.ZERO
        for p in front+back:
            centre += p
        centre /= float(front.size()+back.size())
        var n: int = front.size()
        for k in range(n):
            _face(front[k],front[(k+1)%n],back[(k+1)%n],back[k],centre,colour,false)
        for k in range(1,n-1):
            _tri_out(front[0],front[k],front[k+1],centre,colour)
            _tri_out(back[0],back[k],back[k+1],centre,colour)

    func _tri_out(a: Vector3, bb: Vector3, c: Vector3, centre: Vector3, colour: Color) -> void:
        if (bb-a).cross(c-a).dot((a+bb+c)/3.0-centre) < 0.0:
            tri(a,c,bb,colour)
        else:
            tri(a,bb,c,colour)

    ## Flat polygon at height y (concrete aprons), CCW or CW.
    func floor_poly(poly: PackedVector2Array, y: float, colour: Color) -> void:
        var tris: PackedInt32Array = Geometry2D.triangulate_polygon(poly)
        if tris.is_empty():
            return
        var base: int = pos.size()
        for p in poly:
            pos.append(Vector3(p.x,y,p.y))
            nrm.append(Vector3.UP)
            col.append(colour)
        for k in range(0,tris.size(),3):
            var a3: Vector3 = pos[base+tris[k]]
            var b3: Vector3 = pos[base+tris[k+1]]
            var c3: Vector3 = pos[base+tris[k+2]]
            if (b3-a3).cross(c3-a3).y < 0.0:
                idx.append_array([base+tris[k],base+tris[k+1],base+tris[k+2]])
            else:
                idx.append_array([base+tris[k],base+tris[k+2],base+tris[k+1]])

    func commit(opaque: Material, glow_mat: Material) -> ArrayMesh:
        var mesh := ArrayMesh.new()
        if not idx.is_empty():
            var arr: Array = []
            arr.resize(Mesh.ARRAY_MAX)
            arr[Mesh.ARRAY_VERTEX] = pos
            arr[Mesh.ARRAY_NORMAL] = nrm
            arr[Mesh.ARRAY_COLOR] = col
            arr[Mesh.ARRAY_INDEX] = idx
            mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arr)
            mesh.surface_set_material(mesh.get_surface_count()-1,opaque)
        if not eidx.is_empty():
            var arr2: Array = []
            arr2.resize(Mesh.ARRAY_MAX)
            arr2[Mesh.ARRAY_VERTEX] = epos
            arr2[Mesh.ARRAY_NORMAL] = enrm
            arr2[Mesh.ARRAY_COLOR] = ecol
            arr2[Mesh.ARRAY_INDEX] = eidx
            mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arr2)
            mesh.surface_set_material(mesh.get_surface_count()-1,glow_mat)
        return mesh

static func materials() -> Array:
    var opaque := StandardMaterial3D.new()
    opaque.vertex_color_use_as_albedo = true
    opaque.roughness = 0.78
    # A little self-light keeps facades readable at night (no extra lights).
    opaque.emission_enabled = true
    opaque.emission = Color(0.07,0.065,0.06)
    opaque.cull_mode = BaseMaterial3D.CULL_BACK
    var glow := StandardMaterial3D.new()
    glow.vertex_color_use_as_albedo = true
    glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    return [opaque,glow]

# ================================================================ shutters

static func _shutter(a: Acc, u0: float, u1: float, v: float, h: float, colour: Color, open: bool) -> void:
    # Steel frame + roller box, then either ribbed slats or the dark bay.
    a.box(u0-0.22,u0,v-0.12,v+0.05,0.0,h+0.25,TRIM)
    a.box(u1,u1+0.22,v-0.12,v+0.05,0.0,h+0.25,TRIM)
    a.box(u0-0.22,u1+0.22,v-0.30,v+0.05,h,h+0.42,colour.darkened(0.25))
    if open:
        a.box(u0,u1,v+0.02,v+0.08,0.0,h,Color(0.05,0.05,0.07))
        a.box(u0+0.4,u1-0.4,v+0.06,v+0.10,h*0.55,h*0.62,WINDOW_WARM,true)   # bay strip light
        return
    a.box(u0,u1,v-0.04,v+0.02,0.0,h,colour)
    var y: float = 0.30
    while y < h-0.1:
        a.box(u0,u1,v-0.07,v-0.03,y,y+0.07,colour.darkened(0.22))
        y += 0.42

static func _downpipe(a: Acc, u: float, v: float, h: float) -> void:
    a.box(u-0.08,u+0.08,v-0.08,v+0.08,0.0,h,TRIM)

static func _wall_lamp(a: Acc, u: float, v: float, y: float) -> void:
    a.box(u-0.25,u+0.25,v-0.35,v,y,y+0.18,TRIM)
    a.box(u-0.20,u+0.20,v-0.32,v-0.04,y-0.06,y,LAMP_WARM,true)

## Neon-framed sign panel on a facade (front face at v, facing the road).
static func _sign(a: Acc, u0: float, u1: float, v: float, y0: float, y1: float, neon: Color, seed: int) -> void:
    a.box(u0,u1,v-0.18,v,y0,y1,Color(0.07,0.07,0.09))
    var t: float = 0.07
    a.box(u0,u1,v-0.22,v-0.18,y1-t,y1,neon,true)
    a.box(u0,u1,v-0.22,v-0.18,y0,y0+t,neon,true)
    a.box(u0,u0+t,v-0.22,v-0.18,y0,y1,neon,true)
    a.box(u1-t,u1,v-0.22,v-0.18,y0,y1,neon,true)
    # Abstract glyph blocks (no real text): a few bright bars.
    var n: int = 2+seed%3
    var w: float = (u1-u0-0.6)/float(n)
    for k in range(n):
        var gu: float = u0+0.3+w*float(k)
        var tall: float = 0.35+0.25*float((seed>>k)&1)
        a.box(gu+w*0.18,gu+w*0.82,v-0.24,v-0.20,(y0+y1)*0.5-tall*0.5,(y0+y1)*0.5+tall*0.5,
            neon.lerp(Color.WHITE,0.35),true)

# ============================================================ garage (1x1)

## Stand-alone corner garage: front gable facing the road, roller shutter,
## side door, gable sign, lamp, downpipes, AC unit on the side wall.
static func garage(a: Acc, v0: float, d: float, palette: int, variant: int) -> void:
    var wall: Color = WALLS[palette%WALLS.size()]
    var roof: Color = ROOFS[palette%ROOFS.size()]
    var neon: Color = NEON[(palette+variant)%NEON.size()]
    var u0: float = 0.9
    var u1: float = S-0.9
    var v1: float = v0+d
    var h: float = 4.3
    var ridge: float = h+2.3
    var um: float = (u0+u1)*0.5
    a.box(u0-0.06,u1+0.06,v0-0.06,v1+0.06,0.0,0.32,CONCRETE.darkened(0.15))     # plinth
    a.box(u0,u1,v0,v1,0.0,h,wall)
    # Gable walls front + back, ridge perpendicular to the street.
    for vv in [[v0,v0+0.18],[v1-0.18,v1]]:
        a.prism([a.w(u0,vv[0],h),a.w(u1,vv[0],h),a.w(um,vv[0],ridge)] as Array[Vector3],
            [a.w(u0,vv[1],h),a.w(u1,vv[1],h),a.w(um,vv[1],ridge)] as Array[Vector3],wall)
    # Roof: two slabs with eaves and an overhang, ridge cap.
    var ov: float = 0.5
    var th: float = 0.22
    for side in [[u0-0.45,um],[u1+0.45,um]]:
        var ue: float = side[0]
        var ur: float = side[1]
        var ye: float = h-0.12
        var front: Array[Vector3] = [a.w(ue,v0-ov,ye),a.w(ur,v0-ov,ridge+0.05),a.w(ur,v0-ov,ridge+0.05+th),a.w(ue,v0-ov,ye+th)]
        var back: Array[Vector3] = [a.w(ue,v1+ov,ye),a.w(ur,v1+ov,ridge+0.05),a.w(ur,v1+ov,ridge+0.05+th),a.w(ue,v1+ov,ye+th)]
        a.prism(front,back,roof)
    a.box(um-0.16,um+0.16,v0-ov,v1+ov,ridge+0.12,ridge+0.40,roof.darkened(0.3))
    # Front: shutter left of centre, side door on the right.
    var sw: float = minf(6.2,(u1-u0)-3.6)
    var s0: float = u0+0.9
    _shutter(a,s0,s0+sw,v0,3.3,SHUTTERS[variant%SHUTTERS.size()],variant%4 == 0)
    var du: float = s0+sw+0.9
    a.box(du,du+1.05,v0-0.05,v0+0.02,0.0,2.2,wall.darkened(0.45))
    a.box(du+0.15,du+0.9,v0-0.07,v0-0.03,1.4,1.95,WINDOW_WARM,true)
    _sign(a,um-2.4,um+2.4,v0,h+0.25,h+1.25,neon,variant)
    _wall_lamp(a,s0+sw*0.5,v0,3.95)
    _downpipe(a,u0+0.12,v0-0.12,h)
    _downpipe(a,u1-0.12,v0-0.12,h)
    # Exposed side walls: AC unit right, small lit window left.
    a.box(u1,u1+0.55,v0+d*0.55,v0+d*0.55+1.0,1.0,1.8,Color(0.82,0.83,0.85))
    a.box(u1+0.55,u1+0.58,v0+d*0.55+0.15,v0+d*0.55+0.85,1.1,1.7,TRIM)
    a.box(u0-0.04,u0,v0+d*0.35,v0+d*0.35+1.4,2.2,3.1,WINDOW_WARM,true)

# ==================================================== workshop row (n x 1)

## One cell of a joined workshop row. Ridge runs along the street so the
## roof continues unbroken into the neighbours; outer walls, gable ends,
## downpipes and AC units appear only on exposed sides. The fascia and its
## neon line run through the whole row; a two-cell row carries one long
## sign across both bays (the 2 x 1 workshop).
static func workshop(a: Acc, v0: float, d: float, join_l: bool, join_r: bool, row_len: int,
        row_idx: int, palette: int, variant: int) -> void:
    var wall: Color = WALLS[palette%WALLS.size()]
    var roof: Color = ROOFS[palette%ROOFS.size()]
    var neon: Color = NEON[palette%NEON.size()]
    var u0: float = 0.0 if join_l else 0.9
    var u1: float = S if join_r else S-0.9
    var v1: float = v0+d
    var h: float = 4.6
    var ridge: float = h+1.9
    var vm: float = v0+d*0.5
    a.box(u0-(0.0 if join_l else 0.06),u1+(0.0 if join_r else 0.06),v0-0.06,v1+0.06,0.0,0.32,CONCRETE.darkened(0.15))
    a.box(u0,u1,v0,v1,0.0,h,wall)
    # Roof slabs (front + back) spanning the cell; overhang only at row ends.
    var ue0: float = u0-(0.0 if join_l else 0.45)
    var ue1: float = u1+(0.0 if join_r else 0.45)
    var th: float = 0.22
    for side in [[v0-0.55,vm],[v1+0.55,vm]]:
        var ve: float = side[0]
        var vr: float = side[1]
        var left: Array[Vector3] = [a.w(ue0,ve,h-0.12),a.w(ue0,vr,ridge+0.05),a.w(ue0,vr,ridge+0.05+th),a.w(ue0,ve,h-0.12+th)]
        var right: Array[Vector3] = [a.w(ue1,ve,h-0.12),a.w(ue1,vr,ridge+0.05),a.w(ue1,vr,ridge+0.05+th),a.w(ue1,ve,h-0.12+th)]
        a.prism(left,right,roof)
    a.box(ue0,ue1,vm-0.16,vm+0.16,ridge+0.12,ridge+0.38,roof.darkened(0.3))
    # Gable end walls only where the row ends.
    if not join_l:
        a.prism([a.w(u0,v0,h),a.w(u0,v1,h),a.w(u0,vm,ridge)] as Array[Vector3],
            [a.w(u0+0.18,v0,h),a.w(u0+0.18,v1,h),a.w(u0+0.18,vm,ridge)] as Array[Vector3],wall)
        _downpipe(a,u0+0.12,v0-0.12,h)
        a.box(u0-0.04,u0,v0+d*0.40,v0+d*0.40+1.6,2.1,3.0,WINDOW_WARM,true)
    if not join_r:
        a.prism([a.w(u1,v0,h),a.w(u1,v1,h),a.w(u1,vm,ridge)] as Array[Vector3],
            [a.w(u1-0.18,v0,h),a.w(u1-0.18,v1,h),a.w(u1-0.18,vm,ridge)] as Array[Vector3],wall)
        _downpipe(a,u1-0.12,v0-0.12,h)
        a.box(u1,u1+0.55,v0+d*0.5,v0+d*0.5+1.0,1.0,1.8,Color(0.82,0.83,0.85))
    # Shared pilaster at a joint (drawn once, by the right-hand cell).
    if join_l:
        a.box(-0.22,0.22,v0-0.16,v0+0.02,0.0,h-1.0,wall.darkened(0.18))
    # Continuous fascia band with a neon line through the whole row.
    a.box(ue0,ue1,v0-0.30,v0,h-1.05,h-0.15,Color(0.08,0.08,0.10))
    a.box(ue0,ue1,v0-0.34,v0-0.30,h-1.05,h-0.98,neon,true)
    # Service bay.
    var bay_w: float = 6.4
    var bc: float = S*0.5
    _shutter(a,bc-bay_w*0.5,bc+bay_w*0.5,v0,3.25,SHUTTERS[(palette+variant)%SHUTTERS.size()],variant%3 == 0)
    _wall_lamp(a,bc,v0-0.30,h-1.25)
    if row_len == 2:
        # 2 x 1 workshop: one long roof sign over both bays (left cell).
        if row_idx == 0:
            _roof_sign(a,S-6.0,S+6.0,vm,ridge,neon,palette*7+variant)
    elif row_len > 2 and row_idx%2 == 1:
        _sign(a,bc-2.0,bc+2.0,v0-0.30,h-0.90,h-0.25,neon,variant)
    # Roof vents on middle bays.
    if join_l and join_r:
        a.box(S*0.5-0.6,S*0.5+0.6,vm+1.0,vm+2.2,ridge-0.7,ridge-0.05,Color(0.55,0.57,0.60))

static func _roof_sign(a: Acc, u0: float, u1: float, vm: float, ridge: float, neon: Color, seed: int) -> void:
    a.box(u0+0.4,u0+0.6,vm-0.1,vm+0.1,ridge,ridge+1.3,TRIM)
    a.box(u1-0.6,u1-0.4,vm-0.1,vm+0.1,ridge,ridge+1.3,TRIM)
    _sign(a,u0,u1,vm-0.05,ridge+1.2,ridge+2.6,neon,seed)

# ========================================================= fence and apron

## Block wall with a mesh fence on top. Joined fences share their posts and
## run on with no gap; free ends get a thicker end post.
static func fence(a: Acc, v: float, join_l: bool, join_r: bool) -> void:
    var u0: float = 0.0 if join_l else 0.35
    var u1: float = S if join_r else S-0.35
    a.box(u0,u1,v-0.18,v+0.18,0.0,0.55,CONCRETE,false,CONCRETE.lightened(0.15))
    var post := Color(0.20,0.22,0.24)
    var uu: float = 0.0 if join_l else u0
    while uu < u1-0.01:
        a.box(uu-0.07,uu+0.07,v-0.07,v+0.07,0.55,2.0,post)
        uu += 3.5
    if not join_r:
        a.box(u1-0.12,u1+0.12,v-0.12,v+0.12,0.0,2.15,post)
    if not join_l:
        a.box(u0-0.12,u0+0.12,v-0.12,v+0.12,0.0,2.15,post)
    a.box(u0,u1,v-0.04,v+0.04,1.95,2.03,post)
    a.box(u0,u1,v-0.04,v+0.04,1.25,1.31,post)
    # Mesh infill: one thin panel each side (reads as wire mesh from the
    # race cameras) instead of dozens of bars.
    a.box(u0,u1,v-0.015,v+0.015,0.55,1.95,Color(0.24,0.27,0.30))

## Concrete apron of a lot (v from vp to the back of the cell). Corner masks
## like a dual grid: a corner is rounded where no paved neighbour shares it,
## straight where the next lot continues the slab.
static func apron(a: Acc, vp: float, join_l: bool, join_r: bool) -> void:
    var u0: float = 0.0 if join_l else 0.3
    var u1: float = S if join_r else S-0.3
    var v1: float = S-0.3
    var rad: float = 1.8
    var pts := PackedVector2Array()
    var corners: Array = [[u0,vp,not join_l,Vector2(1,1)],[u1,vp,not join_r,Vector2(-1,1)],
        [u1,v1,not join_r,Vector2(-1,-1)],[u0,v1,not join_l,Vector2(1,-1)]]
    for k in range(4):
        var cn: Array = corners[k]
        var cu: float = cn[0]
        var cv: float = cn[1]
        if not bool(cn[2]):
            var p: Vector2 = a.o+a.r*cu+a.b*cv
            pts.append(p)
            continue
        var inward: Vector2 = cn[3]
        var centre := Vector2(cu,cv)+inward*rad
        var a0: float = atan2(-inward.y,-inward.x)
        for s in range(5):
            var ang: float = a0-PI*0.25+PI*0.5*float(s)/4.0
            var lp: Vector2 = centre+Vector2(cos(ang),sin(ang))*rad
            pts.append(a.o+a.r*lp.x+a.b*lp.y)
    a.floor_poly(pts,0.035,CONCRETE)

## Street lamp: pole, arm over the apron toward the road, warm head.
static func lamp(a: Acc, u: float, v: float) -> void:
    var pole := Color(0.18,0.19,0.21)
    a.box(u-0.11,u+0.11,v-0.11,v+0.11,0.0,6.2,pole)
    a.box(u-0.06,u+0.06,v-1.5,v,6.0,6.12,pole)
    a.box(u-0.24,u+0.24,v-1.75,v-1.25,5.75,6.02,pole)
    a.box(u-0.20,u+0.20,v-1.70,v-1.30,5.68,5.75,LAMP_WARM,true)

# ================================================================== trees

## Voxel cherry blossoms / layered pines (the approved race tree art,
## shared with drift_track) as multimeshes under parent.
static func build_trees(parent: Node3D, trees: Array) -> void:
    var voxel_xf: Array[Transform3D] = []
    var voxel_col: Array[Color] = []
    var cone_xf: Array[Transform3D] = []
    var cone_col: Array[Color] = []
    var trunk_xf: Array[Transform3D] = []
    var shadow_xf: Array[Transform3D] = []
    var shadow_dir := Vector2(0.55,0.75)
    for tree in trees:
        var pos: Vector2 = tree["pos"]
        var radius: float = tree["radius"]
        var h: float = tree["height"]
        var local := RandomNumberGenerator.new()
        local.seed = int(tree["seed"])
        var shadow_len: float = 2.6*h
        var shadow_basis := Basis.from_scale(Vector3(radius*2.5,1.0,radius*2.9))
        shadow_basis = Basis(Vector3.UP,local.randf_range(0.0,TAU))*shadow_basis
        shadow_xf.append(Transform3D(shadow_basis,
            Vector3(pos.x+shadow_dir.x*shadow_len,0.088,pos.y+shadow_dir.y*shadow_len)))
        if bool(tree["cherry"]):
            var trunk_h: float = 2.6*h
            trunk_xf.append(Transform3D(Basis.from_scale(Vector3(0.42,trunk_h,0.42)),
                Vector3(pos.x,trunk_h*0.5,pos.y)))
            # Pixel/voxel blossom canopy (approved reference: pink "pixel"
            # cherry trees). Voxels are snapped to a 0.62 m lattice.
            var vs: float = 0.62
            var centre := Vector3(pos.x,trunk_h+radius*0.55,pos.y)
            var used: Dictionary = {}
            for k in range(int(radius*22.0)):
                var dir := Vector3(local.randf_range(-1,1),local.randf_range(-0.55,1),local.randf_range(-1,1))
                if dir.length() > 1.0:
                    continue
                var p: Vector3 = centre+Vector3(dir.x*radius,dir.y*radius*0.72,dir.z*radius)
                var snapped := Vector3i(int(round(p.x/vs)),int(round(p.y/vs)),int(round(p.z/vs)))
                if used.has(snapped):
                    continue
                used[snapped] = true
                var size: float = vs*local.randf_range(0.92,1.18)
                voxel_xf.append(Transform3D(Basis.from_scale(Vector3.ONE*size),Vector3(snapped)*vs))
                var height_t: float = clampf((p.y-centre.y)/radius*0.8+0.5,0.0,1.0)
                var pink := Color(0.80,0.24,0.50).lerp(Color(1.0,0.60,0.82),height_t)
                pink = pink.lerp(Color(1.0,0.86,0.93),local.randf()*0.22)
                voxel_col.append(pink)
        else:
            var base_h: float = 0.6
            for tier in range(3):
                var s: float = (1.0-float(tier)*0.24)*radius
                cone_xf.append(Transform3D(Basis.from_scale(Vector3(s,h*1.25,s)),
                    Vector3(pos.x,base_h+1.7*h+float(tier)*1.55*h,pos.y)))
                cone_col.append(Color(0.06,0.15,0.11).lerp(Color(0.12,0.24,0.16),float(tier)/2.0))
            trunk_xf.append(Transform3D(Basis.from_scale(Vector3(0.38,base_h+1.2,0.38)),
                Vector3(pos.x,(base_h+1.2)*0.5,pos.y)))
    var foliage := StandardMaterial3D.new()
    foliage.vertex_color_use_as_albedo = true
    foliage.roughness = 0.9
    var voxel := BoxMesh.new()
    voxel.size = Vector3.ONE
    _multimesh(parent,"Cherry blossom voxels",voxel,foliage,voxel_xf,voxel_col)
    var cone := CylinderMesh.new()
    cone.top_radius = 0.04
    cone.bottom_radius = 1.0
    cone.height = 2.6
    cone.radial_segments = 7
    cone.rings = 1
    _multimesh(parent,"Night pines",cone,foliage,cone_xf,cone_col)
    var bark := StandardMaterial3D.new()
    bark.albedo_color = Color(0.20,0.13,0.11)
    var trunk := BoxMesh.new()
    trunk.size = Vector3.ONE
    _multimesh(parent,"Tree trunks",trunk,bark,trunk_xf)
    var shade := ShaderMaterial.new()
    shade.shader = SHADOW_SHADER
    shade.set_shader_parameter("core",Vector2(0.16,0.16))
    shade.set_shader_parameter("softness",0.30)
    shade.set_shader_parameter("corner",0.16)
    shade.set_shader_parameter("opacity",0.50)
    var quad := PlaneMesh.new()
    quad.size = Vector2.ONE
    _multimesh(parent,"Soft tree shadows",quad,shade,shadow_xf)

static func _multimesh(parent: Node3D, label: String, mesh: Mesh, material: Material,
        transforms: Array[Transform3D], colours: Array[Color] = []) -> void:
    if transforms.is_empty():
        return
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.use_colors = not colours.is_empty()
    mm.mesh = mesh
    mm.instance_count = transforms.size()
    for k in range(transforms.size()):
        mm.set_instance_transform(k,transforms[k])
        if mm.use_colors:
            mm.set_instance_color(k,colours[k])
    var node := MultiMeshInstance3D.new()
    node.name = label
    node.multimesh = mm
    node.material_override = material
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(node)
