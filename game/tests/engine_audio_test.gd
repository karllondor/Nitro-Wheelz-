extends SceneTree
## Procedural inline-six fallback: gearbox/RPM model, continuous pitch,
## headroom (no clipping) and firing-frequency correctness.
const SYNTH = preload("res://scripts/audio/engine_synth.gd")
const AUDIO = preload("res://scripts/audio/drive_audio.gd")

func _initialize() -> void:
    call_deferred("_run")

func _goertzel(buf: PackedVector2Array, hz: float) -> float:
    var w: float = TAU*hz/SYNTH.SAMPLE_RATE
    var coeff: float = 2.0*cos(w)
    var s1: float = 0.0
    var s2: float = 0.0
    for v in buf:
        var s0: float = v.x+coeff*s1-s2
        s2 = s1
        s1 = s0
    return s1*s1+s2*s2-coeff*s1*s2

func _run() -> void:
    # Gearbox: rpm rises within a gear, drops on upshift, stays in range.
    var r30: float = SYNTH.rpm_for(30.0,1.0,0.0)
    var r45: float = SYNTH.rpm_for(45.0,1.0,0.0)
    var r50: float = SYNTH.rpm_for(50.0,1.0,0.0)
    if not (r45 > r30 and r50 < r45):
        _fail("RPM should climb in gear and drop after the 1-2 upshift (%d %d %d)" % [r30,r45,r50])
        return
    for kmh in range(0,230,5):
        var r: float = SYNTH.rpm_for(float(kmh),1.0,1.0)
        if r < SYNTH.IDLE_RPM-0.1 or r > SYNTH.LIMIT_RPM+0.1:
            _fail("RPM out of range at %d km/h" % kmh)
            return
    if SYNTH.rpm_for(60.0,1.0,1.0) <= SYNTH.rpm_for(60.0,1.0,0.0):
        _fail("Drift wheelspin should lift revs above road speed")
        return
    # Same voice from idle to limiter: pitch follows rpm (3 pulses/rev).
    var synth: NitroEngineSynth = SYNTH.new()
    for target in [1200.0,3000.0,6000.0]:
        synth.rpm = target
        synth.load = 1.0
        synth.render(4096)
        var buf: PackedVector2Array = synth.render(8192)
        var firing: float = target/60.0*3.0
        var on: float = _goertzel(buf,firing)
        var off_low: float = _goertzel(buf,firing*0.78)
        var off_high: float = _goertzel(buf,firing*1.27)
        if on < 8.0*maxf(off_low,off_high):
            _fail("Firing frequency %.1f Hz not dominant at %d rpm" % [firing,int(target)])
            return
    # Headroom: full load + squeal + impact must not clip.
    synth.rpm = SYNTH.LIMIT_RPM
    synth.load = 1.0
    synth.squeal = 1.0
    synth.impact(1.0)
    var peak: float = 0.0
    var energy: float = 0.0
    for chunk in range(6):
        var buf: PackedVector2Array = synth.render(2048)
        for v in buf:
            peak = maxf(peak,absf(v.x))
            energy += v.x*v.x
    if peak >= 1.0 or energy < 1.0:
        _fail("Synth clipped or silent (peak %.3f energy %.2f)" % [peak,energy])
        return
    # Controller wiring works headless (dummy audio driver).
    var sound: NitroDriveAudio = AUDIO.new()
    root.add_child(sound)
    await process_frame
    if sound.synth == null:
        _fail("Drive audio did not create the synth engine")
        return
    for i in range(120):
        sound.drive_tick(80.0,30.0,1.0,0.0,false,1.0/120.0)
    if sound.synth.rpm <= 3000.0 or sound.synth.squeal <= 0.1:
        _fail("Drive state did not reach the synth (rpm %.0f squeal %.2f)" % [sound.synth.rpm,sound.synth.squeal])
        return
    sound.silence()
    if not sound.synth_muted:
        _fail("Pause/finish must mute the synth")
        return
    sound.queue_free()
    await process_frame
    print("PASS: gearbox rpm, continuous inline-six pitch, no clipping, controller wiring")
    print("NOT RUN: subjective sound quality on phone speakers/headphones")
    quit(0)

func _fail(msg: String) -> void:
    printerr("FAIL: "+msg)
    quit(1)
