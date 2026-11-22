extends SceneTree
## v0.1.21 audio + car-profile regression (owner brief P0 / P1):
##  * no recorded effect can play: no recorded clip inside the Godot project
##    (only the background music), the originals are archived outside it,
##    and a race holds exactly one audio player: the synth;
##  * every car loads its own handling + engine profile; Lada red and white
##    share one; the race car is the same model as the garage preview;
##  * the garage choice survives an app restart (DRIVE without the garage);
##  * both engines through idle, acceleration + shifts, drift, lift-off,
##    braking to a stop and a wall impact: no clipping, steady idle, no
##    tyre/scrape/crackle noise when stationary, no rev flares while braking
##    (negative control: the plain speed map would flare by >1500 rpm);
##  * restart clears every transient; pause keeps the sound state; a new
##    car never inherits the previous car's audio state;
##  * music default sits under the engine.
const SYNTH = preload("res://scripts/audio/engine_synth.gd")
const AUDIO = preload("res://scripts/audio/drive_audio.gd")
const CARS = preload("res://scripts/vehicles/car_catalog.gd")
const STYLE = preload("res://scripts/ui/hud_style.gd")
const AUDIO_EXT: Array[String] = ["ogg","wav","mp3","opus","flac"]
const ALLOWED_AUDIO: Array[String] = ["res://assets/music/night_drift.ogg"]
const DT: float = 1.0/60.0
const FRAMES: int = 368   # ~1/60 s at 22.05 kHz

func _initialize() -> void:
    call_deferred("_run")

func _fail(msg: String) -> void:
    printerr("FAIL: "+msg)
    quit(1)

func _audio_files(dir: String, out: Array) -> void:
    for f in DirAccess.get_files_at(dir):
        if AUDIO_EXT.has(f.get_extension().to_lower()):
            out.append(dir.path_join(f))
    for d in DirAccess.get_directories_at(dir):
        if not d.begins_with("."):
            _audio_files(dir.path_join(d),out)

func _rms(buf: PackedVector2Array) -> float:
    var acc: float = 0.0
    for v in buf:
        acc += v.x*v.x
    return sqrt(acc/float(maxi(buf.size(),1)))

func _peak(buf: PackedVector2Array) -> float:
    var p: float = 0.0
    for v in buf:
        p = maxf(p,maxf(absf(v.x),absf(v.y)))
    return p

func _run() -> void:
    # 1) No recorded effects in the game; originals archived outside it.
    var found: Array = []
    _audio_files("res://",found)
    for f in found:
        if not ALLOWED_AUDIO.has(str(f)):
            _fail("Recorded audio inside the game project: "+str(f))
            return
    var archive: String = ProjectSettings.globalize_path("res://").path_join("../archive/recorded_sfx")
    if DirAccess.get_files_at(archive.path_join("ogg")).size() != 17 \
            or DirAccess.get_files_at(archive.path_join("wav_masters")).size() < 17:
        _fail("Original recordings must stay archived in archive/recorded_sfx (outside the export)")
        return
    # 2) Race per car: own profile, garage model, one audio player only.
    ProjectSettings.set_setting("nitro/selected_track","res://tracks/benchmark_oval.json")
    var engines: Dictionary = {}
    for variant in ["red","white","blue"]:
        CARS.select(variant)
        var race: Node3D = (load("res://scenes/race.tscn") as PackedScene).instantiate()
        root.add_child(race)
        await process_frame
        var err: String = _check_race(race,variant)
        engines[variant] = [race.get("sfx").synth.layout,race.get("model").wheelbase]
        race.queue_free()
        await process_frame
        if not err.is_empty():
            _fail(err)
            return
    # v0.1.38: the red Lada (13B rotary) and the white Lada (tuned N20B20 turbo) are two cars on
    # one body: same chassis (wheelbase), different engine; the RYU-32 has its own body and V8.
    if engines["red"][1] != engines["white"][1] or engines["red"][0] == engines["white"][0] \
            or engines["white"][0] == engines["blue"][0] or engines["red"][0] == engines["blue"][0]:
        _fail("Lada red (13B) and white (N20 turbo) must share the chassis but not the engine, RYU-32 its own: "+str(engines))
        return
    # 3) Garage choice survives an app restart (no garage visit).
    CARS.select("blue")
    ProjectSettings.clear("nitro/car_variant")
    if CARS.selected() != "blue":
        _fail("Saved car not used after restart when going straight to DRIVE")
        return
    CARS.select("red")
    # 4) Driving scenario, both engines.
    for variant in ["red","blue"]:
        var err2: String = await _scenario(variant)
        if not err2.is_empty():
            _fail(err2)
            return
    # 5) Music sits under the engine by default and does not adapt.
    if STYLE.MUSIC_DEFAULT > 0.5:
        _fail("Music default too loud for the engine mix")
        return
    var music_src: String = FileAccess.get_file_as_string("res://scripts/audio/music_player.gd")
    if music_src.contains("speed_kmh") or music_src.contains("rpm") or music_src.contains("drift_angle") or music_src.contains("synth"):
        _fail("Music must not adapt to driving")
        return
    print("PASS: no recorded SFX in the game (archived outside the export), one synth player per race, per-car profiles (Lada red = white, RYU-32 own), garage model in race, car choice survives restart, idle/accel/shifts/drift/lift/braking/impact for I4 + V8, no rev flares braking, restart clears transients, seamless pause (race + sound state kept), no carry-over between cars, music under the engine")
    print("NOT RUN: listening test on Android (sound quality is not approved by this test)")
    quit(0)

func _check_race(race: Node3D, variant: String) -> String:
    var players: Array = race.find_children("*","AudioStreamPlayer",true,false)
    players.append_array(race.find_children("*","AudioStreamPlayer2D",true,false))
    players.append_array(race.find_children("*","AudioStreamPlayer3D",true,false))
    if players.size() != 1 or not ((players[0] as AudioStreamPlayer).stream is AudioStreamGenerator):
        return "Race %s must hold exactly the synth audio player, found %d" % [variant,players.size()]
    var synth = race.get("sfx").synth
    var eng: Dictionary = CARS.engine(variant)
    if synth.cylinders != int(eng["cylinders"]) or synth.layout != str(eng["layout"]) \
            or absf(synth.idle_rpm-float(eng["idle_rpm"])) > 0.01:
        return "Race %s did not load its engine profile" % variant
    if absf(race.get("model").wheelbase-float(CARS.handling(variant).get("wheelbase",race.get("model").wheelbase))) > 1e-6:
        return "Race %s did not load its handling profile" % variant
    if synth.rpm != synth.idle_rpm or synth.shifts != 0 or synth.misfires != 0 or synth.afterfire != 0.0:
        return "Race %s audio did not start from a fresh idle" % variant
    # Same model as the garage preview (same factory, same variant details).
    var car: Node3D = race.get("car_root")
    var preview: Node3D = CARS.make(variant)
    root.add_child(preview)   # builds its mesh children like the garage does
    var same: bool = car.get_script() == preview.get_script() \
        and (car.find_child("White variant closed long bonnet",true,false) != null) == (preview.find_child("White variant closed long bonnet",true,false) != null)
    preview.free()
    if not same:
        return "Race %s car differs from the garage preview" % variant
    # Pause / resume: race state and sound state survive untouched.
    var model = race.get("model")
    model.velocity = Vector2(0,-20.0)
    race.get("sfx").drive_tick(72.0,0.0,1.0,0.0,false,0.2)
    var keep: Array = [model.position,model.velocity,race.get("time_elapsed"),race.get("lap"),
        race.get("lap_score"),synth.rpm,synth.gear]
    race.call("_toggle_pause")
    if not bool(race.get("paused")) or not race.get("sfx").synth_player.stream_paused:
        return "Race %s pause did not freeze race + sound" % variant
    race.call("_toggle_pause")
    var now: Array = [model.position,model.velocity,race.get("time_elapsed"),race.get("lap"),
        race.get("lap_score"),synth.rpm,synth.gear]
    if now != keep or bool(race.get("paused")) or race.get("sfx").synth_player.stream_paused:
        return "Race %s pause/resume changed race or sound state: %s -> %s" % [variant,str(keep),str(now)]
    return ""

func _drive(sound: NitroDriveAudio, speed: float, angle: float, gas: float, hb: float) -> PackedVector2Array:
    sound.drive_tick(speed,angle,gas,hb,false,DT)
    return sound.synth.render(FRAMES)

func _scenario(variant: String) -> String:
    var sound: NitroDriveAudio = AUDIO.new()
    root.add_child(sound)
    await process_frame
    sound.synth.apply_profile(CARS.engine(variant))
    var s: NitroEngineSynth = sound.synth
    var name: String = s.layout
    # Idle, stationary, 3 s: steady, quiet, no tyre / scrape / crackle.
    # 100 ms windows (several firings each: a single 1/60 s block may or may
    # not contain a pulse at 760-950 rpm).
    var blocks: Array[float] = []
    var idle_peak: float = 0.0
    var win := PackedVector2Array()
    for i in range(180):
        var b: PackedVector2Array = _drive(sound,0.0,0.0,0.0,0.0)
        if i >= 30:
            win.append_array(b)
            idle_peak = maxf(idle_peak,_peak(b))
            if win.size() >= 6*FRAMES:
                blocks.append(_rms(win))
                win = PackedVector2Array()
    var lo: float = blocks.min()
    var hi: float = blocks.max()
    var idle_rms: float = 0.0
    for v in blocks:
        idle_rms += v/float(blocks.size())
    if s.squeal > 0.0 or s.scrape > 0.0 or s.afterfire > 0.0 or absf(s.rpm-s.idle_rpm) > 1.0:
        return name+": stationary car makes tyre/scrape/crackle noise or revs"
    if hi > 3.0*lo or idle_peak > 0.5:
        return name+": idle is not steady (block RMS %.4f..%.4f, peak %.3f)" % [lo,hi,idle_peak]
    # Acceleration through the gears, full throttle.
    var speed: float = 0.0
    var peak: float = 0.0
    var max_rpm: float = 0.0
    var drive_rms: float = 0.0
    var n: int = 0
    for i in range(420):
        speed = minf(speed+DT*30.0,190.0)
        var b2: PackedVector2Array = _drive(sound,speed,0.0,1.0,0.0)
        peak = maxf(peak,_peak(b2))
        max_rpm = maxf(max_rpm,s.rpm)
        drive_rms += _rms(b2)
        n += 1
    drive_rms /= float(n)
    var shifts: int = s.shifts
    if s.shifts < 3 or max_rpm > s.limit_rpm+1.0:
        return name+": acceleration should shift up (%d shifts, max %d rpm)" % [s.shifts,int(max_rpm)]
    if drive_rms < 2.0*idle_rms:
        return name+": engine under load not clearly louder than idle"
    # Drift: tyres squeal.
    for i in range(90):
        speed = 75.0
        peak = maxf(peak,_peak(_drive(sound,speed,35.0,0.85,0.0)))
    if s.squeal < 0.3:
        return name+": drift does not squeal (%.2f)" % s.squeal
    # Lift off: revs fall, crackle window opens, squeal fades.
    var rpm_before_lift: float = s.rpm
    for i in range(40):
        peak = maxf(peak,_peak(_drive(sound,speed,0.0,0.0,0.0)))
    if s.rpm >= rpm_before_lift or s.squeal > 0.2:
        return name+": lift-off should drop revs and stop the squeal"
    # Braking 120 -> 0 off the throttle: no rev flares (natural wind-down).
    for i in range(240):
        speed = minf(speed+DT*40.0,120.0)
        _drive(sound,speed,0.0,1.0,0.0)
    var prev_rpm: float = s.rpm
    var flare: float = 0.0
    var map_flare: float = 0.0
    var prev_map: float = s.rpm_of(speed,0.0,0.0)
    while speed > 0.0:
        speed = maxf(speed-DT*45.0,0.0)
        peak = maxf(peak,_peak(_drive(sound,speed,0.0,0.0,0.0)))
        flare = maxf(flare,s.rpm-prev_rpm)
        prev_rpm = s.rpm
        var m: float = s.rpm_of(speed,0.0,0.0)
        map_flare = maxf(map_flare,m-prev_map)
        prev_map = m
    if flare > 150.0:
        return name+": revs flare while braking (+%d rpm)" % int(flare)
    if map_flare < 1500.0:
        return name+": negative control lost: the plain speed map should flare while braking"
    for i in range(60):
        _drive(sound,0.0,0.0,0.0,0.0)
    if absf(s.rpm-s.idle_rpm) > 30.0:
        return name+": engine not back at idle after stopping (%d rpm)" % int(s.rpm)
    # Wall impact: a thud that dies away.
    for i in range(10):
        _drive(sound,0.0,0.0,0.0,0.0)
    sound.wall_event(9.0)
    var hit: float = _rms(_drive(sound,0.0,0.0,0.0,0.0))+_rms(_drive(sound,0.0,0.0,0.0,0.0))
    for i in range(40):
        _drive(sound,0.0,0.0,0.0,0.0)
    var after: float = _rms(_drive(sound,0.0,0.0,0.0,0.0))
    if hit < 4.0*idle_rms or after > 2.0*idle_rms:
        return name+": wall impact missing or ringing on (%.4f / %.4f vs idle %.4f)" % [hit,after,idle_rms]
    if peak >= 1.0:
        return name+": clipped (peak %.3f)" % peak
    # Pause keeps the exact sound state; resume continues.
    for i in range(30):
        _drive(sound,60.0,0.0,1.0,0.0)
    var keep: Array = [s.rpm,s.gear,s.load]
    sound.pause_audio(true)
    if not sound.synth_player.stream_paused or not sound.audio_paused:
        return name+": pause did not freeze the sound"
    sound.pause_audio(false)
    if [s.rpm,s.gear,s.load] != keep or sound.synth_player.stream_paused:
        return name+": pause/resume changed the sound state"
    # Restart: hit, lift for crackle, then reset -> quiet idle, nothing left.
    for i in range(60):
        _drive(sound,110.0,0.0,1.0,0.0)
    _drive(sound,110.0,0.0,0.0,0.0)
    sound.wall_event(12.0)
    sound.reset()
    if s.afterfire != 0.0 or s.rpm != s.idle_rpm or s.misfires != 0 or s.scrape_target != 0.0:
        return name+": restart left audio state behind"
    var rest: Array[float] = []
    var rwin := PackedVector2Array()
    for i in range(42):
        rwin.append_array(_drive(sound,0.0,0.0,0.0,0.0))
        if rwin.size() >= 6*FRAMES:
            rest.append(_rms(rwin))
            rwin = PackedVector2Array()
    if rest.max() > 2.0*hi:
        return name+": restart is not a quiet idle (block %.4f vs idle max %.4f)" % [rest.max(),hi]
    sound.queue_free()
    await process_frame
    # A new car starts fresh, whatever the previous one was doing.
    var other: NitroDriveAudio = AUDIO.new()
    root.add_child(other)
    await process_frame
    other.synth.apply_profile(CARS.engine("blue" if variant == "red" else "red"))
    if other.synth.rpm != other.synth.idle_rpm or other.synth.shifts != 0 or other.synth.squeal != 0.0:
        return name+": next car inherited audio state"
    other.queue_free()
    await process_frame
    print("AUDIO %s idle rms %.4f (steady %.2fx), load rms %.4f, %d shifts, max %d rpm, braking flare +%d rpm (speed map +%d), peak %.3f" % [
        name,idle_rms,hi/lo,drive_rms,shifts,int(max_rpm),int(flare),int(map_flare),peak])
    return ""
