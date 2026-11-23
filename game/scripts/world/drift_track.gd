extends Node3D
class_name NitroDriftTrack
## Nitro Track DNA v1: visual surfaces, solid barrier meshes and analytic
## vehicle contacts all derive from the SAME validated sampled corridor.
## The planar arcade car intentionally uses deterministic analytic contacts;
## the identical triangles are also exposed to the Godot physics engine.

const TRACK_DATA: String = "res://tracks/shin_kawa_v2.json"
const EVENT_LAYOUT = preload("res://scripts/events/event_layout.gd")
const EVENT_PAINT = preload("res://scripts/events/event_paint.gd")
var road_style := "circuit"
var event_mode := ""
var event_layout := {"zones":[],"warnings":[]}
var track_data_path: String = TRACK_DATA
var display_name: String = "Shin-Kawa Drift Park"
const DNA = preload("res://scripts/world/track_dna.gd")
const ASPHALT = preload("res://assets/surfaces/asphalt.webp")
const GRASS = preload("res://assets/surfaces/grass_night.webp")
const DIRT = preload("res://assets/surfaces/dirt_verge.webp")
const FLOWERS = preload("res://assets/surfaces/flower_cluster.png")
const SHADOW_SHADER = preload("res://assets/shaders/soft_shadow.gdshader")
const SKY_SHADER = preload("res://assets/shaders/dusk_sky.gdshader")
const CLOUD_SHADOW_SHADER = preload("res://assets/shaders/cloud_shadows.gdshader")
const CLOUDS = preload("res://assets/surfaces/cloud_noise.png")
const ROAD_LOGO = preload("res://assets/brand/road_logo.png")
const BARRIER_ADS = preload("res://assets/surfaces/barrier_ads.png")
const CONCRETE_SLABS = preload("res://assets/surfaces/concrete_slabs.png")
# Night drift-park palette (approved gameplay reference: dark asphalt,
# blue/white kerbs, earth verge, olive grass, cherry blossom).
# v0.1.36 (owner, driftit.app comparison): the asphalt is a bit lighter so the
# car, the tyre marks and the kerbs read better (was Color(1.0,0.99,1.04)).
const ASPHALT_TINT := Color(2.1,2.08,2.18)
const LINE_COLOUR := Color(0.88,0.88,0.86)
const KERB_BLUE := Color(0.10,0.33,0.80)
const KERB_WHITE := Color(0.86,0.87,0.90)
const KERB_BEVEL := Color(0.09,0.09,0.11)
const BARRIER_FACE_A := Color(0.30,0.31,0.36)
const BARRIER_FACE_B := Color(0.26,0.27,0.32)
const BARRIER_TOP_A := Color(0.58,0.59,0.64)
const BARRIER_TOP_B := Color(0.52,0.53,0.58)
const KERB_INSET: float = 0.42       # outer gap between kerb and barrier
const KERB_WIDTH: float = 1.25
const KERB_BLOCK_M: float = 3.0
const LINE_INSET: float = 1.97       # kerb + safety gap
const LINE_WIDTH: float = 0.20
const VERGE_WIDTH: float = 3.6
const PROP_SEED: int = 7741
const HALF_ROAD_WIDTH: float = 12.0  # legacy test compatibility, local widths vary
const CAR_WALL_CLEARANCE: float = 1.18
const WALL_HEIGHT: float = 1.30
const WALL_THICKNESS: float = 0.40

var centerline: Array[Vector2] = []
var left_edge: Array[Vector2] = []
var right_edge: Array[Vector2] = []
var halfwidths: PackedFloat32Array = PackedFloat32Array()
var arc_lengths: PackedFloat32Array = PackedFloat32Array()
var length_metres: float = 0.0
var validation_errors: PackedStringArray = PackedStringArray()
var track_valid: bool = false
var track_id: String = ""
## Visual options used by the 3D track builder preview: open chains are
## drawn without wrap-around, start line, ground or lights.
var closed_loop: bool = true
var with_environment: bool = true
## Roadside trees and verge flowers. Off when a procedural world (3D builder
## tracks, v0.1.23) provides the scenery, so builder and race match.
var with_props: bool = true
## v0.1.36: track-side decoration that is part of the race look (barrier
## advertising band, NITRO WHEELZ road inscription). Off for the quick
## track-builder previews (build_from_samples), on everywhere else.
var with_decor: bool = true
var world: Node3D = null
## v0.1.25 terrain worlds: road height per centreline sample (empty = the
## legacy flat road at y = 0) and the open-route layout (start a little
## inside the first tile, finish line before the end cap).
var heights: PackedFloat32Array = PackedFloat32Array()
var start_index: int = 0
## Region kerb / run-off colours (terrain tracks; defaults = the approved
## night-park blue/white kerbs and the plain dirt shoulder).
var kerb_a: Color = KERB_BLUE
var kerb_b: Color = KERB_WHITE
var runoff_tint: Color = Color.WHITE
var shoulder_concrete: bool = false

func apply_region_style(desc: Dictionary) -> void:
    var inf: Dictionary = TERRAIN_CAT.info(str(desc.get("archetype","")))
    var k: Array = inf.get("kerb",[KERB_BLUE,KERB_WHITE])
    kerb_a = k[0]
    kerb_b = k[1]
    runoff_tint = inf.get("runoff",Color.WHITE)
    # v0.1.27: street circuits get a concrete shoulder (asphalt texture,
    # light grey) instead of the dirt verge.
    shoulder_concrete = str(inf.get("relief","")) == "urban"
var finish_index: int = -1
var finish_progress: float = 1.0
const OPEN_START_M: float = 18.0
const OPEN_FINISH_M: float = 30.0
const PROC_WORLD = preload("res://scripts/world/procedural_world.gd")
const BUILD_GRID = preload("res://scripts/world/track_grid.gd")
const TERRAIN_WORLD = preload("res://scripts/world/terrain/terrain_world.gd")
const TERRAIN_TRACK = preload("res://scripts/world/terrain/terrain_track.gd")
const ROAD_PROFILE = preload("res://scripts/world/terrain/road_profile.gd")
const TERRAIN_CAT = preload("res://scripts/world/terrain/terrain_catalog.gd")
## Generated terrain world (v0.1.25 terrain-first tracks) or null.
var terrain: NitroTerrainWorld = null
## v0.1.27: the race builds the terrain itself in frame slices behind a
## loading animation (build() only records the descriptor).
var defer_terrain: bool = false
var pending_terrain: Dictionary = {}
const STEPS = preload("res://scripts/world/step_runner.gd")

func _ready() -> void:
    if centerline.is_empty():
        build()

func build() -> void:
    var compiled: Dictionary = DNA.read_track(track_data_path)
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(track_data_path)) if FileAccess.file_exists(track_data_path) else null
    var grid: RefCounted = world_grid(raw) if raw is Dictionary else null
    if grid != null:
        with_props = false
    var tdesc: Dictionary = TERRAIN_TRACK.world_of(raw) if raw is Dictionary else {}
    if not tdesc.is_empty():
        # Terrain-first track: the generated landscape replaces the flat
        # park ground, sky and roadside props (same world as the builder).
        with_props = false
        with_environment = false
        apply_region_style(tdesc)
        if raw.get("event_version",0)==1:
            event_mode=str(tdesc.get("event_mode","practice"))
            road_style=str(raw.get("road_style","circuit"))
    _apply_compiled(compiled)
    if not tdesc.is_empty() and track_valid:
        if defer_terrain:
            pending_terrain = tdesc
        else:
            build_terrain(tdesc)
    if grid != null and track_valid:
        world = PROC_WORLD.new()
        world.name = "Procedural world"
        add_child(world)
        world.generate(grid.links,grid.cols,grid.rows,int(raw["world"].get("seed",1)))

## Generate the terrain world of this track and adapt it to the road. A
## terrain track saved without (matching) knot heights gets its heights
## solved here with the same solver the builder uses.
func build_terrain(desc: Dictionary) -> void:
    STEPS.run_now(build_terrain_steps(desc))

## build_terrain() as steps (field bake, terrain + scenery chunks, road fit).
func build_terrain_steps(desc: Dictionary) -> Array:
    return [func():
        terrain = TERRAIN_WORLD.new()
        terrain.name = "Terrain world"
        terrain.setup(desc)
        terrain.scenery_range = 650.0
        var more: Array = terrain.field.bake_steps()
        more.append(func():
            add_child(terrain)
            var b2: Array = terrain.build_steps()
            b2.append(func(): return _terrain_road_steps(desc))
            return b2)
        return more]

func _terrain_road_steps(desc: Dictionary) -> Array:
    if heights.size() != centerline.size():
        var grade: float = float(TERRAIN_CAT.info(str(desc.get("archetype","")))["grade"])
        heights = ROAD_PROFILE.solve(terrain.field,centerline,halfwidths,closed_loop,grade)
        # Road meshes were built flat: rebuild them on the solved heights.
        for child in get_children():
            if child != terrain:
                remove_child(child)
                child.queue_free()
        _build_visuals()
    return terrain.set_road_steps(centerline,halfwidths,heights,closed_loop)

## Grade (rise / run) of the road along the centreline direction at a
## sample_info() result; 0 on flat tracks.
func grade_from_info(info: Dictionary) -> float:
    if heights.is_empty():
        return 0.0
    var n: int = centerline.size()
    var i: int = int(info["index"])
    var j: int = (i+1)%n
    return (heights[j]-heights[i])/maxf(centerline[i].distance_to(centerline[j]),0.01)

## The builder grid behind a saved track that carries a procedural world,
## or null. The tiles must reproduce the saved road exactly (a track reshaped
## in the node editor keeps no world).
static func world_grid(raw: Dictionary) -> RefCounted:
    if not (raw.get("world",null) is Dictionary) or not (raw.get("builder",null) is Dictionary):
        return null
    if str(raw["world"].get("theme","")) != PROC_WORLD.THEME:
        return null
    var builder: Dictionary = raw["builder"]
    var grid = BUILD_GRID.new(int(builder.get("cols",8)),int(builder.get("rows",12)))
    if not grid.load_builder_data(raw):
        return null
    # Same closed road, whatever tile the loop walk starts on / its direction.
    var cps: Array = grid.to_track_data("check","check")["control_points"]
    var saved: Array = raw.get("control_points",[])
    if cps.size() != saved.size() or saved.is_empty():
        return null
    var n: int = cps.size()
    var first := Vector2(float(saved[0][0]),float(saved[0][1]))
    for k in range(n):
        if Vector2(float(cps[k][0]),float(cps[k][1])).distance_to(first) > 0.01:
            continue
        for dir in [1,-1]:
            var same: bool = true
            for i in range(n):
                var q: Array = cps[posmod(k+dir*i,n)]
                if Vector2(float(q[0]),float(q[1])).distance_to(Vector2(float(saved[i][0]),float(saved[i][1]))) > 0.01:
                    same = false
                    break
            if same:
                return grid
    return null

func rebuild_from_data(data: Dictionary) -> bool:
    # Future editor entrypoint: reject invalid data without replacing the
    # currently playable track. No accidental broken geometry is generated.
    var compiled: Dictionary = DNA.compile(data)
    if not bool(compiled.get("ok",false)):
        validation_errors = compiled["errors"]
        return false
    _apply_compiled(compiled)
    return true

func _apply_compiled(compiled: Dictionary) -> void:
    track_valid = bool(compiled.get("ok",false))
    validation_errors = compiled.get("errors",PackedStringArray())
    if not track_valid:
        push_error("Nitro Track DNA rejected circuit: "+str(validation_errors))
        return
    for child in get_children():
        remove_child(child)
        child.queue_free()
    centerline = compiled["centerline"]
    left_edge = compiled["left_edge"]
    right_edge = compiled["right_edge"]
    halfwidths = compiled["halfwidths"]
    arc_lengths = compiled["arc_lengths"]
    length_metres = float(compiled["length_metres"])
    track_id = str(compiled["track_id"])
    display_name = str(compiled["track_name"])
    closed_loop = bool(compiled.get("closed",true))
    heights = compiled.get("heights",PackedFloat32Array())
    if heights.size() != centerline.size():
        heights = PackedFloat32Array()
    _layout_ends()
    _build_visuals()

func _layout_ends() -> void:
    start_index = 0
    finish_index = -1
    finish_progress = 1.0
    if closed_loop or centerline.size() < 4:
        return
    var n: int = centerline.size()
    for i in range(n):
        if arc_lengths[i] >= OPEN_START_M:
            start_index = i
            break
    finish_index = n-1
    for i2 in range(n-1,0,-1):
        if length_metres-arc_lengths[i2] >= OPEN_FINISH_M:
            finish_index = i2
            break
    finish_progress = arc_lengths[finish_index]/maxf(length_metres,1.0)

## Road surface height under sample i (0 on legacy flat tracks).
func hy(i: int) -> float:
    return heights[i] if not heights.is_empty() else 0.0

## Road surface height at a sample_info() result.
func height_from_info(info: Dictionary) -> float:
    if heights.is_empty():
        return 0.0
    var i: int = int(info["index"])
    return lerpf(heights[i],heights[(i+1)%heights.size()],float(info["t"]))

func road_height_at(pos: Vector2) -> float:
    return height_from_info(sample_info(pos)) if not heights.is_empty() else 0.0

## Builder preview: draw the same road/kerb/verge/scenery for an arbitrary
## sampled centreline (open chain or closed loop). Not used for racing.
func build_from_samples(samples: Array[Vector2], halfwidth: float, closed: bool,
        id: String = "builder_preview", environment: bool = false,
        sample_heights: PackedFloat32Array = PackedFloat32Array()) -> void:
    for child in get_children():
        remove_child(child)
        child.queue_free()
    closed_loop = closed
    heights = sample_heights if sample_heights.size() == samples.size() else PackedFloat32Array()
    with_environment = environment
    with_decor = environment
    centerline = samples.duplicate()
    left_edge.clear()
    right_edge.clear()
    halfwidths = PackedFloat32Array()
    arc_lengths = PackedFloat32Array()
    var n: int = centerline.size()
    if n < 2:
        track_valid = false
        return
    var total: float = 0.0
    for i in range(n):
        var prev: Vector2 = centerline[(i-1+n)%n] if (closed or i > 0) else centerline[i]
        var next: Vector2 = centerline[(i+1)%n] if (closed or i < n-1) else centerline[i]
        var tangent: Vector2 = (next-prev).normalized()
        var normal := Vector2(-tangent.y,tangent.x)
        left_edge.append(centerline[i]-normal*halfwidth)
        right_edge.append(centerline[i]+normal*halfwidth)
        halfwidths.append(halfwidth)
        arc_lengths.append(total)
        if closed or i < n-1:
            total += centerline[i].distance_to(centerline[(i+1)%n])
    length_metres = total
    track_id = id
    track_valid = true
    _layout_ends()
    _build_visuals()

func _segment_count() -> int:
    return centerline.size() if closed_loop else centerline.size()-1

func _build_visuals() -> void:
    _build_clearance_grid()
    if with_environment:
        _build_environment()
    # Layering outward from the racing surface (brief: surface -> painted
    # line -> safety gap -> kerb -> outer gap -> barrier -> verge).
    # v0.1.36: street circuits get concrete SLABS (visible joints = a cheap sense
    # of scale and speed) instead of the asphalt texture tinted light.
    _add_corridor("Compacted shoulder",_shift_edge(left_edge,-VERGE_WIDTH),
        _shift_edge(right_edge,VERGE_WIDTH),0.018,Color(1.0,1.0,1.03) if shoulder_concrete else runoff_tint,
        CONCRETE_SLABS if shoulder_concrete else DIRT,6.0)
    _add_corridor("Single continuous driving surface",left_edge,right_edge,
        0.05,ASPHALT_TINT,ASPHALT,7.0)
    var inset:=0.32 if road_style=="road" else LINE_INSET
    if road_style!="road":
        _build_kerbs()
    event_layout=EVENT_LAYOUT.generate(self,event_mode)
    EVENT_PAINT.build(self)
    _add_corridor("White edge left",_shift_edge(left_edge,inset),
        _shift_edge(left_edge,inset+LINE_WIDTH),0.066,LINE_COLOUR)
    _add_corridor("White edge right",_shift_edge(right_edge,-inset-LINE_WIDTH),
        _shift_edge(right_edge,-inset),0.066,LINE_COLOUR)
    if closed_loop:
        _build_start_line()
    elif centerline.size() >= 4:
        _build_start_line(start_index,false)
        _build_start_line(finish_index,true)
    _build_barriers()
    if with_decor and road_style!="road":
        _build_barrier_ads()
        _build_road_logos()
    if with_props:
        _build_track_props()
    if with_environment:
        _build_cloud_shadows()

func _shift_edge(edge: Array[Vector2], metres: float) -> Array[Vector2]:
    var shifted: Array[Vector2] = []
    for i in range(edge.size()):
        var inward: Vector2 = (right_edge[i]-left_edge[i]).normalized()
        shifted.append(edge[i]+inward*metres)
    return shifted

func start_position() -> Vector2:
    return centerline[start_index]

func start_heading() -> float:
    var n: int = centerline.size()
    var tangent: Vector2 = (centerline[1]-centerline[n-1]).normalized()
    if not closed_loop:
        tangent = (centerline[mini(start_index+1,n-1)]-centerline[maxi(start_index-1,0)]).normalized()
    return atan2(tangent.x,-tangent.y)

func sample_info(pos: Vector2) -> Dictionary:
    var best_sq: float = INF
    var index: int = 0
    var nearest: Vector2 = Vector2.ZERO
    var segment_t: float = 0.0
    var n: int = centerline.size()
    for i in range(_segment_count()):
        var a: Vector2 = centerline[i]
        var b: Vector2 = centerline[(i+1)%n]
        var delta: Vector2 = b-a
        var t: float = clampf((pos-a).dot(delta)/maxf(delta.length_squared(),0.000001),0.0,1.0)
        var p: Vector2 = a+delta*t
        var dsq: float = pos.distance_squared_to(p)
        if dsq < best_sq:
            best_sq=dsq
            index=i
            nearest=p
            segment_t=t
    var next_i: int = (index+1)%n
    var segment: Vector2 = centerline[next_i]-centerline[index]
    var width: float = lerpf(halfwidths[index],halfwidths[next_i],segment_t)
    var progress: float = (arc_lengths[index]+segment.length()*segment_t)/maxf(length_metres,1.0)
    return {"distance":sqrt(best_sq),"point":nearest,"index":index,
        "t":segment_t,"width":width,"progress":progress,
        "tangent":segment.normalized()}

func resolve_wall(pos: Vector2, travel_velocity: Vector2) -> Dictionary:
    # Derive analytic contact from the *same sampled edge segments*
    # used for the blue/white wall mesh. Not a distance-to-centre fudge.
    var info: Dictionary = sample_info(pos)
    var i: int = int(info["index"])
    var next_i: int = (i+1)%centerline.size()
    var t: float = float(info["t"])
    var normal: Vector2 = (right_edge[i].lerp(right_edge[next_i],t) -
        left_edge[i].lerp(left_edge[next_i],t)).normalized()
    var side: float = -1.0 if (pos-Vector2(info["point"])).dot(normal)<0.0 else 1.0
    var boundary: Vector2 = left_edge[i].lerp(left_edge[next_i],t) if side<0 else right_edge[i].lerp(right_edge[next_i],t)
    var outward: Vector2 = normal*side
    var safe_centre: Vector2 = boundary-outward*(CAR_WALL_CLEARANCE+0.10)
    var penetration: float = (pos-safe_centre).dot(outward)
    if penetration <= 0.0:
        return {"hit":false,"position":pos,"velocity":travel_velocity,
            "impact_speed":0.0,"normal":Vector2.ZERO}
    var outward_speed: float = maxf(travel_velocity.dot(outward),0.0)
    var reflected: Vector2 = (travel_velocity-outward*(1.18*outward_speed))*0.80
    var corrected: Vector2 = pos-outward*(penetration+0.005)
    return {"hit":true,"position":corrected,"velocity":reflected,
        "impact_speed":outward_speed,"normal":outward}

## Oriented car footprint against the walls. The centre-point test above
## keeps the car's middle 1.28 m from the barrier, which is enough side-on
## but let the nose or tail (2.4 m from the centre at race scale) pass into
## and through the barrier when the car met it at an angle. Probes on the
## corners, bumpers and doors are pushed back to the barrier face, and the
## contact adds a yaw kick from its lever arm (car swings off the wall).
const BODY_HALF_LENGTH: float = 2.30   # 4.166 m shell x1.15 race scale, rounded bumpers
const BODY_HALF_WIDTH: float = 1.05
const BODY_SKIN: float = 0.05
# Per-car footprint (set by the race from the chosen car); Lada defaults.
var body_half_length: float = BODY_HALF_LENGTH
var body_half_width: float = BODY_HALF_WIDTH
const BODY_PROBES: Array[Vector2] = [Vector2(1,1),Vector2(1,-1),Vector2(-1,1),Vector2(-1,-1),
    Vector2(1,0),Vector2(-1,0),Vector2(0.45,1),Vector2(0.45,-1),Vector2(-0.45,1),Vector2(-0.45,-1)]
const PROBE_WINDOW: int = 24

func resolve_body(pos: Vector2, heading: float, travel_velocity: Vector2) -> Dictionary:
    var first: Dictionary = resolve_wall(pos,travel_velocity)
    var p: Vector2 = first["position"]
    var v: Vector2 = first["velocity"]
    var hit: bool = bool(first["hit"])
    var impact: float = float(first["impact_speed"])
    var normal: Vector2 = first["normal"]
    var yaw_impulse: float = 0.0
    var fwd := Vector2(sin(heading),-cos(heading))
    var rgt := Vector2(cos(heading),sin(heading))
    var hint: int = int(sample_info(p)["index"])
    for _pass in range(3):
        var worst: float = 0.0
        var worst_out: Vector2 = Vector2.ZERO
        var worst_arm: Vector2 = Vector2.ZERO
        for o in BODY_PROBES:
            var arm: Vector2 = fwd*(o.x*body_half_length)+rgt*(o.y*body_half_width)
            var c: Vector3 = _probe_penetration(p+arm,hint)
            if c.z > worst:
                worst = c.z
                worst_out = Vector2(c.x,c.y)
                worst_arm = arm
        if worst <= 0.0:
            break
        hit = true
        normal = worst_out
        p -= worst_out*(worst+0.005)
        var vn: float = maxf(v.dot(worst_out),0.0)
        if vn > 0.0:
            v = (v-worst_out*(1.18*vn))*0.80
            impact = maxf(impact,vn)
            # Angular impulse of a corner contact (unit mass, I ~ 1.75 m^2).
            var lever: float = worst_arm.cross(-worst_out)
            yaw_impulse += 0.6*lever*1.18*vn/(1.75+lever*lever)
    return {"hit":hit,"position":p,"velocity":v,"impact_speed":impact,
        "normal":normal,"yaw_impulse":clampf(yaw_impulse,-2.5,2.5)}

## Returns (outward.x, outward.y, penetration) of one body point past the
## barrier face, searching only the centreline near the car (hint index).
func _probe_penetration(q: Vector2, hint: int) -> Vector3:
    var n: int = centerline.size()
    var best_sq: float = INF
    var index: int = hint
    var seg_t: float = 0.0
    var nearest: Vector2 = q
    for k in range(-PROBE_WINDOW,PROBE_WINDOW+1):
        var i: int = posmod(hint+k,n)
        if not closed_loop:
            i = hint+k
            if i < 0 or i > n-2:
                continue
        var a: Vector2 = centerline[i]
        var delta: Vector2 = centerline[(i+1)%n]-a
        var t: float = clampf((q-a).dot(delta)/maxf(delta.length_squared(),0.000001),0.0,1.0)
        var pt: Vector2 = a+delta*t
        var dsq: float = q.distance_squared_to(pt)
        if dsq < best_sq:
            best_sq = dsq
            index = i
            seg_t = t
            nearest = pt
    var next_i: int = (index+1)%n
    var across: Vector2 = (right_edge[index].lerp(right_edge[next_i],seg_t)-
        left_edge[index].lerp(left_edge[next_i],seg_t)).normalized()
    var side: float = -1.0 if (q-nearest).dot(across) < 0.0 else 1.0
    var boundary: Vector2 = left_edge[index].lerp(left_edge[next_i],seg_t) if side < 0.0 \
        else right_edge[index].lerp(right_edge[next_i],seg_t)
    var outward: Vector2 = across*side
    # Barrier face is drawn 0.10 m outside the edge; keep a small skin.
    var limit: Vector2 = boundary+outward*(0.10-BODY_SKIN)
    var result := Vector3(outward.x,outward.y,(q-limit).dot(outward))
    if not closed_loop:
        # Open route: end-cap barriers across the road at both ends. Only
        # where the probe's nearest stretch IS the first / last segment and
        # it lies across the road width (not a world-wide half plane).
        if index == 0:
            var t0: Vector2 = (centerline[1]-centerline[0]).normalized()
            var lat0: float = absf((q-centerline[0]).dot(Vector2(-t0.y,t0.x)))
            var pen0: float = (centerline[0]+t0*(0.10+BODY_SKIN)-q).dot(t0)
            if lat0 <= halfwidths[0]+1.0 and pen0 > result.z and pen0 > 0.0:
                result = Vector3(-t0.x,-t0.y,pen0)
        if index == n-2:
            var te: Vector2 = (centerline[n-1]-centerline[n-2]).normalized()
            var late: float = absf((q-centerline[n-1]).dot(Vector2(-te.y,te.x)))
            var pen1: float = (q-(centerline[n-1]-te*(0.10+BODY_SKIN))).dot(te)
            if late <= halfwidths[n-1]+1.0 and pen1 > result.z and pen1 > 0.0:
                result = Vector3(te.x,te.y,pen1)
    return result

func _add_corridor(label: String,a: Array[Vector2],b: Array[Vector2],
        height: float,tint: Color,texture: Texture2D = null,tile_m: float = 7.0) -> void:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for i in range(_segment_count()):
        var next_i: int = (i+1)%centerline.size()
        var y0: float = height+hy(i)
        var y1: float = height+hy(next_i)
        var p: Vector3 = Vector3(a[i].x,y0,a[i].y)
        var q: Vector3 = Vector3(b[i].x,y0,b[i].y)
        var r: Vector3 = Vector3(a[next_i].x,y1,a[next_i].y)
        var u: Vector3 = Vector3(b[next_i].x,y1,b[next_i].y)
        _add_tri(st,p,r,q,tint,tile_m)
        _add_tri(st,q,r,u,tint,tile_m)
    var arr: ArrayMesh = st.commit()
    var mat := StandardMaterial3D.new()
    mat.vertex_color_use_as_albedo = true
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    if texture != null:
        mat.albedo_texture = texture
        mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    arr.surface_set_material(0,mat)
    var mesh := MeshInstance3D.new()
    mesh.name = label
    mesh.mesh = arr
    add_child(mesh)

func _add_tri(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,
        tint: Color,tile_m: float = 7.0) -> void:
    for p in [a,b,c]:
        st.set_color(tint)
        st.set_normal(Vector3.UP)
        # World-space UVs make adjacent procedural segments seamlessly tile.
        st.set_uv(Vector2(p.x,p.z)/tile_m)
        st.add_vertex(p)

func _wall_tri(st: SurfaceTool,vertices: PackedVector3Array,
        a: Vector3,b: Vector3,c: Vector3,tint: Color) -> void:
    for p in [a,b,c]:
        st.set_color(tint)
        st.set_normal(Vector3.UP)
        st.add_vertex(p)
        vertices.append(p)

func _build_barriers() -> void:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var triangles := PackedVector3Array()
    var count: int = centerline.size()
    for i in range(_segment_count()):
        var next_i: int = (i+1)%count
        # Concrete barrier: darker inner face, lit top, subtle 3-sample
        # panel rhythm as a speed reference. Geometry is unchanged.
        var panel: bool = int(i/3)%2==0
        var colour: Color = BARRIER_FACE_A if panel else BARRIER_FACE_B
        var top_colour: Color = BARRIER_TOP_A if panel else BARRIER_TOP_B
        var n0: Vector2 = (right_edge[i]-left_edge[i]).normalized()
        var n1: Vector2 = (right_edge[next_i]-left_edge[next_i]).normalized()
        for side in [-1.0,1.0]:
            var p: Vector2 = left_edge[i] if side<0 else right_edge[i]
            var q: Vector2 = left_edge[next_i] if side<0 else right_edge[next_i]
            p += n0*side*0.10
            q += n1*side*0.10
            var ya: float = hy(i)
            var yb: float = hy(next_i)
            var foot: float = 0.055 if heights.is_empty() else -0.5
            var bottom_a := Vector3(p.x,foot+ya,p.y)
            var bottom_b := Vector3(q.x,foot+yb,q.y)
            var top_a := Vector3(p.x,WALL_HEIGHT+ya,p.y)
            var top_b := Vector3(q.x,WALL_HEIGHT+yb,q.y)
            var outer_p: Vector2 = p+n0*side*WALL_THICKNESS
            var outer_q: Vector2 = q+n1*side*WALL_THICKNESS
            var outside_a := Vector3(outer_p.x,WALL_HEIGHT+ya,outer_p.y)
            var outside_b := Vector3(outer_q.x,WALL_HEIGHT+yb,outer_q.y)
            _wall_tri(st,triangles,bottom_a,bottom_b,top_a,colour)
            _wall_tri(st,triangles,top_a,bottom_b,top_b,colour)
            _wall_tri(st,triangles,top_a,top_b,outside_a,top_colour)
            _wall_tri(st,triangles,outside_a,top_b,outside_b,top_colour)
            if not heights.is_empty():
                # outer face down to the ground (terrain worlds: roads on fills)
                var ob_a := Vector3(outer_p.x,ya-0.5,outer_p.y)
                var ob_b := Vector3(outer_q.x,yb-0.5,outer_q.y)
                _wall_tri(st,triangles,outside_a,outside_b,ob_a,colour.darkened(0.1))
                _wall_tri(st,triangles,ob_a,outside_b,ob_b,colour.darkened(0.1))
    if not closed_loop and count >= 4:
        # End caps of an open route: a barrier across the road at both ends.
        for end in [0,count-1]:
            var tan: Vector2 = (centerline[1]-centerline[0]).normalized() if end == 0 \
                else (centerline[count-1]-centerline[count-2]).normalized()
            var dir: float = -1.0 if end == 0 else 1.0
            var l: Vector2 = left_edge[end]+(left_edge[end]-right_edge[end]).normalized()*0.5+tan*dir*0.10
            var r: Vector2 = right_edge[end]+(right_edge[end]-left_edge[end]).normalized()*0.5+tan*dir*0.10
            var lo: Vector2 = l+tan*dir*WALL_THICKNESS
            var ro: Vector2 = r+tan*dir*WALL_THICKNESS
            var yy: float = hy(end)
            var foot2: float = 0.055 if heights.is_empty() else -0.5
            var a1 := Vector3(l.x,yy+foot2,l.y)
            var b1 := Vector3(r.x,yy+foot2,r.y)
            var c1 := Vector3(r.x,yy+WALL_HEIGHT,r.y)
            var d1 := Vector3(l.x,yy+WALL_HEIGHT,l.y)
            var c2 := Vector3(ro.x,yy+WALL_HEIGHT,ro.y)
            var d2 := Vector3(lo.x,yy+WALL_HEIGHT,lo.y)
            _wall_tri(st,triangles,a1,b1,c1,KERB_BLUE)
            _wall_tri(st,triangles,a1,c1,d1,KERB_BLUE)
            _wall_tri(st,triangles,d1,c1,c2,BARRIER_TOP_A)
            _wall_tri(st,triangles,d1,c2,d2,BARRIER_TOP_A)
    var mesh: ArrayMesh = st.commit()
    var mat := StandardMaterial3D.new()
    mat.vertex_color_use_as_albedo = true
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mesh.surface_set_material(0,mat)
    var visual := MeshInstance3D.new()
    visual.name = "Walls from Track DNA edges"
    visual.mesh = mesh
    add_child(visual)
    var body := StaticBody3D.new()
    body.name = "Exactly matched wall triangle collision mesh"
    var collider := CollisionShape3D.new()
    var shape := ConcavePolygonShape3D.new()
    shape.data = triangles
    collider.shape = shape
    body.add_child(collider)
    add_child(body)

func _build_start_line(at: int = 0, finish: bool = false) -> void:
    var n: int = centerline.size()
    var p: Vector2 = centerline[at]
    var t: Vector2 = (centerline[(at+1)%n]-centerline[(at-1+n)%n]).normalized()
    if not closed_loop:
        t = (centerline[mini(at+1,n-1)]-centerline[maxi(at-1,0)]).normalized()
    var across: Vector2 = (right_edge[at]-left_edge[at]).normalized()
    var road_width: float = halfwidths[at]*2.0
    var line_heading: float = atan2(t.x,-t.y)
    var tiles: int = 20
    for tile in range(tiles):
        for stripe in range(2):
            var board := MeshInstance3D.new()
            var box := BoxMesh.new()
            box.size = Vector3(road_width/float(tiles),0.025,0.58)
            board.mesh = box
            var lateral: float = -halfwidths[at]+(float(tile)+0.5)*road_width/float(tiles)
            var longitudinal: float = (float(stripe)-0.5)*0.58
            var pt: Vector2 = p+across*lateral+t*longitudinal
            board.position = Vector3(pt.x,0.094+hy(at),pt.y)
            board.rotation.y = -line_heading
            var material := StandardMaterial3D.new()
            material.albedo_color = Color.WHITE if (tile+stripe)%2==0 else Color(0.055,0.055,0.06)
            if finish and (tile+stripe)%2 != 0:
                material.albedo_color = Color(0.85,0.10,0.16)
            material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
            board.material_override = material
            add_child(board)


# ------------------------------------------------------------ road clearance

var _clearance_grid: Dictionary = {}
## Scenery placement records (headless-testable; MultiMesh data is not
## readable from the dummy renderer).
var tree_positions: Array[Vector2] = []
var flower_positions: Array[Vector2] = []
const CLEARANCE_CELL_M: float = 24.0

func _build_clearance_grid() -> void:
    # Spatial hash of centreline segments: fast "how far from ANY road
    # branch is this point" queries for scenery placement.
    _clearance_grid.clear()
    var n: int = centerline.size()
    for i in range(_segment_count()):
        var a: Vector2 = centerline[i]
        var b: Vector2 = centerline[(i+1)%n]
        var lo := Vector2i(int(floor(minf(a.x,b.x)/CLEARANCE_CELL_M)),int(floor(minf(a.y,b.y)/CLEARANCE_CELL_M)))
        var hi := Vector2i(int(floor(maxf(a.x,b.x)/CLEARANCE_CELL_M)),int(floor(maxf(a.y,b.y)/CLEARANCE_CELL_M)))
        for cx in range(lo.x,hi.x+1):
            for cy in range(lo.y,hi.y+1):
                var key := Vector2i(cx,cy)
                if not _clearance_grid.has(key):
                    _clearance_grid[key] = PackedInt32Array()
                var list: PackedInt32Array = _clearance_grid[key]
                list.append(i)
                _clearance_grid[key] = list

func road_clearance(pos: Vector2, search_m: float = 60.0) -> float:
    ## Distance from pos to the nearest road edge in metres (negative when
    ## the point lies on the road). INF when no road is within search_m.
    var best: float = INF
    var n: int = centerline.size()
    var reach: int = int(ceil(search_m/CLEARANCE_CELL_M))
    var cell := Vector2i(int(floor(pos.x/CLEARANCE_CELL_M)),int(floor(pos.y/CLEARANCE_CELL_M)))
    for dx in range(-reach,reach+1):
        for dy in range(-reach,reach+1):
            var key := cell+Vector2i(dx,dy)
            if not _clearance_grid.has(key):
                continue
            for i in _clearance_grid[key]:
                var a: Vector2 = centerline[i]
                var b: Vector2 = centerline[(i+1)%n]
                var ab: Vector2 = b-a
                var t: float = clampf((pos-a).dot(ab)/maxf(ab.length_squared(),0.000001),0.0,1.0)
                var d: float = pos.distance_to(a+ab*t)-lerpf(halfwidths[i],halfwidths[(i+1)%n],t)
                best = minf(best,d)
    return best

# ------------------------------------------------------------------- kerbs

func _build_kerbs() -> void:
    # Flat raised blue/white rumble strips inside both edges. Block length is
    # adjusted so an EVEN number of blocks spans the loop: the colour
    # sequence stays continuous across every segment join and the start/end.
    var n: int = centerline.size()
    var blocks: int = maxi(2,int(round(length_metres/(KERB_BLOCK_M*2.0)))*2)
    var block_len: float = length_metres/float(blocks)
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var top_y: float = 0.074
    var low_y: float = 0.054
    for side in [-1.0,1.0]:
        var edge: Array[Vector2] = left_edge if side < 0.0 else right_edge
        var inward: float = 1.0 if side < 0.0 else -1.0
        var outer: Array[Vector2] = _shift_edge(edge,inward*KERB_INSET)
        var inner: Array[Vector2] = _shift_edge(edge,inward*(KERB_INSET+KERB_WIDTH))
        var lip: Array[Vector2] = _shift_edge(edge,inward*(KERB_INSET+KERB_WIDTH+0.16))
        var back: Array[Vector2] = _shift_edge(edge,inward*(KERB_INSET-0.10))
        for i in range(_segment_count()):
            var j: int = (i+1)%n
            var s0: float = arc_lengths[i]
            var s1: float = arc_lengths[j] if j != 0 else length_metres
            var cuts: Array[float] = [0.0]
            var k: int = int(floor(s0/block_len))+1
            while float(k)*block_len < s1-0.0001:
                cuts.append((float(k)*block_len-s0)/maxf(s1-s0,0.0001))
                k += 1
            cuts.append(1.0)
            for c in range(cuts.size()-1):
                var t0: float = cuts[c]
                var t1: float = cuts[c+1]
                var mid_s: float = s0+(s1-s0)*(t0+t1)*0.5
                var colour: Color = kerb_a if int(floor(mid_s/block_len))%2 == 0 else kerb_b
                var o0: Vector2 = outer[i].lerp(outer[j],t0)
                var o1: Vector2 = outer[i].lerp(outer[j],t1)
                var i0: Vector2 = inner[i].lerp(inner[j],t0)
                var i1: Vector2 = inner[i].lerp(inner[j],t1)
                var e0: float = lerpf(hy(i),hy(j),t0)
                var e1: float = lerpf(hy(i),hy(j),t1)
                _flat_quad(st,o0,o1,i0,i1,top_y,top_y,colour,e0,e1)
                var l0: Vector2 = lip[i].lerp(lip[j],t0)
                var l1: Vector2 = lip[i].lerp(lip[j],t1)
                _flat_quad(st,i0,i1,l0,l1,top_y,low_y,colour.darkened(0.45),e0,e1)
                var b0: Vector2 = back[i].lerp(back[j],t0)
                var b1: Vector2 = back[i].lerp(back[j],t1)
                _flat_quad(st,b0,b1,o0,o1,low_y,top_y,KERB_BEVEL,e0,e1)
    var mesh: ArrayMesh = st.commit()
    var mat := StandardMaterial3D.new()
    mat.vertex_color_use_as_albedo = true
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    mesh.surface_set_material(0,mat)
    var node := MeshInstance3D.new()
    node.name = "Blue white kerbs"
    node.mesh = mesh
    add_child(node)

func _flat_quad(st: SurfaceTool,a0: Vector2,a1: Vector2,b0: Vector2,b1: Vector2,
        ya: float,yb: float,colour: Color,e0: float = 0.0,e1: float = 0.0) -> void:
    var p0 := Vector3(a0.x,ya+e0,a0.y)
    var p1 := Vector3(a1.x,ya+e1,a1.y)
    var q0 := Vector3(b0.x,yb+e0,b0.y)
    var q1 := Vector3(b1.x,yb+e1,b1.y)
    for p in [p0,p1,q0,q0,p1,q1]:
        st.set_color(colour)
        st.set_normal(Vector3.UP)
        st.add_vertex(p)

# ------------------------------------------------------------- environment

func _build_environment() -> void:
    var plane := MeshInstance3D.new()
    plane.name = "Ground outside track"
    var ground := PlaneMesh.new()
    ground.size = Vector2(900,900)
    plane.mesh = ground
    plane.position.y = -0.08
    var m := StandardMaterial3D.new()
    m.albedo_color = Color(1.18,1.18,1.08)
    m.albedo_texture = GRASS
    m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    m.uv1_scale = Vector3(900.0/18.0,900.0/18.0,1.0)
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    plane.material_override = m
    add_child(plane)
    # Cool moonlight key from the upper left + violet night ambient.
    var moon := DirectionalLight3D.new()
    moon.name = "Moonlight"
    moon.rotation_degrees = Vector3(-62,-38,0)
    moon.light_color = Color(1.0,0.90,0.80)
    moon.light_energy = 1.05
    moon.shadow_enabled = false
    add_child(moon)
    var env := WorldEnvironment.new()
    var res := Environment.new()
    # Golden-hour sky with drifting clouds (seen from the chase camera).
    var sky := Sky.new()
    var sky_mat := ShaderMaterial.new()
    sky_mat.shader = SKY_SHADER
    sky_mat.set_shader_parameter("clouds",CLOUDS)
    sky_mat.set_shader_parameter("sun_dir",moon.basis*Vector3(0,0,1))
    sky.sky_material = sky_mat
    res.background_mode = Environment.BG_SKY
    res.sky = sky
    res.background_color = Color(0.025,0.03,0.055)
    res.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    res.ambient_light_color = Color(0.52,0.48,0.66)
    res.ambient_light_energy = 0.85
    res.fog_enabled = false
    env.environment = res
    add_child(env)

# ----------------------------------------------------------------- scenery

func _build_track_props() -> void:
    # Deterministic per-track scenery: voxel cherry-blossom trees, dark
    # pines, soft tree shadows and pink flower clusters on the verge.
    # Every prop is rejected if it approaches ANY branch of road.
    var rng := RandomNumberGenerator.new()
    rng.seed = absi(hash(track_id))+PROP_SEED
    var n: int = centerline.size()
    var trees: Array[Dictionary] = []
    var next_s: float = 0.0
    for i in range(n):
        if arc_lengths[i] < next_s:
            continue
        next_s = arc_lengths[i]+rng.randf_range(7.0,13.0)
        var ahead: Vector2 = centerline[mini(i+1,n-1)] if not closed_loop else centerline[(i+1)%n]
        var behind: Vector2 = centerline[maxi(i-1,0)] if not closed_loop else centerline[(i-1+n)%n]
        var tangent: Vector2 = (ahead-behind).normalized()
        var normal := Vector2(-tangent.y,tangent.x)
        for side in [-1.0,1.0]:
            for ring in range(2):
                if rng.randf() < (0.30 if ring == 0 else 0.55):
                    continue
                var gap: float = rng.randf_range(5.5,13.0) if ring == 0 else rng.randf_range(16.0,34.0)
                var pos: Vector2 = centerline[i]+normal*side*(halfwidths[i]+VERGE_WIDTH+gap)+tangent*rng.randf_range(-4.0,4.0)
                var zone: float = sin(arc_lengths[i]*0.011+side*1.7)+rng.randf_range(-0.45,0.45)
                var cherry: bool = zone > 0.05
                var radius: float = rng.randf_range(2.3,3.3) if cherry else rng.randf_range(1.9,2.6)
                if road_clearance(pos) < radius+3.2:
                    continue
                var crowded: bool = false
                for other in trees:
                    if Vector2(other["pos"]).distance_to(pos) < (float(other["radius"])+radius)*0.95:
                        crowded = true
                        break
                if crowded:
                    continue
                trees.append({"pos":pos,"cherry":cherry,"radius":radius,
                    "height":rng.randf_range(0.9,1.2),"seed":rng.randi()})
    tree_positions.clear()
    for tree in trees:
        tree_positions.append(Vector2(tree["pos"]))
    _build_trees(trees)
    _build_verge_flowers(rng)

func _multimesh(label: String,mesh: Mesh,material: Material,transforms: Array[Transform3D],
        colours: Array[Color] = []) -> void:
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
    add_child(node)

func _build_trees(trees: Array[Dictionary]) -> void:
    # Same tree art as the procedural world (moved to NitroSceneryModules).
    PROC_WORLD.MODS.build_trees(self,trees)

func _build_verge_flowers(rng: RandomNumberGenerator) -> void:
    var n: int = centerline.size()
    var xf: Array[Transform3D] = []
    var cols: Array[Color] = []
    flower_positions.clear()
    for side in [-1.0,1.0]:
        var edge: Array[Vector2] = left_edge if side < 0.0 else right_edge
        var next_s: float = 0.0
        for i in range(_segment_count()):
            if arc_lengths[i] < next_s:
                continue
            next_s = arc_lengths[i]+rng.randf_range(0.8,2.2)
            if rng.randf() < 0.25:
                continue
            var j: int = (i+1)%n
            var t: float = rng.randf()
            var e: Vector2 = edge[i].lerp(edge[j],t)
            var inward: Vector2 = (right_edge[i]-left_edge[i]).normalized()
            var out_dir: Vector2 = -inward if side < 0.0 else inward
            var dist: float = rng.randf_range(VERGE_WIDTH*0.55,VERGE_WIDTH+3.0)
            var pos: Vector2 = e+out_dir*dist
            if road_clearance(pos) < 1.2:
                continue
            var size: float = rng.randf_range(0.9,1.9)
            var basis := Basis(Vector3.UP,rng.randf_range(0.0,TAU))*Basis.from_scale(Vector3(size,1.0,size))
            xf.append(Transform3D(basis,Vector3(pos.x,0.03,pos.y)))
            flower_positions.append(pos)
            cols.append(Color(1,1,1).lerp(Color(1.0,0.75,0.9),rng.randf()))
    var mat := StandardMaterial3D.new()
    mat.albedo_texture = FLOWERS
    mat.vertex_color_use_as_albedo = true
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
    mat.alpha_scissor_threshold = 0.45
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    var quad := PlaneMesh.new()
    quad.size = Vector2.ONE
    _multimesh("Verge blossom clusters",quad,mat,xf,cols)

# ---------------------------------------------------------- barrier advertising
## v0.1.36 (owner, driftit.app comparison): a band of printed boards on the inner
## face of both barriers ("advertising strip by the walls ... a sense of scale and
## speed at a low cost"). One extra mesh, one draw call. Only names of this game
## are printed (tools/art/make_track_textures.py). Reads left -> right for a driver.
const AD_PANEL_M: float = 2.4          # one board; the texture holds four
const AD_BOTTOM: float = 0.40
const AD_HEIGHT: float = 0.60
const AD_INSET: float = 0.012          # in front of the wall face (no z-fighting)

func _build_barrier_ads() -> void:
    var count: int = centerline.size()
    if count < 4:
        return
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var texture_len: float = AD_PANEL_M*4.0
    for side in [-1.0,1.0]:
        var run: float = 0.0
        for i in range(_segment_count()):
            var j: int = (i+1)%count
            var n0: Vector2 = (right_edge[i]-left_edge[i]).normalized()
            var n1: Vector2 = (right_edge[j]-left_edge[j]).normalized()
            var p: Vector2 = (left_edge[i] if side < 0.0 else right_edge[i])+n0*side*(0.10-AD_INSET)
            var q: Vector2 = (left_edge[j] if side < 0.0 else right_edge[j])+n1*side*(0.10-AD_INSET)
            var seg: float = p.distance_to(q)
            if seg < 0.001:
                continue
            # u grows with the driving direction on the left wall and against it
            # on the right wall, so the writing is never mirrored.
            var u0: float = run/texture_len
            var u1: float = (run+seg)/texture_len
            if side > 0.0:
                u0 = -u0
                u1 = -u1
            var ya: float = hy(i)
            var yb: float = hy(j)
            var pa := Vector3(p.x,ya+AD_BOTTOM,p.y)
            var pb := Vector3(p.x,ya+AD_BOTTOM+AD_HEIGHT,p.y)
            var qa := Vector3(q.x,yb+AD_BOTTOM,q.y)
            var qb := Vector3(q.x,yb+AD_BOTTOM+AD_HEIGHT,q.y)
            var tri: Array = [[pa,Vector2(u0,1)],[qa,Vector2(u1,1)],[pb,Vector2(u0,0)],
                [pb,Vector2(u0,0)],[qa,Vector2(u1,1)],[qb,Vector2(u1,0)]]
            for v in tri:
                st.set_normal(Vector3.UP)
                st.set_uv(v[1])
                st.add_vertex(v[0])
            run += seg
    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    mat.albedo_texture = BARRIER_ADS
    mat.albedo_color = Color(0.86,0.86,0.9)
    mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    var band := MeshInstance3D.new()
    band.name = "Barrier advertising band"
    band.mesh = st.commit()
    band.material_override = mat
    band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(band)

# ------------------------------------------------- NITRO WHEELZ road inscription
## v0.1.36 (owner, driftit.app comparison): ONE clear NITRO WHEELZ inscription in
## the middle of the asphalt on the longer straight sections, painted like road
## markings (letters stand up in the driving direction, stretched along the road).
const LOGO_MIN_STRAIGHT_M: float = 45.0
const LOGO_MAX_COUNT: int = 4
const LOGO_END_MARGIN_M: float = 28.0      # keep clear of the start / finish line
const LOGO_STRAIGHT_TOLERANCE_DEG: float = 6.0
const LOGO_HEIGHT: float = 0.064           # over the asphalt (0.05), under the edge lines (0.066)

## Centre arc length (m) and painted size of every inscription on this track:
## [{"arc": m, "width": across, "length": along}], longest straights first.
func road_logo_spots(min_straight_m: float = LOGO_MIN_STRAIGHT_M, tolerance_deg: float = LOGO_STRAIGHT_TOLERANCE_DEG) -> Array:
    var spots: Array = []
    var n: int = centerline.size()
    var segs: int = _segment_count()
    if n < 4 or segs < 4 or arc_lengths.size() < n:
        return spots
    var runs: Array = []
    var start: int = 0
    var heading0: float = 0.0
    for i in range(segs):
        var d: Vector2 = centerline[(i+1)%n]-centerline[i]
        if d.length_squared() < 0.0001:
            continue
        var h: float = atan2(d.y,d.x)
        if i == start:
            heading0 = h
            continue
        if absf(wrapf(h-heading0,-PI,PI)) > deg_to_rad(tolerance_deg):
            runs.append([start,i])
            start = i
            heading0 = h
    runs.append([start,segs])
    var finish_arcs: Array[float] = [arc_lengths[0]]
    if not closed_loop and finish_index > 0:
        finish_arcs = [arc_lengths[start_index],arc_lengths[finish_index]]
    for r in runs:
        var a0: float = arc_lengths[int(r[0])]
        var a1: float = arc_lengths[mini(int(r[1]),n-1)] if int(r[1]) < n else length_metres
        var run_len: float = a1-a0
        if run_len < min_straight_m:
            continue
        var mid: float = (a0+a1)*0.5
        var ok: bool = true
        for fa in finish_arcs:
            var gap: float = absf(mid-fa)
            if closed_loop:
                gap = minf(gap,length_metres-gap)
            if gap < LOGO_END_MARGIN_M:
                ok = false
        if not ok:
            continue
        var mi: int = clampi(int(r[0])+(int(r[1])-int(r[0]))/2,0,n-1)
        var width: float = minf(halfwidths[mi]*2.0*0.70,9.6)
        spots.append({"arc":mid,"width":width,"length":width*1.4,"run":run_len})
    spots.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x["run"]) > float(y["run"]))
    return spots.slice(0,LOGO_MAX_COUNT)

## Road point at an arc length: centre, unit vector across the road
## (left -> right), surface height.
func _road_at_arc(arc: float) -> Dictionary:
    var n: int = centerline.size()
    var segs: int = _segment_count()
    var a: float = arc
    if closed_loop:
        a = fposmod(arc,length_metres)
    var i := clampi(arc_lengths.bsearch(a,false)-1,0,segs-1)
    var j: int = (i+1)%n
    var seg_len: float = maxf(centerline[i].distance_to(centerline[j]),0.001)
    var t: float = clampf((a-arc_lengths[i])/seg_len,0.0,1.0)
    var left: Vector2 = left_edge[i].lerp(left_edge[j],t)
    var right: Vector2 = right_edge[i].lerp(right_edge[j],t)
    return {"centre":(left+right)*0.5,"across":(right-left).normalized(),
        "y":lerpf(hy(i),hy(j),t)}

func _build_road_logos() -> void:
    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    mat.albedo_texture = ROAD_LOGO
    mat.albedo_color = Color(1,1,1,0.92)
    mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    mat.no_depth_test = false
    var count: int = 0
    for spot in road_logo_spots():
        var arc: float = float(spot["arc"])
        var width: float = float(spot["width"])
        var length: float = float(spot["length"])
        var st := SurfaceTool.new()
        st.begin(Mesh.PRIMITIVE_TRIANGLES)
        var slices: int = 6
        var rows: Array = []
        for k in range(slices+1):
            var f: float = float(k)/float(slices)
            var at: Dictionary = _road_at_arc(arc+(f-0.5)*length)
            var c: Vector2 = at["centre"]
            var ac: Vector2 = at["across"]
            var y: float = LOGO_HEIGHT+float(at["y"])
            # v = 0 is the top of the picture = the far end (driving direction).
            rows.append([Vector3(c.x-ac.x*width*0.5,y,c.y-ac.y*width*0.5),
                Vector3(c.x+ac.x*width*0.5,y,c.y+ac.y*width*0.5),1.0-f])
        for k in range(slices):
            var r0: Array = rows[k]
            var r1: Array = rows[k+1]
            var quad: Array = [[r0[0],Vector2(0,r0[2])],[r0[1],Vector2(1,r0[2])],
                [r1[0],Vector2(0,r1[2])],[r1[1],Vector2(1,r1[2])]]
            for idx in [0,2,1,1,2,3]:
                st.set_normal(Vector3.UP)
                st.set_uv(quad[idx][1])
                st.add_vertex(quad[idx][0])
        var mesh := MeshInstance3D.new()
        mesh.name = "NITRO WHEELZ road inscription %d" % count
        mesh.mesh = st.commit()
        mesh.material_override = mat
        mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(mesh)
        count += 1

func _build_cloud_shadows() -> void:
    # One transparent plane over the whole park: drifting cloud shadows
    # darken asphalt, kerbs and grass (below the car, above the road).
    var lo := Vector2(INF,INF)
    var hi := Vector2(-INF,-INF)
    for p in left_edge+right_edge:
        lo = Vector2(minf(lo.x,p.x),minf(lo.y,p.y))
        hi = Vector2(maxf(hi.x,p.x),maxf(hi.y,p.y))
    var margin: float = 160.0
    var plane := PlaneMesh.new()
    plane.size = (hi-lo)+Vector2(margin,margin)*2.0
    var node := MeshInstance3D.new()
    node.name = "Cloud shadows"
    node.mesh = plane
    var mid: Vector2 = (lo+hi)*0.5
    node.position = Vector3(mid.x,0.095,mid.y)
    var mat := ShaderMaterial.new()
    mat.shader = CLOUD_SHADOW_SHADER
    mat.set_shader_parameter("clouds",CLOUDS)
    node.material_override = mat
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(node)
