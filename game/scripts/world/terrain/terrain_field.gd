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

func _n(k: int, x: float, z: float) -> float:
    return _noise[k].get_noise_2d(x,z)

func _ridged(k: int, x: float, z: float) -> float:
    return 1.0-absf(_noise[k].get_noise_2d(x,z))

static func _edge(u: float, v: float) -> float:
    # Rounded-rectangle norm of the play area: 1 on its border.
    return pow(pow(absf(u),4.0)+pow(absf(v),4.0),0.25)

## Coast archetype: x of the sea cliff line at z (sea is west of it).
func coast_x(z: float) -> float:
    return -PLAY_HALF_X*0.50+75.0*sin(z/230.0+_phase)+34.0*_n(2,0.0,z)

## Ojcow: canyon centre (u units) at v.
func canyon_u(v: float) -> float:
    return 0.30*sin(v*1.9+_phase)

func stream_offset(x: float, z: float) -> float:
    # Signed distance (m, approx.) from the Pradnik-like stream on the valley floor.
    var v: float = z/PLAY_HALF_Z
    var cu: float = canyon_u(v)+0.05*sin(v*7.0+_phase*2.0)
    return x-cu*PLAY_HALF_X

func raw_height(x: float, z: float) -> float:
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
            var t: float = h/7.0
            var f: float = floor(t)
            h = (f+smoothstep(0.30,0.70,t-f))*7.0
            h += smoothstep(0.95,1.9,e)*(110.0+80.0*(_n(3,x,z)*0.5+0.5))
        "mountainside":
            h = 24.0+0.15*(PLAY_HALF_Z-z)+16.0*_n(0,x,z)+24.0*_ridged(1,x,z)-12.0
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
            var wall: float = smoothstep(0.40,0.98,d)
            h = floor_h+90.0*pow(wall,1.3)+14.0*_n(1,x,z)*wall
            h += 16.0*maxf(0.0,_ridged(2,x,z)-0.55)/0.45*smoothstep(0.15,0.55,wall)*(1.0-smoothstep(0.85,1.0,wall))
            var s: float = absf(stream_offset(x,z))
            h -= 2.2*(1.0-smoothstep(3.0,11.0,s))
        "alpine":
            h = 60.0+0.065*(PLAY_HALF_Z-z)+11.0*_n(0,x,z)+4.0*_n(1,x,z)
            var crag: float = _ridged(2,x,z)
            h += 26.0*maxf(0.0,crag-0.78)/0.22
            h += smoothstep(0.95,2.0,e)*(380.0*(0.55+0.45*_ridged(3,x,z)))
        "coast":
            var land: float = 46.0+8.0*_n(0,x,z)+4.0*_n(1,x,z)
            land += smoothstep(1.0,1.9,maxf(u,absf(v)))*(60.0+40.0*_ridged(3,x,z))
            h = land if x >= coast_x(z) else -7.0+2.0*_n(4,x,z)
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
    return x-coast_x(z)

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
            lo = minf(lo,hh)
            hi = maxf(hi,hh)
            sum += hh
            cnt += 1
            if is_water(p.x,p.y):
                if relief == "canyon":
                    stream = true
                else:
                    wet += 1
    var mean: float = sum/float(cnt)
    if wet > 0:
        return {"state":2,"reason":"SEA / WATER","h":mean}
    if relief == "coast":
        var d: float = INF
        for a2 in range(-2,3):
            for b2 in range(-2,3):
                var q: Vector2 = ctr+Vector2(float(a2),float(b2))*14.0
                d = minf(d,coast_distance(q.x,q.y))
        if d < 20.0:
            return {"state":2,"reason":"CLIFF EDGE: ROAD + BARRIER NEED 20 m","h":mean}
        if d < 34.0:
            return {"state":1,"reason":"CLIFF SHELF: BARRIER + RETAINING WALL","h":mean}
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
