extends RefCounted
const STYLE = preload("res://scripts/ui/hud_style.gd")

## Callbacks return an error to keep the confirmed operation on screen.
static func show(parent: Node, title: String, message: String, action: String,
        callback: Callable, initial_name: Variant = null) -> ConfirmationDialog:
    var dialog := ConfirmationDialog.new()
    dialog.name = "Track file dialog"
    dialog.title = title
    dialog.dialog_text = message
    dialog.transient = true
    dialog.exclusive = true
    dialog.dialog_autowrap = true
    dialog.dialog_hide_on_ok = false
    dialog.ok_button_text = action
    dialog.cancel_button_text = "CANCEL"
    var viewport := parent.get_viewport().get_visible_rect().size
    var scale := clampf(viewport.x/700.0,0.85,1.5)
    dialog.theme = STYLE.screen_theme(scale)
    dialog.get_ok_button().custom_minimum_size.y = 48.0*scale
    dialog.get_cancel_button().custom_minimum_size.y = 48.0*scale
    var edit: LineEdit
    if initial_name != null:
        edit = LineEdit.new()
        edit.name = "Track name"
        edit.text = str(initial_name)
        edit.max_length = 42
        edit.custom_minimum_size.y = 48.0*scale
        dialog.add_child(edit)
        dialog.register_text_enter(edit)
    dialog.confirmed.connect(func():
        var error: String = callback.call(edit.text) if edit != null else callback.call()
        if error == "":
            dialog.queue_free()
        else:
            dialog.dialog_text = message+"\n\n"+error)
    dialog.canceled.connect(dialog.queue_free)
    parent.add_child(dialog)
    dialog.popup_centered(Vector2i(int(minf(viewport.x*0.90,570.0)),0))
    if edit != null:
        edit.grab_focus()
        edit.select_all()
    return dialog
