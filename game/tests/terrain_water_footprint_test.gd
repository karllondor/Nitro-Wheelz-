extends SceneTree
## Measure the triangles used for the asphalt against the triangles of
## the rendered water ribbon, including both banks and the closing segment.
const WORLD = preload("res://scripts/world/terrain/terrain_world.gd")
const TT = preload("res://scripts/world/terrain/terrain_track.gd")
const CAT = preload("res://scripts/world/terrain/terrain_catalog.gd")
const DNA = preload("res://scripts/world/track_dna.gd")

func _initialize() -> void:
    run.call_deferred()

static func measure(w, comp: Dictionary) -> Dictionary:
    var vertices: PackedVector3Array = w.stream_node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
    var rows := []
    for i in range(0,vertices.size(),6):
        var p: Vector3 = vertices[i]
        var q: Vector3 = vertices[i+2]
        var a: Vector2 = w.field.to_local(p.x,p.z)
        var b: Vector2 = w.field.to_local(q.x,q.z)
        rows.append([a,b,p.y,q.y])
    var result := {"min":INF,"index":-1,"point":Vector2.ZERO,"sections":0}
    var n: int = comp.centerline.size()
    for i in range(n if comp.closed else n-1):
        var j := (i+1)%n
        var corners := PackedVector2Array()
        for p: Vector2 in [comp.left_edge[i],comp.right_edge[i],comp.left_edge[j],comp.right_edge[j]]:
            corners.append(w.field.to_local(p.x,p.y))
        var box := Rect2(corners[0],Vector2.ZERO)
        for p in corners:
            box=box.expand(p)
        for row in rows:
            var a: Vector2=row[0]
            var b: Vector2=row[1]
            if b.y<box.position.y or a.y>box.end.y or maxf(a.x,b.x)+2*w.STREAM_HALF_M<box.position.x or minf(a.x,b.x)>box.end.x:
                continue
            var span:=Vector2(2*w.STREAM_HALF_M,0)
            var ribbon:=PackedVector2Array([a,a+span,b+span,b])
            for ids in [[0,1,2],[1,3,2]]:
                var tri:=PackedVector2Array([corners[ids[0]],corners[ids[1]],corners[ids[2]]])
                if Geometry2D.is_polygon_clockwise(tri):
                    tri.reverse()
                var overlap:=Geometry2D.intersect_polygons(tri,ribbon)
                for poly in overlap:
                    result.sections+=1
                    for p in poly:
                        var denom: float=(corners[ids[1]]-corners[ids[0]]).cross(corners[ids[2]]-corners[ids[0]])
                        if absf(denom)<0.00001: continue
                        var u: float=(p-corners[ids[0]]).cross(corners[ids[2]]-corners[ids[0]])/denom
                        var v: float=(corners[ids[1]]-corners[ids[0]]).cross(p-corners[ids[0]])/denom
                        var t: float=v if ids[0]==0 else u+v
                        var deck:=lerpf(comp.heights[i],comp.heights[j],clampf(t,0,1))
                        var water:=lerpf(row[2],row[3],inverse_lerp(a.y,b.y,p.y))
                        if deck-water<result.min:
                            result.min=deck-water
                            result.index=i
                            result.point=w.field.to_world(p.x,p.y)
    return result

func run() -> void:
    var w=WORLD.new()
    var desc=CAT.descriptor("pl_ojcow",621727)
    w.with_lighting=false
    w.setup(desc)
    root.add_child(w)
    w.build()
    var loop: Dictionary=TT.generate_loop(TT.new_grid(),w.field,desc,3).data
    var grid=TT.new_grid()
    var lg: Dictionary=TT.load_grid(grid,loop)
    var route: Array[Vector2i]=[]
    route.assign(lg.order)
    route.pop_back()
    var edited_desc=desc.duplicate()
    edited_desc.road_style="road"
    var data:=TT.track_data(grid,route,false,w.field,edited_desc,"Open canyon road","water_route")
    route.reverse()
    route.pop_back()
    var changed:=TT.track_data(grid,route,false,w.field,edited_desc,"Edited route","water_edit")
    var failed:=false
    for item: Dictionary in [data,changed,loop]:
        var c:=DNA.compile(item)
        w.set_road(c.centerline,c.halfwidths,c.heights,c.closed)
        var lowered := 0
        var depth_min := INF
        for row in range(-440,441):
            var wp: Vector2 = w.field.to_world(w.field.stream_x(row),row)
            var water: float=w.stream_level(row)
            if water<w.stream_natural_level(row)-0.05:
                lowered+=1
                depth_min=minf(depth_min,water-w.height_at(wp.x,wp.y))
        print("Lowered channel ",lowered," sampled metres; minimum wet depth ",depth_min)
        if lowered==0 or depth_min<0.29: failed=true
        var r:=measure(w,c)
        print("WATER footprint ",item.id," width ",item.width_m," closed ",c.closed," intersections ",r.sections," minimum ",r.min," at ",r.point," segment ",r.index)
        if r.sections==0 or r.min<2.19: failed=true
    w.free()
    if not failed: print("PASS: rendered stream/deck footprint, saved route, edited open route and loop")
    quit(1 if failed else 0)
