extends RefCounted
const COLORS = {"OUTSIDE":Color("#42d9ca"),"CLIP":Color("#ffba43"),"INIT":Color("#af92ff"),"FLICK":Color("#ec78ad")}

static func build(track) -> void:
    var strips: Array = []
    if track.road_style=="road":
        var s:=0.0
        while s<track.length_metres:
            strips.append([s,minf(s+4,track.length_metres),0,0.24,Color.WHITE])
            s+=10
    for z in track.event_layout.zones:
        strips.append([z.a+0.12,z.b-0.12,z.d,z.band,COLORS[z.kind]])
    if strips.is_empty():
        return
    var st:=SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for strip in strips:
        var a: float=strip[0]
        var i:=maxi(0,track.arc_lengths.bsearch(a)-1)
        while i<track._segment_count() and a<float(strip[1])-0.0001:
            var j: int=(i+1)%track.centerline.size()
            var begin: float=track.arc_lengths[i]
            var end: float=track.length_metres if j==0 else track.arc_lengths[j]
            var b:=minf(end,strip[1])
            if b>a:
                var ta := clampf(inverse_lerp(begin,end,a),0.0,1.0)
                var tb := clampf(inverse_lerp(begin,end,b),0.0,1.0)
                var wa: float = lerpf(track.halfwidths[i],track.halfwidths[j],ta)*2.0
                var wb: float = lerpf(track.halfwidths[i],track.halfwidths[j],tb)*2.0
                var lo: float = strip[2]-strip[3]*0.5
                var hi: float = strip[2]+strip[3]*0.5
                var quad := [
                    Vector2(ta,clampf(0.5+lo/wa,0,1)),Vector2(tb,clampf(0.5+lo/wb,0,1)),
                    Vector2(tb,clampf(0.5+hi/wb,0,1)),Vector2(ta,clampf(0.5+hi/wa,0,1))]
                _emit_patch(st,track,i,j,_clip_diagonal(quad,1.0),strip[4],false)
                _emit_patch(st,track,i,j,_clip_diagonal(quad,-1.0),strip[4],true)
            i+=1
            a=b
    var mesh:=MeshInstance3D.new()
    mesh.name="Road paint"
    mesh.set_meta("fixed_paint_palette",true)
    mesh.mesh=st.commit()
    var mat:=StandardMaterial3D.new()
    mat.vertex_color_use_as_albedo=true
    mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.cull_mode=BaseMaterial3D.CULL_DISABLED
    mesh.material_override=mat
    mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    track.add_child(mesh)

## Clip at the actual asphalt diagonal. A quad that crosses it can bridge
## across the two road planes on a graded bend and intersect the asphalt.
static func _clip_diagonal(quad: Array, side: float) -> PackedVector2Array:
    var out := PackedVector2Array()
    var previous: Vector2 = quad.back()
    var distance := (previous.x+previous.y-1.0)*side
    for point: Vector2 in quad:
        var next_distance := (point.x+point.y-1.0)*side
        if (distance < 0.0) != (next_distance < 0.0):
            out.append(previous.lerp(point,distance/(distance-next_distance)))
        if next_distance <= 0.0:
            out.append(point)
        previous = point
        distance = next_distance
    return out

static func _emit_patch(st: SurfaceTool, track, i: int, j: int, patch: PackedVector2Array,
        color: Color, upper: bool) -> void:
    for v in range(1,patch.size()-1):
        if absf((patch[v]-patch[0]).cross(patch[v+1]-patch[0])) < 0.0000001:
            continue
        for uv in [patch[0],patch[v],patch[v+1]]:
            var p: Vector2
            if upper:
                p = track.right_edge[j]+(track.right_edge[i]-track.right_edge[j])*(1.0-uv.x) \
                    +(track.left_edge[j]-track.right_edge[j])*(1.0-uv.y)
            else:
                p = track.left_edge[i]+(track.left_edge[j]-track.left_edge[i])*uv.x \
                    +(track.right_edge[i]-track.left_edge[i])*uv.y
            st.set_color(color)
            st.set_normal(Vector3.UP)
            st.add_vertex(Vector3(p.x,lerpf(track.hy(i),track.hy(j),uv.x)+0.081,p.y))
