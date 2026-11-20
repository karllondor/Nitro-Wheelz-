extends RefCounted
class_name NitroTerrainField
## Deterministic terrain of one archetype + seed (terrain-first builder).
##
## raw_height(x, z) is an analytic recipe (FastNoiseLite layers with seeds
## derived from the terrain seed + archetype, and a macro shape per relief),
## baked into an 8 m grid over the detailed area. The play area (the 12 x 16
## builder tiles of 56 m) is shaped so that a full-width road fits on many
## tiles; dramatic relief (peaks, canyon walls, sea cliffs) sits around it or
## crosses it as a feature the road can follow. `height` = `base` + the
## local road deformation written by NitroTerrainWorld (only near the road).
const CAT = preload("res://scripts/world/terrain/terrain_catalog.gd")

const STEP: float = 8.0
const HALF_X: float = 560.0          # detailed terrain half extent
const HALF_Z: float = 672.0
const COLS: int = 12                 # builder grid (tiles of 56 m)
const ROWS: int = 16
const CELL_M: float = 56.0
const PLAY_HALF_X: float = COLS*CELL_M*0.5
const PLAY_HALF_Z: float = ROWS*CELL_M*0.5
const SEA_LEVEL: float = 0.0
const VERSION: int = 1

var archetype: String = "jp_sakura"
var terrain_seed: int = 1
var info: Dictionary = {}
var relief: String = "rolling"
var nx: int = 0
var nz: int = 0
var base: PackedFloat32Array = PackedFloat32Array()
var height: PackedFloat32Array = PackedFloat32Array()
var rock: PackedFloat32Array = PackedFloat32Array()
var forest: PackedFloat32Array = PackedFloat32Array()
var tint: PackedFloat32Array = PackedFloat32Array()
var snow: PackedFloat32Array = PackedFloat32Array()
var water: PackedByteArray = PackedByteArray()
var _noise: Array[FastNoiseLite] = []
var _phase: float = 0.0
# v0.1.27 per-seed macro composition: mirrored layout (sea side, slope
# direction, harbour side...), main-form parameters and large features.
var mx: float = 1.0
var mz: float = 1.0
var macro: Dictionary = {}
var features: Array = []          # [lx, lz, sigma, amplitude]
var bake_ms: float = 0.0

func _init(arch: String = "jp_sakura", seed_value: int = 1) -> void:
    archetype = CAT.valid(arch)
    terrain_seed = seed_value
    info = CAT.info(archetype)
    relief = str(info["relief"])
    _setup_noise()
    bake()

static func hash_seed(a: int, b: String, c: int) -> int:
    var h: int = (a*73856093) ^ (hash(b)*19349663) ^ (c*83492791)
    return absi(h) % 2147483000

func _setup_noise() -> void:
    # (frequency, octaves) per layer; layer seeds derive from the terrain seed.
    var layers: Array = [[1.0/320.0,3],[1.0/130.0,2],[1.0/260.0,3],[1.0/520.0,4],[1.0/90.0,2],[1.0/40.0,1]]
    match relief:
        "terraced":
            layers = [[1.0/420.0,3],[1.0/200.0,2],[1.0/350.0,3],[1.0/520.0,4],[1.0/90.0,2],[1.0/40.0,1]]
        "mountainside":
            layers = [[1.0/240.0,3],[1.0/320.0,3],[1.0/180.0,2],[1.0/520.0,4],[1.0/90.0,2],[1.0/40.0,1]]
        "alpine":
            layers = [[1.0/260.0,3],[1.0/90.0,2],[1.0/170.0,3],[1.0/480.0,5],[1.0/60.0,2],[1.0/40.0,1]]
        "canyon":
            layers = [[1.0/200.0,2],[1.0/150.0,3],[1.0/70.0,2],[1.0/600.0,4],[1.0/110.0,2],[1.0/40.0,1]]
        "coast":
            layers = [[1.0/280.0,3],[1.0/110.0,2],[1.0/150.0,2],[1.0/520.0,4],[1.0/90.0,2],[1.0/40.0,1]]
    _noise.clear()
    for k in range(layers.size()):
        var n := FastNoiseLite.new()
        n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
        n.fractal_type = FastNoiseLite.FRACTAL_FBM
        n.fractal_octaves = int(layers[k][1])
        n.frequency = float(layers[k][0])
        n.seed = hash_seed(terrain_seed,archetype,k)
        _noise.append(n)
    _phase = float(hash_seed(terrain_seed,archetype,99) % 6283)/1000.0
    var rng := RandomNumberGenerator.new()
    rng.seed = hash_seed(terrain_seed,archetype,7777)
    mx = 1.0 if rng.randf() < 0.5 else -1.0
    mz = 1.0 if rng.randf() < 0.5 else -1.0
    macro = {
        "canyon_amp":rng.randf_range(0.16,0.36),"canyon_freq":rng.randf_range(1.3,2.5),
        "canyon_width":rng.randf_range(0.36,0.48),
        "coast_base":rng.randf_range(-0.60,-0.40),"bay_amp":rng.randf_range(50.0,105.0),
        "bay_len":rng.randf_range(170.0,300.0),"cliff_h":rng.randf_range(54.0,70.0),
        "alpine_rim":rng.randf_range(0.78,1.12),"alpine_tilt":rng.randf_range(0.045,0.080),
        "crag":rng.randf_range(0.74,0.84),
        "touge_tilt":rng.randf_range(0.12,0.18),"touge_ridge":rng.randf_range(16.0,30.0),
        "terrace":rng.randf_range(6.0,9.0),
    }
    features.clear()
    var count: int = rng.randi_range(2,4)
    var amp_max: float = {"rolling":20.0,"terraced":18.0,"mountainside":16.0,"urban":3.0,"canyon":8.0,
        "alpine":22.0,"coast":12.0,"hills":30.0}.get(relief,10.0)
    for k in range(count):
        var lx: float = rng.randf_range(-1.05,1.05)*PLAY_HALF_X
        var lz: float = rng.randf_range(-1.05,1.05)*PLAY_HALF_Z
        var amp: float = rng.randf_range(0.45,1.0)*amp_max*(1.0 if rng.randf() < 0.7 else -0.7)
        features.append([lx,lz,rng.randf_range(110.0,230.0),amp])

## World <-> local macro frame (mirrors only, so distances are preserved).
func to_local(x: float, z: float) -> Vector2:
    return Vector2(x*mx,z*mz)

func to_world(lx: float, lz: float) -> Vector2:
    return Vector2(lx*mx,lz*mz)

func _features(lx: float, lz: float) -> float:
    var h: float = 0.0
    for f in features:
        var dx: float = lx-float(f[0])
        var dz: float = lz-float(f[1])
        var s2: float = float(f[2])*float(f[2])
        h += float(f[3])*exp(-(dx*dx+dz*dz)/(2.0*s2))
    return h

func _n(k: int, x: float, z: float) -> float:
    return _noise[k].get_noise_2d(x,z)

func _ridged(k: int, x: float, z: float) -> float:
    return 1.0-absf(_noise[k].get_noise_2d(x,z))

static func _edge(u: float, v: float) -> float:
    # Rounded-rectangle norm of the play area: 1 on its border.
    return pow(pow(absf(u),4.0)+pow(absf(v),4.0),0.25)

## Coast archetype: x of the sea cliff line at z (sea is west of it).
## (LOCAL frame: lz in, local x out; use coast_point() for world space.)
func coast_x(z: float) -> float:
    # Bays and headlands at the 200-400 m scale (a road can follow the
    # cliff); the rock face mesh adds the small-scale jaggedness.
    var base: float = float(macro.get("coast_base",-0.50))
    var amp: float = float(macro.get("bay_amp",75.0))
    var ln: float = float(macro.get("bay_len",230.0))
    return PLAY_HALF_X*base+amp*sin(z/ln+_phase)+26.0*_n(2,0.0,z*0.30)

## World position of the cliff edge for a local z (coast archetype).
func coast_point(lz: float, offset_land: float = 0.0) -> Vector2:
    return to_world(coast_x(lz)+offset_land,lz)

## Ojcow: canyon centre (u units) at v.
func canyon_u(v: float) -> float:
    return float(macro.get("canyon_amp",0.30))*sin(v*float(macro.get("canyon_freq",1.9))+_phase)

## Local x of the stream at local z.
func stream_x(lz: float) -> float:
    var v: float = lz/PLAY_HALF_Z
    return (canyon_u(v)+0.05*sin(v*7.0+_phase*2.0))*PLAY_HALF_X

func stream_offset(x: float, z: float) -> float:
    # Signed distance (m, approx.) from the Pradnik-like stream on the valley floor.
    var l: Vector2 = to_local(x,z)
    return l.x-stream_x(l.y)

func raw_height(wx: float, wz: float) -> float:
    # Macro forms in the seed's mirrored local frame; noise in world space.
    var l: Vector2 = to_local(wx,wz)
    return _raw_local(l.x,l.y)+_features(l.x,l.y)*_feature_mask(l.x,l.y)

func _feature_mask(lx: float, lz: float) -> float:
    # Large features never fill the sea or the canyon floor.
    if relief == "coast" and lx < coast_x(lz)+30.0:
        return 0.0
    return 1.0

func _raw_local(x: float, z: float) -> float:
    var u: float = x/PLAY_HALF_X
    var v: float = z/PLAY_HALF_Z
    var e: float = _edge(u,v)
    var h: float = 0.0
    match relief:
        "rolling":
            h = 12.0+8.0*_n(0,x,z)+3.5*_n(1,x,z)
            h += smoothstep(0.95,1.9,e)*(70.0+70.0*(_n(3,x,z)*0.5+0.5))
        "terraced":
            h = 30.0+24.0*_n(0,x,z)+10.0*_n(1,x,z)+18.0*_ridged(2,x,z)
            var step: float = float(macro.get("terrace",7.0))
            var t: float = h/step
            var f: float = floor(t)
            h = (f+smoothstep(0.30,0.70,t-f))*step
            h += smoothstep(0.95,1.9,e)*(110.0+80.0*(_n(3,x,z)*0.5+0.5))
        "mountainside":
            h = 24.0+float(macro.get("touge_tilt",0.15))*(PLAY_HALF_Z-z)+16.0*_n(0,x,z) \
                +float(macro.get("touge_ridge",24.0))*_ridged(1,x,z)-12.0
            h += smoothstep(1.0,1.9,-v)*(240.0+120.0*_ridged(3,x,z))
            h += smoothstep(1.0,1.8,absf(u))*(120.0+80.0*_ridged(3,x,z))
            h -= smoothstep(1.0,1.6,v)*30.0
        "urban":
            h = 5.0+1.4*_n(0,x,z)
            h = lerpf(h,-6.0,smoothstep(1.12,1.18,v))
            h += smoothstep(1.2,2.2,-v)*(45.0+35.0*_ridged(3,x,z))
        "canyon":
            var uu: float = u-canyon_u(v)
            var d: float = absf(uu)
            var floor_h: float = 18.0+3.0*_n(0,x,z)
            var wall: float = smoothstep(float(macro.get("canyon_width",0.40)),0.98,d)
            h = floor_h+90.0*pow(wall,1.3)+14.0*_n(1,x,z)*wall
            h += 16.0*maxf(0.0,_ridged(2,x,z)-0.55)/0.45*smoothstep(0.15,0.55,wall)*(1.0-smoothstep(0.85,1.0,wall))
            var s: float = absf(stream_offset(x,z))
            h -= 2.2*(1.0-smoothstep(3.0,11.0,s))
        "alpine":
            h = 60.0+float(macro.get("alpine_tilt",0.065))*(PLAY_HALF_Z-z)+11.0*_n(0,x,z)+4.0*_n(1,x,z)
            var crag: float = _ridged(2,x,z)
            var ct: float = float(macro.get("crag",0.78))
            h += 26.0*maxf(0.0,crag-ct)/(1.0-ct)
            h += smoothstep(0.95,2.0,e)*(380.0*float(macro.get("alpine_rim",1.0))*(0.55+0.45*_ridged(3,x,z)))
        "coast":
            # v0.1.27: taller cliffs (54-70 m by seed), a headland rise
            # towards the edge, the sea floor dropping away offshore.
            var cx: float = coast_x(z)
            var dl: float = x-cx
            var land: float = float(macro.get("cliff_h",58.0))+8.0*_n(0,x,z)+4.0*_n(1,x,z)
            land += 6.0*(1.0-smoothstep(0.0,90.0,dl))
            land += smoothstep(1.0,1.9,maxf(u,absf(v)))*(60.0+40.0*_ridged(3,x,z))
            h = land if dl >= 0.0 else -7.0-6.0*smoothstep(0.0,260.0,-dl)+2.0*_n(4,x,z)
        "hills":
            h = 22.0+16.0*_n(0,x,z)+7.0*_n(1,x,z)
            h += 6.0*maxf(0.0,_ridged(2,x,z)-0.62)/0.38
            h += smoothstep(1.0,1.9,absf(v))*(40.0+40.0*_ridged(3,x,z))
            h = lerpf(h,-6.0,smoothstep(1.30,1.46,u))
        _:
            h = 10.0
    return h

func bake() -> void:
    var t0: int = Time.get_ticks_usec()
    nx = int(round(HALF_X*2.0/STEP))+1
    nz = int(round(HALF_Z*2.0/STEP))+1
    var n: int = nx*nz
    base.resize(n)
    rock.resize(n)
    forest.resize(n)
    tint.resize(n)
    snow.resize(n)
    water.resize(n)
    for j in range(nz):
        var z: float = -HALF_Z+float(j)*STEP
        for i in range(nx):
            base[j*nx+i] = raw_height(-HALF_X+float(i)*STEP,z)
    height = base.duplicate()
    for j in range(nz):
        var z2: float = -HALF_Z+float(j)*STEP
        for i in range(nx):
            var x2: float = -HALF_X+float(i)*STEP
            var k: int = j*nx+i
            _masks(k,i,j,x2,z2)
    bake_ms = float(Time.get_ticks_usec()-t0)/1000.0

func _masks(k: int, i: int, j: int, x: float, z: float) -> void:
    var h: float = base[k]
    var slope: float = _grid_slope(base,i,j)
    var u: float = x/PLAY_HALF_X
    var v: float = z/PLAY_HALF_Z
    var e: float = _edge(u,v)
    var wet: bool = false
    if bool(info["sea"]) and h < SEA_LEVEL+0.4:
        wet = true
    if relief == "canyon" and absf(stream_offset(x,z)) < 4.0:
        wet = true
    water[k] = 1 if wet else 0
    var r: float = smoothstep(0.55,1.1,slope)
    match str(info["rock_kind"]):
        "limestone":
            r = maxf(r,smoothstep(0.42,0.8,slope)*smoothstep(0.2,0.6,_ridged(2,x,z)))
        "granite":
            r = maxf(r,smoothstep(0.55,0.95,slope))
            if relief == "alpine":
                r = maxf(r,smoothstep(0.86,0.94,_ridged(2,x,z))*0.85)
        "basalt":
            r = maxf(r,smoothstep(0.6,1.2,slope))
        "none":
            r = 0.0
    rock[k] = clampf(r,0.0,1.0)
    var dens: float = float(info["forest"])*(0.55+0.45*_n(4,x,z))
    dens *= 0.35+0.65*smoothstep(0.65,1.15,e)          # clearings inside the play area
    dens *= 1.0-smoothstep(0.7,1.1,slope)
    if relief == "alpine":
        dens *= 1.0-smoothstep(170.0,260.0,h)           # tree line
    if wet:
        dens = 0.0
    forest[k] = clampf(dens,0.0,1.0)
    var t: float = 0.0
    match str(info["tint_mask"]):
        "petals":
            t = smoothstep(0.1,0.6,_n(4,x+300.0,z))*0.8
        "leaves":
            t = clampf(dens*1.4,0.0,1.0)*(0.6+0.4*_n(5,x,z))
        "heather":
            t = smoothstep(0.0,0.5,_n(4,x,z+200.0))
        "fields":
            var fx: int = int(floor((x+_n(5,x,z)*14.0)/70.0))
            var fz: int = int(floor((z+_n(5,z,x)*14.0)/52.0))
            t = float(posmod(fx*7+fz*13+terrain_seed,5))/4.0
        "parks":
            t = smoothstep(0.55,0.8,_n(4,x,z))
    tint[k] = clampf(t,0.0,1.0)
    var s: float = 0.0
    if relief == "alpine":
        s = smoothstep(300.0+30.0*_n(5,x,z),360.0,h)*(1.0-smoothstep(0.9,1.4,slope)*0.6)
    elif relief == "mountainside" or relief == "terraced":
        s = smoothstep(330.0,380.0,h)*0.6
    snow[k] = clampf(s,0.0,1.0)

func _grid_slope(arr: PackedFloat32Array, i: int, j: int) -> float:
    var i0: int = maxi(i-1,0)
    var i1: int = mini(i+1,nx-1)
    var j0: int = maxi(j-1,0)
    var j1: int = mini(j+1,nz-1)
    var dx: float = (arr[j*nx+i1]-arr[j*nx+i0])/(float(i1-i0)*STEP)
    var dz: float = (arr[j1*nx+i]-arr[j0*nx+i])/(float(j1-j0)*STEP)
    return sqrt(dx*dx+dz*dz)

# ------------------------------------------------------------- sampling

func inside(x: float, z: float) -> bool:
    return absf(x) <= HALF_X and absf(z) <= HALF_Z

func _bilinear(arr: PackedFloat32Array, x: float, z: float) -> float:
    var fx: float = clampf((x+HALF_X)/STEP,0.0,float(nx-1)-0.0001)
    var fz: float = clampf((z+HALF_Z)/STEP,0.0,float(nz-1)-0.0001)
    var i: int = int(fx)
    var j: int = int(fz)
    var tx: float = fx-float(i)
    var tz: float = fz-float(j)
    var a: float = arr[j*nx+i]
    var b: float = arr[j*nx+i+1]
    var c: float = arr[(j+1)*nx+i]
    var d: float = arr[(j+1)*nx+i+1]
    return lerpf(lerpf(a,b,tx),lerpf(c,d,tx),tz)

## Current ground height (with road cut/fill) — what the player sees.
func height_at(x: float, z: float) -> float:
    if not inside(x,z):
        return raw_height(x,z)
    return _bilinear(height,x,z)

## Generated ground height before any road deformation.
func base_at(x: float, z: float) -> float:
    if not inside(x,z):
        return raw_height(x,z)
    return _bilinear(base,x,z)

func mask_at(arr: PackedFloat32Array, x: float, z: float) -> float:
    if not inside(x,z):
        return 0.0
    return _bilinear(arr,x,z)

func is_water(x: float, z: float) -> bool:
    if bool(info["sea"]) and base_at(x,z) < SEA_LEVEL+0.4:
        return true
    if relief == "canyon" and absf(stream_offset(x,z)) < 4.0:
        return true
    return false

func slope_at(x: float, z: float) -> float:
    var dx: float = (base_at(x+STEP,z)-base_at(x-STEP,z))/(2.0*STEP)
    var dz: float = (base_at(x,z+STEP)-base_at(x,z-STEP))/(2.0*STEP)
    return sqrt(dx*dx+dz*dz)

## Signed horizontal distance to the sea cliff (coast only; + = land).
func coast_distance(x: float, z: float) -> float:
    if relief != "coast":
        return INF
    var l: Vector2 = to_local(x,z)
    return l.x-coast_x(l.y)

# ------------------------------------------------------------ city grid

## v0.1.27 Japan City street grid (deterministic per seed; shared by the
## ground shader, which paints the streets, and the scenery, which fills
## the blocks). Grid frame: U = (cos a, sin a), V = (-sin a, cos a); street
## lines every pitch along each axis; every n-th line is an avenue.
var _city: Dictionary = {}
func city_grid() -> Dictionary:
    if not _city.is_empty():
        return _city
    var rng := RandomNumberGenerator.new()
    rng.seed = hash_seed(terrain_seed,archetype,4411)
    var ang: float = rng.randf_range(-0.38,0.38)
    var pu: float = snappedf(rng.randf_range(66.0,84.0),3.0)
    var pv: float = snappedf(rng.randf_range(60.0,78.0),3.0)
    var every: int = rng.randi_range(3,4)
    _city = {"angle":ang,"u":Vector2(cos(ang),sin(ang)),"v":Vector2(-sin(ang),cos(ang)),
        "pitch":Vector2(pu,pv),"off":Vector2(rng.randf_range(0.0,pu),rng.randf_range(0.0,pv)),
        "every":every,"phase":Vector2i(rng.randi_range(0,every-1),rng.randi_range(0,every-1)),
        "side_w":12.0,"ave_w":21.0,"walk":2.8,
        "downtown":Vector2(rng.randf_range(-0.55,0.55)*PLAY_HALF_X,rng.randf_range(-0.85,0.15)*PLAY_HALF_Z)}
    return _city

func city_local(p: Vector2) -> Vector2:
    var g: Dictionary = city_grid()
    return Vector2(p.dot(g["u"]),p.dot(g["v"]))

func city_world(l: Vector2) -> Vector2:
    var g: Dictionary = city_grid()
    return (g["u"] as Vector2)*l.x+(g["v"] as Vector2)*l.y

## Street line `i` on axis 0 (lines of constant U) or 1: [centre, width].
func city_line(axis: int, i: int) -> Array:
    var g: Dictionary = city_grid()
    var pitch: float = float((g["pitch"] as Vector2)[axis])
    var off: float = float((g["off"] as Vector2)[axis])
    var ave: bool = posmod(i-int((g["phase"] as Vector2i)[axis]),int(g["every"])) == 0
    return [off+float(i)*pitch,float(g["ave_w"]) if ave else float(g["side_w"]),ave]

# ---------------------------------------------------------- buildability

static func tile_centre(c: Vector2i) -> Vector2:
    return Vector2((float(c.x)-float(COLS-1)*0.5)*CELL_M,(float(c.y)-float(ROWS-1)*0.5)*CELL_M)

## Can a 24 m road + 3.6 m verges + barrier margin be built through tile c?
## green (0): on grade; amber (1): substantial cut/fill, retaining walls or
## a short bridge; red (2): not buildable, with a reason.
func tile_build(c: Vector2i) -> Dictionary:
    if c.x < 0 or c.y < 0 or c.x >= COLS or c.y >= ROWS:
        return {"state":2,"reason":"OUTSIDE THE MAP","h":0.0}
    var ctr: Vector2 = tile_centre(c)
    var lo: float = INF
    var hi: float = -INF
    var wet: int = 0
    var stream: bool = false
    var sum: float = 0.0
    var cnt: int = 0
    for a in range(-2,3):
        for b in range(-2,3):
            var p: Vector2 = ctr+Vector2(float(a),float(b))*12.0
            var hh: float = base_at(p.x,p.y)
            var sea_point: bool = relief == "coast" and is_water(p.x,p.y)
            if not sea_point:
                # coast: the sea below the cliff is not part of the road span
                lo = minf(lo,hh)
                hi = maxf(hi,hh)
                sum += hh
                cnt += 1
            if is_water(p.x,p.y):
                if relief == "canyon":
                    stream = true
                elif relief != "coast" or (absi(a) <= 1 and absi(b) <= 1 and a*a+b*b <= 1):
                    # coast: the cliff rule below measures the drop exactly
                    wet += 1
    var mean: float = sum/float(maxi(cnt,1))
    if wet > 0 or cnt == 0:
        return {"state":2,"reason":"SEA / WATER","h":mean}
    if relief == "coast":
        # Distance from the drop to the road corridor near the tile centre
        # (where a road through this tile runs). A 24 m road + 3.6 m verge
        # + barrier strip needs ~20 m from its centre line: closer is red.
        # Every sample of the final road is checked again by classify().
        var d: float = coast_distance(ctr.x,ctr.y)
        if d < 21.0:
            return {"state":2,"reason":"CLIFF EDGE: ROAD + VERGE + BARRIER NEED 21 m","h":mean}
        if d < 40.0:
            return {"state":1,"reason":"CLIFF SHELF: CLIFF WALL, FULL WIDTH ON LAND","h":mean}
    var span: float = hi-lo
    if span > 32.0:
        return {"state":2,"reason":"TOO STEEP (%d m DROP IN ONE TILE)" % int(span),"h":mean}
    if stream:
        return {"state":1,"reason":"STREAM: SHORT BRIDGE","h":mean}
    if span > 9.0:
        return {"state":1,"reason":"CUT / FILL + RETAINING WALLS","h":mean}
    return {"state":0,"reason":"ON GRADE","h":mean}

func build_map() -> Dictionary:
    var out: Dictionary = {}
    for y in range(ROWS):
        for x in range(COLS):
            out[Vector2i(x,y)] = tile_build(Vector2i(x,y))
    return out

## Deterministic fingerprint of the generated (undeformed) terrain.
func fingerprint() -> int:
    var acc: int = 17
    for k in range(0,base.size(),37):
        acc = (acc*31+int(base[k]*100.0)) & 0x7fffffff
    return acc
