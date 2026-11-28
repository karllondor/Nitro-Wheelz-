extends SceneTree
## Issue #65 / #59 (v0.1.52) Android UI rescue, on a portrait phone viewport (1080 x 2340 window, canvas_items
## stretch -> 1280 x 2773 like the owner's phone):
##  * every menu page keeps BACK on screen in a footer, the page itself scrolls (DEVELOPER runs past the screen);
##  * a finger drag that starts ON a button scrolls the page and does NOT press that button; a still tap presses it;
##  * Android BACK (AndroidBack autoload): closes an open confirmation card first (never confirms), otherwise goes
##    to the parent page; quit_on_go_back is off (BACK no longer closes the game from any screen);
##  * SAVE / RENAME / DELETE cards: ~92 % of the screen width, thumb-size buttons, in the upper part (keyboard),
##    an error keeps the card open, CANCEL never calls the store;
##  * diagnostic overlays: one DEVELOPER switch turns all off, the touch overlay has its own DIAG OFF button;
##  * garage: the paint palette is visible as swatches, a swatch selects and saves that paint, a car without a
##    palette says so.
## Restores user://nitro_dev.cfg and user://nitro_garage.cfg byte for byte. NOT proven here: real finger feel and
## the Android keyboard on the owner's phone (owner QA).
const BOOT = preload("res://scenes/boot.tscn")
const GARAGE = preload("res://scenes/garage.tscn")
const FILE_DIALOG = preload("res://scripts/ui/track_file_dialog.gd")
const TOUCH_DIAG = preload("res://scripts/ui/touch_diagnostics.gd")
const AUDIO_DBG = preload("res://scripts/ui/audio_debug_overlay.gd")
const PHYS_DEV = preload("res://scripts/world/terrain/physics_dev.gd")
const CARS = preload("res://scripts/vehicles/car_catalog.gd")
const COSMETICS = preload("res://scripts/vehicles/car_cosmetics.gd")
const FILES: Array[String] = ["user://nitro_dev.cfg","user://nitro_garage.cfg"]

var saved: Dictionary = {}

func _initialize() -> void:
    call_deferred("_run")

func _frames(n: int = 2) -> void:
    for _i in range(n):
        await process_frame

func _run() -> void:
    for f in FILES:
        saved[f] = FileAccess.get_file_as_bytes(f) if FileAccess.file_exists(f) else null
    var selected: String = CARS.selected()
    root.size = Vector2i(1080,2340)
    await _frames()
    var err: String = await _checks()
    for f in FILES:
        if saved[f] == null:
            if FileAccess.file_exists(f):
                DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
        else:
            var w := FileAccess.open(f,FileAccess.WRITE)
            w.store_buffer(saved[f])
            w.close()
    CARS.select(selected)
    if err != "":
        printerr("FAIL: "+err)
        quit(1)
        return
    print("PASS: Android UI rescue (#65/#59) on a 1080x2340 portrait phone - every menu page keeps BACK on screen and scrolls, a drag starting on a button scrolls without pressing it, a still tap presses, Android BACK closes a card first then goes to the parent page (quit_on_go_back off), a duplicate BACK is ignored and the main menu leaves only on a second deliberate BACK, the BACK log is kept and shown in DEVELOPER, SAVE/RENAME/DELETE cards are 92 % wide with thumb-size buttons in the upper screen and keep errors on screen, CANCEL never touches the store, one switch turns all diagnostic overlays off + DIAG OFF on the overlay, garage paint swatches select and save a paint; NOT proven: finger feel and the Android keyboard on the owner's phone")
    quit(0)

func _win(p: Vector2) -> Vector2:
    return root.get_final_transform()*p

func _touch(p: Vector2, pressed: bool) -> void:
    var t := InputEventScreenTouch.new()
    t.index = 0
    t.position = _win(p)
    t.pressed = pressed
    Input.parse_input_event(t)

func _drag(p: Vector2, rel: Vector2) -> void:
    var d := InputEventScreenDrag.new()
    d.index = 0
    d.position = _win(p)
    d.relative = rel*root.get_final_transform().get_scale()
    Input.parse_input_event(d)

func _checks() -> String:
    if bool(ProjectSettings.get_setting("application/config/quit_on_go_back",true)):
        return "quit_on_go_back must be off (Android BACK closed the game from any screen)"
    var back_nav: Node = root.get_node_or_null("AndroidBack")
    if back_nav == null or not back_nav.has_method("handle_back"):
        return "the AndroidBack autoload is missing"
    var vis: Vector2 = root.get_visible_rect().size
    if vis.y < vis.x*2.0:
        return "test needs a portrait viewport (%s)" % str(vis)
    var boot: Control = BOOT.instantiate()
    boot.set("navigate_enabled",false)
    root.add_child(boot)
    await _frames()
    var scroll: ScrollContainer = boot.find_child("Page scroll",true,false)
    var footer: Control = boot.find_child("Page footer",true,false)
    if scroll == null or footer == null:
        return "the menu needs a scrolling page and a footer"
    # ------------------------------------------------------------------ every page: BACK on screen, page bounded
    for pg in ["dev","drive","settings","elev","setup","park","profile","build"]:
        boot.call("show_page",pg)
        await _frames()
        var back: Button = null
        for c in footer.get_children():
            if c is Button and (c as Button).text.begins_with("◀"):
                back = c
        if back == null or not back.is_visible_in_tree():
            return "page %s: BACK must sit in the footer" % pg
        var r: Rect2 = back.get_global_rect()
        if r.end.y > vis.y+0.5 or r.position.y < 0.0:
            return "page %s: BACK is off screen (%s, screen %s)" % [pg,str(r),str(vis)]
        if scroll.get_global_rect().end.y > r.position.y+0.5:
            return "page %s: the scrolling page overlaps BACK" % pg
        if r.size.y < 60.0*float(boot.get("ui_unit")):
            return "page %s: BACK must be thumb size (%.0f)" % [pg,r.size.y]
    boot.call("show_page","dev")
    await _frames(3)
    var page: Control = boot.find_child("Menu page",true,false)
    if page.get_combined_minimum_size().y <= scroll.size.y:
        return "DEVELOPER is expected to be longer than the screen here (it scrolls)"
    var vbar: VScrollBar = scroll.get_v_scroll_bar()
    if vbar.max_value+0.5 < page.get_combined_minimum_size().y:
        return "the last DEVELOPER switch must be reachable by scrolling"
    if boot.find_child("Touch diagnostics",true,false) == null or boot.find_child("Overlays off",true,false) == null:
        return "DEVELOPER must keep TOUCH DIAGNOSTICS and offer DIAGNOSTIC OVERLAYS"
    # ------------------------------------------------------------- drag on a button = scroll, still tap = press
    var diag: Button = boot.find_child("Diagnostics",true,false)
    var start: Vector2 = diag.get_global_rect().get_center()
    boot.set("last_scene","")
    _touch(start,true)
    await _frames()
    var p: Vector2 = start
    for _i in range(12):
        p += Vector2(0.0,-40.0)
        _drag(p,Vector2(0.0,-40.0))
        await _frames(1)
    _touch(p,false)
    await _frames(3)
    if scroll.scroll_vertical < 200:
        return "a drag starting on a button must scroll the page (scroll %d)" % scroll.scroll_vertical
    if str(boot.get("last_scene")) != "":
        return "the button under a scrolling finger must not be pressed (%s)" % str(boot.get("last_scene"))
    scroll.scroll_vertical = 0
    await _frames(2)
    start = diag.get_global_rect().get_center()
    _touch(start,true)
    await _frames()
    _drag(start+Vector2(2.0,3.0),Vector2(2.0,3.0))
    await _frames()
    _touch(start+Vector2(2.0,3.0),false)
    await _frames(3)
    if not str(boot.get("last_scene")).ends_with("input_monitor.tscn"):
        return "a still tap must press the button (got '%s')" % str(boot.get("last_scene"))
    # ------------------------------------------------------------------------------------------ Android BACK
    boot.call("show_page","elev")
    await _frames()
    back_nav.call("forget_last_back")
    if str(back_nav.call("handle_back")) != "cancel":
        return "BACK without a card must go to the screen's cancel path"
    await _frames(3)
    if str(boot.get("page_name")) != "dev":
        return "BACK on ELEVATION PHYSICS must return to DEVELOPER (%s)" % str(boot.get("page_name"))
    back_nav.call("forget_last_back")
    back_nav.call("handle_back")
    # v0.1.54: the same BACK delivered twice (owner's phone: DEVELOPER -> main menu -> game closed) is ignored.
    if str(back_nav.call("handle_back")) != "ignored":
        return "a second BACK within the debounce window must be ignored"
    await _frames(3)
    if str(boot.get("page_name")) != "main":
        return "BACK on DEVELOPER must return to the main menu (%s)" % str(boot.get("page_name"))
    # The main menu never leaves the game on one BACK: the first asks to press again, a second (after the debounce) leaves.
    boot.call("disarm_exit")
    if str(boot.call("go_back")) != "armed" or not (boot.get("status_label") as Label).text.contains("AGAIN"):
        return "the first BACK on the main menu must only ask to press again"
    if str(boot.call("go_back")) == "quit":
        return "an instant second BACK (a duplicate) must not leave the game"
    boot.set("_exit_armed_ms",Time.get_ticks_msec()-800)
    if str(boot.call("go_back")) != "quit":
        return "a deliberate second BACK on the main menu leaves the game"
    boot.set("_exit_armed_ms",Time.get_ticks_msec()-5000)
    if str(boot.call("go_back")) != "armed":
        return "a BACK long after the prompt asks again (does not leave)"
    var back_log: PackedStringArray = back_nav.call("log_lines",8)
    if not "\n".join(back_log).contains("ignored") or not "\n".join(back_log).contains("main menu"):
        return "the system BACK log must record ignored duplicates and main-menu presses"
    boot.call("show_page","dev")
    await _frames()
    var log_label: Label = boot.find_child("System back log",true,false)
    if log_label == null or not log_label.text.contains("SYSTEM BACK LOG"):
        return "DEVELOPER must show the system BACK log"
    boot.call("show_page","main")
    await _frames()
    # ------------------------------------------------------------------------------ confirmation cards
    boot.call("show_page","drive")
    await _frames()
    var calls: Array = []
    var card: Node = FILE_DIALOG.show(boot,"DELETE TRACK","Move “X” to Track Trash?","DELETE",func() -> String:
        calls.append("delete")
        return "")
    await _frames(2)
    var u: float = float(card.get("unit"))
    var panel: Control = card.find_child("Card",true,false)
    if panel.size.x < vis.x*0.85:
        return "the card must be about 92 %% of the screen width (%.0f of %.0f)" % [panel.size.x,vis.x]
    if card.get_ok_button().size.y < 86.0*u or card.get_cancel_button().size.y < 86.0*u:
        return "card buttons must be thumb size"
    if card.get_ok_button().get_theme_font_size("font_size") < int(24.0*u):
        return "card button text must be readable"
    back_nav.call("forget_last_back")
    if str(back_nav.call("handle_back")) != "modal":
        return "BACK must close an open card first"
    await _frames(2)
    if is_instance_valid(card) and card.is_inside_tree() and not card.is_queued_for_deletion():
        return "BACK must close the card"
    if not calls.is_empty() or str(boot.get("page_name")) != "drive":
        return "closing a card with BACK must neither confirm nor leave the page"
    var tries: Array = []
    var rename: Node = FILE_DIALOG.show(boot,"RENAME TRACK","Rename X","RENAME",func(n: String) -> String:
        tries.append(n)
        return "NAME ALREADY USED" if tries.size() == 1 else "","Old name")
    await _frames(2)
    var edit: LineEdit = rename.find_child("Track name",true,false)
    if edit == null or edit.size.y < 80.0*u or edit.get_global_rect().end.y > vis.y*0.45:
        return "the name field must be big and in the upper screen (keyboard)"
    if rename.get_ok_button().get_global_rect().end.y > vis.y*0.5:
        return "the card buttons must stay above the Android keyboard"
    edit.text = "Taken"
    rename.get_ok_button().pressed.emit()
    await _frames()
    if not is_instance_valid(rename) or rename.is_queued_for_deletion() or not str(rename.get("dialog_text")).contains("NAME ALREADY USED"):
        return "an error must keep the card open and show it"
    edit.text = "Fresh"
    rename.get_ok_button().pressed.emit()
    await _frames()
    if tries != ["Taken","Fresh"] or (is_instance_valid(rename) and not rename.is_queued_for_deletion()):
        return "a successful confirm must close the card (%s)" % str(tries)
    var never: Array = []
    var c2: Node = FILE_DIALOG.show(boot,"SAVE TRACK","Replace?","SAVE",func() -> String:
        never.append(1)
        return "")
    await _frames()
    c2.get_cancel_button().pressed.emit()
    await _frames()
    if not never.is_empty():
        return "CANCEL must never call the store"
    # ----------------------------------------------------------------------------------- overlays off
    TOUCH_DIAG.set_enabled(true)
    AUDIO_DBG.set_enabled(true)
    PHYS_DEV.set_value("telemetry",true)
    boot.call("show_page","dev")
    await _frames()
    var ov: Button = boot.find_child("Overlays off",true,false)
    if not ov.text.contains("TOUCH") or not ov.text.contains("AUDIO") or not ov.text.contains("TELEMETRY") or ov.disabled:
        return "DIAGNOSTIC OVERLAYS must list what is on (%s)" % ov.text
    ov.pressed.emit()
    await _frames()
    if TOUCH_DIAG.enabled() or AUDIO_DBG.enabled() or bool(PHYS_DEV.load_settings()["telemetry"]):
        return "DIAGNOSTIC OVERLAYS must turn every overlay off"
    if not (boot.find_child("Overlays off",true,false) as Button).text.contains("ALL OFF"):
        return "the switch must then read ALL OFF"
    TOUCH_DIAG.set_enabled(true)
    var host := Node.new()
    root.add_child(host)
    var d: Node = TOUCH_DIAG.attach(host)
    await _frames()
    var off: Button = d.find_child("Diagnostics off",true,false) if d != null else null
    if off == null or not off.get_global_rect().intersects(Rect2(Vector2.ZERO,vis)):
        return "the touch overlay needs its own visible DIAG OFF button"
    off.pressed.emit()
    await _frames()
    if TOUCH_DIAG.enabled() or is_instance_valid(d):
        return "DIAG OFF must switch the overlay off and remove it"
    host.queue_free()
    boot.queue_free()
    await _frames()
    # ----------------------------------------------------------------------------------------- garage paint
    CARS.select("red")
    var garage: Control = GARAGE.instantiate()
    root.add_child(garage)
    await _frames(3)
    var prof: Dictionary = CARS.cosmetic_profile("red")
    var row: Control = garage.find_child("Paint swatches",true,false)
    if row == null or row.get_child_count() != COSMETICS.paints(prof).size():
        return "the garage must show one swatch per paint preset"
    for sw in row.get_children():
        var rr: Rect2 = (sw as Control).get_global_rect()
        if rr.position.x < 0.0 or rr.end.x > vis.x+0.5 or rr.size.y < 40.0:
            return "paint swatches must be on screen and tappable (%s)" % str(rr)
    (row.get_child(2) as Button).pressed.emit()
    await _frames()
    var want: Dictionary = COSMETICS.paints(prof)[2]
    var now: Dictionary = COSMETICS.current("red",prof)
    if str(now["paint_color_hex"]).to_lower() != str(want["hex"]).to_lower():
        return "a swatch must select and save that paint"
    if not (garage.get("version_label") as Label).text.contains(str(want["name"])):
        return "the garage must name the chosen paint"
    var paint_b: Button = garage.find_child("Cosmetic paint",true,false)
    if paint_b.get_theme_font_size("font_size") < int(19.0*float(garage.get("ui_unit"))):
        return "PAINT must be readable"
    garage.call("_choose","flame")
    await _frames()
    if row.get_child_count() != 0 or not (garage.find_child("Paint note",true,false) as Label).visible:
        return "a car without a palette must say so"
    garage.queue_free()
    await _frames()
    return ""
