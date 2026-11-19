extends Control
class_name NitroAudioDebugOverlay
## DEVELOPER > AUDIO DEBUG OVERLAY: lists the engine state, active loops and
## one-shots and the last mixer decisions (PLAY / BLOCK / STOP + reason).
## Off by default; never part of the player HUD.
const STYLE = preload("res://scripts/ui/hud_style.gd")
const SETTINGS_PATH: String = "user://nitro_settings.cfg"
var audio: Node

static func enabled() -> bool:
    var cfg := ConfigFile.new()
    if cfg.load(SETTINGS_PATH) != OK:
        return false
    return bool(cfg.get_value("developer","audio_debug",false))

static func set_enabled(on: bool) -> void:
    var cfg := ConfigFile.new()
    cfg.load(SETTINGS_PATH)
    cfg.set_value("developer","audio_debug",on)
    cfg.save(SETTINGS_PATH)

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(_delta: float) -> void:
    queue_redraw()

func _draw() -> void:
    if audio == null or not audio.has_method("debug_lines"):
        return
    var s: Vector2 = get_viewport_rect().size
    var lines: PackedStringArray = audio.debug_lines()
    var size: int = int(clampf(minf(s.x,s.y)/46.0,11.0,24.0))
    var lh: float = float(size)*1.25
    var box := Rect2(s.x*0.02,s.y*0.30,s.x*0.96,lh*float(lines.size())+lh*0.6)
    draw_rect(box,Color(0,0,0,0.72))
    draw_rect(box,Color(STYLE.PINK.r,STYLE.PINK.g,STYLE.PINK.b,0.8),false,2.0)
    for i in range(lines.size()):
        var line: String = lines[i]
        var col: Color = Color(0.85,0.87,0.92)
        if line.contains(" PLAY "):
            col = Color(0.45,1.0,0.6)
        elif line.contains(" BLOCK ") or line.contains(" SKIP "):
            col = Color(1.0,0.75,0.35)
        elif line.contains(" STOP "):
            col = Color(1.0,0.45,0.45)
        elif line.begins_with("LOOP") or line.begins_with("ONE"):
            col = STYLE.PINK_SOFT
        draw_string(STYLE.SEMI,Vector2(box.position.x+8.0,box.position.y+lh*(float(i)+1.0)),line,
            HORIZONTAL_ALIGNMENT_LEFT,box.size.x-16.0,size,col)
