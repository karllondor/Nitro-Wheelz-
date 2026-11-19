extends Node
class_name NitroDriveAudio
## Car audio mixer (v0.1.20 audio hotfix).
## Layers: the per-car engine SYNTH (always) + the owner's recorded effects,
## cut to their useful part (docs/audio/SFX_AUDIT.md, assets/audio/
## processed/). Every recorded one-shot goes through one gate: edge-triggered
## events, per-clip cooldown, no restart while it still plays, exclusive
## groups (one tyre / turbo / exhaust / wall / kerb sound at a time) with
## priorities, and a global limit of simultaneous one-shots. Loops (drift
## squeal, wall slide, gravel, wind) and the synth road noise follow the car
## smoothly; road noise ducks while drifting. Modes for comparison:
## "recorded" (synth + recorded effects, default) and "synth" (synth only).
## A diagnostic log records every decision with its reason.
const ROOT_ORIGINAL: String = "res://assets/audio/"
const ROOT: String = "res://assets/audio/processed/"
const SPEC_PATH: String = "res://assets/audio/sfx_spec.json"
const SETTINGS_PATH: String = "user://nitro_settings.cfg"
const SYNTH = preload("res://scripts/audio/engine_synth.gd")
const STYLE = preload("res://scripts/ui/hud_style.gd")
## The owner's 17 recordings (registry kept; not all are used, see audit).
const CLIPS: Array[String] = [
    "tyre_rolling","tyre_corner","tyre_drift","tyre_handbrake","tyre_regrip",
    "turbo_spool","turbo_bov","turbo_flutter","exhaust_single","exhaust_pops",
    "engine_limiter","curb_rumble","barrier_scrape_light","barrier_hit",
    "barrier_scrape_heavy","gravel_roll","wind_speed"
]
## One-shot events: level at full intensity, cooldown, priority (higher
## wins), exclusive group, and whether only turbo engines may use it.
const EVENTS: Dictionary = {
    "tyre_handbrake": {"gain_db":-9.0,"cooldown":0.9,"priority":50,"excl":"tyre"},
    "tyre_regrip": {"gain_db":-14.0,"cooldown":1.5,"priority":30,"excl":"tyre"},
    "turbo_spool": {"gain_db":-17.0,"cooldown":3.0,"priority":20,"excl":"turbo","turbo_only":true},
    "turbo_bov": {"gain_db":-13.0,"cooldown":2.0,"priority":35,"excl":"turbo","turbo_only":true},
    "exhaust_single": {"gain_db":-15.0,"cooldown":1.5,"priority":40,"excl":"exhaust"},
    "exhaust_pops": {"gain_db":-13.0,"cooldown":2.0,"priority":45,"excl":"exhaust"},
    "curb_rumble": {"gain_db":-14.0,"cooldown":0.9,"priority":25,"excl":"kerb"},
    "barrier_hit": {"gain_db":-6.0,"cooldown":0.6,"priority":100,"excl":"wall"},
    "barrier_scrape_light": {"gain_db":-9.0,"cooldown":1.0,"priority":60,"excl":"wall"},
}
const LOOPS: Dictionary = {
    "tyre_drift": {"gain_db":-8.0,"rate":6.0},
    "barrier_scrape_heavy": {"gain_db":-11.0,"rate":12.0},
    "gravel_roll": {"gain_db":-12.0,"rate":5.0},
    "wind_speed": {"gain_db":-18.0,"rate":2.0},
}
const MAX_ONESHOTS: int = 3
const LOG_SIZE: int = 14
const ANY_GROUP: Dictionary = {"tyre_handbrake":"tyres","tyre_regrip":"tyres","tyre_drift":"tyres",
    "gravel_roll":"tyres","turbo_spool":"engine","turbo_bov":"engine","exhaust_single":"engine",
    "exhaust_pops":"engine"}

var voices: Dictionary = {}          # clip -> AudioStreamPlayer (processed clips)
var clip_length: Dictionary = {}     # clip -> seconds (from the spec)
var has_source_audio: bool = false
var recorded_mode: bool = true
var test_mode: bool = false          # tests: no decoders, bookkeeping only
var clock: float = 0.0
var last_played: Dictionary = {}
var active: Dictionary = {}          # one-shot clip -> {start, length, priority}
var loop_level: Dictionary = {}      # loop clip -> current linear level (0..1)
var loop_reason: Dictionary = {}
var log: Array[Dictionary] = []
var play_count: Dictionary = {}      # clip -> plays since the scene started
var turbo: bool = true
var exhaust_pitch: float = 1.0
# Driving state for edge detection.
var previous_gas: float = 0.0
var previous_handbrake: float = 0.0
var previous_afterfire: float = 0.0
var full_throttle_time: float = 0.0
var drifting: bool = false
var drift_time: float = 0.0
var last_kerb_call: float = -100.0
var drift_mix: float = 0.0
var full_throttle_time_before_lift: float = 0.0

var synth: NitroEngineSynth
var synth_player: AudioStreamPlayer
var synth_playback: AudioStreamGeneratorPlayback
var synth_muted: bool = false

static func clip_group(name: String) -> String:
    return str(ANY_GROUP.get(name,"fx"))

static func group_gain(group: String) -> float:
    match group:
        "engine": return STYLE.vol_engine
        "tyres": return STYLE.vol_tyres
    return STYLE.vol_fx

## DEVELOPER setting: "recorded" (synth + recorded effects) or "synth".
static func audio_mode() -> String:
    var cfg := ConfigFile.new()
    if cfg.load(SETTINGS_PATH) != OK:
        return "recorded"
    return str(cfg.get_value("developer","audio_mode","recorded"))

static func set_audio_mode(mode: String) -> void:
    var cfg := ConfigFile.new()
    cfg.load(SETTINGS_PATH)
    cfg.set_value("developer","audio_mode",mode)
    cfg.save(SETTINGS_PATH)

func _ready() -> void:
    recorded_mode = audio_mode() != "synth"
    _read_spec()
    # Headless CI has no audio device; decoders are never created there.
    if recorded_mode and not test_mode and DisplayServer.get_name() != "headless":
        _load_clips()
    _make_synth()
    _apply_mode()

func _read_spec() -> void:
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(SPEC_PATH))
    if raw is Dictionary:
        for name in (raw["clips"] as Dictionary).keys():
            clip_length[name] = float(raw["clips"][name]["length"])

func _load_clips() -> void:
    for name in clip_length.keys():
        var uri: String = ROOT+name+".ogg"
        if not ResourceLoader.exists(uri):
            continue
        var stream: AudioStream = load(uri) as AudioStream
        if stream == null:
            continue
        if LOOPS.has(name) and stream is AudioStreamOggVorbis:
            (stream as AudioStreamOggVorbis).loop = true
        var player := AudioStreamPlayer.new()
        player.name = "SFX_"+name
        player.stream = stream
        player.volume_db = -60.0
        player.bus = "Master"
        add_child(player)
        voices[name] = player
        has_source_audio = true

func _exit_tree() -> void:
    # Release decoder streams before the scene exits (no leaks at shutdown).
    for player in voices.values():
        if is_instance_valid(player):
            (player as AudioStreamPlayer).stop()
            (player as AudioStreamPlayer).stream = null
    voices.clear()
    has_source_audio = false

func _make_synth() -> void:
    synth = SYNTH.new()
    synth_player = AudioStreamPlayer.new()
    synth_player.name = "Synth engine"
    var generator := AudioStreamGenerator.new()
    generator.mix_rate = SYNTH.SAMPLE_RATE
    generator.buffer_length = 0.12
    synth_player.stream = generator
    synth_player.volume_db = -8.0
    add_child(synth_player)
    synth_player.play()
    synth_playback = synth_player.get_stream_playback() as AudioStreamGeneratorPlayback

## Synth-only mode keeps the synth's own squeal / impact / scrape / crackle;
## with recorded effects those layers are handed to the recordings.
func _apply_mode() -> void:
    if synth == null:
        return
    synth.crackle = not _has("exhaust_pops")

## A recorded layer is used only in recorded mode and when its clip loaded;
## otherwise the synth keeps that layer (missing assets never mean silence).
func _has(name: String) -> bool:
    return recorded_mode and (test_mode or voices.has(name))

## Per-car effects from the car profile's "sfx" block (turbo clips allowed,
## exhaust pitch: the V8 plays the pops lower).
func apply_car_sfx(sfx: Dictionary, engine_turbo: bool) -> void:
    turbo = bool(sfx.get("turbo_clips",engine_turbo))
    exhaust_pitch = float(sfx.get("exhaust_pitch",1.0))

func _process(_delta: float) -> void:
    if synth != null:
        synth.engine_gain = STYLE.vol_engine
        synth.tyre_gain = STYLE.vol_tyres
        synth.fx_gain = STYLE.vol_fx
    if synth == null or synth_playback == null or synth_muted:
        return
    var frames: int = synth_playback.get_frames_available()
    if frames > 0:
        synth_playback.push_buffer(synth.render(frames))

# ------------------------------------------------------------ the gate

func _log(clip: String, action: String, reason: String) -> void:
    log.append({"t":clock,"clip":clip,"action":action,"reason":reason})
    while log.size() > LOG_SIZE:
        log.pop_front()

func _refresh_active() -> void:
    for name in active.keys():
        var a: Dictionary = active[name]
        if clock-float(a["start"]) >= float(a["length"]):
            active.erase(name)

func _stop(name: String, reason: String) -> void:
    active.erase(name)
    if voices.has(name):
        (voices[name] as AudioStreamPlayer).stop()
    _log(name,"STOP",reason)

## Try to play a recorded one-shot. Returns true when it plays.
func trigger(name: String, reason: String, intensity: float = 1.0, pitch: float = 1.0) -> bool:
    if not EVENTS.has(name):
        return false
    var ev: Dictionary = EVENTS[name]
    if not recorded_mode:
        _log(name,"SKIP","synth-only mode")
        return false
    if not test_mode and not voices.has(name):
        return false
    if bool(ev.get("turbo_only",false)) and not turbo:
        _log(name,"SKIP","this engine has no turbo")
        return false
    _refresh_active()
    var since: float = clock-float(last_played.get(name,-1000.0))
    if since < float(ev["cooldown"]):
        _log(name,"BLOCK","cooldown %.1fs" % (float(ev["cooldown"])-since))
        return false
    if active.has(name):
        _log(name,"BLOCK","still playing")
        return false
    var prio: int = int(ev["priority"])
    for other in active.keys():
        if str(EVENTS[other]["excl"]) == str(ev["excl"]):
            if int(EVENTS[other]["priority"]) >= prio:
                _log(name,"BLOCK","group busy: "+str(other))
                return false
            _stop(other,"replaced by "+name)
    if active.size() >= MAX_ONESHOTS:
        var lowest: String = ""
        for other in active.keys():
            if lowest.is_empty() or int(EVENTS[other]["priority"]) < int(EVENTS[lowest]["priority"]):
                lowest = other
        if int(EVENTS[lowest]["priority"]) >= prio:
            _log(name,"BLOCK","too many sounds")
            return false
        _stop(lowest,"voice limit, "+name+" wins")
    var length: float = float(clip_length.get(name,1.0))/maxf(pitch,0.1)
    active[name] = {"start":clock,"length":length,"priority":prio}
    last_played[name] = clock
    play_count[name] = int(play_count.get(name,0))+1
    if voices.has(name):
        var player: AudioStreamPlayer = voices[name]
        player.pitch_scale = pitch
        player.volume_db = float(ev["gain_db"])+linear_to_db(maxf(intensity*group_gain(clip_group(name)),0.0005))
        player.stop()
        player.play()
    _log(name,"PLAY",reason)
    return true

func _loop(name: String, target: float, dt: float, reason: String) -> void:
    var cur: float = float(loop_level.get(name,0.0))
    var rate: float = float(LOOPS[name]["rate"])
    cur = move_toward(cur,clampf(target,0.0,1.0),rate*dt)
    loop_level[name] = cur
    loop_reason[name] = reason
    if not voices.has(name):
        return
    var player: AudioStreamPlayer = voices[name]
    if cur <= 0.002:
        if player.playing:
            player.stop()
        return
    player.volume_db = float(LOOPS[name]["gain_db"])+linear_to_db(maxf(cur*group_gain(clip_group(name)),0.0005))
    if not player.playing:
        player.play()

# ------------------------------------------------------------ driving

func drive_tick(speed_kmh: float,drift_angle_deg: float,gas: float,
        handbrake: float,offroad: bool,dt: float) -> void:
    if dt <= 0.0:
        return
    clock += dt
    if synth_muted and synth_player != null:
        synth_muted = false
        synth_player.stream_paused = false
    var slip: float = clampf((absf(drift_angle_deg)-6.0)/32.0,0.0,1.0)
    # Drift with hysteresis so the squeal and the regrip do not chatter.
    if not drifting and slip > 0.20 and speed_kmh > 14.0:
        drifting = true
        drift_time = 0.0
    elif drifting and (slip < 0.08 or speed_kmh < 10.0):
        drifting = false
        if drift_time > 0.6 and speed_kmh > 20.0:
            trigger("tyre_regrip","drift of %.1fs ended" % drift_time)
    if drifting:
        drift_time += dt
    if synth != null:
        var synth_slip: float = clampf((absf(drift_angle_deg)-8.0)/30.0,0.0,1.0)
        if handbrake > 0.45 and speed_kmh > 10.0:
            synth_slip = maxf(synth_slip,0.6)
        synth.set_state(speed_kmh,gas,synth_slip,dt)
        if _has("tyre_drift"):
            synth.squeal = 0.0
        # Road noise rises with speed and ducks while the tyres squeal.
        var squeal_mix: float = maxf(drift_mix,synth.squeal)
        synth.road_noise = clampf(speed_kmh/120.0,0.0,1.0)*0.55*(1.0-0.85*squeal_mix) if speed_kmh > 3.0 else 0.0
    # Loops.
    var drift_target: float = slip*(0.6+0.4*gas) if (drifting or slip > 0.12) and speed_kmh > 12.0 else 0.0
    _loop("tyre_drift",drift_target,dt,"slip %.0f%%" % (slip*100.0) if drift_target > 0.0 else "no slip")
    drift_mix = float(loop_level.get("tyre_drift",0.0))
    var wind: float = clampf((speed_kmh-60.0)/80.0,0.0,1.0)
    _loop("wind_speed",wind*wind,dt,"%.0f km/h" % speed_kmh)
    _loop("gravel_roll",clampf(speed_kmh/60.0,0.0,1.0) if offroad else 0.0,dt,"off-road" if offroad else "on asphalt")
    # Edge-triggered one-shots.
    if handbrake > 0.45 and previous_handbrake < 0.45 and speed_kmh > 20.0:
        trigger("tyre_handbrake","handbrake pulled at %d km/h" % int(speed_kmh))
    full_throttle_time = full_throttle_time+dt if gas > 0.7 else 0.0
    if gas > 0.7 and previous_gas < 0.3 and speed_kmh > 10.0:
        trigger("turbo_spool","throttle stamped at %d km/h" % int(speed_kmh))
    if previous_gas > 0.7 and gas < 0.2 and speed_kmh > 14.0 and full_throttle_time_before_lift > 1.0:
        trigger("turbo_bov","lift after %.1fs on boost" % full_throttle_time_before_lift)
    # Exhaust: exactly once per afterfire window (rising edge), never per tick.
    if synth != null:
        var af: float = synth.afterfire
        if af >= 0.99 and previous_afterfire < 0.99:
            if speed_kmh > 60.0:
                trigger("exhaust_pops","lift-off at %d km/h, %d rpm" % [int(speed_kmh),int(synth.rpm)],1.0,exhaust_pitch)
            elif speed_kmh > 30.0:
                trigger("exhaust_single","lift-off at %d km/h" % int(speed_kmh),1.0,exhaust_pitch)
        previous_afterfire = af
    full_throttle_time_before_lift = full_throttle_time if gas > 0.7 else full_throttle_time_before_lift
    previous_handbrake = handbrake
    previous_gas = gas

func wall_event(impact_mps: float) -> void:
    if not _has("barrier_hit"):
        if synth != null:
            synth.impact(clampf(impact_mps/14.0,0.15,1.0))
        return
    if impact_mps >= 3.0:
        trigger("barrier_hit","impact %.1f m/s" % impact_mps,clampf(0.45+impact_mps/16.0,0.45,1.0))
    elif impact_mps >= 1.2:
        trigger("barrier_scrape_light","touch %.1f m/s" % impact_mps)

## Continuous body-on-wall contact (sliding speed along the barrier, m/s);
## 0 when the car is clear of the walls.
func wall_contact(slide_mps: float) -> void:
    if synth == null:
        return
    var level: float = clampf((slide_mps-1.0)/22.0,0.0,1.0) if slide_mps > 1.0 else 0.0
    if _has("barrier_scrape_heavy"):
        synth.scrape_target = 0.0
        _loop("barrier_scrape_heavy",level,1.0/120.0,"sliding %.1f m/s" % slide_mps if level > 0.0 else "clear")
    else:
        synth.scrape_target = level

## Called every tick while a wheel is on a kerb: plays once on entry.
func kerb_event(speed_kmh: float) -> void:
    var entering: bool = clock-last_kerb_call > 0.25
    last_kerb_call = clock
    if entering and speed_kmh > 12.0:
        trigger("curb_rumble","kerb entry at %d km/h" % int(speed_kmh),clampf(speed_kmh/90.0,0.4,1.0))

func reset() -> void:
    synth_muted = false
    if synth_player != null:
        synth_player.stream_paused = false
    if synth != null:
        synth.rpm = synth.idle_rpm
        synth.load = 0.0
        synth.squeal = 0.0
        synth.scrape = 0.0
        synth.scrape_target = 0.0
        synth.road_noise = 0.0
    previous_gas = 0.0
    previous_handbrake = 0.0
    previous_afterfire = 0.0
    full_throttle_time = 0.0
    full_throttle_time_before_lift = 0.0
    drifting = false
    drift_mix = 0.0
    for name in active.keys():
        _stop(name,"reset")
    for name in LOOPS.keys():
        loop_level[name] = 0.0
        if voices.has(name):
            (voices[name] as AudioStreamPlayer).stop()

func silence() -> void:
    synth_muted = true
    if synth_player != null:
        # clear_buffer() is illegal while playing; pausing keeps it silent.
        synth_player.stream_paused = true
    if synth != null:
        synth.rpm = synth.idle_rpm
        synth.squeal = 0.0
        synth.scrape = 0.0
        synth.scrape_target = 0.0
        synth.road_noise = 0.0
    for player in voices.values():
        (player as AudioStreamPlayer).stop()
    active.clear()
    for name in LOOPS.keys():
        loop_level[name] = 0.0

## Diagnostics: what plays right now and why (DEVELOPER > AUDIO DEBUG).
func debug_lines() -> PackedStringArray:
    _refresh_active()
    var out: PackedStringArray = []
    out.append("MODE %s  •  %s  •  turbo clips %s  •  exhaust pitch %.2f" % [
        "SYNTH + RECORDED" if recorded_mode else "SYNTH ONLY",
        synth.layout if synth != null else "-","on" if turbo else "off",exhaust_pitch])
    if synth != null:
        out.append("ENGINE %4d rpm  gear %d  load %.2f  squeal %.2f  road %.2f  afterfire %.2f%s" % [
            int(synth.rpm),synth.gear,synth.load,synth.squeal,synth.road_noise,synth.afterfire,
            "  LIMITER" if synth.on_limiter() else ""])
    for name in LOOPS.keys():
        var lv: float = float(loop_level.get(name,0.0))
        if lv > 0.002:
            out.append("LOOP %-20s %5.1f dB  (%s)" % [name,float(LOOPS[name]["gain_db"])+linear_to_db(lv),str(loop_reason.get(name,""))])
    for name in active.keys():
        var a: Dictionary = active[name]
        out.append("ONE  %-20s %.2f/%.2fs" % [name,clock-float(a["start"]),float(a["length"])])
    for i in range(log.size()-1,maxi(-1,log.size()-7),-1):
        var e: Dictionary = log[i]
        out.append("%6.2f %-5s %-20s %s" % [float(e["t"]),str(e["action"]),str(e["clip"]),str(e["reason"])])
    return out
