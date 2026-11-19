extends Node
class_name NitroDriveAudio
## Adaptive sound layers for user-owned WAN 30-second source films.
## Audio assets are separate .ogg in res://assets/audio/ - no hardwired video.
## Silent fail-safe if some imported clips are unavailable.
const ROOT: String = "res://assets/audio/"
const CLIPS: Array[String] = [
    "tyre_rolling","tyre_corner","tyre_drift","tyre_handbrake","tyre_regrip",
    "turbo_spool","turbo_bov","turbo_flutter","exhaust_single","exhaust_pops",
    "engine_limiter","curb_rumble","barrier_scrape_light","barrier_hit",
    "barrier_scrape_heavy","gravel_roll","wind_speed"
]
var voices: Dictionary = {}
var previous_gas: float = 0.0
var previous_handbrake: float = 0.0
var previous_drifting: bool = false
var turbo_cooldown: float = 0.0
var bump_cooldown: float = 0.0
var scrape_cooldown: float = 0.0
var roll_cooldown: float = 0.0
var has_source_audio: bool = false

func _ready() -> void:
    for name in CLIPS:
        var uri: String = ROOT+name+".ogg"
        if not ResourceLoader.exists(uri):
            continue
        var stream: AudioStream = load(uri) as AudioStream
        if stream == null:
            continue
        var player := AudioStreamPlayer.new()
        player.name = "SFX_"+name
        # All clips share the same front-of-car mixing position (2D)
        # on mobile; dedicated volume based on physics, not screen camera.
        player.stream = stream
        player.volume_db = -45.0
        player.bus = "Master"
        add_child(player)
        voices[name] = player
        has_source_audio = true
    for continuous in ["tyre_rolling","tyre_drift","wind_speed","gravel_roll"]:
        if voices.has(continuous):
            var player: AudioStreamPlayer = voices[continuous]
            var duplicated: AudioStream = player.stream.duplicate()
            if duplicated is AudioStreamOggVorbis:
                (duplicated as AudioStreamOggVorbis).loop = true
            player.stream = duplicated
            player.play()

func _exit_tree() -> void:
    # Four looping OGG players must release their decoder streams before the
    # scene exits, otherwise Godot reports resources still in use at shutdown.
    for player in voices.values():
        if is_instance_valid(player):
            (player as AudioStreamPlayer).stop()
            (player as AudioStreamPlayer).stream = null
    voices.clear()
    has_source_audio = false

func _loop_volume(name: String,linear: float,dt: float) -> void:
    if not voices.has(name):
        return
    var player: AudioStreamPlayer = voices[name]
    var target_db: float = linear_to_db(maxf(linear,0.0005))
    player.volume_db = move_toward(player.volume_db,target_db,50.0*dt)
    if not player.playing:
        player.play()

func _one_shot(name: String,db: float = -9.0) -> void:
    if not voices.has(name):
        return
    var player: AudioStreamPlayer = voices[name]
    player.volume_db = db
    player.stop()
    player.play()

func drive_tick(speed_kmh: float,drift_angle_deg: float,gas: float,
        handbrake: float,offroad: bool,dt: float) -> void:
    if not has_source_audio or dt <= 0.0:
        return
    var speed: float = clampf(speed_kmh/115.0,0.0,1.0)
    var slip: float = clampf((absf(drift_angle_deg)-6.0)/32.0,0.0,1.0)
    var skidding: bool = slip > 0.12 and speed_kmh > 14.0
    turbo_cooldown = maxf(0.0,turbo_cooldown-dt)
    bump_cooldown = maxf(0.0,bump_cooldown-dt)
    scrape_cooldown = maxf(0.0,scrape_cooldown-dt)
    roll_cooldown = maxf(0.0,roll_cooldown-dt)

    _loop_volume("tyre_rolling",0.08 + (speed*0.14 if speed_kmh>3.0 else 0.0),dt)
    _loop_volume("tyre_drift",slip*(0.25+0.25*gas) if skidding else 0.0,dt)
    _loop_volume("wind_speed",pow(speed,2.3)*0.25,dt)
    _loop_volume("gravel_roll",0.22*speed if offroad else 0.0,dt)

    if handbrake > 0.45 and previous_handbrake < 0.45 and speed_kmh > 7.0:
        _one_shot("tyre_handbrake",-6.0)
    if previous_drifting and not skidding and speed_kmh > 15.0:
        _one_shot("tyre_regrip",-11.0)
    if gas > 0.7 and previous_gas < 0.3 and turbo_cooldown <= 0.0 and speed_kmh > 10.0:
        _one_shot("turbo_spool",-12.0)
        turbo_cooldown = 3.0
    if previous_gas > 0.7 and gas < 0.2 and speed_kmh > 14.0:
        _one_shot("turbo_bov",-10.0)
        if speed_kmh > 55.0:
            _one_shot("exhaust_single",-19.0)
    # We have no gear/RPM simulation yet. This proxy plays the limiter only
    # at extreme speed; it must not imitate a constant inline-six soundtrack.
    if speed_kmh > 140.0 and gas > 0.7 and turbo_cooldown <= 0.0:
        _one_shot("engine_limiter",-15.0)
        turbo_cooldown = 3.0
    previous_handbrake = handbrake
    previous_gas = gas
    previous_drifting = skidding

func wall_event(impact_mps: float) -> void:
    if not has_source_audio:
        return
    if bump_cooldown <= 0.0:
        _one_shot("barrier_hit",clampf(-20.0+impact_mps*1.6,-20.0,-4.0))
        bump_cooldown = 0.45
    if impact_mps < 3.0 and scrape_cooldown <= 0.0:
        _one_shot("barrier_scrape_light",-12.0)
        scrape_cooldown = 1.2
    elif impact_mps > 7.0 and scrape_cooldown <= 0.0:
        _one_shot("barrier_scrape_heavy",-9.0)
        scrape_cooldown = 1.8

func kerb_event(speed_kmh: float) -> void:
    if has_source_audio and speed_kmh > 12.0 and roll_cooldown <= 0.0:
        _one_shot("curb_rumble",-16.0)
        roll_cooldown = 1.3

func reset() -> void:
    previous_gas = 0.0
    previous_handbrake = 0.0
    previous_drifting = false
    for continuous in ["tyre_drift","wind_speed","gravel_roll"]:
        if voices.has(continuous):
            (voices[continuous] as AudioStreamPlayer).volume_db = -56.0

func silence() -> void:
    for player in voices.values():
        (player as AudioStreamPlayer).volume_db = -56.0
