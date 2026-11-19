extends Node
class_name NitroDriveAudio
## Car audio: everything comes from the procedural synth (engine, tyre
## squeal, wall scrape, impacts) - no recorded sound effects (v0.1.21: the
## recorded pack was removed at the owner's request, the synth-only sound
## was preferred). The engine voice follows the car profile (Lada I4 /
## RYU-32 V8) through synth.apply_profile(); race.gd feeds the driving state.
const SYNTH = preload("res://scripts/audio/engine_synth.gd")
const STYLE = preload("res://scripts/ui/hud_style.gd")

var synth: NitroEngineSynth
var synth_player: AudioStreamPlayer
var synth_playback: AudioStreamGeneratorPlayback
var synth_muted: bool = false

func _ready() -> void:
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

func _process(_delta: float) -> void:
    if synth == null:
        return
    # Player mix (settings sliders): engine, tyres, effects.
    synth.engine_gain = STYLE.vol_engine
    synth.tyre_gain = STYLE.vol_tyres
    synth.fx_gain = STYLE.vol_fx
    if synth_playback == null or synth_muted:
        return
    var frames: int = synth_playback.get_frames_available()
    if frames > 0:
        synth_playback.push_buffer(synth.render(frames))

func drive_tick(speed_kmh: float,drift_angle_deg: float,gas: float,
        handbrake: float,_offroad: bool,dt: float) -> void:
    if dt <= 0.0 or synth == null:
        return
    if synth_muted and synth_player != null:
        synth_muted = false
        synth_player.stream_paused = false
    var slip: float = clampf((absf(drift_angle_deg)-8.0)/30.0,0.0,1.0)
    if handbrake > 0.45 and speed_kmh > 10.0:
        slip = maxf(slip,0.6)
    synth.set_state(speed_kmh,gas,slip,dt)

func wall_event(impact_mps: float) -> void:
    if synth != null:
        synth.impact(clampf(impact_mps/14.0,0.15,1.0))

## Continuous body-on-wall contact (sliding speed along the barrier, m/s);
## 0 when the car is clear of the walls. Drives the synth scrape layer.
func wall_contact(slide_mps: float) -> void:
    if synth != null:
        synth.scrape_target = clampf((slide_mps-1.0)/22.0,0.0,1.0) if slide_mps > 1.0 else 0.0

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

## Diagnostics (DEVELOPER > AUDIO DEBUG OVERLAY): live synth state.
func debug_lines() -> PackedStringArray:
    var out: PackedStringArray = []
    if synth == null:
        return out
    out.append("ENGINE %s  •  %d cyl  •  %d exhaust bank(s)" % [synth.layout,synth.cylinders,synth._banks])
    out.append("RPM %4d  gear %d  load %.2f  firing %.0f Hz%s" % [int(synth.rpm),synth.gear,synth.load,
        synth.firing_hz(),"  LIMITER" if synth.on_limiter() else ""])
    out.append("afterfire %.2f  misfires %d  shifts %d  limiter hits %d" % [synth.afterfire,synth.misfires,
        synth.shifts,synth.limiter_hits])
    out.append("TYRES squeal %.2f   WALL scrape %.2f" % [synth.squeal,synth.scrape])
    out.append("MIX engine %d%%  tyres %d%%  effects %d%%%s" % [int(synth.engine_gain*100.0),
        int(synth.tyre_gain*100.0),int(synth.fx_gain*100.0),"  (MUTED)" if synth_muted else ""])
    return out
