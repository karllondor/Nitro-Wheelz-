extends RefCounted
## Player-track SAVE / SAVE AS / RENAME / DELETE confirmation (boot My Tracks, node editor, terrain builder).
## v0.1.52 (issue #65): a portrait-readable in-scene card (mobile_modal.gd) instead of the native ConfirmationDialog
## that opened as a tiny window on phones. Same call, same protection: the callback runs the guarded store operation
## and returns an error to keep the card open with that error; CANCEL never touches files.
const MODAL = preload("res://scripts/ui/mobile_modal.gd")

static func show(parent: Node, title: String, message: String, action: String,
        callback: Callable, initial_name: Variant = null) -> NitroMobileModal:
    return MODAL.open(parent,"Track file dialog",title,message,action,callback,initial_name)
