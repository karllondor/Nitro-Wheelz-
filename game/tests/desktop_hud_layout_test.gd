extends SceneTree
## Desktop/Web geometry + input regression. Runs in Linux headless CI;
## Web profile is checked by injecting the profile, without relying on OS flags.
const STYLE = preload("res://scripts/ui/hud_style.gd")
const TOUCH = preload("res://scripts/ui/race_touch.gd")
const RACE = preload("res://scenes/race.tscn")
const SCREENS: Array[Vector2] = [
    Vector2(640,360),Vector2(800,600),Vector2(960,540),
    Vector2(1280,720),Vector2(1920,1080),Vector2(2560,1080),
    Vector2(768,900)]

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    printerr("FAIL: desktop HUD: "+message)
    quit(1)

func _overlaps(a: Rect2, b: Rect2) -> bool:
    return a.grow(-0.5).intersects(b.grow(-0.5))

func _run() -> void:
    for profile in ["pc","web"]:
        for s in SCREENS:
            var m: Dictionary = STYLE.metrics(s,profile)
            var viewport := Rect2(Vector2.ZERO,s)
            var tag: String = "%s %dx%d" % [profile,int(s.x),int(s.y)]
            for key in ["header","bank_panel","camera","pause","score","speed"]:
                if not viewport.encloses(Rect2(m[key])):
                    _fail(tag+": "+key+" off screen")
                    return
            for pair in [["header","bank_panel"],["header","camera"],
                    ["header","pause"],["camera","pause"],["bank_panel","camera"],
                    ["bank_panel","pause"],["speed","score"]]:
                if _overlaps(Rect2(m[pair[0]]),Rect2(m[pair[1]])):
                    _fail(tag+": overlap "+str(pair[0])+"/"+str(pair[1]))
                    return
            for key in ["map","name","lap","chase"]:
                if not Rect2(m["header"]).encloses(Rect2(m[key])):
                    _fail(tag+": "+key+" exceeds track card")
                    return
            for key in ["total","total_label"]:
                if not Rect2(m["bank_panel"]).encloses(Rect2(m[key])):
                    _fail(tag+": "+key+" exceeds score card")
                    return
            var occupied: float = 0.0
            for key in ["header","bank_panel","camera","pause","score","speed"]:
                occupied += Rect2(m[key]).get_area()
            if s.x >= 960.0 and occupied / (s.x*s.y) > 0.17:
                _fail(tag+": HUD covers too much of the screen")
                return
    # Existing mobile geometry remains the default, down to each Rect2.
    for s in [Vector2(360,640),Vector2(720,1600),Vector2(1280,720)]:
        if STYLE.metrics(s) != STYLE.metrics(s,"mobile"):
            _fail("mobile layout changed")
            return
    var touch: NitroRaceTouch = TOUCH.new()
    root.add_child(touch)
    await process_frame
    if touch._layout(Vector2(720,1600))["camera"] != STYLE.metrics(Vector2(720,1600))["camera"]:
        _fail("mobile camera hit-zone diverged from drawing")
        return
    touch.queue_free()
    await process_frame
    var race: Node3D = RACE.instantiate()
    root.add_child(race)
    await process_frame
    var actions: NitroRaceDesktopActions = race.get("desktop_actions")
    if actions == null or actions.camera_button == null or actions.pause_button == null:
        _fail("desktop CAMERA/PAUSE controls not instanced")
        return
    if STYLE.platform_profile() != "mobile":
        if not actions.visible or race.get("touch").visible:
            _fail("PC/Web action layer not selected")
            return
        var old_camera: int = int(race.get("camera_mode"))
        actions.camera_button.pressed.emit()
        if int(race.get("camera_mode")) == old_camera:
            _fail("CAMERA button did not switch the camera")
            return
        actions.pause_button.pressed.emit()
        if not bool(race.get("paused")) or actions.visible:
            _fail("PAUSE button did not open its exclusive modal")
            return
        race.call("_toggle_pause")
        if bool(race.get("paused")) or not actions.visible:
            _fail("RESUME did not restore PC/Web actions")
            return
        race.call("_show_results")
        if actions.visible:
            _fail("actions leaked into results screen")
            return
        race.call("_restart")
        if not actions.visible:
            _fail("restart did not restore desktop actions")
            return
    print("PASS: PC/Web compact HUD geometry on %d viewports, safe camera/pause targets, live clicks and transitions; mobile metrics unchanged" % SCREENS.size())
    print("NOT RUN: physical mouse, Android touchscreen, actual browser, visual Linux fullscreen screenshots")
    quit(0)
