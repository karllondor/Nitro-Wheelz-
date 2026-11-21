extends Control
class_name NitroAudioDebugOverlay
## DEVELOPER > AUDIO DEBUG OVERLAY: live state of the sound synth (engine
## layout, rpm, gear, load, misfires, squeal, scrape, player mix).
## Off by default; never part of the player HUD.
const STYLE = preload("res://scripts/ui/hud_style.gd")
const DEV = preload("res://scripts/dev_settings.gd")   # user://nitro_dev.cfg
var audio: Node

static func enabled() -> bool:
    return bool(DEV.get_value("developer","audio_debug",false))

static func set_enabled(on: bool) -> void:
    DEV.set_value("developer","audio_debug",on)

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
        var col: Color = STYLE.PINK_SOFT if i == 0 else Color(0.85,0.87,0.92)
        draw_string(STYLE.SEMI,Vector2(box.position.x+8.0,box.position.y+lh*(float(i)+1.0)),line,
            HORIZONTAL_ALIGNMENT_LEFT,box.size.x-16.0,size,col)
