extends SceneTree
## v0.1.25 terrain-first world:
##  * 8 archetypes x 10 fixed seeds: deterministic (same seed = same terrain,
##    different seeds = different terrain), enough buildable tiles;
##  * a generated loop on every archetype: valid, no red sample, grade within
##    the archetype target, closed loops periodic (h(0) == h(L), no step);
##  * Tatry / Touge real gradients; open route on each country;
##  * Irish cliff edge: a road along the cliff shelf keeps the FULL road
##    width + verge on land, gets cliff walls, and the 20 m rule refuses
##    tiles at the edge.
const CAT = preload("res://scripts/world/terrain/terrain_catalog.gd")
const FIELD = preload("res://scripts/world/terrain/terrain_field.gd")
const TT = preload("res://scripts/world/terrain/terrain_track.gd")
const PROFILE = preload("res://scripts/world/terrain/road_profile.gd")
const WORLD = preload("res://scripts/world/terrain/terrain_world.gd")
const DNA = preload("res://scripts/world/track_dna.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(msg: String) -> void:
    print("FAIL: "+msg)
    quit(1)

func _run() -> void:
    var t_start: int = Time.get_ticks_msec()
    var report: PackedStringArray = []
    # --- determinism + buildability, 8 x 10 seeds
    for a in CAT.ORDER:
        var prints: Dictionary = {}
        var worst_build: int = 999
        for seed_value in range(1,11):
            var f: NitroTerrainField = FIELD.new(a,seed_value)
            f.bake()
            var fp: int = f.fingerprint()
            if prints.has(fp):
                _fail("%s: seeds %d and %d gave the same terrain" % [a,int(prints[fp]),seed_value])
                return
            prints[fp] = seed_value
            if seed_value <= 2:
                var again: NitroTerrainField = FIELD.new(a,seed_value)
                again.bake()
                if again.fingerprint() != fp or again.base != f.base:
                    _fail("%s seed %d is not deterministic" % [a,seed_value])
                    return
            var map: Dictionary = f.build_map()
            var ok_tiles: int = 0
            for c in map.keys():
                if int(map[c]["state"]) < 2:
                    ok_tiles += 1
            worst_build = mini(worst_build,ok_tiles)
        if worst_build < 90:
            _fail("%s: only %d of 192 tiles buildable on its worst seed" % [a,worst_build])
            return
        report.append("%s>=%d" % [str(CAT.info(a)["short"]),worst_build])
    # --- a generated loop on every archetype
    var grades: PackedStringArray = []
    for a2 in CAT.ORDER:
        var desc: Dictionary = CAT.descriptor(a2,1)
        var f2: NitroTerrainField = FIELD.new(a2,1)
        f2.bake()
        var grid: NitroTrackGrid = TT.new_grid()
        var gen: Dictionary = TT.generate_loop(grid,f2,desc,7)
        if not bool(gen.get("ok",false)):
            _fail("%s: no buildable loop generated" % a2)
            return
        var ev: Dictionary = gen["eval"]
        var comp: Dictionary = ev["compiled"]
        var h: PackedFloat32Array = comp["heights"]
        var c: Array = comp["centerline"]
        var target: float = float(CAT.info(a2)["grade"])
        var gmax: float = float(ev["max_grade"])
        if gmax > target*1.10+0.002:
            _fail("%s: max grade %.2f %% above the %.1f %% target" % [a2,gmax*100.0,target*100.0])
            return
        var n: int = c.size()
        for i in range(n):
            var j: int = (i+1)%n
            var ds: float = (c[i] as Vector2).distance_to(c[j])
            if absf(h[j]-h[i]) > target*1.25*ds+0.05:
                _fail("%s: height step %.2f m over %.1f m at sample %d (closing joint %s)" % [a2,absf(h[j]-h[i]),ds,i,j == 0])
                return
        if int(ev["class"]["worst"]) >= 2:
            _fail("%s: generated loop has unbuildable samples" % a2)
            return
        grades.append("%s %.1f/%.0f%%" % [str(CAT.info(a2)["short"]),gmax*100.0,target*100.0])
    # Mountain archetypes really climb.
    for a3 in ["pl_tatry","jp_touge"]:
        var f3: NitroTerrainField = FIELD.new(a3,1)
        f3.bake()
        var g3: NitroTrackGrid = TT.new_grid()
        var r3: Dictionary = TT.generate_loop(g3,f3,CAT.descriptor(a3,1),7)
        var hh: PackedFloat32Array = r3["eval"]["compiled"]["heights"]
        var lo: float = INF
        var hi: float = -INF
        for v in hh:
            lo = minf(lo,v)
            hi = maxf(hi,v)
        if hi-lo < 15.0 or float(r3["eval"]["max_grade"]) < float(CAT.info(a3)["grade"])*0.6:
            _fail("%s: road should climb (%.1f m, %.1f %%)" % [a3,hi-lo,float(r3["eval"]["max_grade"])*100.0])
            return
    # --- open routes in each country
    for a4 in ["jp_forest","pl_ojcow","ie_hills"]:
        var f4: NitroTerrainField = FIELD.new(a4,3)
        f4.bake()
        var g4: NitroTrackGrid = TT.new_grid()
        var r4: Dictionary = TT.generate_route(g4,f4,CAT.descriptor(a4,3),3)
        if not bool(r4.get("ok",false)):
            _fail("%s: no open route generated" % a4)
            return
        var cp: Dictionary = r4["eval"]["compiled"]
        if bool(cp["closed"]) or (cp["heights"] as PackedFloat32Array).size() != (cp["centerline"] as Array).size():
            _fail("%s: route must compile open with heights" % a4)
            return
        var hr: PackedFloat32Array = cp["heights"]
        if absf(hr[0]-hr[hr.size()-1]) < 0.0001 and hr.size() > 2:
            pass  # equal ends are allowed, just not required
    # --- Irish cliff edge: road along the cliff shelf
    var fc: NitroTerrainField = FIELD.new("ie_coast",1)
    fc.bake()
    var map2: Dictionary = fc.build_map()
    var edge_refused: int = 0
    for k in map2.keys():
        if str(map2[k]["reason"]).begins_with("CLIFF EDGE"):
            edge_refused += 1
    if edge_refused == 0:
        _fail("Cliff edge tiles must be refused (20 m rule)")
        return
    # A 24 m-wide road that follows the cliff with its centre line 24 m from
    # the drop (asphalt edge 12 m, verge edge 8.4 m from the edge) along a
    # 300 m stretch of fairly straight cliff (the first one found).
    var descc: Dictionary = {}
    var evc: Dictionary = {}
    var found: String = ""
    for sd in range(1,6):
        fc = FIELD.new("ie_coast",sd)
        fc.bake()
        var z0: float = -420.0
        while z0 <= 120.0 and found == "":
            var straight: bool = true
            var zz: float = z0
            while zz <= z0+300.0:
                if absf((fc.coast_x(zz+8.0)-fc.coast_x(zz-8.0))/16.0) > 0.55:
                    straight = false
                    break
                zz += 10.0
            if straight:
                var cps: Array = []
                var z: float = z0
                while z <= z0+300.0:
                    var slope: float = (fc.coast_x(z+12.0)-fc.coast_x(z-12.0))/24.0
                    var nrm := Vector2(1.0,-slope).normalized()
                    var q: Vector2 = Vector2(fc.coast_x(z),z)+nrm*24.0
                    cps.append([snappedf(q.x,0.001),snappedf(q.y,0.001)])
                    z += 50.0
                descc = CAT.descriptor("ie_coast",sd)
                var datac: Dictionary = {"schema_version":1,"id":"cliff","name":"cliff","closed":false,"topology":"open",
                    "width_m":24.0,"control_points":cps,"world":descc}
                var flatc: Dictionary = DNA.compile(datac)
                if bool(flatc.get("ok",false)):
                    var hc: PackedFloat32Array = PROFILE.solve(fc,flatc["centerline"],flatc["halfwidths"],false,0.03)
                    datac["elevation"] = {"version":1,"max_grade":0.03,"knot_heights":PROFILE.knot_heights(hc,cps.size(),DNA.SUBDIVISIONS)}
                    var ev2: Dictionary = TT.evaluate(fc,datac)
                    if bool(ev2["ok"]):
                        evc = ev2
                        found = "seed %d z %d..%d" % [sd,int(z0),int(z0+300.0)]
            z0 += 30.0
        if found != "":
            break
    if found == "":
        _fail("No straight cliff stretch accepted a full-width road 24 m from the drop")
        return
    var compc: Dictionary = evc["compiled"]
    var cc: Array = compc["centerline"]
    var hwc: PackedFloat32Array = compc["halfwidths"]
    var min_land: float = INF
    var nearest_centre: float = INF
    for i3 in range(cc.size()):
        var nrm: Vector2 = PROFILE._normal(cc,i3,false)
        nearest_centre = minf(nearest_centre,fc.coast_distance((cc[i3] as Vector2).x,(cc[i3] as Vector2).y))
        for side in [-1.0,1.0]:
            var e: Vector2 = (cc[i3] as Vector2)+nrm*side*(hwc[i3]+PROFILE.VERGE)
            min_land = minf(min_land,fc.coast_distance(e.x,e.y))
    if min_land < PROFILE.CLIFF_CLEAR_M:
        _fail("Road edge + verge must stay on land along the cliff (%.1f m)" % min_land)
        return
    var classes: PackedInt32Array = evc["class"]["class"]
    if not classes.has(5):
        _fail("A road this close to the cliff must get a cliff barrier class (nearest centre %.1f m)" % nearest_centre)
        return
    var wc := WORLD.new()
    wc.with_lighting = false
    wc.setup(descc)
    wc.field = fc
    root.add_child(wc)
    wc.build()
    wc.set_road(cc,hwc,compc["heights"],false)
    if float(wc.structure_counts().get("cliff_wall_m",0.0)) < 20.0:
        _fail("Cliff-side road needs a stone cliff wall (got %s)" % [wc.structure_counts()])
        return
    print("PASS: terrain world - 8 archetypes x 10 seeds deterministic + distinct (buildable tiles worst seed: %s), loops on all 8 within grade targets (%s), closed loops periodic, Tatry/Touge climb, open routes in 3 countries, Irish cliff-edge road (centre 24 m from the drop, 300 m, %s) keeps full width + verge on land (min %.1f m, centre %.1f m from the drop) with %d m of cliff wall, %d edge tiles refused - %.1f s" % [
        ", ".join(report),", ".join(grades),found,min_land,nearest_centre,int(float(wc.structure_counts()["cliff_wall_m"])),edge_refused,
        float(Time.get_ticks_msec()-t_start)/1000.0])
    quit(0)
