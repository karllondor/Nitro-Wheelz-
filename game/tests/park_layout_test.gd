extends SceneTree
## NITRO WHEELZ PARK (issue #27) - the pavement, the paint, the logo, the cones.
##  * ONE continuous surface: every exercise (2 donuts, 2 eights, the long flattened
##    eight) fits inside it, nothing overlaps nothing, the start is on it;
##  * no collider of any kind: no walls, no kerbs, no cone bodies (CollisionObject3D);
##  * the logo is THE approved asset (git blob sha of nitro_wheelz_logo.svg unchanged,
##    the pavement PNG has the SVG's proportions), lies flat, is centred, never touched
##    by a cone;
##  * the figure-eight geometry is a real eight (crossing in the middle, the lobes turn
##    opposite ways); the long route has wide, forgiving curves (radius >= 17 m);
##  * cones: bounded count, none inside the logo, route cones never in the other strand;
##  * a starter car follows the long route inside the corridor (physics, weakest car);
##  * the far soft edge holds the car silently; cones never change the car.
const LAYOUT = preload("res://scripts/park/park_layout.gd")
const PARK_TRACK = preload("res://scripts/park/park_track.gd")
const CONES = preload("res://scripts/park/park_cones.gd")
const DRIVE = preload("res://scripts/driving/drive_model.gd")
const CARS = preload("res://scripts/vehicles/car_catalog.gd")
const RACE = preload("res://scenes/race.tscn")
## git blob sha1 of game/assets/brand/nitro_wheelz_logo.svg as verified on the
## owner-approved asset (issue #27, the "brand asset lock" comment).
const APPROVED_LOGO_BLOB: String = "f9d7b56850ce38baa91087cbd8e35e16e84d4920"

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    printerr("FAIL: "+message)
    quit(1)

func _blob_sha1(path: String) -> String:
    var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
    var ctx := HashingContext.new()
    ctx.start(HashingContext.HASH_SHA1)
    ctx.update(("blob %d" % bytes.size()).to_utf8_buffer())
    ctx.update(PackedByteArray([0]))
    ctx.update(bytes)
    return ctx.finish().hex_encode()

func _run() -> void:
    # ------------------------------------------------------------ one surface
    var ex: Array[Dictionary] = LAYOUT.exercises()
    if ex.size() != 5:
        _fail("expected 5 exercises (2 donuts, 2 eights, the long eight), got %d" % ex.size())
        return
    var footprints: Array = []        # [id, centre, half extents (x, z)]
    for e in ex:
        var c: Vector2 = e["centre"]
        var r: float = float(e["radius"])
        match str(e["kind"]):
            "donut":
                footprints.append([str(e["id"]),c,Vector2(r+4.0,r+4.0)])
            _:
                var spread: float = LAYOUT.ROUTE_SPREAD if str(e["kind"]) == "route" else LAYOUT.EIGHT_SPREAD
                var pad_m: float = 4.0+(LAYOUT.ROUTE_WIDTH*0.5 if str(e["kind"]) == "route" else 0.0)
                footprints.append([str(e["id"]),c,Vector2(r*(1.0+spread)+4.0,r+pad_m)])
    footprints.append(["logo",LAYOUT.LOGO_CENTRE,Vector2(LAYOUT.LOGO_WIDTH,LAYOUT.LOGO_WIDTH*LAYOUT.LOGO_ASPECT)*0.5])
    for i in range(footprints.size()):
        var fi: Array = footprints[i]
        var ci: Vector2 = fi[1]
        var hi_e: Vector2 = fi[2]
        for sx in [-1.0,1.0]:
            for sz in [-1.0,1.0]:
                if LAYOUT.pad_distance(ci+Vector2(hi_e.x*sx,hi_e.y*sz),0.0) > -1.0:
                    _fail("%s sticks out of the paved surface" % str(fi[0]))
                    return
        for k in range(i+1,footprints.size()):
            var fk: Array = footprints[k]
            var gx: float = absf(ci.x-Vector2(fk[1]).x)-hi_e.x-Vector2(fk[2]).x
            var gz: float = absf(ci.y-Vector2(fk[1]).y)-hi_e.y-Vector2(fk[2]).y
            if gx < 2.0 and gz < 2.0:
                _fail("%s and %s overlap (gaps %.1f / %.1f m)" % [str(fi[0]),str(fk[0]),gx,gz])
                return
    if LAYOUT.pad_distance(LAYOUT.START_POS,0.0) > -10.0:
        _fail("the start is not safely on the pavement")
        return
    # ------------------------------------------------------- the eights are eights
    for kind in [[LAYOUT.EIGHT_LARGE_CENTRE,LAYOUT.EIGHT_LARGE_RADIUS,LAYOUT.EIGHT_SPREAD],
            [LAYOUT.EIGHT_SMALL_CENTRE,LAYOUT.EIGHT_SMALL_RADIUS,LAYOUT.EIGHT_SPREAD],
            [LAYOUT.ROUTE_CENTRE,LAYOUT.ROUTE_RADIUS,LAYOUT.ROUTE_SPREAD]]:
        var path: PackedVector2Array = LAYOUT.eight_path(kind[0],float(kind[1]),float(kind[2]),0.75)
        var centre: Vector2 = kind[0]
        # the path crosses the middle twice
        var passes: int = 0
        var was_near: bool = false
        for q in path:
            var near: bool = q.distance_to(centre) < 1.2
            if near and not was_near:
                passes += 1
            was_near = near
        if passes != 2:
            _fail("an eight must cross its middle twice, got %d" % passes)
            return
        # one lobe left, the other right: signed turning per half
        var turn_west: float = 0.0
        var turn_east: float = 0.0
        for i2 in range(1,path.size()-1):
            var a: Vector2 = (path[i2]-path[i2-1]).normalized()
            var b: Vector2 = (path[i2+1]-path[i2]).normalized()
            var cross: float = a.x*b.y-a.y*b.x           # z south: + = clockwise on screen
            if path[i2].x < centre.x-1.0:
                turn_west += asin(clampf(cross,-1.0,1.0))
            elif path[i2].x > centre.x+1.0:
                turn_east += asin(clampf(cross,-1.0,1.0))
        if not (turn_west < -3.0 and turn_east > 3.0):
            _fail("the lobes must turn opposite ways (west %.1f rad, east %.1f rad)" % [turn_west,turn_east])
            return
        if LAYOUT.lobe_turn(0) != 1 or LAYOUT.lobe_turn(1) != -1:
            _fail("lobe_turn must say west = left (+1), east = right (-1)")
            return
    # the long route: wide forgiving curves (curvature radius >= 17 m everywhere)
    var route: PackedVector2Array = LAYOUT.route_path(1.0)
    var min_r: float = INF
    for i3 in range(route.size()):
        var p0: Vector2 = route[posmod(i3-3,route.size())]
        var p1: Vector2 = route[i3]
        var p2: Vector2 = route[(i3+3)%route.size()]
        var a1: Vector2 = (p1-p0)
        var b1: Vector2 = (p2-p1)
        var ang: float = absf(wrapf(b1.angle()-a1.angle(),-PI,PI))
        if ang > 0.001:
            min_r = minf(min_r,(a1.length()+b1.length())*0.5/ang)
    if min_r < LAYOUT.ROUTE_RADIUS*0.9:
        _fail("the long route has a curve tighter than a starter car likes: radius %.1f m" % min_r)
        return
    var route_len: float = LAYOUT.path_length(route)
    if route_len < 200.0 or route_len > 450.0:
        _fail("the long route is %.0f m (a miniature circuit: 200 .. 450 m)" % route_len)
        return
    # -------------------------------------------------------------------- cones
    var cones: Array[Dictionary] = LAYOUT.cones()
    if cones.size() < 40 or cones.size() > 130:
        _fail("cone count %d outside the mobile budget 40 .. 130" % cones.size())
        return
    var groups: Dictionary = {}
    for c in cones:
        groups[str(c["group"])] = int(groups.get(str(c["group"]),0))+1
        var cp: Vector2 = c["pos"]
        if LAYOUT.pad_distance(cp,0.0) > -2.0:
            _fail("a cone is off the pavement")
            return
        var lx: float = absf(cp.x-LAYOUT.LOGO_CENTRE.x)
        var lz: float = absf(cp.y-LAYOUT.LOGO_CENTRE.y)
        if lx < LAYOUT.LOGO_WIDTH*0.5+3.0 and lz < LAYOUT.LOGO_WIDTH*LAYOUT.LOGO_ASPECT*0.5+3.0:
            _fail("a cone stands on the logo")
            return
    for need in ["donut_left","donut_right","eight_large","eight_small","route_lobe","route"]:
        if int(groups.get(need,0)) < 2:
            _fail("cone group %s is missing (%s)" % [need,str(groups)])
            return
    if int(groups["route"]) < 30:
        _fail("the long route needs its cone lines (%d)" % int(groups["route"]))
        return
    for c2 in cones:
        if str(c2["group"]) != "route":
            continue
        var cp2: Vector2 = c2["pos"]
        var nearest: float = INF
        for q2 in route:
            nearest = minf(nearest,cp2.distance_to(q2))
        if nearest < LAYOUT.ROUTE_WIDTH*0.5-0.6 or nearest > LAYOUT.ROUTE_WIDTH*0.5+0.6:
            _fail("a route cone is %.1f m from the line, not on the corridor edge" % nearest)
            return
    # ------------------------------------------------------------ the logo asset
    var blob: String = _blob_sha1("res://assets/brand/nitro_wheelz_logo.svg")
    if blob != APPROVED_LOGO_BLOB:
        _fail("nitro_wheelz_logo.svg is not the owner-approved asset (blob %s)" % blob)
        return
    var svg: String = FileAccess.get_file_as_string("res://assets/brand/nitro_wheelz_logo.svg")
    if not svg.contains('viewBox="0 0 620 349"'):
        _fail("the approved logo viewBox changed")
        return
    var tex: Texture2D = load("res://assets/brand/nitro_wheelz_logo_pavement.png")
    var aspect: float = float(tex.get_height())/float(tex.get_width())
    if absf(aspect-LAYOUT.LOGO_ASPECT) > 0.004:
        _fail("the pavement logo texture has the wrong proportion %.4f (SVG %.4f)" % [aspect,LAYOUT.LOGO_ASPECT])
        return
    if tex.get_width() < 1200:
        _fail("the pavement logo texture is too small to read at game-camera scale (%d px)" % tex.get_width())
        return
    # ---------------------------------------------------- the track: no collider
    var track: NitroParkTrack = PARK_TRACK.new()
    track.with_environment = false
    root.add_child(track)
    track.build()
    if not track.track_valid or not track.is_park():
        _fail("the Park track did not build")
        return
    if not track.find_children("*","CollisionObject3D",true,false).is_empty() \
            or not track.find_children("*","CollisionShape3D",true,false).is_empty():
        _fail("the Park must have NO collider (no wall, no kerb, no cone body)")
        return
    for far in [Vector2(0,0),Vector2(400,400),Vector2(-900,10),LAYOUT.DONUT_LEFT,LAYOUT.ROUTE_CENTRE]:
        var hit: Dictionary = track.resolve_body(far,0.7,Vector2(20,5))
        if bool(hit["hit"]):
            _fail("resolve_body hit something at %s" % str(far))
            return
        var info: Dictionary = track.sample_info(far)
        if float(info["width"])-float(info["distance"]) < 1000.0 or float(info["progress"]) != 0.0:
            _fail("the Park must look like an infinitely wide, finish-less surface to the race code")
            return
    if track.finish_progress < 1.5 or track.closed_loop:
        _fail("the Park must have no finish and no laps")
        return
    var logo_mesh: MeshInstance3D = null
    var paint_ok: bool = false
    for ch in track.get_children():
        if str(ch.name).begins_with("NITRO WHEELZ logo"):
            logo_mesh = ch
        if str(ch.name) == "Park guide paint":
            paint_ok = true
    if logo_mesh == null or not paint_ok or track.find_child("Nitro Wheelz Park paving",false,false) == null:
        _fail("pavement, paint or the logo is missing")
        return
    var lv: PackedVector3Array = logo_mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
    var lo := Vector2(INF,INF)
    var hi := Vector2(-INF,-INF)
    var ys: Array[float] = []
    for v in lv:
        lo = Vector2(minf(lo.x,v.x),minf(lo.y,v.z))
        hi = Vector2(maxf(hi.x,v.x),maxf(hi.y,v.z))
        if not ys.has(v.y):
            ys.append(v.y)
    if ys.size() != 1 or ys[0] < 0.055 or ys[0] > 0.09:
        _fail("the logo must lie FLAT on the pavement (y values %s)" % str(ys))
        return
    var centre_err: float = ((lo+hi)*0.5).distance_to(LAYOUT.LOGO_CENTRE)
    if centre_err > 0.05 or absf((hi.x-lo.x)-LAYOUT.LOGO_WIDTH) > 0.05 or absf((hi.y-lo.y)/(hi.x-lo.x)-LAYOUT.LOGO_ASPECT) > 0.002:
        _fail("the logo is not centred / not in the artwork's proportions")
        return
    # -------------------------------------------- starter car follows the route
    var worst: String = ""
    for variant in ["e30","red"]:
        var m = DRIVE.new()
        m.apply_profile(CARS.handling(variant))
        var dir0: Vector2 = (route[2]-route[0]).normalized()
        m.reset(route[0],atan2(dir0.x,-dir0.y))
        m.velocity = m.forward()*(40.0/3.6)
        var cursor: int = 0
        var in_corridor: float = 0.0
        var total: float = 0.0
        var progress: float = 0.0
        var t: float = 0.0
        while t < 40.0:
            var best: int = cursor
            var bd: float = INF
            for k in range(-20,41):
                var i4: int = posmod(cursor+k,route.size())
                var d: float = m.position.distance_squared_to(route[i4])
                if d < bd:
                    bd = d
                    best = i4
            var moved: int = posmod(best-cursor+route.size()/2,route.size())-route.size()/2
            progress += float(maxi(moved,0))
            cursor = best
            var tgt: Vector2 = route[(cursor+8)%route.size()]
            var to: Vector2 = tgt-m.position
            var err: float = wrapf(atan2(to.x,-to.y)-m.heading,-PI,PI)
            m.step(1.0/240.0,clampf(err*1.6,-1.0,1.0),clampf(0.5+(40.0-m.speed_kmh())*0.04,0.0,1.0),0.0,0.0)
            t += 1.0/240.0
            total += 1.0
            if sqrt(bd) <= LAYOUT.ROUTE_WIDTH*0.5+1.2:
                in_corridor += 1.0
        var share: float = in_corridor/total
        if share < 0.9 or progress < route_len*0.9:
            worst = "%s: corridor %.2f, driven %.0f of %.0f m" % [variant,share,progress,route_len]
    if worst != "":
        _fail("a starter car cannot follow the long route at 40 km/h: "+worst)
        return
    # ------------------------------------------------- the race scene on the Park
    ProjectSettings.set_setting("nitro/selected_track",LAYOUT.TRACK_PATH)
    ProjectSettings.set_setting("nitro/park_mode","free")
    ProjectSettings.set_setting("nitro/car_variant","red")      # pinned: the garage choice persists between tests
    var race: Node3D = RACE.instantiate()
    root.add_child(race)
    await process_frame
    await process_frame
    if race.park == null or race.get("track") == null or not (race.track is NitroParkTrack):
        _fail("race.gd did not create the Park controller for the Park track")
        return
    if race.park.tutorial != null or race.park.guide != null:
        _fail("FREE DRIVE must have no tutorial and no guide")
        return
    if race.find_child("Park guide layer",true,false) != null:
        _fail("FREE DRIVE must not create the guide layer")
        return
    # the soft edge: far away -> held at the edge, silently
    race.model.position = Vector2(2000,2000)
    race.model.velocity = Vector2(30,30)
    var cooldown_before: float = race.collision_cooldown
    race._physics_process(1.0/120.0)
    var d_edge: float = LAYOUT.pad_distance(race.model.position,0.0)
    if d_edge > LAYOUT.SOFT_EDGE_M+0.8:
        _fail("the soft edge did not hold the car (%.1f m outside the paving)" % d_edge)
        return
    if race.wall_collision_count != 0 or race.collision_cooldown != cooldown_before:
        _fail("the soft edge must be silent (no wall feedback)")
        return
    # cones never change the car: drive straight through the donut cones with and without cones
    var results: Array = []
    for with_cones in [true,false]:
        race.model.reset(LAYOUT.DONUT_LEFT+Vector2(-30.0,0.2),deg_to_rad(90.0))
        race.model.velocity = race.model.forward()*14.0
        race.park.cones.reset_all()
        if not with_cones:
            for i5 in range(race.park.cones.positions.size()):
                race.park.cones.positions[i5] = Vector2(5000,5000)
        for k in range(360):
            race._physics_process(1.0/120.0)
        results.append([race.model.position,race.model.velocity,race.model.heading])
    var a_res: Array = results[0]
    var b_res: Array = results[1]
    if Vector2(a_res[0]).distance_to(Vector2(b_res[0])) > 0.0001 or Vector2(a_res[1]).distance_to(Vector2(b_res[1])) > 0.0001:
        _fail("cones changed the car: with %s without %s" % [str(a_res[0]),str(b_res[0])])
        return
    print("PASS: Nitro Wheelz Park - one surface with 5 exercises + the logo, no overlap, no collider anywhere, the approved logo asset (blob %s) lying flat and centred, real figure-eights (two crossings, opposite lobes), the long route %.0f m with curves >= %.0f m radius that a starter car follows (E30 and Lada), %d cones (route cone lines on the corridor edge, none on the logo), silent soft edge, cones never change the car" % [blob.substr(0,8),route_len,min_r,cones.size()])
    quit(0)
