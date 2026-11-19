extends SceneTree
## Regression (owner report v0.1.14): the car could pass through barriers.
## Only the car's centre was tested against the wall, so a nose- or tail-
## first hit pushed the front 2.4 m into and through the barrier. The whole
## oriented body (corners, bumpers, doors) must stay inside the barrier face.
const TRACK = preload("res://scripts/world/drift_track.gd")
const TRACKS: Array[String] = ["res://tracks/shin_kawa_v2.json","res://tracks/benchmark_oval.json",
    "res://tracks/benchmark_sweepers.json","res://tracks/shin_kawa_full_circuit.json"]

func _initialize() -> void:
    call_deferred("_run")

func _corner_depth(t: NitroDriftTrack, pos: Vector2, heading: float) -> float:
    var fwd := Vector2(sin(heading),-cos(heading))
    var rgt := Vector2(cos(heading),sin(heading))
    var hint: int = int(t.sample_info(pos)["index"])
    var worst: float = -INF
    for o in t.BODY_PROBES:
        var q: Vector2 = pos+fwd*(o.x*t.body_half_length)+rgt*(o.y*t.body_half_width)
        worst = maxf(worst,t._probe_penetration(q,hint).z)
    return worst

func _run() -> void:
    var tested: int = 0
    # Lada footprint, then the longer RYU-32 coupe footprint.
    for half_len in [2.30,2.52]:
      for path in TRACKS:
        var t: NitroDriftTrack = TRACK.new()
        t.track_data_path = path
        t.with_environment = false
        t.body_half_length = half_len
        root.add_child(t)
        await process_frame
        var n: int = t.centerline.size()
        for i in range(0,n,maxi(1,int(n/10))):
            var a: Vector2 = t.centerline[i]
            var tangent: Vector2 = (t.centerline[(i+1)%n]-a).normalized()
            var across := Vector2(-tangent.y,tangent.x)
            for side in [-1.0,1.0]:
                for nose_first in [true,false]:
                    var out: Vector2 = across*side
                    # Heading so the nose (or the tail) points straight at the wall.
                    var dir: Vector2 = out if nose_first else -out
                    var heading: float = atan2(dir.x,-dir.y)
                    var pos: Vector2 = a
                    var vel: Vector2 = out*16.0
                    var dt: float = 1.0/120.0
                    for step in range(150):
                        pos += vel*dt
                        var c: Dictionary = t.resolve_body(pos,heading,vel)
                        pos = c["position"]
                        vel = c["velocity"]
                        heading += float(c["yaw_impulse"])*dt
                        vel += out*16.0*dt*4.0  # keep pushing into the wall
                        var depth: float = _corner_depth(t,pos,heading)
                        if depth > 0.02:
                            _fail("%s sample %d: body %.2f m past the barrier face (%s)" % [
                                path.get_file(),i,depth,"nose" if nose_first else "tail"])
                            return
                    tested += 1
        # Centre-point test alone must be shown insufficient: a nose-first
        # car whose centre is still 1.5 m inside the edge already overlaps.
        var a0: Vector2 = t.centerline[0]
        var tan0: Vector2 = (t.centerline[1]-a0).normalized()
        var out0 := Vector2(-tan0.y,tan0.x)
        var half: float = float(t.sample_info(a0)["width"])
        var probe_pos: Vector2 = a0+out0*(half-1.5)
        var head0: float = atan2(out0.x,-out0.y)
        if bool(t.resolve_wall(probe_pos,out0)["hit"]):
            _fail("Fixture invalid: centre test already hits")
            return
        if not bool(t.resolve_body(probe_pos,head0,out0*5.0)["hit"]):
            _fail("Nose-first contact 1.5 m from the edge was not detected")
            return
        # Side-on along the road at the same spot is NOT a contact.
        if bool(t.resolve_body(probe_pos-out0*0.2,atan2(tan0.x,-tan0.y),tan0*20.0)["hit"]):
            _fail("Driving parallel near the kerb must not collide")
            return
        t.queue_free()
        await process_frame
    print("PASS: whole car body stays inside the barriers (%d nose/tail-first impacts on 4 tracks, Lada + RYU-32 footprints)" % tested)
    print("NOT RUN: on-device feel of the new wall yaw kick")
    quit(0)

func _fail(msg: String) -> void:
    printerr("FAIL: "+msg)
    quit(1)
