extends Node
## Issue #65 / #59 on a real Android build (emulator in CI, started by tools/android_three_circuits_smoke.sh with
## NITRO_SMOKE=uxrescue through the debug-only marker user://qa-uxrescue.once). Real OS input, not simulated events:
##  * DEVELOPER: after the screenshot the script swipes up with `adb shell input swipe` starting ON a button ->
##    the page must scroll and that button must NOT be pressed;
##  * Android BACK (`adb shell input keyevent KEYCODE_BACK`) -> DEVELOPER returns to the main menu, the game keeps
##    running (quit_on_go_back off);
##  * DELETE and RENAME cards: screenshot, then BACK closes the card without confirming;
##  * the GARAGE with its paint swatches (screenshot).
## Writes nothing to the player's tracks, records or settings: the cards are opened with test callbacks.
const FILE_DIALOG = preload("res://scripts/ui/track_file_dialog.gd")
const GARAGE = preload("res://scenes/garage.tscn")

var failures: Array[String] = []
var android: bool = OS.has_feature("android")

func _ready() -> void:
    _run.call_deferred()

func _check(ok: bool, message: String) -> void:
    if not ok:
        failures.append(message)

func _wait(seconds: float) -> void:
    await get_tree().create_timer(seconds).timeout

func _shot(label: String) -> void:
    for _f in range(4):
        await get_tree().process_frame
    await RenderingServer.frame_post_draw
    if not android:
        return
    var marker := FileAccess.open("user://ready-"+label,FileAccess.WRITE)
    marker.store_line(label)
    marker.close()
    while not FileAccess.file_exists("user://captured-"+label):
        await _wait(0.15)
    await _wait(1.5) # the script's swipe / BACK after the screenshot lands here

func _run() -> void:
    var boot: Node = get_tree().current_scene
    for _i in range(40):
        if boot != null and boot.has_method("show_page"):
            break
        await _wait(0.25)
        boot = get_tree().current_scene
    _check(boot != null and boot.has_method("show_page"),"the menu did not start")
    if failures.is_empty():
        await _exercise(boot)
    var verdict := "PASS: Android UI rescue on device - DEVELOPER scrolls under a real swipe that starts on a button without pressing it, Android BACK returns to the menu without closing the game, BACK closes DELETE and RENAME cards without confirming, garage paint swatches shown"
    if not failures.is_empty():
        verdict = "FAIL: "+str(failures)
    print(verdict)
    var file := FileAccess.open("user://uxrescue-verdict.txt",FileAccess.WRITE)
    file.store_line(verdict)
    file.close()

func _exercise(boot: Node) -> void:
    boot.set("navigate_enabled",false)
    boot.set("last_scene","")
    boot.call("show_page","dev")
    var scroll: ScrollContainer = boot.find_child("Page scroll",true,false)
    _check(scroll != null,"no scrolling page")
    if scroll == null:
        return
    await _shot("ux-dev-top")
    _check(scroll.scroll_vertical > 100,"a real swipe on DEVELOPER did not scroll (%d)" % scroll.scroll_vertical)
    _check(str(boot.get("last_scene")) == "","the swipe pressed a button (%s)" % str(boot.get("last_scene")))
    await _shot("ux-dev-scrolled")
    _check(str(boot.get("page_name")) == "main","Android BACK did not return from DEVELOPER (%s)" % str(boot.get("page_name")))
    boot.call("show_page","drive")
    var confirmed: Array = []
    var del: Node = FILE_DIALOG.show(boot,"DELETE TRACK","Move “QA UX” to Track Trash? It will disappear from My Tracks until restored.",
        "DELETE",func() -> String:
            confirmed.append("delete")
            return "")
    await _shot("ux-delete")
    _check(not is_instance_valid(del) or del.is_queued_for_deletion(),"Android BACK did not close the DELETE card")
    var ren: Node = FILE_DIALOG.show(boot,"RENAME TRACK","Rename QA UX","RENAME",func(_n: String) -> String:
        confirmed.append("rename")
        return "","QA UX")
    # The field is released so the emulator's BACK reaches the game (with the field focused, Android's first BACK
    # only hides the on-screen keyboard - expected behaviour, checked by the owner on the phone).
    var edit: LineEdit = ren.find_child("Track name",true,false)
    if edit != null:
        edit.release_focus()
        DisplayServer.virtual_keyboard_hide()
    await _shot("ux-rename")
    for _i in range(10): # the first BACK may only hide the on-screen keyboard
        if not is_instance_valid(ren) or ren.is_queued_for_deletion():
            break
        await _wait(0.5)
    _check(not is_instance_valid(ren) or ren.is_queued_for_deletion(),"Android BACK did not close the RENAME card")
    _check(confirmed.is_empty(),"BACK confirmed a card: "+str(confirmed))
    var garage: Control = GARAGE.instantiate()
    get_tree().root.add_child(garage)
    (boot as CanvasItem).visible = false
    await _shot("ux-garage")
    var row: Node = garage.find_child("Paint swatches",true,false)
    _check(row != null and (row.get_child_count() > 0 or (garage.find_child("Paint note",true,false) as Label).visible),
        "garage paint swatches missing")
    garage.queue_free()
    (boot as CanvasItem).visible = true
    boot.call("show_page","main")
