extends SceneTree
## Issue #19 ("rzeka na drodze", Ojców, v0.1.33): the canyon stream was a ribbon at
## the channel ground + 1.0 m built independently of the road, so over the road's
## bridge sections the water was above (or coplanar with) the asphalt.
## On the Ojców valley (the owner's seed 621727 and seed 2), four generated loops
## each, with the REAL terrain world:
##  * control: with the natural (v0.1.33) level the water is within 0.3 m of the
##    asphalt or above it on many road samples - the test is not blind;
##  * with the road set, the stream MESH is >= 2.0 m below the road surface at
##    every sample whose asphalt (half-width) lies over the ribbon (slab
##    underside is 1.6 m below the surface), also at segment midpoints;
##  * the water never leaves its natural level without a ramp: no step steeper
##    than 0.9 between neighbouring ribbon vertices (rapids, never a cliff);
##  * samples that do not touch the ribbon keep the natural level (the stream is
##    not hidden or flattened globally) and clearing the road restores the natural
##    ribbon exactly;
##  * the same road gives the same ribbon on a fresh world (builder / race / reload)
##    and after edit -> other road -> undo (same road again);
##  * a world without a stream (Touge) gets no stream node.
const CAT = preload("res://scripts/world/terrain/terrain_catalog.gd")
const TT = preload("res://scripts/world/terrain/terrain_track.gd")
const WORLD = preload("res://scripts/world/terrain/terrain_world.gd")
const CLEARANCE: float = 2.0

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var t0: int = Time.get_ticks_msec()
    var err: String = await _checks()
    if not err.is_empty():
        printerr("FAIL: "+err)
        quit(1)
        return
    print("PASS: Ojców stream vs road - water held >= %.1f m below the road surface over every bridge section (%s), natural level kept elsewhere, no step steeper than 0.9, clear / undo / fresh world give the identical ribbon, control: the v0.1.33 level was within 0.3 m of the asphalt or above it on %d samples (%.0f s)" % [
        CLEARANCE,_summary,_control_hits,float(Time.get_ticks_msec()-t0)/1000.0])
    for _f in range(3):
        await process_frame
    quit(0)

var _summary: String = ""
var _control_hits: int = 0

func _world(desc: Dictionary) -> NitroTerrainWorld:
    var w: NitroTerrainWorld = WORLD.new()
    w.with_lighting = false
    w.setup(desc)
    root.add_child(w)
    w.build()
    return w

func _road(w: NitroTerrainWorld, desc: Dictionary, route_seed: int) -> Dictionary:
    var grid: NitroTrackGrid = TT.new_grid()
    var gen: Dictionary = TT.generate_loop(grid,w.field,desc,route_seed)
    if not bool(gen.get("ok",false)):
        return {}
    var comp: Dictionary = gen["eval"]["compiled"]
    var smp: Array[Vector2] = []
    for p in comp["centerline"]:
        smp.append(p)
    return {"samples":smp,"hw":comp["halfwidths"],"h":comp["heights"]}

# (local z, y) pairs of the stream mesh, sorted by z.
func _ribbon(w: NitroTerrainWorld) -> Array:
    var arrays: Array = w.stream_node.mesh.surface_get_arrays(0)
    var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
    var pairs: Array = []
    for v in vs:
        pairs.append([w.field.to_local(v.x,v.z).y,v.y])
    pairs.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
    return pairs

func _level_at(pairs: Array, lz: float) -> float:
    var lo: int = 0
    var hi: int = pairs.size()-1
    while hi-lo > 1:
        var mid: int = (lo+hi)/2
        if float(pairs[mid][0]) <= lz:
            lo = mid
        else:
            hi = mid
    var za: float = float(pairs[lo][0])
    var zb: float = float(pairs[hi][0])
    var t: float = clampf((lz-za)/maxf(zb-za,0.0001),0.0,1.0)
    return lerpf(float(pairs[lo][1]),float(pairs[hi][1]),t)

func _hash(w: NitroTerrainWorld) -> int:
    return hash(w.stream_node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX])

func _checks() -> String:
    var crossing_samples: int = 0
    var routes_done: int = 0
    var min_clear: float = INF
    for world_seed in [621727,2]:
        var desc: Dictionary = CAT.descriptor("pl_ojcow",world_seed)
        var w: NitroTerrainWorld = _world(desc)
        if w.stream_node == null:
            return "An Ojców world must have a stream"
        var natural_hash: int = _hash(w)
        var roads: Array = []
        for route_seed in [3,5,7,11]:
            var r: Dictionary = _road(w,desc,route_seed)
            if r.is_empty():
                continue
            roads.append(r)
        if roads.is_empty():
            return "No loop could be generated on Ojców seed %d" % world_seed
        for r2 in roads:
            var smp: Array[Vector2] = r2["samples"]
            var hw: PackedFloat32Array = r2["hw"]
            var rh: PackedFloat32Array = r2["h"]
            w.set_road(smp,hw,rh,true)
            var pairs: Array = _ribbon(w)
            routes_done += 1
            for i in range(smp.size()):
                var l: Vector2 = w.field.to_local(smp[i].x,smp[i].y)
                var off: float = absf(l.x-w.field.stream_x(l.y))
                var nat: float = w.stream_natural_level(l.y)
                if off < w.STREAM_HALF_M+hw[i]:
                    crossing_samples += 1
                    if rh[i]-nat < 0.3:
                        _control_hits += 1
                    var clear: float = rh[i]-_level_at(pairs,l.y)
                    min_clear = minf(min_clear,clear)
                    if clear < CLEARANCE-0.001:
                        return "Ojców seed %d: the water is only %.2f m below the road surface over sample %d (needs >= %.1f m)" % [world_seed,clear,i,CLEARANCE]
                    # Midway to the next sample (the ribbon is linear between vertices).
                    var j: int = (i+1)%smp.size()
                    var mid: Vector2 = (smp[i]+smp[j])*0.5
                    var lm: Vector2 = w.field.to_local(mid.x,mid.y)
                    if absf(lm.x-w.field.stream_x(lm.y)) < w.STREAM_HALF_M+hw[i]:
                        var cm: float = (rh[i]+rh[j])*0.5-_level_at(pairs,lm.y)
                        if cm < CLEARANCE-0.3:
                            return "Ojców seed %d: the water is %.2f m below the road surface between samples %d / %d" % [world_seed,cm,i,j]
            # Far (along the stream) from every crossing the level is the natural one: the
            # stream is not hidden or flattened globally.
            for pr in pairs:
                var near := INF
                var at: Vector2 = w.field.to_world(w.field.stream_x(pr[0]),pr[0])
                for i in range(smp.size()):
                    near=minf(near,at.distance_to(smp[i])-hw[i])
                if near>40.0 and absf(float(pr[1])-w.stream_natural_level(float(pr[0])))>0.01:
                    return "Far water changed on Ojców seed %d" % world_seed
            # No cliffs in the ribbon.
            for k in range(1,pairs.size()):
                var dz: float = float(pairs[k][0])-float(pairs[k-1][0])
                if dz > 0.2 and absf(float(pairs[k][1])-float(pairs[k-1][1]))/dz > 0.9:
                    return "The ribbon steps %.2f m over %.2f m (rapids must stay a ramp)" % [absf(float(pairs[k][1])-float(pairs[k-1][1])),dz]
        # Clearing the road restores the natural ribbon; the same road again gives the same ribbon.
        var first: Dictionary = roads[0]
        w.set_road(first["samples"],first["hw"],first["h"],true)
        var hash_first: int = _hash(w)
        w.set_road(roads[roads.size()-1]["samples"],roads[roads.size()-1]["hw"],roads[roads.size()-1]["h"],true)
        w.set_road(first["samples"],first["hw"],first["h"],true)
        if _hash(w) != hash_first:
            return "edit -> other road -> undo must give the identical ribbon"
        var empty: Array[Vector2] = []
        w.set_road(empty,PackedFloat32Array(),PackedFloat32Array(),true)
        if _hash(w) != natural_hash:
            return "Clearing the road must restore the natural stream exactly"
        # A fresh world (race / reload) with the same road.
        var w2: NitroTerrainWorld = _world(desc)
        w2.set_road(first["samples"],first["hw"],first["h"],true)
        if _hash(w2) != hash_first:
            return "A fresh world with the same road must build the identical ribbon (builder vs race)"
        root.remove_child(w)
        w.free()
        root.remove_child(w2)
        w2.free()
    if crossing_samples < 20 or _control_hits < 10:
        return "The test roads barely cross the stream (%d samples, %d control hits): the check is blind" % [crossing_samples,_control_hits]
    # A world without a stream.
    var dj: Dictionary = CAT.descriptor("jp_touge",1)
    var wj: NitroTerrainWorld = _world(dj)
    if wj.stream_node != null:
        return "Only canyon worlds have a stream"
    root.remove_child(wj)
    wj.free()
    _summary = "%d loops, %d road samples over the stream, minimum clearance %.2f m" % [routes_done,crossing_samples,min_clear]
    return ""
