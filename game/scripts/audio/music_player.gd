extends Node
## Background music (autoload "Music"): one original track that simply plays
## and loops in menus and races — no adaptation to driving (owner's choice).
## Volume follows the MUSIC slider; SOUND OFF mutes it with everything else.
## Track: res://assets/music/night_drift.ogg, made by tools/compose_music.py.
const STYLE = preload("res://scripts/ui/hud_style.gd")
const TRACK: String = "res://assets/music/night_drift.ogg"

var player: AudioStreamPlayer
var _applied: float = -1.0

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS   # keeps playing while paused
    STYLE.ensure_settings()
    # No audio device (and no Vorbis decoders) in headless test runs.
    if DisplayServer.get_name() == "headless" or not ResourceLoader.exists(TRACK):
        return
    var stream: AudioStream = load(TRACK) as AudioStream
    if stream is AudioStreamOggVorbis:
        (stream as AudioStreamOggVorbis).loop = true
    player = AudioStreamPlayer.new()
    player.name = "Background music"
    player.stream = stream
    player.bus = "Master"
    add_child(player)
    _apply_volume()
    player.play()

func _process(_delta: float) -> void:
    if player != null and absf(_applied-STYLE.vol_music) > 0.001:
        _apply_volume()

func _apply_volume() -> void:
    _applied = STYLE.vol_music
    player.volume_db = linear_to_db(maxf(STYLE.vol_music,0.0001))-6.0
    player.stream_paused = STYLE.vol_music <= 0.001

func _exit_tree() -> void:
    if player != null:
        player.stop()
        player.stream = null
