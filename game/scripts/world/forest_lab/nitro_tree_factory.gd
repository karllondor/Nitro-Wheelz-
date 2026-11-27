extends RefCounted
class_name NitroTreeFactory
## NITRO FOREST LAB (issue #54): eight procedural, faceted, opaque low-poly tree species.
##
## Rebuilt from the owner's prototype ZIP (nitro_tree_factory.gd, SHA-256 908dbd04...): the prototype's conifers were a fair
## start, its broadleaf species (thin trunks with small detached bipyramid "umbrellas") were not, so every crown is now built
## from overlapping faceted LUMPS (icosahedra, flat shaded, lighter on top / darker underneath) on visible branches, the way
## the approved illustration shows them, and the conifers got ragged, drooping, asymmetric tiers.
##
## Contract (what the game and the tests rely on):
##  * ONE surface, ONE material per mesh: opaque, vertex colours = the absolute palette, UV.x = foliage mask (1 foliage /
##    0 wood) so forest_lab_tree.gdshader can sway only the foliage (DEVELOPER > VEGETATION WIND) - a MultiMesh of one
##    species is ONE draw call;
##  * metre scale, root at the origin, +Y up (the game scales instances by roughly 0.7 .. 1.5);
##  * deterministic: the same (species, LOD, season, params) always gives the identical mesh (seed = species + variant);
##    NEAR and FAR share one crown plan, so the silhouette hardly changes at the LOD switch;
##  * budgets (asserted by forest_lab_factory_test): NEAR <= 520 triangles, FAR <= 160 (shrub 200 / 70);
##  * no per-leaf geometry, no alpha, no textures; the season only changes colours, never the geometry.
enum Type { LAYERED_PINE, TALL_FIR, OAK, JAPANESE_MAPLE, SHRUB, BIRCH, SAKURA, ROWAN }
enum LOD { NEAR, FAR }
enum Season { SPRING, SUMMER, AUTUMN_GOLD, AUTUMN_ORANGE, AUTUMN_RED }

const SPECIES_NAMES: Array[String] = ["Pine", "Fir", "Oak", "Japanese maple", "Shrub", "Birch", "Sakura", "Rowan"]
const SEASON_NAMES: Array[String] = ["Spring", "Summer", "Autumn gold", "Autumn orange", "Autumn red"]
## Mesh height in metres at height = 1.0 (the Touge scatter and the Designer scale from this).
const BASE_HEIGHT: Array[float] = [9.5, 12.5, 10.0, 6.6, 1.5, 10.6, 8.6, 8.2]
const NEAR_TRI_BUDGET: int = 520
const FAR_TRI_BUDGET: int = 160
const SHRUB_NEAR_BUDGET: int = 200
const SHRUB_FAR_BUDGET: int = 70
const SHADER_PATH: String = "res://assets/shaders/forest_lab_tree.gdshader"

const BARK_BROWN := Color("5b3d2a")
const BARK_DARK := Color("3d2f29")
const BARK_LIGHT := Color("e2ddc9")
const BARK_GREY := Color("8a8176")
const BIRCH_MARK := Color("34383a")
const BERRY_RED := Color("c2331f")
const PINK_LIGHT := Color("ffd6e6")
const PINK_MID := Color("f58fba")
const PINK_DARK := Color("e0639a")

static var _ico_cache: Dictionary = {}

# ---------------------------------------------------------------------------------------------- public API

static func species_name(tree_type: int) -> String:
    if tree_type < 0 or tree_type >= SPECIES_NAMES.size():
        return "Unknown"
    return SPECIES_NAMES[tree_type]

## Designer / scatter knobs. Every key is optional in make_mesh(); out-of-range values are clamped.
static func default_params(_tree_type: int = 0) -> Dictionary:
    return {"height":1.0,"crown":1.0,"density":1.0,"trunk":1.0,"lean":0.0,"variant":0,
        "blossom":1.0,"saturation":1.0,"brightness":1.0,"tiers":0}

static func clamp_params(p: Dictionary) -> Dictionary:
    var d: Dictionary = default_params()
    for k in d.keys():
        if p.has(k):
            d[k] = p[k]
    d["height"] = clampf(float(d["height"]),0.6,1.6)
    d["crown"] = clampf(float(d["crown"]),0.6,1.6)
    d["density"] = clampf(float(d["density"]),0.5,1.6)
    d["trunk"] = clampf(float(d["trunk"]),0.6,1.8)
    d["lean"] = clampf(float(d["lean"]),0.0,0.18)
    d["variant"] = clampi(int(d["variant"]),0,7)
    d["blossom"] = clampf(float(d["blossom"]),0.0,1.6)
    d["saturation"] = clampf(float(d["saturation"]),0.5,1.5)
    d["brightness"] = clampf(float(d["brightness"]),0.7,1.3)
    d["tiers"] = clampi(int(d["tiers"]),0,12)
    return d

static func params_key(tree_type: int, lod: int, season: int, params: Dictionary) -> String:
    var p: Dictionary = clamp_params(params)
    return "%d|%d|%d|%.3f|%.3f|%.3f|%.3f|%.3f|%d|%.3f|%.3f|%.3f|%d" % [tree_type,lod,season,p["height"],p["crown"],p["density"],
        p["trunk"],p["lean"],p["variant"],p["blossom"],p["saturation"],p["brightness"],p["tiers"]]

static func tri_count(mesh: ArrayMesh) -> int:
    var n: int = 0
    for s in range(mesh.get_surface_count()):
        n += int((mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()/3)
    return n

static func tri_budget(tree_type: int, lod: int) -> int:
    if tree_type == Type.SHRUB:
        return SHRUB_NEAR_BUDGET if lod == LOD.NEAR else SHRUB_FAR_BUDGET
    return NEAR_TRI_BUDGET if lod == LOD.NEAR else FAR_TRI_BUDGET

## The one shared material (opaque, vertex colours, foliage-only sway). `sway` follows DEVELOPER > VEGETATION WIND.
static func make_material(sway: float = 1.0) -> ShaderMaterial:
    var m := ShaderMaterial.new()
    m.shader = load(SHADER_PATH)
    m.set_shader_parameter("sway",sway)
    return m

## Palette of a species in a season: [main, light, dark, accent].
static func palette(tree_type: int, season: int) -> Array[Color]:
    var s: int = clampi(season,0,4)
    match tree_type:
        Type.LAYERED_PINE:
            return [Color("4f7a40"),Color("6f9f55"),Color("33562f"),Color("8fbd68")]
        Type.TALL_FIR:
            return [Color("2d6a47"),Color("3f8e60"),Color("1e4a35"),Color("5aa87c")]
        Type.BIRCH:
            return _pick(s,[[Color("a8bd58"),Color("c6d876"),Color("86a040"),Color("dbe68f")],
                [Color("7ca14b"),Color("9cc260"),Color("5e8639"),Color("b8d778")],
                [Color("e4ca40"),Color("f5e06c"),Color("c9a82c"),Color("fff0a0")],
                [Color("e2a034"),Color("f2c058"),Color("c47c26"),Color("f9d98a")],
                [Color("c65b38"),Color("de7c53"),Color("a8442a"),Color("ee9d70")]])
        Type.OAK:
            return _pick(s,[[Color("87ab43"),Color("a6c85c"),Color("678a30"),Color("c1de7d")],
                [Color("5f8330"),Color("7fa541"),Color("476a24"),Color("9cc65a")],
                [Color("cdad34"),Color("e4c653"),Color("a88a28"),Color("f4dd85")],
                [Color("de7333"),Color("f1944f"),Color("b85a26"),Color("f9b87a")],
                [Color("b83c31"),Color("d5594b"),Color("8f2d26"),Color("e8826f")]])
        Type.SAKURA:
            return _pick(s,[[PINK_MID,PINK_LIGHT,PINK_DARK,Color("fff0f5")],
                [Color("6d9952"),Color("88b668"),Color("55793f"),Color("a4d081")],
                [Color("e3bb47"),Color("f3d46d"),Color("c29a32"),Color("fbe9a0")],
                [Color("e28b3d"),Color("f2a95f"),Color("bd6b2a"),Color("f9c98e")],
                [Color("b6514b"),Color("d06f66"),Color("93403b"),Color("e39a90")]])
        Type.JAPANESE_MAPLE:
            return _pick(s,[[Color("bd343a"),Color("d9585b"),Color("8f2428"),Color("ec8a85")],
                [Color("8a3c39"),Color("a65853"),Color("6c2d2b"),Color("c27d76")],
                [Color("e6ac38"),Color("f6c95e"),Color("c28a24"),Color("fde29a")],
                [Color("eb6c23"),Color("f9964a"),Color("c4501a"),Color("fdb985")],
                [Color("c72f2e"),Color("e5514b"),Color("9e2222"),Color("f38c80")]])
        Type.ROWAN:
            return _pick(s,[[Color("7fa84a"),Color("9dc562"),Color("62883a"),Color("bcdc86")],
                [Color("668c39"),Color("84ac4e"),Color("4e7229"),Color("a3cc6d")],
                [Color("dfb936"),Color("f2d05d"),Color("bc9a2a"),Color("fbe6a0")],
                [Color("eb812a"),Color("faa14f"),Color("c5651e"),Color("fdc58c")],
                [Color("c83b35"),Color("e0594f"),Color("a02c28"),Color("ee8a7c")]])
        _:
            return _pick(s,[[Color("4f8a3b"),Color("6ba653"),Color("3a6a2a"),Color("8bc46e")],
                [Color("4e8539"),Color("6aa150"),Color("3a6a2a"),Color("8abf6c")],
                [Color("c8b43d"),Color("e0cc5e"),Color("a08f2c"),Color("f2e695")],
                [Color("d56c2c"),Color("ea8d4e"),Color("ad5320"),Color("f5b283")],
                [Color("bb3440"),Color("d4535d"),Color("8f2630"),Color("e88890")]])

static func _pick(s: int, table: Array) -> Array[Color]:
    var out: Array[Color] = []
    for c in table[s]:
        out.append(c)
    return out

## make_mesh(type, lod, season, params): the one entry point. Deterministic.
static func make_mesh(tree_type: int, lod: int = LOD.NEAR, season: int = Season.SUMMER, params: Dictionary = {}) -> ArrayMesh:
    var p: Dictionary = clamp_params(params)
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    st.set_smooth_group(-1)
    var near: bool = lod == LOD.NEAR
    var rng := RandomNumberGenerator.new()
    rng.seed = 9137+tree_type*117+int(p["variant"])*7919          # NOT lod: NEAR and FAR share one plan
    var pal: Array[Color] = palette(tree_type,season)
    if float(p["saturation"]) != 1.0 or float(p["brightness"]) != 1.0:
        for i in range(pal.size()):
            pal[i] = _tune(pal[i],float(p["saturation"]),float(p["brightness"]))
    var bark_s: float = float(p["saturation"])
    var bark_v: float = float(p["brightness"])
    var ctx := {"st":st,"rng":rng,"near":near,"pal":pal,"p":p,"season":season,"bs":bark_s,"bv":bark_v}
    match tree_type:
        Type.LAYERED_PINE:
            _conifer(ctx,BASE_HEIGHT[0],3.0,6,9,false)
        Type.TALL_FIR:
            _conifer(ctx,BASE_HEIGHT[1],1.95,9,8,true)
        Type.BIRCH:
            _birch(ctx)
        Type.OAK:
            _oak(ctx)
        Type.SAKURA:
            _sakura(ctx)
        Type.JAPANESE_MAPLE:
            _maple(ctx)
        Type.ROWAN:
            _rowan(ctx)
        _:
            _shrub(ctx)
    st.generate_normals()
    var mesh := ArrayMesh.new()
    st = ctx["st"]
    st.commit(mesh)
    return mesh

static func _tune(c: Color, sat: float, val: float) -> Color:
    return Color.from_hsv(c.h,clampf(c.s*sat,0.0,1.0),clampf(c.v*val,0.0,1.0))

static func _bark(ctx: Dictionary, c: Color) -> Color:
    return _tune(c,float(ctx["bs"]),float(ctx["bv"]))

# ------------------------------------------------------------------------------------------------ primitives

## One triangle, wound so that it faces away from `ref`. Godot's FRONT face is CLOCKWISE seen from outside, i.e.
## (b-a) x (c-a) points INTO the solid; SurfaceTool.generate_normals then yields the outward normal. Back-face culling stays ON.
static func _t(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ref: Vector3, col: Color, mask: float) -> void:
    var n: Vector3 = (b-a).cross(c-a)
    if n.dot((a+b+c)/3.0-ref) > 0.0:
        var tmp: Vector3 = b
        b = c
        c = tmp
    var uv := Vector2(mask,0.0)
    var lin: Color = col                       # the game's convention: vertex / instance colours are authored "raw" (as CLASSIC does)
    st.set_color(lin)
    st.set_uv(uv)
    st.add_vertex(a)
    st.set_color(lin)
    st.set_uv(uv)
    st.add_vertex(b)
    st.set_color(lin)
    st.set_uv(uv)
    st.add_vertex(c)

static func _ico(detail: int) -> Dictionary:
    if _ico_cache.has(detail):
        return _ico_cache[detail]
    var out: Dictionary = {}
    if detail < 0:
        out = {"v":[Vector3(1,0,0),Vector3(-1,0,0),Vector3(0,1,0),Vector3(0,-1,0),Vector3(0,0,1),Vector3(0,0,-1)],
            "f":[[0,2,4],[4,2,1],[1,2,5],[5,2,0],[4,3,0],[1,3,4],[5,3,1],[0,3,5]]}
    else:
        var phi: float = 1.618033988749895
        var vs: Array = [Vector3(-1,phi,0),Vector3(1,phi,0),Vector3(-1,-phi,0),Vector3(1,-phi,0),
            Vector3(0,-1,phi),Vector3(0,1,phi),Vector3(0,-1,-phi),Vector3(0,1,-phi),
            Vector3(phi,0,-1),Vector3(phi,0,1),Vector3(-phi,0,-1),Vector3(-phi,0,1)]
        for i in range(vs.size()):
            vs[i] = (vs[i] as Vector3).normalized()
        var fs: Array = [[0,11,5],[0,5,1],[0,1,7],[0,7,10],[0,10,11],[1,5,9],[5,11,4],[11,10,2],[10,7,6],[7,1,8],
            [3,9,4],[3,4,2],[3,2,6],[3,6,8],[3,8,9],[4,9,5],[2,4,11],[6,2,10],[8,6,7],[9,8,1]]
        if detail >= 1:
            var nf: Array = []
            for f in fs:
                var a: int = f[0]
                var b: int = f[1]
                var c: int = f[2]
                var ab: int = vs.size()
                vs.append(((vs[a] as Vector3)+(vs[b] as Vector3)).normalized())
                var bc: int = vs.size()
                vs.append(((vs[b] as Vector3)+(vs[c] as Vector3)).normalized())
                var ca: int = vs.size()
                vs.append(((vs[c] as Vector3)+(vs[a] as Vector3)).normalized())
                nf.append([a,ab,ca])
                nf.append([b,bc,ab])
                nf.append([c,ca,bc])
                nf.append([ab,bc,ca])
            fs = nf
        out = {"v":vs,"f":fs}
    _ico_cache[detail] = out
    return out

## A faceted lump: lighter on top, darker underneath, a little random facet tone. detail -1 = 8 faces, 0 = 20, 1 = 80.
static func _blob(ctx: Dictionary, centre: Vector3, radii: Vector3, col: Color, detail: int, mask: float = 1.0, jitter: float = 0.17, spin: float = 0.0) -> void:
    var st: SurfaceTool = ctx["st"]
    var rng: RandomNumberGenerator = ctx["rng"]
    var m: Dictionary = _ico(detail)
    var base: Array = m["v"]
    var vs: Array[Vector3] = []
    for v in base:
        var j: float = 1.0+rng.randf_range(-jitter,jitter)
        var q := Vector3((v as Vector3).x*radii.x*j,(v as Vector3).y*radii.y*j,(v as Vector3).z*radii.z*j)
        if spin != 0.0:
            q = q.rotated(Vector3.UP,spin)
        vs.append(centre+q)
    for f in m["f"]:
        var a: Vector3 = vs[f[0]]
        var b: Vector3 = vs[f[1]]
        var c: Vector3 = vs[f[2]]
        var n: Vector3 = (b-a).cross(c-a).normalized()
        if n.dot((a+b+c)/3.0-centre) < 0.0:
            n = -n
        var shade: Color = col
        if n.y >= 0.0:
            shade = col.lerp(col.lightened(0.38),clampf(n.y*1.05,0.0,1.0))
        else:
            shade = col.lerp(col.darkened(0.36),clampf(-n.y*1.1,0.0,1.0))
        var tone: float = rng.randf_range(-0.07,0.10)
        shade = shade.lightened(tone) if tone >= 0.0 else shade.darkened(-tone)
        _t(st,a,b,c,centre,shade,mask)

## Tapered limb (trunk / branch): `sides` faces, light / dark banding, mask 0 (wood).
static func _limb(ctx: Dictionary, base: Vector3, tip: Vector3, r0: float, r1: float, sides: int, col: Color) -> void:
    var st: SurfaceTool = ctx["st"]
    var up: Vector3 = tip-base
    if up.length_squared() < 1.0e-6:
        return
    up = up.normalized()
    var axis: Vector3 = Vector3.UP if absf(up.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
    var right: Vector3 = up.cross(axis).normalized()
    var fwd: Vector3 = up.cross(right).normalized()
    for i in range(sides):
        var a0: float = TAU*float(i)/float(sides)
        var a1: float = TAU*float(i+1)/float(sides)
        var v0: Vector3 = right*cos(a0)+fwd*sin(a0)
        var v1: Vector3 = right*cos(a1)+fwd*sin(a1)
        var shade: Color = col.lightened(0.08) if i%3 == 0 else (col.darkened(0.10) if i%3 == 1 else col.darkened(0.20))
        var mid: Vector3 = (base+tip)*0.5
        _t(st,base+v0*r0,tip+v0*r1,tip+v1*r1,mid,shade,0.0)
        _t(st,base+v0*r0,tip+v1*r1,base+v1*r0,mid,shade,0.0)

## One ragged, drooping conifer tier (the pine / fir building block).
static func _tier(ctx: Dictionary, centre: Vector3, radius: float, height: float, sides: int, col: Color, droop: float) -> void:
    var st: SurfaceTool = ctx["st"]
    var rng: RandomNumberGenerator = ctx["rng"]
    var ring: Array[Vector3] = []
    var phase: float = rng.randf()*TAU
    for i in range(sides):
        var a: float = phase+TAU*float(i)/float(sides)
        var rr: float = radius*(rng.randf_range(0.92,1.10) if i%2 == 0 else rng.randf_range(0.62,0.82))
        ring.append(centre+Vector3(cos(a)*rr,-droop*(rr/radius)+rng.randf_range(-0.12,0.10),sin(a)*rr))
    var apex: Vector3 = centre+Vector3(rng.randf_range(-0.10,0.10)*radius,height,rng.randf_range(-0.10,0.10)*radius)
    var under: Vector3 = centre+Vector3(0,-droop*0.5,0)
    for i in range(sides):
        var j: int = (i+1)%sides
        var top: Color = col.lightened(rng.randf_range(0.05,0.22)) if i%3 == 0 else col.darkened(rng.randf_range(0.0,0.16))
        _t(st,ring[i],apex,ring[j],centre+Vector3(0,-height,0),top,1.0)
        _t(st,ring[i],ring[j],under,apex,col.darkened(0.42),1.0)

# ------------------------------------------------------------------------------------------------- species

## Pine (broad, asymmetric) and fir (tall, narrow, cedar-like): ragged drooping tiers on a visible trunk.
static func _conifer(ctx: Dictionary, h0: float, r0: float, tiers0: int, sides0: int, thin: bool) -> void:
    var rng: RandomNumberGenerator = ctx["rng"]
    var p: Dictionary = ctx["p"]
    var near: bool = ctx["near"]
    var pal: Array[Color] = ctx["pal"]
    var h: float = h0*float(p["height"])
    var rad: float = r0*float(p["crown"])
    var tiers: int = int(p["tiers"])
    if tiers == 0:
        tiers = int(round(float(tiers0)*float(p["density"])))
    tiers = clampi(tiers,3,12)
    var sides: int = sides0 if near else 6
    if not near:
        tiers = maxi(3,int(ceil(float(tiers)*0.55)))
    var trunk_r: float = (0.26 if thin else 0.36)*float(p["trunk"])
    var lean: Vector3 = Vector3(float(p["lean"]),0,float(p["lean"])*0.4)*h*0.35
    var bark: Color = _bark(ctx,BARK_BROWN)
    _limb(ctx,Vector3.ZERO,Vector3(0,h*0.93,0)+lean,trunk_r,0.05,6 if near else 4,bark)
    var lowest: float = h*(0.15 if thin else 0.22)
    var top: float = h*0.90
    for t in range(tiers):
        var f: float = float(t)/float(maxi(tiers-1,1))
        var y: float = lerpf(lowest,top,f)
        var r: float = rad*pow(1.0-f,0.85)*rng.randf_range(0.86,1.14)+rad*0.10
        var th: float = (h/float(tiers))*(1.55 if thin else 1.35)
        var col: Color = pal[0].lerp(pal[1],f*0.55) if t%2 == 0 else pal[0].lerp(pal[2],0.35+f*0.2)
        var off: Vector3 = Vector3(rng.randf_range(-0.16,0.16),0,rng.randf_range(-0.16,0.16))*rad*(0.6 if thin else 1.0)
        _tier(ctx,Vector3(0,y,0)+off+lean*f,r,th,sides,col,0.34*r)
    # a crisp leader on top
    _tier(ctx,Vector3(0,h*0.93,0)+lean,rad*0.11,h*0.07,5 if near else 4,pal[1],0.05)

## Birch: slim white trunk with charcoal bands, thin branches, airy yellow-green crown clumps.
static func _birch(ctx: Dictionary) -> void:
    var rng: RandomNumberGenerator = ctx["rng"]
    var p: Dictionary = ctx["p"]
    var near: bool = ctx["near"]
    var pal: Array[Color] = ctx["pal"]
    var h: float = BASE_HEIGHT[5]*float(p["height"])
    var cw: float = float(p["crown"])
    var lean: float = float(p["lean"])
    var white: Color = _bark(ctx,BARK_LIGHT)
    var mark: Color = _bark(ctx,BIRCH_MARK)
    var tr: float = 0.20*float(p["trunk"])
    # trunk in three gently bending segments
    var pts: Array[Vector3] = [Vector3.ZERO,Vector3(0.10+lean*h*0.3,h*0.30,0.06),Vector3(-0.14,h*0.58,0.10+lean*h*0.2),Vector3(0.06,h*0.84,-0.08)]
    for i in range(pts.size()-1):
        _limb(ctx,pts[i],pts[i+1],tr*lerpf(1.0,0.55,float(i)/3.0),tr*lerpf(1.0,0.55,float(i+1)/3.0),6 if near else 4,white)
    if near:
        for i in range(12):
            var yy: float = 0.5+float(i)*0.46
            var seg: int = clampi(int(yy/(h*0.28)),0,2)
            var f: float = clampf((yy-pts[seg].y)/maxf(pts[seg+1].y-pts[seg].y,0.01),0.0,1.0)
            var c: Vector3 = pts[seg].lerp(pts[seg+1],f)
            var r: float = tr*lerpf(lerpf(1.0,0.55,float(seg)/3.0),lerpf(1.0,0.55,float(seg+1)/3.0),f)+0.02
            var a: float = float(i)*1.13
            var d := Vector3(cos(a),0,sin(a))
            var tg := Vector3(-sin(a),0,cos(a))
            var w: float = rng.randf_range(0.10,0.22)
            var q: Vector3 = c+d*r
            _t(ctx["st"],q-tg*w,q+tg*w+Vector3(0,0.04,0),q+Vector3(0,-0.05,0),c,mark,0.0)
    var n: int = clampi(int(round(9.0*float(p["density"]))),5,14)
    var blobs: Array = []
    for i in range(n):
        var a: float = float(i)*2.399963+rng.randf_range(-0.3,0.3)
        var fy: float = (float(i)+0.5)/float(n)
        var y: float = h*lerpf(0.47,0.97,fy)
        var rr: float = lerpf(1.55,0.35,fy)*cw*rng.randf_range(0.8,1.12)
        blobs.append({"p":Vector3(cos(a)*rr+pts[3].x*fy,y,sin(a)*rr),"r":Vector3(1,1.15,1)*rng.randf_range(1.2,1.6)*cw,"c":(i+1)%3,"ao":0.4+0.6*(1.0-fy)})
        if near and i%2 == 0:
            _limb(ctx,pts[2].lerp(pts[3],fy*0.6),(blobs[i]["p"] as Vector3)-Vector3(0,0.2,0),0.065,0.014,4,_bark(ctx,BARK_GREY))
    _crown(ctx,blobs,pal,1.0)

## Oak: thick short trunk forking into limbs, a broad dome of 12+ overlapping lumps (lighter outside, darker inside).
static func _oak(ctx: Dictionary) -> void:
    var rng: RandomNumberGenerator = ctx["rng"]
    var p: Dictionary = ctx["p"]
    var near: bool = ctx["near"]
    var pal: Array[Color] = ctx["pal"]
    var h: float = BASE_HEIGHT[2]*float(p["height"])
    var cw: float = float(p["crown"])
    var tr: float = 0.52*float(p["trunk"])
    var th: float = h*0.40
    var bark: Color = _bark(ctx,BARK_BROWN)
    var lean := Vector3(float(p["lean"])*h*0.3,0,0)
    _limb(ctx,Vector3.ZERO,Vector3(0,th,0)+lean,tr,tr*0.58,7 if near else 5,bark)
    var cc: Vector3 = Vector3(0,th+h*0.30,0)+lean
    var R: float = 4.3*cw
    var Y: float = h*0.34
    var n: int = clampi(int(round(12.0*float(p["density"]))),7,18)
    var blobs: Array = []
    for i in range(n):
        var a: float = float(i)*2.399963+rng.randf_range(-0.25,0.25)
        var fy: float = (float(i)+0.5)/float(n)
        var ring: float = sqrt(1.0-pow(fy*1.55-0.55,2.0)) if fy*1.55-0.55 < 1.0 else 0.2
        var pos: Vector3 = cc+Vector3(cos(a)*R*ring*rng.randf_range(0.62,0.98),(fy*1.45-0.62)*Y,sin(a)*R*ring*rng.randf_range(0.62,0.98))
        blobs.append({"p":pos,"r":Vector3(1.0,0.82,1.0)*R*rng.randf_range(0.36,0.50),"c":(0 if i%3 == 2 else (1 if i%3 == 0 else 0)),"ao":fy,"big":i == n-1})
        if near and i%3 == 0:
            _limb(ctx,Vector3(0,th*0.86,0)+lean,pos-Vector3(0,pos.y*0.18,0),tr*0.34,0.05,5,bark)
    # a dark inner mass keeps the dome from looking hollow
    blobs.append({"p":cc+Vector3(0,-Y*0.1,0),"r":Vector3(1,0.8,1)*R*0.55,"c":2,"ao":0.25,"big":false})
    _crown(ctx,blobs,pal,1.0)

## Sakura: twisting fork, a wide umbrella of pink lumps (spring) with lighter blossom puffs; green / autumn otherwise.
static func _sakura(ctx: Dictionary) -> void:
    var rng: RandomNumberGenerator = ctx["rng"]
    var p: Dictionary = ctx["p"]
    var near: bool = ctx["near"]
    var pal: Array[Color] = ctx["pal"]
    var spring: bool = int(ctx["season"]) == Season.SPRING
    var h: float = BASE_HEIGHT[6]*float(p["height"])
    var cw: float = float(p["crown"])
    var tr: float = 0.30*float(p["trunk"])
    var bark: Color = _bark(ctx,BARK_DARK)
    var th: float = h*0.36
    var fork: Vector3 = Vector3(0.30+float(p["lean"])*h*0.3,th,0.16)
    _limb(ctx,Vector3.ZERO,fork,tr,tr*0.62,7 if near else 5,bark)
    var R: float = 3.7*cw
    var n: int = clampi(int(round(11.0*float(p["density"]))),6,16)
    var blobs: Array = []
    for i in range(n):
        var a: float = float(i)*2.399963+rng.randf_range(-0.3,0.3)
        var fy: float = (float(i)+0.5)/float(n)
        var rr: float = R*sqrt(fy)*rng.randf_range(0.6,1.0)
        var y: float = lerpf(h*0.66,h*0.93,1.0-fy)+rng.randf_range(-0.25,0.25)
        var pos := Vector3(cos(a)*rr,y,sin(a)*rr)
        blobs.append({"p":pos,"r":Vector3(1.0,0.76,1.0)*rng.randf_range(0.95,1.45)*cw,"c":i%3,"ao":1.0-fy*0.5})
        if near and i%2 == 0:
            _limb(ctx,fork,pos-Vector3(0,0.35,0),0.13,0.025,4,bark)
    _crown(ctx,blobs,pal,1.0)
    if near and spring:
        var puffs: int = int(round(7.0*float(p["blossom"])))
        for i in range(puffs):
            var a2: float = float(i)*2.399963+0.7
            var rr2: float = R*rng.randf_range(0.30,0.85)
            var q := Vector3(cos(a2)*rr2,h*rng.randf_range(0.86,1.0),sin(a2)*rr2)
            _blob(ctx,q,Vector3(0.62,0.42,0.62)*cw,PINK_LIGHT.lerp(pal[3],0.35),0,1.0,0.18)

## Japanese maple: short multi-stem trunk, LAYERED flat crown of red / orange lumps with lighter rims.
static func _maple(ctx: Dictionary) -> void:
    var rng: RandomNumberGenerator = ctx["rng"]
    var p: Dictionary = ctx["p"]
    var near: bool = ctx["near"]
    var pal: Array[Color] = ctx["pal"]
    var h: float = BASE_HEIGHT[3]*float(p["height"])
    var cw: float = float(p["crown"])
    var tr: float = 0.22*float(p["trunk"])
    var bark: Color = _bark(ctx,BARK_DARK)
    var stems: int = 3
    var tops: Array[Vector3] = []
    var fork := Vector3(0,h*0.20,0)
    _limb(ctx,Vector3.ZERO,fork,tr*1.25,tr*0.95,6 if near else 4,bark)       # one short common trunk, then the fork
    for s in range(stems):
        var a: float = TAU*float(s)/float(stems)+rng.randf_range(-0.3,0.3)
        var top := Vector3(cos(a)*0.62,h*rng.randf_range(0.40,0.48),sin(a)*0.62)
        tops.append(top)
        _limb(ctx,fork,top,tr*0.85,tr*0.5,6 if near else 4,bark)
    var layers: int = 3
    var per: int = clampi(int(round(4.0*float(p["density"]))),3,6)
    var blobs: Array = []
    for l in range(layers):
        var fl: float = float(l)/float(layers-1)
        var y: float = lerpf(h*0.52,h*0.88,fl)
        var rl: float = lerpf(2.3,1.05,fl)*cw
        for i in range(per if l < layers-1 else 2):
            var a2: float = TAU*float(i)/float(per)+float(l)*0.9+rng.randf_range(-0.25,0.25)
            var rr: float = rl*(rng.randf_range(0.62,0.95) if l < layers-1 else 0.25)
            var pos := Vector3(cos(a2)*rr,y+rng.randf_range(-0.12,0.12),sin(a2)*rr)
            blobs.append({"p":pos,"r":Vector3(1.0,0.52,1.0)*rng.randf_range(1.05,1.40)*cw,"c":(i+l)%3,"ao":fl})
            if near and l == 0 and i%2 == 0:
                _limb(ctx,tops[i%stems],pos-Vector3(0,0.1,0),0.11,0.03,4,bark)
    _crown(ctx,blobs,pal,1.0)

## Rowan: slender grey trunk, a compact light-green crown and clusters of RED berries (small shared 8-face lumps).
static func _rowan(ctx: Dictionary) -> void:
    var rng: RandomNumberGenerator = ctx["rng"]
    var p: Dictionary = ctx["p"]
    var near: bool = ctx["near"]
    var pal: Array[Color] = ctx["pal"]
    var h: float = BASE_HEIGHT[7]*float(p["height"])
    var cw: float = float(p["crown"])
    var tr: float = 0.22*float(p["trunk"])
    var bark: Color = _bark(ctx,BARK_GREY)
    var th: float = h*0.50
    _limb(ctx,Vector3.ZERO,Vector3(0.10+float(p["lean"])*h*0.3,th,0.05),tr,tr*0.45,6 if near else 4,bark)
    var n: int = clampi(int(round(8.0*float(p["density"]))),5,12)
    var blobs: Array = []
    for i in range(n):
        var a: float = float(i)*2.399963+rng.randf_range(-0.3,0.3)
        var fy: float = (float(i)+0.5)/float(n)
        var rr: float = lerpf(1.45,0.3,fy)*cw*rng.randf_range(0.8,1.1)
        var pos := Vector3(cos(a)*rr,h*lerpf(0.60,0.97,fy),sin(a)*rr)
        blobs.append({"p":pos,"r":Vector3(1.0,0.88,1.0)*rng.randf_range(1.2,1.55)*cw,"c":i%3,"ao":1.0-fy})
        if near and i%2 == 0:
            _limb(ctx,Vector3(0,th*0.9,0),pos-Vector3(0,0.2,0),0.075,0.016,4,bark)
    _crown(ctx,blobs,pal,1.0)
    var berries: Color = _tune(BERRY_RED,float(p["saturation"]),float(p["brightness"]))
    var clusters: int = int(round((6.0 if near else 3.0)*float(p["blossom"])))
    for i in range(clusters):
        var b: Dictionary = blobs[(i*2)%blobs.size()]
        var bp: Vector3 = b["p"]
        var a: float = float(i)*2.1+0.6
        var rb: Vector3 = b["r"]
        var base_p: Vector3 = bp+Vector3(cos(a)*rb.x*0.78,-rb.y*0.62,sin(a)*rb.z*0.78)
        for j in range(3 if near else 1):
            var q: Vector3 = base_p+Vector3((float(j)-1.0)*0.26,-0.11*float(j%2),(float(j)-1.0)*0.16)
            _blob(ctx,q,Vector3(0.27,0.27,0.27),berries,-1,1.0,0.12)

## Shrub: a cushion of 4-5 low lumps, optional pink flowers (spring) / red berries (autumn red).
static func _shrub(ctx: Dictionary) -> void:
    var rng: RandomNumberGenerator = ctx["rng"]
    var p: Dictionary = ctx["p"]
    var near: bool = ctx["near"]
    var pal: Array[Color] = ctx["pal"]
    var season: int = int(ctx["season"])
    var s: float = BASE_HEIGHT[4]/1.5*float(p["height"])
    var cw: float = float(p["crown"])
    var n: int = clampi(int(round(5.0*float(p["density"]))),3,7)
    var blobs: Array = []
    for i in range(n):
        var a: float = TAU*float(i)/float(n)+rng.randf_range(-0.3,0.3)
        var rr: float = 0.5*cw*s*rng.randf_range(0.6,1.1)
        blobs.append({"p":Vector3(cos(a)*rr,0.52*s+rng.randf_range(-0.06,0.1),sin(a)*rr),"r":Vector3(1.0,0.78,1.0)*rng.randf_range(0.62,0.86)*cw*s,"c":i%3,"ao":0.5})
    blobs.append({"p":Vector3(0,0.78*s,0),"r":Vector3(1.0,0.72,1.0)*0.60*cw*s,"c":0,"ao":1.0})
    _crown(ctx,blobs,pal,1.0)
    if not near:
        return
    var dots: Color
    var count: int = 0
    if season == Season.SPRING:
        dots = PINK_MID.lerp(PINK_LIGHT,0.3)
        count = int(round(10.0*float(p["blossom"])))
    elif season == Season.AUTUMN_RED:
        dots = _tune(BERRY_RED,float(p["saturation"]),float(p["brightness"]))
        count = int(round(8.0*float(p["blossom"])))
    for i in range(count):
        var a2: float = float(i)*2.399963
        var rr2: float = rng.randf_range(0.3,0.95)*cw*s
        _blob(ctx,Vector3(cos(a2)*rr2,rng.randf_range(0.7,1.15)*s,sin(a2)*rr2),Vector3(0.12,0.11,0.12)*s*1.4,dots,-1,1.0,0.15)

## Shared crown builder: NEAR = 20-face lumps (80 for a `big` one), FAR = every other lump, 1.25x bigger, 8 faces.
## Lower lumps are darker (ambient occlusion), `c` picks main / light / dark so the crown reads as layered.
static func _crown(ctx: Dictionary, blobs: Array, pal: Array[Color], _mask: float) -> void:
    var near: bool = ctx["near"]
    var rng: RandomNumberGenerator = ctx["rng"]
    var idx: int = 0
    for b in blobs:
        idx += 1
        if not near and blobs.size() > 6 and idx%2 == 0:
            continue
        var col: Color = pal[0] if int(b["c"]) == 0 else (pal[1] if int(b["c"]) == 1 else pal[2].lerp(pal[0],0.45))
        col = col.darkened(clampf((1.0-float(b["ao"]))*0.28,0.0,0.3))
        var r: Vector3 = b["r"]
        var detail: int = -1
        if near:
            detail = 1 if bool(b.get("big",false)) else 0
        else:
            r *= 1.22
        _blob(ctx,b["p"],r,col,detail,1.0,0.17,rng.randf()*TAU)
