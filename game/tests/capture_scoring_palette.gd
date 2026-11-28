extends SceneTree
## Issue #66 evidence (developer tool, needs a display): the REAL race HUD draws three scoring callouts (a technical bonus,
## a banked chain, a lost chain) over the sky of each lighting preset (DAWN, DAY with a white cloud strip, GOLDEN HOUR, NIGHT)
## for several HUD accents. Run on the BASE and on the patched code and compare the PNGs.
##   OUT_DIR=/abs/dir TAG=after xvfb-run -a -s "-screen 0 540x1200x24" godot --path game \
##     --rendering-driver opengl3 --resolution 540x1200 --script res://tests/capture_scoring_palette.gd
## Only touches the HUD accent in memory (restored); writes PNGs only.
const STYLE = preload("res://scripts/ui/hud_style.gd")
const HUD = preload("res://scripts/ui/race_hud.gd")
const ENV = preload("res://scripts/lighting/race_environment.gd")
const TIME = preload("res://scripts/lighting/time_of_day.gd")
const ACCENTS: Array[String] = ["pink","red","cyan"]

func _initialize() -> void:
    call_deferred("_run")

func _backdrop(preset: int) -> Array:
    if preset == TIME.Preset.DAY:
        return [Color(0.55,0.72,0.95),Color(0.80,0.88,0.97)]
    var look: Dictionary = ENV.LOOKS[preset]
    return [look.sky,look.horizon]

func _run() -> void:
    var out: String = OS.get_environment("OUT_DIR")
    out = (out if out != "" else "user://palette").trim_suffix("/")+"/"
    var tag: String = OS.get_environment("TAG")
    tag = tag if tag != "" else "shot"
    DirAccess.make_dir_recursive_absolute(out)
    var was: String = STYLE.accent_name
    var size: Vector2 = root.get_visible_rect().size
    var only: String = OS.get_environment("ONLY")   # optional: one preset label, e.g. DAY
    for preset in [TIME.Preset.DAWN,TIME.Preset.DAY,TIME.Preset.GOLDEN_HOUR,TIME.Preset.NIGHT]:
        if only != "" and TIME.LABELS[preset].replace(" ","_") != only:
            continue
        for accent in ACCENTS:
            STYLE.set_accent(accent)
            var holder := Control.new()
            holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
            root.add_child(holder)
            var colors: Array = _backdrop(preset)
            var top := ColorRect.new()
            top.color = colors[0]
            top.position = Vector2.ZERO
            top.size = Vector2(size.x,size.y*0.5)
            holder.add_child(top)
            var bottom := ColorRect.new()
            bottom.color = colors[1]
            bottom.position = Vector2(0.0,size.y*0.5)
            bottom.size = Vector2(size.x,size.y*0.5)
            holder.add_child(bottom)
            if preset == TIME.Preset.DAY:
                var cloud := ColorRect.new()                       # worst case for light text: a white cloud behind the callouts
                cloud.color = Color(1,1,1)
                cloud.position = Vector2(size.x*0.06,size.y*0.425)
                cloud.size = Vector2(size.x*0.88,size.y*0.13)
                holder.add_child(cloud)
            var hud: Control = HUD.new()
            hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
            hud.car_screen = Vector2(size.x*0.5,size.y*0.68)
            var events: Array[Dictionary] = []
            for e in [["KERB CLIP  x1.5",0.15],["BANKED  +12,345",0.10],["WALL!  CHAIN LOST",0.05]]:
                events.append({"text":e[0],"age":e[1]})
            hud.score_events = events
            holder.add_child(hud)
            for _f in range(6):
                await process_frame
            await RenderingServer.frame_post_draw
            root.get_viewport().get_texture().get_image().save_png("%s%s_%s_%s.png" % [out,tag,TIME.LABELS[preset].replace(" ","_"),accent])
            holder.queue_free()
            await process_frame
    STYLE.set_accent(was)
    print("PALETTE CAPTURED to %s" % ProjectSettings.globalize_path(out))
    quit(0)
