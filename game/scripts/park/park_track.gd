extends "res://scripts/world/drift_track.gd"
class_name NitroParkTrack
## NITRO WHEELZ PARK as a track (issue #27): one large flat paved surface, NO
## walls, kerbs or colliders, no finish line, painted guides, the full approved
## logo flat in the middle. race.gd talks to it through the same interface as
## to any circuit (`sample_info`, `resolve_body`, start pose ...), so nothing
## else in the game changes. Layout numbers: park_layout.gd (PROVISIONAL).
const LAYOUT = preload("res://scripts/park/park_layout.gd")
const LOGO_TEXTURE = preload("res://assets/brand/nitro_wheelz_logo_pavement.png")
const PAINT_SHADER = preload("res://assets/shaders/pavement_paint.gdshader")

const PAD_HEIGHT: float = 0.05
const PAINT_HEIGHT: float = 0.062
const LOGO_PAINT_HEIGHT: float = 0.066
const PAINT_WHITE := Color(0.92,0.92,0.90,0.92)
const PAINT_PINK := Color(1.0,0.45,0.78,0.92)
const PAINT_YELLOW := Color(1.0,0.82,0.30,0.92)

func is_park() -> bool:
    return true

func build() -> void:
    display_name = "NITRO WHEELZ PARK"
    track_id = "nitro_wheelz_park"
    closed_loop = false
    # Compatibility stub of a "route" so the code that reads the centre line
    # (HUD, camera, loaders) works; the Park has no finish and no laps.
    var s: Vector2 = LAYOUT.START_POS
    centerline = [s,s+Vector2(0,-10),s+Vector2(0,-20),s+Vector2(0,-30)]
    var half: Vector2 = LAYOUT.PAD_SIZE*0.5
    left_edge = [Vector2(-half.x,-half.y),Vector2(-half.x,half.y),Vector2(-half.x,half.y),Vector2(-half.x,half.y)]
    right_edge = [Vector2(half.x,-half.y),Vector2(half.x,half.y),Vector2(half.x,half.y),Vector2(half.x,half.y)]
    halfwidths = PackedFloat32Array([half.x,half.x,half.x,half.x])
    arc_lengths = PackedFloat32Array([0.0,10.0,20.0,30.0])
    length_metres = 30.0
    start_index = 0
    finish_index = -1
    finish_progress = 2.0            # never reached: a free surface has no finish
    heights = PackedFloat32Array()   # flat
    track_valid = true
    if with_environment:
        _build_environment()         # sky, moonlight, the big grass plane outside
    _build_pad()
    _build_guide_paint()
    _build_logo()
    # (no cloud shadows on the Park: a flat training pad must read evenly everywhere)

# ----------------------------------------------------------------- interface

func start_position() -> Vector2:
    return LAYOUT.START_POS

func start_heading() -> float:
    return LAYOUT.START_HEADING

## No road: the car is always "on the road", the width is effectively infinite
## (no kerb proximity), the progress is constant.
func sample_info(pos: Vector2) -> Dictionary:
    return {"distance":0.0,"point":pos,"index":0,"t":0.0,"width":100000.0,
        "progress":0.0,"tangent":Vector2(0,-1)}

## NOTHING to collide with: no walls, no cones (they move out of the way and
## never touch the car state), no barrier. The far soft edge is applied by the
## Park controller silently.
func resolve_body(pos: Vector2, _heading: float, travel_velocity: Vector2) -> Dictionary:
    return {"hit":false,"position":pos,"velocity":travel_velocity,"impact_speed":0.0,
        "normal":Vector2.ZERO,"yaw_impulse":0.0}

func resolve_wall(pos: Vector2, travel_velocity: Vector2) -> Dictionary:
    return {"hit":false,"position":pos,"velocity":travel_velocity,"impact_speed":0.0,"normal":Vector2.ZERO}

# --------------------------------------------------------------------- pad

func _material_unshaded(texture: Texture2D = null) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.vertex_color_use_as_albedo = true
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    if texture != null:
        mat.albedo_texture = texture
        mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    return mat

func _build_pad() -> void:
    var outline: PackedVector2Array = LAYOUT.pad_outline(0.0,12)
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var n: int = outline.size()
    for i in range(n):
        var a: Vector2 = outline[i]
        var b: Vector2 = outline[(i+1)%n]
        for p in [Vector2.ZERO,a,b]:
            st.set_color(ASPHALT_TINT)
            st.set_normal(Vector3.UP)
            st.set_uv(Vector2(p.x,p.y)/7.0)
            st.add_vertex(Vector3(p.x,PAD_HEIGHT,p.y))
    var mesh := MeshInstance3D.new()
    mesh.name = "Nitro Wheelz Park paving"
    mesh.mesh = st.commit()
    mesh.material_override = _material_unshaded(ASPHALT)
    mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(mesh)
    # A dark rim just outside the paving so the edge reads against the grass.
    var rim := LAYOUT.pad_outline(0.0,12)
    _ribbon_mesh("Paving edge",[{"pts":rim,"closed":true,"width":0.9,"on":1000.0,"off":0.0,
        "colour":Color(0.04,0.04,0.06,0.9),"offset":-0.0}],PAINT_HEIGHT-0.004)

# -------------------------------------------------------------- paint guides

## Painted guides: donut rings, the two eights, the flattened-eight line with
## direction chevrons and the pad's edge line. Paint only: NO collider.
func _build_guide_paint() -> void:
    var jobs: Array = []
    # Pad edge line (a continuous white line a little inside the paving).
    jobs.append({"pts":LAYOUT.pad_outline(-2.2,12),"closed":true,"width":0.30,"on":1000.0,"off":0.0,"colour":PAINT_WHITE})
    # Donut rings (dashed) + a small cross at the centre cone.
    for d in [LAYOUT.DONUT_LEFT,LAYOUT.DONUT_RIGHT]:
        jobs.append({"pts":_circle(d,LAYOUT.DONUT_RADIUS,72),"closed":true,"width":0.35,"on":3.2,"off":2.0,"colour":PAINT_WHITE})
        jobs.append({"pts":_circle(d,LAYOUT.DONUT_RADIUS*0.45,40),"closed":true,"width":0.22,"on":1.2,"off":1.6,"colour":PAINT_WHITE})
    # The two figure-eights.
    jobs.append({"pts":LAYOUT.eight_path(LAYOUT.EIGHT_LARGE_CENTRE,LAYOUT.EIGHT_LARGE_RADIUS,LAYOUT.EIGHT_SPREAD,1.0),
        "closed":true,"width":0.35,"on":3.2,"off":2.0,"colour":PAINT_WHITE})
    jobs.append({"pts":LAYOUT.eight_path(LAYOUT.EIGHT_SMALL_CENTRE,LAYOUT.EIGHT_SMALL_RADIUS,LAYOUT.EIGHT_SPREAD,1.0),
        "closed":true,"width":0.35,"on":3.2,"off":2.0,"colour":PAINT_PINK})
    # The longer flattened eight: a centre line and the corridor edges.
    var route: PackedVector2Array = LAYOUT.route_path(1.0)
    jobs.append({"pts":route,"closed":true,"width":0.40,"on":4.0,"off":2.5,"colour":PAINT_YELLOW})
    _ribbon_mesh("Park guide paint",jobs,PAINT_HEIGHT)
    _chevrons(route)

static func _circle(centre: Vector2, radius: float, count: int) -> PackedVector2Array:
    var out := PackedVector2Array()
    for k in range(count):
        var a: float = TAU*float(k)/float(count)
        out.append(centre+Vector2(cos(a),sin(a))*radius)
    return out

## One mesh for a list of painted polylines {pts, closed, width, on, off, colour}.
func _ribbon_mesh(label: String, jobs: Array, y: float) -> void:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var quads: int = 0
    for job in jobs:
        var pts: PackedVector2Array = job["pts"]
        var closed: bool = bool(job["closed"])
        var half_w: float = float(job["width"])*0.5
        var on: float = float(job["on"])
        var off: float = float(job["off"])
        var colour: Color = job["colour"]
        var n: int = pts.size()
        var count: int = n if closed else n-1
        var run: float = 0.0
        for i in range(count):
            var a: Vector2 = pts[i]
            var b: Vector2 = pts[(i+1)%n]
            var seg: float = a.distance_to(b)
            if seg < 0.0001:
                continue
            var period: float = on+off
            var on_here: bool = fposmod(run+seg*0.5,period) < on
            run += seg
            if not on_here:
                continue
            var dir: Vector2 = (b-a)/seg
            var nrm := Vector2(-dir.y,dir.x)*half_w
            # overlap the ends a hair so curves have no cracks
            var a2: Vector2 = a-dir*0.02
            var b2: Vector2 = b+dir*0.02
            for p in [a2-nrm,b2-nrm,a2+nrm,a2+nrm,b2-nrm,b2+nrm]:
                st.set_color(colour)
                st.set_normal(Vector3.UP)
                st.add_vertex(Vector3(p.x,y,p.y))
            quads += 1
    if quads == 0:
        return
    var mi := MeshInstance3D.new()
    mi.name = label
    mi.mesh = st.commit()
    var mat := _material_unshaded()
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.render_priority = -3
    mi.material_override = mat
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(mi)

## Direction chevrons along the route line (so the line reads as one direction).
func _chevrons(route: PackedVector2Array) -> void:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var next_at: float = 14.0
    var run: float = 0.0
    var n: int = route.size()
    for i in range(n):
        var a: Vector2 = route[i]
        var b: Vector2 = route[(i+1)%n]
        run += a.distance_to(b)
        if run < next_at:
            continue
        next_at += 34.0
        var dir: Vector2 = (b-a).normalized()
        var nrm := Vector2(-dir.y,dir.x)
        var tip: Vector2 = b+dir*1.6
        var l: Vector2 = b-dir*1.4+nrm*1.4
        var r: Vector2 = b-dir*1.4-nrm*1.4
        var l2: Vector2 = b-dir*0.5+nrm*0.7
        var r2: Vector2 = b-dir*0.5-nrm*0.7
        # a chevron = two thin quads meeting at the tip
        for tri in [[tip,l,l2],[tip,l2,r2],[tip,r2,r],[l,l2,tip]]:
            for p in tri:
                st.set_color(PAINT_YELLOW)
                st.set_normal(Vector3.UP)
                st.add_vertex(Vector3(p.x,PAINT_HEIGHT+0.002,p.y))
    var mi := MeshInstance3D.new()
    mi.name = "Park route chevrons"
    mi.mesh = st.commit()
    var mat := _material_unshaded()
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.render_priority = -3
    mi.material_override = mat
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(mi)

# --------------------------------------------------------------------- logo

## The approved full NITRO WHEELZ logo (nitro_wheelz_logo.svg, rasterised 1:1
## into nitro_wheelz_logo_pavement.png), lying flat at the centre. "Up" of the
## artwork is north, so it reads from the start position. A thin wear shader
## roughens the paint without touching outline, colours or proportions.
func _build_logo() -> void:
    var w: float = LAYOUT.LOGO_WIDTH
    var h: float = w*LAYOUT.LOGO_ASPECT
    var c: Vector2 = LAYOUT.LOGO_CENTRE
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var quad: Array = [[Vector2(-w*0.5,-h*0.5),Vector2(0,0)],[Vector2(w*0.5,-h*0.5),Vector2(1,0)],
        [Vector2(-w*0.5,h*0.5),Vector2(0,1)],[Vector2(-w*0.5,h*0.5),Vector2(0,1)],
        [Vector2(w*0.5,-h*0.5),Vector2(1,0)],[Vector2(w*0.5,h*0.5),Vector2(1,1)]]
    for v in quad:
        var p: Vector2 = v[0]
        st.set_normal(Vector3.UP)
        st.set_uv(v[1])
        st.add_vertex(Vector3(c.x+p.x,LOGO_PAINT_HEIGHT,c.y+p.y))
    var mi := MeshInstance3D.new()
    mi.name = "NITRO WHEELZ logo painted on the pavement"
    mi.mesh = st.commit()
    var mat := ShaderMaterial.new()
    mat.shader = PAINT_SHADER
    mat.set_shader_parameter("logo",LOGO_TEXTURE)
    mat.set_shader_parameter("size_m",Vector2(w,h))
    mat.render_priority = -2
    mi.material_override = mat
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(mi)
