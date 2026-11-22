extends SceneTree
## Android start screen (#25.Q2, owner request c7080732329, v0.1.38).
##
## Root cause of the oversized NW monogram before the game (found in the Godot 4.7.2 Android export
## plugin, platform/android/export/export_plugin.cpp, load_icon_refs): with no "splash_screen/icon" the
## Android 12+ system splash icon is the ADAPTIVE FOREGROUND icon. In the v0.1.37 APK
## res/drawable/splash_icon.webp was byte-identical to res/mipmap/icon_foreground.webp, i.e. the NW crown.
## Fix: a fully transparent splash icon, so the system start screen is only the flat dark adaptive
## background; the home-screen launcher icon (main + adaptive layers), the approved boot artwork, the
## in-game loading screen and its progress bar are NOT touched. The system splash cannot show a
## full-bleed picture (Android 12+ = one icon on one colour); the approved artwork comes next, from the
## Godot boot splash, as early as the engine can draw it (docs/ANDROID_START_SCREEN.md).
const PRESETS: String = "res://export_presets.cfg"
const SPLASH: String = "res://assets/brand/android_splash_icon.png"
# SHA-256 of the assets that must NOT change (v0.1.37 values).
const UNCHANGED: Dictionary = {
    "res://assets/brand/app_icon_192.png":"ed4eae4daa38b9f84974fad91b74e55f98c9fb3d00c05634ed6d5eea70569b5b",
    "res://assets/brand/app_icon_fg_432.png":"67795fd207d4cd3567fd1e1b08109c76bc7894e42a7601fb39ff215256ca2082",
    "res://assets/brand/app_icon_bg_432.png":"7fcd20e126093a959b50a107e41ccc514ec82fc828396395160974f63a85f1bc",
    "res://assets/brand/app_icon.png":"5b90b00c1310782a499ba49902d17876c86ad10e1f737793f733d49024800390",
    "res://assets/brand/boot_splash.png":"5b7e2e095d7d902a67da8f25994abb3922477fcdc120c38cf5edd8335194b61d",
    "res://assets/brand/loading_screen.jpg":"a981bac69970d9b2344475d5479f1bc9b48e2a35e666306d1329b6e780352125"}

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    printerr("FAIL: "+message)
    quit(1)

func _run() -> void:
    var cfg := ConfigFile.new()
    if cfg.load(PRESETS) != OK:
        _fail("export_presets.cfg unreadable")
        return
    var section: String = ""
    for s in cfg.get_sections():
        if s.ends_with(".options") and cfg.has_section_key(s,"package/unique_name"):
            section = s
    if section == "":
        _fail("Android preset options not found")
        return
    if str(cfg.get_value(section,"splash_screen/icon","")) != SPLASH:
        _fail("the Android preset must set splash_screen/icon = "+SPLASH+" (otherwise the NW foreground icon becomes the start-screen icon)")
        return
    var img := Image.load_from_file(ProjectSettings.globalize_path(SPLASH))
    if img == null or img.is_empty():
        _fail("the splash icon image cannot be read")
        return
    if img.get_width() != 432 or img.get_height() != 432:
        _fail("the splash icon must be 432 x 432 like the adaptive layers")
        return
    img.convert(Image.FORMAT_RGBA8)
    if img.get_used_rect() != Rect2i():
        _fail("the splash icon must be fully transparent (no enlarged icon), used rect "+str(img.get_used_rect()))
        return
    # The home-screen launcher icon, the boot artwork and the loading screen art are unchanged.
    for path in UNCHANGED.keys():
        var sha: String = FileAccess.get_sha256(path)
        if sha != str(UNCHANGED[path]):
            _fail("%s changed (expected the v0.1.37 file, got %s)" % [path,sha])
            return
    for key in ["launcher_icons/main_192x192","launcher_icons/adaptive_foreground_432x432","launcher_icons/adaptive_background_432x432"]:
        if not str(cfg.get_value(section,key,"")).begins_with("res://assets/brand/app_icon"):
            _fail("the launcher icon option "+key+" must still use the NW launcher icon files")
            return
    if int(ProjectSettings.get_setting("application/boot_splash/minimum_display_time",0)) < 500 \
            or str(ProjectSettings.get_setting("application/boot_splash/image","")) != "res://assets/brand/boot_splash.png":
        _fail("the approved boot artwork must stay the Godot boot splash image")
        return
    # Gradle stays off (no custom Android project): the fix is a plain export option.
    if bool(cfg.get_value(section,"gradle_build/use_gradle_build",false)):
        _fail("gradle_build must stay off for this fix (no custom template needed)")
        return
    print("PASS: Android start screen: transparent splash icon set (432 x 432, used rect empty) so the OS start screen cannot show the NW monogram, launcher icon layers + boot artwork + loading art byte-identical to v0.1.37, no Gradle")
    print("NOT RUN: cold / warm start on the owner's phone (Android 12+ system splash behaviour is OS / OEM controlled)")
    quit(0)
