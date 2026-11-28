extends CanvasLayer
class_name NitroMobileModal
## Portrait-readable confirmation card (issue #65, v0.1.52), used for the player-track SAVE / SAVE AS / RENAME /
## DELETE confirmations (track_file_dialog.gd).
## Replaces the native ConfirmationDialog that opened as a tiny desktop window on a portrait phone:
##  * an in-scene full-screen layer (dimmed background takes every touch: nothing behind can be pressed by mistake);
##  * a card ~92 % of the screen width in portrait, placed in the upper part so the Android keyboard never covers
##    the name field or the buttons;
##  * text, field and buttons sized from the same ui unit as the menus (thumb-size buttons, >= 88 px on a phone);
##  * Android BACK (android_back.gd closes the top modal) / Escape = CANCEL.
## Data protection is unchanged: the callback does the guarded store operation and returns an error string; on an
## error the card stays open and shows it (nothing is overwritten or deleted silently). CANCEL never touches files.
const STYLE = preload("res://scripts/ui/hud_style.gd")
const DANGER: Color = Color(1.0,0.36,0.40)

signal confirmed
signal canceled

var title_text: String = ""
var message: String = ""
## Message plus the last error (kept for tests and readers of the old ConfirmationDialog API).
var dialog_text: String = ""
var error_text: String = ""
var unit: float = 1.0
var callback: Callable
var name_edit: LineEdit
var _ok: Button
var _cancel: Button
var _message_label: Label
var _error_label: Label
var _card: PanelContainer

## Callbacks return an error to keep the confirmed operation on screen.
static func open(parent: Node, node_name: String, title: String, message: String, action: String,
        callback: Callable, initial_name: Variant = null) -> NitroMobileModal:
    var old: Node = parent.get_node_or_null(node_name)
    if old != null:
        parent.remove_child(old)
        old.queue_free()
    var dialog: NitroMobileModal = load("res://scripts/ui/mobile_modal.gd").new()
    dialog.name = node_name
    dialog.layer = 110
    dialog.title_text = title
    dialog.message = message
    dialog.dialog_text = message
    dialog.callback = callback
    parent.add_child(dialog)
    dialog._build(parent.get_viewport().get_visible_rect().size,action,initial_name)
    return dialog

static func ui_unit_for(s: Vector2) -> float:
    return clampf(s.x/700.0,1.0,2.2) if s.y > s.x else clampf(s.y/560.0,0.9,1.4)

func get_ok_button() -> Button:
    return _ok

func get_cancel_button() -> Button:
    return _cancel

func _build(s: Vector2, action: String, initial_name: Variant) -> void:
    add_to_group("nitro_modal")
    unit = ui_unit_for(s)
    var portrait: bool = s.y > s.x
    var root := Control.new()
    root.name = "Modal root"
    root.theme = STYLE.screen_theme(unit)
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(root)
    var dim := ColorRect.new()
    dim.name = "Dim"
    dim.color = Color(0.0,0.0,0.0,0.72)
    dim.mouse_filter = Control.MOUSE_FILTER_STOP
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(dim)
    _card = PanelContainer.new()
    _card.name = "Card"
    var w: float = minf(s.x*(0.92 if portrait else 0.62),980.0*unit)
    _card.custom_minimum_size = Vector2(w,0.0)
    _card.position = Vector2((s.x-w)*0.5,s.y*(0.09 if portrait else 0.08))
    _card.size = Vector2(w,0.0)
    root.add_child(_card)
    var pad := MarginContainer.new()
    for side in ["left","right","top","bottom"]:
        pad.add_theme_constant_override("margin_"+side,int(26.0*unit))
    _card.add_child(pad)
    var col := VBoxContainer.new()
    col.add_theme_constant_override("separation",int(18.0*unit))
    pad.add_child(col)
    var title := Label.new()
    title.name = "Title"
    title.text = title_text
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_override("font",STYLE.BOLD)
    title.add_theme_font_size_override("font_size",int(30.0*unit))
    title.add_theme_color_override("font_color",DANGER if action == "DELETE" else STYLE.WHITE)
    col.add_child(title)
    _message_label = Label.new()
    _message_label.name = "Message"
    _message_label.text = message
    _message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _message_label.add_theme_font_size_override("font_size",int(22.0*unit))
    _message_label.add_theme_color_override("font_color",STYLE.MUTED)
    col.add_child(_message_label)
    if initial_name != null:
        name_edit = LineEdit.new()
        name_edit.name = "Track name"
        name_edit.text = str(initial_name)
        name_edit.max_length = 42
        name_edit.clear_button_enabled = true
        name_edit.select_all_on_focus = true
        name_edit.custom_minimum_size.y = 84.0*unit
        name_edit.add_theme_font_size_override("font_size",int(28.0*unit))
        var box := StyleBoxFlat.new()
        box.bg_color = Color(0.09,0.09,0.12)
        box.border_color = STYLE.EDGE
        box.set_border_width_all(int(maxf(2.0,2.0*unit)))
        box.set_corner_radius_all(int(12.0*unit))
        box.content_margin_left = 18.0*unit
        box.content_margin_right = 12.0*unit
        name_edit.add_theme_stylebox_override("normal",box)
        var focus_box: StyleBoxFlat = box.duplicate()
        focus_box.border_color = STYLE.PINK
        name_edit.add_theme_stylebox_override("focus",focus_box)
        name_edit.text_submitted.connect(func(_t: String) -> void: _confirm())
        col.add_child(name_edit)
    _error_label = Label.new()
    _error_label.name = "Error"
    _error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _error_label.add_theme_font_override("font",STYLE.BOLD)
    _error_label.add_theme_font_size_override("font_size",int(21.0*unit))
    _error_label.add_theme_color_override("font_color",DANGER)
    _error_label.visible = false
    col.add_child(_error_label)
    var row := HBoxContainer.new()
    row.name = "Buttons"
    row.add_theme_constant_override("separation",int(16.0*unit))
    col.add_child(row)
    _cancel = _button("CANCEL",false)
    _cancel.name = "Cancel"
    _cancel.pressed.connect(cancel)
    row.add_child(_cancel)
    _ok = _button(action,true)
    _ok.name = "Confirm"
    _ok.pressed.connect(_confirm)
    row.add_child(_ok)
    if action == "DELETE":
        _ok.add_theme_color_override("font_color",DANGER)
    if name_edit != null:
        name_edit.grab_focus()
        name_edit.select_all()
    else:
        _cancel.grab_focus() # the safe choice has the focus (controller / keyboard)

func _button(caption: String, primary: bool) -> Button:
    var b := Button.new()
    b.text = caption
    b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    b.custom_minimum_size = Vector2(0.0,88.0*unit)
    b.add_theme_font_size_override("font_size",int(26.0*unit))
    STYLE.style_button(b,unit,primary)
    return b

func _confirm() -> void:
    if not is_inside_tree() or is_queued_for_deletion():
        return
    var error: String = str(callback.call(name_edit.text) if name_edit != null else callback.call())
    if error == "":
        confirmed.emit()
        if is_inside_tree():
            queue_free()
        return
    error_text = error
    dialog_text = message+"\n\n"+error
    _error_label.text = error
    _error_label.visible = true

func cancel() -> void:
    if is_queued_for_deletion():
        return
    canceled.emit()
    queue_free()

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        get_viewport().set_input_as_handled()
        cancel()
