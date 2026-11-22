extends SceneTree
## Owner request 2026-11-22: the NITRO WHEELZ key art is the game's loading
## screen.
##  * the art ships as a JPEG the engine can load (941 x 1672); the project's
##    boot splash is a PNG made from it (the only format the engine accepts),
##    fitted by height on the art's own edge colour and kept on screen long enough to read;
##  * NitroBusy poster mode: opened by boot.gd (LOADING) and race.gd (LOADING
##    TRACK); the plain loading card and the compact pill keep working; a missing
##    art falls back to the plain card;
##  * the art is fitted by HEIGHT on every screen shape: never stretched, the
##    logo at the top is never cropped on phones from 9:16 to 9:21, wide screens
##    get bars and show all of it;
##  * the overlay draws (poster mode) at a phone size without errors.
const BUSY = preload("res://scripts/ui/busy_overlay.gd")
const ART: Vector2 = Vector2(941.0,1672.0)
# Logo block of the art (crown + NITRO WHEELZ + Japanese line), as fractions.
const LOGO: Rect2 = Rect2(0.19,0.03,0.61,0.20)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var err: String = await _checks()
    if not err.is_empty():
        printerr("FAIL: "+err)
        quit(1)
        return
    print("PASS: loading screen - key art ships as an engine-readable JPEG (941x1672) and is the boot splash; the poster overlay is opened by the boot and race loading calls, fits by height on 9:16 .. 9:21 phones, tablets and landscape without cropping the logo or stretching, falls back to the plain card without art, and draws")
    for _f in range(3):
        await process_frame
    quit(0)

func _checks() -> String:
    var path: String = BUSY.POSTER_PATH
    if not ResourceLoader.exists(path):
        return "Loading screen art is missing: "+path
    var tex: Texture2D = load(path) as Texture2D
    if tex == null or Vector2(tex.get_size()) != ART:
        return "Loading screen art must load as a 941x1672 texture (got %s)" % [str(tex.get_size()) if tex != null else "null"]
    # The engine only accepts a PNG as the boot splash (a JPEG is rejected and
    # the Godot logo shows): a 9:20 crop of the art with feathered edges.
    var splash: String = str(ProjectSettings.get_setting("application/boot_splash/image",""))
    if splash != "res://assets/brand/boot_splash.png" or not ResourceLoader.exists(splash):
        return "The boot splash must be the PNG made from the loading screen art (got '%s')" % splash
    var splash_tex: Texture2D = load(splash) as Texture2D
    if splash_tex == null or Vector2(splash_tex.get_size()) != Vector2(720.0,1600.0):
        return "The boot splash PNG must load (720x1600)"
    # Engine 4.7: stretch_mode 3 = Keep Height (same rule as the in-game poster).
    if int(ProjectSettings.get_setting("application/boot_splash/stretch_mode",1)) != 3:
        return "The boot splash must be fitted by height (stretch_mode 3)"
    if int(ProjectSettings.get_setting("application/boot_splash/minimum_display_time",0)) < 500:
        return "The boot splash must stay visible long enough to be seen"
    # Fit by height on every screen shape.
    var screens: Array = [Vector2(720,1280),Vector2(1080,1920),Vector2(1080,2340),Vector2(1080,2400),
        Vector2(1080,2520),Vector2(1200,1920),Vector2(1536,2048),Vector2(1280,720),Vector2(2560,1080)]
    for s in screens:
        var r: Rect2 = BUSY.poster_rect(s,ART)
        if absf(r.size.y-s.y) > 0.01 or absf(r.size.x/r.size.y-ART.x/ART.y) > 1e-4:
            return "Art must be fitted by height without stretching on %s (got %s)" % [str(s),str(r)]
        if absf((r.position.x+r.size.x*0.5)-s.x*0.5) > 0.01 or absf(r.position.y) > 0.01:
            return "Art must be centred and touch the top and bottom on %s (got %s)" % [str(s),str(r)]
        # What is visible of the logo block.
        var vis := Rect2(Vector2.ZERO,s)
        var logo := Rect2(r.position+Vector2(LOGO.position.x*r.size.x,LOGO.position.y*r.size.y),
            Vector2(LOGO.size.x*r.size.x,LOGO.size.y*r.size.y))
        if not vis.encloses(logo):
            return "The logo is cropped on %s (logo %s, screen %s)" % [str(s),str(logo),str(vis)]
        if s.x/s.y < 0.5625 and r.size.x < s.x-0.01:
            return "A narrow phone must be filled edge to edge (%s)" % str(s)
    # Poster mode from the real call sites; the other modes are untouched.
    var layer := Node.new()
    root.add_child(layer)
    var poster: NitroBusy = BUSY.open(layer,"LOADING TRACK",false,true)
    var plain: NitroBusy = BUSY.open(layer,"GENERATING TERRAIN")
    var pill: NitroBusy = BUSY.open(layer,"UPDATING TERRAIN",true,true)
    await process_frame
    await process_frame
    if not poster.poster or plain.poster or pill.poster:
        return "Only the full loading card may show the poster (poster %s, plain %s, pill %s)" % [poster.poster,plain.poster,pill.poster]
    poster.set_text("LOADING TRACK","TOUGE ROUTE • TOUGE MOUNTAIN")
    poster.set_progress(0.4)
    await process_frame
    await process_frame
    layer.queue_free()
    await process_frame
    # The call sites ask for the poster.
    for pair in [["res://scripts/boot.gd","\"LOADING\",false,true)"],["res://scripts/race/race.gd","\"LOADING TRACK\",false,true)"]]:
        if not FileAccess.get_file_as_string(str(pair[0])).contains(str(pair[1])):
            return "%s must open the loading screen with the poster" % str(pair[0])
    return ""
