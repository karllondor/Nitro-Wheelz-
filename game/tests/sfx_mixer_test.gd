extends SceneTree
## Audio hotfix regression (v0.1.20): recorded effects play only on their
## real events, once, with cooldowns, priorities and exclusive groups; road
## noise ducks during drifts; engine-specific effects per car; synth-only vs
## recorded comparison mode; diagnostics explain every decision.
const AUDIO = preload("res://scripts/audio/drive_audio.gd")
const CARS = preload("res://scripts/vehicles/car_catalog.gd")
const DT: float = 1.0/120.0

func _initialize() -> void:
    call_deferred("_run")

func _mixer(variant: String = "red", mode: String = "recorded") -> NitroDriveAudio:
    var prev: String = AUDIO.audio_mode()
    AUDIO.set_audio_mode(mode)
    var s: NitroDriveAudio = AUDIO.new()
    s.test_mode = true
    root.add_child(s)
    AUDIO.set_audio_mode(prev)
    s.synth.apply_profile(CARS.engine(variant))
    s.apply_car_sfx(CARS.profile(variant).get("sfx",{}),s.synth.turbo)
    return s

func _plays(s: NitroDriveAudio, clip: String) -> int:
    return int(s.play_count.get(clip,0))

func _ticks(s: NitroDriveAudio, seconds: float, speed: float, angle: float, gas: float, hb: float = 0.0) -> void:
    for i in range(int(seconds/DT)):
        s.drive_tick(speed,angle,gas,hb,false,DT)

func _run() -> void:
    # Every clip the mixer uses exists as a processed cut.
    var probe: NitroDriveAudio = _mixer()
    for name in AUDIO.EVENTS.keys()+AUDIO.LOOPS.keys():
        if not probe.clip_length.has(name) or not ResourceLoader.exists(AUDIO.ROOT+name+".ogg"):
            _fail("Processed SFX missing: "+name)
            return
    probe.queue_free()

    # 1) exhaust pops: exactly once per lift-off, although afterfire stays
    #    above 0.9 for many ticks (v0.1.19 restarted it every tick).
    var s: NitroDriveAudio = _mixer("red")
    _ticks(s,2.0,100.0,0.0,1.0)
    s.synth.rpm = 6000.0
    _ticks(s,0.6,100.0,0.0,0.0)
    if _plays(s,"exhaust_pops") != 1:
        _fail("exhaust_pops must play once per lift-off, played %d" % _plays(s,"exhaust_pops"))
        return
    # A second lift inside the cooldown is refused.
    _ticks(s,0.4,100.0,0.0,1.0)
    s.synth.rpm = 6000.0
    _ticks(s,0.3,100.0,0.0,0.0)
    if _plays(s,"exhaust_pops") != 1:
        _fail("exhaust_pops cooldown not respected")
        return
    s.queue_free()

    # 2) priorities / exclusive groups / voice limit.
    s = _mixer("red")
    if not s.trigger("barrier_scrape_light","test touch"):
        _fail("light wall touch should play")
        return
    if not s.trigger("barrier_hit","test impact"):
        _fail("impact must win over a light touch in the wall group")
        return
    if s.trigger("barrier_scrape_light","test touch 2"):
        _fail("light touch must not play over a running impact")
        return
    s.clock += 2.0
    for n in ["curb_rumble","tyre_handbrake","exhaust_single"]:
        s.trigger(n,"fill")
    if s.active.size() != 3:
        _fail("three different groups should play together")
        return
    if not s.trigger("barrier_hit","big impact") or s.active.size() > AUDIO.MAX_ONESHOTS:
        _fail("an impact must take the lowest-priority voice when all are busy")
        return
    if s.active.has("curb_rumble"):
        _fail("the lowest priority sound (kerb) should be the one replaced")
        return
    s.queue_free()

    # Kerb: called every tick while on the kerb -> one sound per entry.
    s = _mixer("red")
    for i in range(240):
        s.clock += DT
        s.kerb_event(70.0)
    if _plays(s,"curb_rumble") != 1:
        _fail("kerb rumble must play once per kerb entry")
        return
    s.queue_free()

    # 3) road noise ducks smoothly while drifting.
    s = _mixer("red")
    _ticks(s,1.5,80.0,0.0,0.6)
    var straight: float = s.synth.road_noise
    _ticks(s,1.5,80.0,35.0,0.8)
    var drifting: float = s.synth.road_noise
    if straight <= 0.1 or drifting > straight*0.35:
        _fail("road noise must duck during a drift (%.2f -> %.2f)" % [straight,drifting])
        return
    if float(s.loop_level.get("tyre_drift",0.0)) < 0.3:
        _fail("drift squeal loop should be up while drifting")
        return
    # Regrip plays once when a real drift ends, not on every wobble.
    _ticks(s,1.0,80.0,0.0,0.6)
    if _plays(s,"tyre_regrip") != 1:
        _fail("regrip must play once at the end of a drift")
        return
    s.queue_free()

    # 4) engine-specific: Lada turbo clips, RYU-32 V8 none + lower pops.
    for variant in ["red","blue"]:
        s = _mixer(variant)
        _ticks(s,0.5,40.0,0.0,0.0)
        _ticks(s,1.5,60.0,0.0,1.0)
        _ticks(s,0.2,60.0,0.0,0.0)
        var turbo_plays: int = _plays(s,"turbo_spool")+_plays(s,"turbo_bov")
        if variant == "red" and turbo_plays < 1:
            _fail("Lada (turbo) should spool / blow off")
            return
        if variant == "blue" and turbo_plays != 0:
            _fail("RYU-32 V8 has no turbo, but turbo clips played")
            return
        if variant == "blue" and absf(s.exhaust_pitch-0.78) > 0.001:
            _fail("V8 exhaust effects should play lower")
            return
        s.queue_free()

    # 6) diagnostics explain what plays and why.
    s = _mixer("red")
    _ticks(s,1.0,80.0,35.0,0.8,1.0)
    var lines: String = "\n".join(s.debug_lines())
    if not lines.contains("tyre_drift") or not lines.contains("handbrake pulled") or not lines.contains("ENGINE"):
        _fail("diagnostics must list active sounds with reasons:\n"+lines)
        return
    s.queue_free()

    # 7) comparison: synth-only mode plays no recordings, synth keeps squeal,
    #    crackle and impacts; recorded mode hands them to the recordings.
    s = _mixer("red","synth")
    _ticks(s,1.0,80.0,35.0,0.8,1.0)
    s.wall_event(8.0)
    if _plays(s,"tyre_handbrake")+_plays(s,"barrier_hit") != 0 or s.synth.squeal < 0.1 or not s.synth.crackle:
        _fail("synth-only mode must not play recordings and must keep synth layers")
        return
    s.queue_free()
    s = _mixer("red","recorded")
    _ticks(s,1.0,80.0,35.0,0.8)
    if s.synth.squeal > 0.0 or s.synth.crackle:
        _fail("recorded mode must hand squeal and crackle to the recordings")
        return
    s.queue_free()
    await process_frame
    print("PASS: pops once per lift, cooldowns, priorities + exclusive groups + voice limit, kerb once per entry, road noise ducks in drift, regrip once, Lada turbo vs V8 effects, diagnostics, synth-only vs recorded")
    print("NOT RUN: listening on Android (owner) - unit tests cannot approve audio")
    quit(0)

func _fail(msg: String) -> void:
    printerr("FAIL: "+msg)
    quit(1)
