extends SceneTree
## Procedural inline-four ITB engine: gearbox/RPM model, continuous pitch,
## uneven-cylinder idle, shift cut, bouncing limiter, overrun crackle,
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
        # Four-stroke inline-four: 2 firings per crank turn. Uneven
        # cylinders put energy on quarter orders (0.25f, 0.5f, 0.75f, 1.25f)
        # by design, so probe BETWEEN those orders.
        var firing: float = target/60.0*2.0
        if absf(synth.firing_hz()-firing) > 0.01:
            _fail("firing_hz() must follow the four-cylinder firing order")
            return
        var on: float = _goertzel(buf,firing)
        var off_low: float = _goertzel(buf,firing*0.875)
        var off_high: float = _goertzel(buf,firing*1.125)
        if on < 8.0*maxf(off_low,off_high):
            _fail("Firing frequency %.1f Hz not dominant at %d rpm" % [firing,int(target)])
            return
    # Idle lump: uneven cylinders give a real half-order component.
    var idle: NitroEngineSynth = SYNTH.new()
    idle.rpm = SYNTH.IDLE_RPM
    idle.render(4096)
    var idle_buf: PackedVector2Array = idle.render(16384)
    var f_idle: float = idle.firing_hz()
    if _goertzel(idle_buf,f_idle*0.5) < 4.0*_goertzel(idle_buf,f_idle*0.625):
        _fail("Idle should carry the uneven-cylinder half-order lump")
        return
    # Upshift cut, bouncing limiter and lift-off crackle window.
    var drive: NitroEngineSynth = SYNTH.new()
    for k in range(240):
        drive.set_state(float(k)*0.4,1.0,0.0,1.0/60.0)
    if drive.shifts < 1:
        _fail("Upshifts must cut ignition")
        return
    for k in range(180):
        drive.set_state(46.0,1.0,1.0,1.0/60.0)
    if drive.limiter_hits < 3 or drive.rpm > SYNTH.LIMIT_RPM+0.1:
        _fail("Held at the limit the engine must bounce off the limiter (%d hits)" % drive.limiter_hits)
        return
    drive.set_state(46.0,0.0,0.0,1.0/60.0)
    if drive.afterfire < 0.9:
        _fail("Lifting off at high revs must open the overrun crackle window")
        return
    # Tyre squeal: band-limited noise around 0.8-1.3 kHz whose energy is
    # spread (no single siren tone), and it actually adds that band.
    var tyre: NitroEngineSynth = SYNTH.new()
    tyre.rpm = SYNTH.IDLE_RPM
    tyre.render(4096)
    var quiet: PackedVector2Array = tyre.render(8192)
    tyre.squeal = 1.0
    tyre.render(2048)
    var loud: PackedVector2Array = tyre.render(8192)
    var peak_hz: float = 0.0
    var peak_e: float = 0.0
    for k in range(41):
        var hz: float = 700.0+20.0*float(k)
        var e: float = _goertzel(loud,hz)
        if e > peak_e:
            peak_e = e
            peak_hz = hz
    # Refine the peak to 1 Hz so a pure tone cannot hide between bins.
    var coarse: float = peak_hz
    for k in range(-20,21):
        var hz2: float = coarse+float(k)
        var e2: float = _goertzel(loud,hz2)
        if e2 > peak_e:
            peak_e = e2
            peak_hz = hz2
    if peak_e < 20.0*maxf(_goertzel(quiet,peak_hz),1e-6):
        _fail("Tyre squeal does not add its ~1 kHz band (peak %.0f Hz)" % peak_hz)
        return
    # A siren/sine has almost nothing 45 Hz either side of its peak; a
    # screech (resonant noise with wandering pitch) does.
    var side: float = _goertzel(loud,peak_hz-45.0)+_goertzel(loud,peak_hz+45.0)
    if side < peak_e/40.0:
        _fail("Tyre squeal is a pure siren tone, not a noisy screech")
        return
    # Impact: a low body thud right after the hit.
    var hit: NitroEngineSynth = SYNTH.new()
    hit.rpm = SYNTH.IDLE_RPM
    hit.render(4096)
    var before_hit: PackedVector2Array = hit.render(3300)
    hit.impact(1.0)
    var after_hit: PackedVector2Array = hit.render(3300)
    var lf: float = _goertzel(after_hit,55.0)+_goertzel(after_hit,70.0)+_goertzel(after_hit,85.0)
    var mf: float = _goertzel(after_hit,380.0)+_goertzel(after_hit,420.0)+_goertzel(after_hit,460.0)
    if lf < 5.0*maxf(_goertzel(before_hit,55.0)+_goertzel(before_hit,70.0)+_goertzel(before_hit,85.0),1e-6) \
            or lf < 6.0*mf:
        _fail("Wall impact lacks a low body thud (LF "+str(lf)+" vs MF "+str(mf)+")")
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
    sound.wall_contact(15.0)
    if sound.synth.scrape_target < 0.5:
        _fail("Sliding along a wall must drive the scrape layer")
        return
    sound.wall_contact(0.0)
    if sound.synth.scrape_target != 0.0:
        _fail("Scrape must stop when the car leaves the wall")
        return
    sound.silence()
    if not sound.synth_muted:
        _fail("Pause/finish must mute the synth")
        return
    sound.queue_free()
    await process_frame
    print("PASS: gearbox rpm, inline-four ITB firing pitch, uneven idle, shift cut, limiter bounce, overrun crackle, noisy tyre squeal, impact thud, wall scrape, no clipping, controller wiring")
    print("NOT RUN: subjective sound quality on phone speakers/headphones")
    quit(0)

func _fail(msg: String) -> void:
    printerr("FAIL: "+msg)
    quit(1)
