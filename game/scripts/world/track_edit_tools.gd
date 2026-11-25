extends RefCounted
class_name NitroTrackEditTools
## Data helpers of the NODE EDITOR (no UI), so the editor, the menu and the tests share one definition:
##  * which kind of circuit a saved file is (terrain-first / 3D tiles / nodes) and which can be opened,
##  * SET START and REVERSE on the control points (knot 0 = the start line, driving towards knot 1);
##    heights, widths and every other per-knot array follow the same permutation,
##  * the terrain of a terrain circuit: rebuild its landscape from the saved world descriptor, re-solve the road
##    heights on it (what the Terrain Builder does) and flag the stretches that cannot be built (water, cliff, ...),
##  * a picture of that landscape for the editor map, the list of circuits the editor can open.
## A circuit shaped in the node editor is marked `builder.nodes_edited`: its tiles describe an older road, so the
## Terrain Builder must not reload them over it (it refuses the file, the menu routes it to the node editor).
const DNA = preload("res://scripts/world/track_dna.gd")
const TT = preload("res://scripts/world/terrain/terrain_track.gd")
const CAT = preload("res://scripts/world/terrain/terrain_catalog.gd")
const FIELD = preload("res://scripts/world/terrain/terrain_field.gd")
const PROFILE = preload("res://scripts/world/terrain/road_profile.gd")

const LAST_SAVED: String = "user://nitro_editor_last_path.txt"
const MIN_ROAD_WIDTH_M: float = 12.0          # #29 ROAD / TOUGE surface width
const EVENT_NAMES: Dictionary = {"practice":"PRACTICE","club":"CLUB EVENT","pro":"PRO EVENT"}
const BUILTIN: Array = [
    ["SHIN-KAWA","res://tracks/shin_kawa_v2.json"],
    ["SHIN-KAWA • FULL CIRCUIT","res://tracks/shin_kawa_full_circuit.json"],
    ["OVAL","res://tracks/benchmark_oval.json"],
    ["SWEEPERS","res://tracks/benchmark_sweepers.json"],
    ["DRIFTWOOD CIRCUIT","res://tracks/driftwood_circuit.json"],
    ["TESTANDORI RACEWAY","res://tracks/testandori_raceway.json"],
    ["FUJI SPEEDWAY SHORT","res://tracks/fuji_speedway_short.json"]]

# ------------------------------------------------------------------------ kinds

## Point-to-point route (the node editor edits closed loops only).
static func is_open_route(data: Dictionary) -> bool:
    return not bool(data.get("closed",false)) and str(data.get("topology","")) == "open"

## "terrain" (Terrain Builder, has a landscape), "tiles" (3D tile builder) or "nodes" (edited / hand made).
static func kind_of(data: Dictionary) -> String:
    if not TT.world_of(data).is_empty():
        return "terrain"
    var b: Variant = data.get("builder",null)
    if b is Dictionary and not (b.get("tiles",[]) as Array).is_empty():
        return "tiles"
    return "nodes"

static func node_shaped(data: Dictionary) -> bool:
    var b: Variant = data.get("builder",null)
    return b is Dictionary and bool(b.get("nodes_edited",false))

## Called when the node editor saves: the builder tiles of a terrain circuit no longer describe this road.
static func mark_node_shaped(data: Dictionary) -> void:
    var b: Variant = data.get("builder",null)
    if b is Dictionary:
        b["nodes_edited"] = true
        data["builder"] = b

## #29 judged-event circuits (event_version 1): "CLUB EVENT • ROAD" etc.; "" for every other circuit.
static func event_label(data: Dictionary) -> String:
    if int(data.get("event_version",0)) != 1:
        return ""
    var mode: String = str(TT.world_of(data).get("event_mode","practice"))
    return "%s • %s" % [str(EVENT_NAMES.get(mode,"PRACTICE")),"ROAD" if is_narrow_road(data) else "CIRCUIT"]

## The narrow ROAD / TOUGE surface of #29 (12 m, no kerbs).
static func is_narrow_road(data: Dictionary) -> bool:
    return str(data.get("road_style","")) == "road"

static func kind_label(data: Dictionary) -> String:
    match kind_of(data):
        "terrain":
            var w: Dictionary = TT.world_of(data)
            var ev: String = event_label(data)
            return "TERRAIN • "+str(CAT.info(str(w["archetype"]))["short"])+(" • "+ev if ev != "" else "")
        "tiles":
            return "3D TILES"
    return "NODES"

# ------------------------------------------------------------------ start / direction

## Knot `index` becomes knot 0 (the start line); the road is unchanged, the direction of travel stays.
static func rotate_start(data: Dictionary, index: int) -> Dictionary:
    var n: int = (data.get("control_points",[]) as Array).size()
    if n < 2 or index <= 0 or index >= n:
        return data.duplicate(true)
    var order: Array = []
    for k in range(n):
        order.append((index+k)%n)
    return _permute(data,order)

## The other way round the same road; knot 0 stays the start line.
static func reverse_direction(data: Dictionary) -> Dictionary:
    var n: int = (data.get("control_points",[]) as Array).size()
    if n < 3:
        return data.duplicate(true)
    var order: Array = [0]
    for k in range(n-1,0,-1):
        order.append(k)
    return _permute(data,order)

static func _permute(data: Dictionary, order: Array) -> Dictionary:
    var d: Dictionary = data.duplicate(true)
    var n: int = order.size()
    d["control_points"] = _picked(data.get("control_points",[]),order)
    var widths: Variant = data.get("widths_m",[])
    if widths is Array and widths.size() == n:
        d["widths_m"] = _picked(widths,order)
    var el: Variant = d.get("elevation",null)
    if el is Dictionary:
        var kh: Variant = el.get("knot_heights",[])
        if kh is Array and kh.size() == n:
            el["knot_heights"] = _picked(kh,order)
    d["start_index"] = 0
    return d

static func _picked(src: Array, order: Array) -> Array:
    var out: Array = []
    for k in order:
        out.append(src[int(k)])
    return out

## Where the car starts and which way it faces for these control points (same rule as the race: knot 0 towards knot 1).
static func start_pose(data: Dictionary) -> Dictionary:
    var c: Dictionary = DNA.compile(data)
    if not bool(c.get("ok",false)):
        return {}
    var s: Array = c["centerline"]
    var n: int = s.size()
    var tangent: Vector2 = (Vector2(s[1])-Vector2(s[n-1])).normalized()
    return {"position":Vector2(s[0]),"heading":atan2(tangent.x,-tangent.y)}

# ------------------------------------------------------------------------ terrain

static func field_key(data: Dictionary) -> String:
    var w: Dictionary = TT.world_of(data)
    return "" if w.is_empty() else "%s/%d" % [str(w["archetype"]),int(w.get("terrain_seed",1))]

static func field_for(data: Dictionary) -> NitroTerrainField:
    var w: Dictionary = TT.world_of(data)
    if w.is_empty():
        return null
    return FIELD.new(str(w["archetype"]),int(w.get("terrain_seed",1)))

## Re-solve the road heights of `data` on `field` (exactly what the Terrain Builder does when it saves) and classify the
## road. Result: {ok, data (with the new "elevation"), flagged (knot indices over water / cliff / unbuildable ground),
## reasons (readable), max_grade}. ok = geometry valid AND nothing unbuildable.
static func fit_terrain(data: Dictionary, field: NitroTerrainField) -> Dictionary:
    var out: Dictionary = {"ok":true,"data":data,"flagged":[],"reasons":[],"max_grade":0.0}
    var w: Dictionary = TT.world_of(data)
    if w.is_empty() or field == null:
        return out
    var c: Dictionary = DNA.compile(data)
    if not bool(c.get("ok",false)):
        out["ok"] = false
        out["reasons"] = Array(c.get("errors",PackedStringArray()))
        return out
    var n: int = (data["control_points"] as Array).size()
    var grade: float = float(CAT.info(str(w["archetype"]))["grade"])
    var closed: bool = bool(c["closed"])
    var h: PackedFloat32Array = PROFILE.solve(field,c["centerline"],c["halfwidths"],closed,grade)
    var d: Dictionary = data.duplicate(true)
    d["elevation"] = {"version":TT.DATA_VERSION,"max_grade":grade,"knot_heights":PROFILE.knot_heights(h,n,DNA.SUBDIVISIONS)}
    var ev: Dictionary = TT.evaluate(field,d)
    out["data"] = d
    out["ok"] = bool(ev.get("ok",false))
    out["max_grade"] = float(ev.get("max_grade",0.0))
    for r in ev.get("errors",PackedStringArray()):
        out["reasons"].append(str(r))
    var cls: Variant = (ev.get("class",{}) as Dictionary).get("class",null)
    if cls is PackedInt32Array:
        var flagged: Dictionary = {}
        for i in range(cls.size()):
            if int(cls[i]) >= 6:
                var k: int = i/DNA.SUBDIVISIONS
                flagged[k%n] = true
                flagged[(k+1)%n] = true
        out["flagged"] = flagged.keys()
    return out

## The landscape as a small top-down picture for the editor map: sea / river blue, land shaded by height and slope.
## The picture covers x in [-HALF_X, HALF_X], z in [-HALF_Z, HALF_Z] (one pixel per field step).
static func terrain_image(field: NitroTerrainField) -> Image:
    var w: int = field.nx
    var hgt: int = field.nz
    var lo: float = INF
    var hi: float = -INF
    for v in field.base:
        lo = minf(lo,v)
        hi = maxf(hi,v)
    var span: float = maxf(hi-lo,1.0)
    var img: Image = Image.create(w,hgt,false,Image.FORMAT_RGB8)
    var step: float = FIELD.STEP
    for j in range(hgt):
        for i in range(w):
            var x: float = -FIELD.HALF_X+float(i)*step
            var z: float = -FIELD.HALF_Z+float(j)*step
            var col: Color
            if field.is_water(x,z):
                col = Color(0.10,0.27,0.46)
            else:
                var hh: float = field.base[j*w+i]
                var t: float = clampf((hh-lo)/span,0.0,1.0)
                var base_col: Color = Color(0.17,0.29,0.17).lerp(Color(0.46,0.40,0.27),clampf(t*1.6,0.0,1.0)).lerp(Color(0.72,0.72,0.74),clampf(t*1.6-0.9,0.0,1.0))
                var west: float = field.base[j*w+maxi(i-1,0)]
                var east: float = field.base[j*w+mini(i+1,w-1)]
                var north: float = field.base[maxi(j-1,0)*w+i]
                var south: float = field.base[mini(j+1,hgt-1)*w+i]
                var shade: float = clampf(0.62+((west-east)+(south-north))*0.05,0.32,1.1)
                col = Color(base_col.r*shade,base_col.g*shade,base_col.b*shade)
                var steep: float = (absf(east-west)+absf(south-north))/(2.0*step)
                if steep > 0.55:
                    col = col.lerp(Color(0.30,0.29,0.31),0.55)
            img.set_pixel(i,j,col)
    return img

## World rectangle (metres) that terrain_image() covers.
static func terrain_rect() -> Rect2:
    return Rect2(-FIELD.HALF_X,-FIELD.HALF_Z,FIELD.HALF_X*2.0,FIELD.HALF_Z*2.0)

## The tiles of the builder grid = the area where the Terrain Builder lets you put road.
static func play_rect() -> Rect2:
    return Rect2(-FIELD.PLAY_HALF_X,-FIELD.PLAY_HALF_Z,FIELD.PLAY_HALF_X*2.0,FIELD.PLAY_HALF_Z*2.0)

# --------------------------------------------------------------------- listing

static func _read(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return raw if raw is Dictionary else {}

## Every circuit the node editor can open: the player's saved tracks (newest first) and copies of the built-in circuits.
## {path, name, length, kind, label, open (point-to-point route: edited in the Terrain Builder), builtin, time}
static func list_tracks() -> Array[Dictionary]:
    var out: Array[Dictionary] = []
    for f in DirAccess.get_files_at("user://"):
        if not (f.begins_with("nitro_track_") and f.ends_with(".json")):
            continue
        var path: String = "user://"+f
        var raw: Dictionary = _read(path)
        if raw.is_empty():
            continue
        var c: Dictionary = DNA.compile(raw)
        if not bool(c.get("ok",false)):
            continue
        out.append({"path":path,"name":str(c["track_name"]),"length":float(c["length_metres"]),"kind":kind_of(raw),
            "label":kind_label(raw),"open":is_open_route(raw),"builtin":false,"time":FileAccess.get_modified_time(path)})
    out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["time"]) > int(b["time"]))
    for entry in BUILTIN:
        var raw2: Dictionary = _read(str(entry[1]))
        var c2: Dictionary = DNA.compile(raw2) if not raw2.is_empty() else {}
        if not bool(c2.get("ok",false)):
            continue
        out.append({"path":str(entry[1]),"name":str(entry[0]),"length":float(c2["length_metres"]),"kind":"builtin",
            "label":"BUILT-IN (OPENS AS A COPY)","open":false,"builtin":true,"time":0})
    return out

## The circuit an explicit "edit this track" request named (boot menu MY TRACKS / results write LAST_SAVED just before
## the scene change; the editor and the 3D tile builder write it when they save). "" = none / not a closed circuit.
static func marker_track_path() -> String:
    if FileAccess.file_exists(LAST_SAVED):
        var marked: String = FileAccess.get_file_as_string(LAST_SAVED).strip_edges()
        if marked.begins_with("user://nitro_track_") and FileAccess.file_exists(marked):
            var raw: Dictionary = _read(marked)
            if not raw.is_empty() and not is_open_route(raw) and bool(DNA.compile(raw).get("ok",false)):
                return marked
    return ""

## The circuit "TRACK BUILDER > EDIT NODES" opens: the one the player touched last — the explicit request above or the
## newest saved closed circuit of any builder (a circuit just built in the Terrain Builder is what they want to shape).
## "" = none (the editor then starts from the built-in circuit).
static func default_track_path() -> String:
    var newest: String = ""
    var newest_time: int = -1
    for t in list_tracks():
        if bool(t["builtin"]) or bool(t["open"]):
            continue
        if int(t["time"]) > newest_time:
            newest_time = int(t["time"])
            newest = str(t["path"])
    if FileAccess.file_exists(LAST_SAVED):
        var marked: String = FileAccess.get_file_as_string(LAST_SAVED).strip_edges()
        if marked.begins_with("user://nitro_track_") and FileAccess.file_exists(marked):
            var raw: Dictionary = _read(marked)
            if not raw.is_empty() and not is_open_route(raw) and bool(DNA.compile(raw).get("ok",false)):
                if newest == "" or FileAccess.get_modified_time(LAST_SAVED) >= newest_time:
                    return marked
    return newest
