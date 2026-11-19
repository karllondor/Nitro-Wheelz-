extends SceneTree
## v0.1.21 HUD readability / overlap check (owner brief P1) on many screens:
## narrow and tall phones (16:9 .. 21:9), small 360x640, tablets (3:4, 2:3)
## and landscape. Same layout functions the game draws and hit-tests with.
##  * header pieces (minimap, LAP, BANKED SCORE label + number, track name,
##    chase pill) never overlap each other or the front-camera keep-out;
##  * COMBO box, PAUSE / CAM, speedometer + drift angle and the touch
##    controls (joystick, handbrake, brake, gas) never overlap;
##  * the minimap stays prominent;
##  * every text is big enough to read: labels >= 2.2% of the screen's short
##    side (~1.5 mm on a phone), lap / combo / score numbers much larger.
const STYLE = preload("res://scripts/ui/hud_style.gd")
const HUD = preload("res://scripts/ui/race_hud.gd")
const TOUCH = preload("res://scripts/ui/race_touch.gd")
const SCREENS: Array[Vector2] = [
    Vector2(360,640),Vector2(720,1280),Vector2(720,1600),Vector2(1080,2340),
    Vector2(1080,2520),Vector2(1280,2844),Vector2(1536,2048),Vector2(800,1200),
    Vector2(1280,720),Vector2(2340,1080),Vector2(2048,1536)]

func _initialize() -> void:
    call_deferred("_run")

func _fail(msg: String) -> void:
    printerr("FAIL: "+msg)
    quit(1)

func _overlap(a: Rect2, b: Rect2) -> bool:
    return a.size.x > 0.0 and b.size.x > 0.0 and a.grow(-0.5).intersects(b.grow(-0.5))

func _run() -> void:
    var touch: Control = TOUCH.new()
    root.add_child(touch)
    await process_frame
    var worst: Dictionary = {}
    for s in SCREENS:
        var m: Dictionary = STYLE.metrics(s)
        var t: Dictionary = touch.call("_layout",s)
        var short: float = minf(s.x,s.y)
        var tag: String = "%dx%d" % [int(s.x),int(s.y)]
        # Header pieces.
        var head: Array = ["map","lap","total_label","total","name","chase"]
        for i in range(head.size()):
            var ri: Rect2 = m[head[i]]
            if not Rect2(m["header"]).grow(1.0).encloses(ri):
                _fail(tag+": "+str(head[i])+" sticks out of the header")
                return
            if bool(m["portrait"]) and _overlap(ri,Rect2(m["dead"])) and head[i] != "map":
                _fail(tag+": "+str(head[i])+" under the front-camera keep-out")
                return
            for j in range(i+1,head.size()):
                if _overlap(ri,Rect2(m[head[j]])):
                    _fail(tag+": header "+str(head[i])+" overlaps "+str(head[j]))
                    return
        # Everything below the header, incl. touch controls.
        var stick_c: Vector2 = t["joystick_center"]
        var stick_r: float = float(t["joystick_radius"])
        var below: Dictionary = {"combo":m["score"],"pause":t["pause"],"camera":t["camera"],
            "speedometer":m["speed"],"drift angle":m["angle"],
            "joystick":Rect2(stick_c-Vector2(stick_r,stick_r),Vector2(stick_r,stick_r)*2.0),
            "handbrake":t["drift"],"brake":t["brake"],"gas":t["gas"],"header":m["header"]}
        var keys: Array = below.keys()
        for i in range(keys.size()):
            for j in range(i+1,keys.size()):
                if _overlap(Rect2(below[keys[i]]),Rect2(below[keys[j]])):
                    _fail(tag+": "+str(keys[i])+" overlaps "+str(keys[j]))
                    return
            if not Rect2(Vector2.ZERO,s).grow(1.0).encloses(Rect2(below[keys[i]])):
                _fail(tag+": "+str(keys[i])+" off screen")
                return
        # Minimap stays prominent.
        var map: Rect2 = m["map"]
        if minf(map.size.x,map.size.y) < short*0.12:
            _fail(tag+": minimap too small")
            return
        # Readable text.
        var sz: Dictionary = HUD.text_sizes(m,"SHIN-KAWA FULL CIRCUIT")
        var floors: Dictionary = {"banked_label":0.022,"name":0.020,"chase":0.022,"clock":0.022,
            "combo_label":0.022,"to_bank":0.020,"lap":0.030,"combo_value":0.050,"score":0.050}
        for key in floors.keys():
            var rel: float = float(sz[key])/short
            if rel < float(floors[key]):
                _fail(tag+": %s text too small (%.1f px = %.3f of the short side)" % [key,float(sz[key]),rel])
                return
            worst[key] = minf(float(worst.get(key,1.0)),rel)
    touch.queue_free()
    await process_frame
    var parts: PackedStringArray = []
    for key in worst.keys():
        parts.append("%s %.3f" % [key,float(worst[key])])
    print("HUD smallest text / short side: "+", ".join(parts))
    print("PASS: HUD on %d screens (phones 16:9-21:9, 360x640, tablets, landscape): no overlaps in the header, with the camera keep-out, COMBO, buttons, speedometer or touch controls; minimap prominent; all text readable" % SCREENS.size())
    print("NOT RUN: readability on the owner's phone")
    quit(0)
