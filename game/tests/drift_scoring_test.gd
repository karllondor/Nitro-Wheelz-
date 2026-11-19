extends SceneTree
## P3 drift scoring regression: chain banking, duration multiplier, kerb
## proximity, left/right transitions, wall and spin penalties.
const SCORER = preload("res://scripts/race/drift_scorer.gd")
const DT: float = 1.0/120.0

func _initialize() -> void:
    call_deferred("_run")

func _drive(s: NitroDriftScorer, seconds: float, angle: float, speed: float, edge: float, drifting: bool = true) -> void:
    for i in range(int(round(seconds/DT))):
        s.update(DT,drifting,angle,speed,edge)

func _run() -> void:
    if SCORER.angle_factor(5.0) != 0.0 or SCORER.angle_factor(40.0) <= SCORER.angle_factor(15.0):
        _fail("Angle factor must ignore grip driving and reward committed angle")
        return
    if SCORER.angle_factor(100.0) >= SCORER.angle_factor(45.0):
        _fail("Over-rotated slides should score less than the sweet spot")
        return
    # 1) Plain chain: banks only after the grace period, with x1.2 after 3 s.
    var s: NitroDriftScorer = SCORER.new()
    _drive(s,3.0,35.0,25.0,8.0)
    if s.total != 0 or s.chain_score() <= 0:
        _fail("Chain must stay pending while drifting")
        return
    if absf(s.multiplier-1.2) > 0.001:
        _fail("Duration multiplier should be x1.2 after 3 s (got %.2f)" % s.multiplier)
        return
    var expected: int = int(round(s.chain_points*s.multiplier))
    _drive(s,1.0,0.0,25.0,8.0,false)
    if s.total != expected or s.chain_score() != 0 or s.chains_banked != 1:
        _fail("Chain not banked correctly (total=%d expected=%d)" % [s.total,expected])
        return
    # 2) Kerb proximity pays more than the middle of the road.
    var centre: NitroDriftScorer = SCORER.new()
    var kerb: NitroDriftScorer = SCORER.new()
    _drive(centre,2.0,35.0,25.0,10.0)
    _drive(kerb,2.0,35.0,25.0,1.6)
    if kerb.chain_points < centre.chain_points*1.35:
        _fail("Kerb clipping must be rewarded (x%.2f)" % (kerb.chain_points/maxf(centre.chain_points,1.0)))
        return
    if kerb.kerb_clips != 1 or centre.kerb_clips != 0:
        _fail("Kerb clip must be counted once per chain, only near the kerb")
        return
    # 3) Transition left->right inside one chain adds multiplier.
    var t: NitroDriftScorer = SCORER.new()
    _drive(t,1.0,32.0,22.0,8.0)
    _drive(t,0.3,0.0,22.0,8.0,false)
    _drive(t,1.0,-32.0,22.0,8.0)
    if t.transitions != 1 or t.multiplier < 1.25-0.001:
        _fail("Transition not detected/rewarded (transitions=%d mult=%.2f)" % [t.transitions,t.multiplier])
        return
    # 4) Wall contact loses the pending chain; gentle scrapes do not.
    var w: NitroDriftScorer = SCORER.new()
    _drive(w,2.0,35.0,25.0,8.0)
    w.wall_hit(0.8)
    if w.chain_score() <= 0:
        _fail("A light scrape should not cancel the chain")
        return
    w.wall_hit(6.0)
    if w.chain_score() != 0 or w.total != 0 or w.chains_lost != 1:
        _fail("Wall hit must lose the un-banked chain")
        return
    # 5) Spinning out loses the chain too.
    var sp: NitroDriftScorer = SCORER.new()
    _drive(sp,1.5,40.0,20.0,8.0)
    _drive(sp,0.1,130.0,10.0,8.0)
    if sp.chain_score() != 0 or sp.chains_lost != 1:
        _fail("Spin must lose the chain")
        return
    # 6) Race wiring: restart clears the scorer, HUD receives callouts.
    var race: Node3D = (load("res://scenes/race.tscn") as PackedScene).instantiate()
    root.add_child(race)
    await process_frame
    var rs: NitroDriftScorer = race.get("scorer")
    if rs == null:
        _fail("Race has no drift scorer")
        return
    _drive(rs,2.0,35.0,25.0,8.0)
    rs.bank()
    race.call("_restart")
    if rs.total != 0 or int(race.get("lap_score")) != 0:
        _fail("Restart did not clear the score")
        return
    race.queue_free()
    await process_frame
    print("PASS: chain banking, duration multiplier, kerb proximity, transitions, wall/spin penalties, race wiring")
    print("NOT RUN: human-tuned score balance on real laps")
    quit(0)

func _fail(msg: String) -> void:
    printerr("FAIL: "+msg)
    quit(1)
