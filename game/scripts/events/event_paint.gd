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
                var corners: Array[Vector3]=[]
                for station: float in [a,b]:
                    for edge in [-0.5,0.5]:
                        var d: float=strip[2]+edge*strip[3]
                        var t:=inverse_lerp(begin,end,station)
                        var u:=clampf(0.5+d/(track.halfwidths[i]*2),0,1)
                        # Interpolate the exact two asphalt triangles (same diagonal).
                        var left: Vector2=track.left_edge[i]
                        var right: Vector2=track.right_edge[j]
                        var p: Vector2
                        if u+t<=1:
                            p=left+(track.left_edge[j]-left)*t+(track.right_edge[i]-left)*u
                        else:
                            p=right+(track.right_edge[i]-right)*(1-t)+(track.left_edge[j]-right)*(1-u)
                        corners.append(Vector3(p.x,lerpf(track.hy(i),track.hy(j),t)+0.081,p.y))
                for idx in [0,2,1,1,2,3]:
                    st.set_color(strip[4])
                    st.add_vertex(corners[idx])
            i+=1
            a=b
    var mesh:=MeshInstance3D.new()
    mesh.name="Road paint"
    mesh.mesh=st.commit()
    var mat:=StandardMaterial3D.new()
    mat.vertex_color_use_as_albedo=true
    mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.cull_mode=BaseMaterial3D.CULL_DISABLED
    mesh.material_override=mat
    mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    track.add_child(mesh)
