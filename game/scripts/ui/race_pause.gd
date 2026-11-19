extends Control
class_name NitroPauseMenu
## Single modal pause overlay. Blocks touch to old race controls.
const PURPLE := Color(0.56,0.29,0.99)
const GOLD := Color(1.0,0.82,0.25)
const STYLE = preload("res://scripts/ui/hud_style.gd")

func show_pause(on_resume: Callable,on_restart: Callable,on_garage: Callable) -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var s: Vector2 = get_viewport_rect().size
    var sc: float = clampf(s.x/700.0,0.85,1.7)
    theme = STYLE.screen_theme(sc)
    var shade := ColorRect.new()
    shade.color = Color(0.005,0.006,0.011,0.76)
    shade.mouse_filter = Control.MOUSE_FILTER_STOP
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(shade)
    var centre := CenterContainer.new()
    centre.mouse_filter = Control.MOUSE_FILTER_PASS
    centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(centre)
    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(s.x*0.82,0)
    panel.add_theme_stylebox_override("panel",STYLE.modal_box(sc))
    centre.add_child(panel)
    var margin := MarginContainer.new()
    var p: int = int(20.0*sc)
    for side in ["margin_left","margin_right","margin_top","margin_bottom"]:
        margin.add_theme_constant_override(side,p)
    panel.add_child(margin)
    var stack := VBoxContainer.new()
    stack.add_theme_constant_override("separation",int(13.0*sc))
    margin.add_child(stack)
    var head := Label.new()
    head.text = "PAUSED"
    head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    head.add_theme_color_override("font_color",STYLE.WHITE)
    head.add_theme_font_override("font",STYLE.BOLD)
    head.add_theme_font_size_override("font_size",int(34.0*sc))
    stack.add_child(head)
    var hint := Label.new()
    hint.text = "Resume your drift or choose another track"
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.add_theme_color_override("font_color",Color(0.86,0.83,0.95))
    hint.add_theme_font_size_override("font_size",int(16.0*sc))
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    stack.add_child(hint)
    for item in [
        {"name":"RESUME","action":on_resume},
        {"name":"RESTART","action":on_restart},
        {"name":"GARAGE / MENU","action":on_garage}
    ]:
        var btn := Button.new()
        btn.text = str(item["name"])
        btn.custom_minimum_size.y = 52.0*sc
        btn.add_theme_font_size_override("font_size",int(20.0*sc))
        STYLE.style_button(btn,sc)
        btn.pressed.connect(item["action"])
        stack.add_child(btn)
