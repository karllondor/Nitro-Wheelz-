extends SceneTree
## Issue #28 evidence (developer tool, needs a display): the REAL race touch controls and HUD drawn over the sky colours of the
## lighting presets. GAS at rest and pressed, and the minimap with the player's dot, for two HUD accents. Run on the BASE and on
## the patched code and compare the PNGs.
##   OUT_DIR=/abs/dir TAG=after xvfb-run -a -s "-screen 0 540x1200x24" godot --path game \
##     --rendering-driver opengl3 --resolution 540x1200 --script res://tests/capture_hud_gas_minimap.gd
## Writes PNGs only (the HUD accent is changed in memory and restored).
const STYLE = preload("res://scripts/ui/hud_style.gd")
const HUD = preload("res://scripts/ui/race_hud.gd")
const TOUCH = preload("res://scripts/ui/race_touch.gd")
const ENV = preload("res://scripts/lighting/race_environment.gd")
const TIME = preload("res://scripts/lighting/time_of_day.gd")

func _initialize() -> void:
    call_deferred("_run")

func _sky(preset: int) -> Array:
    if preset == TIME.Preset.DAY:
        return [Color(0.55,0.72,0.95),Color(0.80,0.88,0.97)]
    var look: Dictionary = ENV.LOOKS[preset]
    return [look.sky,look.horizon]

func _loop() -> PackedVector2Array:
    var pts := PackedVector2Array()
    for i in range(96):
        var t: float = TAU*float(i)/96.0
        pts.append(Vector2(cos(t)*(160.0+40.0*sin(3.0*t)),sin(t)*(110.0+25.0*cos(2.0*t))))
    return pts

func _frame(out: String, name: String, preset: int, accent: String, pressed: bool) -> void:
    STYLE.set_accent(accent)
    var size: Vector2 = root.get_visible_rect().size
    var holder := Control.new()
    holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(holder)
    var sky: Array = _sky(preset)
    var top := ColorRect.new()
    top.color = sky[0]
    top.size = Vector2(size.x,size.y*0.5)
    holder.add_child(top)
    var bottom := ColorRect.new()
    bottom.color = sky[1]
    bottom.position = Vector2(0.0,size.y*0.5)
    bottom.size = Vector2(size.x,size.y*0.5)
    holder.add_child(bottom)
    var hud: Control = HUD.new()
    hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    hud.track_points = _loop()
    hud.track_progress = 0.28
    hud.closed_loop = true
    holder.add_child(hud)
    var touch: Control = TOUCH.new()
    touch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    touch.throttle = 1.0 if pressed else 0.0
    touch.set("gas_press",1.0 if pressed else 0.0)       # absent before the patch: ignored there
    holder.add_child(touch)
    for _f in range(5):
        await process_frame
    touch.throttle = 1.0 if pressed else 0.0
    touch.set("gas_press",1.0 if pressed else 0.0)
    await process_frame
    await RenderingServer.frame_post_draw
    root.get_viewport().get_texture().get_image().save_png("%s%s_%s.png" % [out,name,"pressed" if pressed else "rest"])
    holder.queue_free()
    await process_frame

func _run() -> void:
    var out: String = OS.get_environment("OUT_DIR")
    out = (out if out != "" else "user://hud").trim_suffix("/")+"/"
    var tag: String = OS.get_environment("TAG")
    tag = tag if tag != "" else "shot"
    DirAccess.make_dir_recursive_absolute(out)
    var was: String = STYLE.accent_name
    for preset in [TIME.Preset.DAWN,TIME.Preset.DAY,TIME.Preset.NIGHT]:
        for accent in ["pink","cyan"]:
            for pressed in [false,true]:
                await _frame(out,"%s_%s_%s" % [tag,TIME.LABELS[preset].replace(" ","_"),accent],preset,accent,pressed)
    STYLE.set_accent(was)
    print("HUD CAPTURED to %s" % ProjectSettings.globalize_path(out))
    quit(0)
