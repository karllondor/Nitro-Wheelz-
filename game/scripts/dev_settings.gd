extends RefCounted
class_name NitroDevSettings
## Developer / test settings (v0.1.32), kept apart from the player's
## settings: user://nitro_dev.cfg. The player's file (nitro_settings.cfg:
## volumes, accent, sound) is never touched by DEVELOPER switches, and
## RESET DEFAULTS here never resets the player's choices.
##
## Older builds kept these in nitro_settings.cfg [developer] / [physics_dev];
## they are moved here once (first read) and removed from the player file.
## Every option, its range, default and effect: docs/DEVELOPER_MODE.md.
const PATH: String = "user://nitro_dev.cfg"
const PLAYER_PATH: String = "user://nitro_settings.cfg"
const LEGACY_SECTIONS: Array[String] = ["developer","physics_dev"]

static var _migrated: bool = false

static func _cfg() -> ConfigFile:
    _migrate()
    var cfg := ConfigFile.new()
    cfg.load(PATH)
    return cfg

static func get_value(section: String, key: String, default: Variant) -> Variant:
    return _cfg().get_value(section,key,default)

static func set_value(section: String, key: String, value: Variant) -> void:
    var cfg: ConfigFile = _cfg()
    cfg.set_value(section,key,value)
    cfg.save(PATH)

static func set_section(section: String, values: Dictionary) -> void:
    var cfg: ConfigFile = _cfg()
    for k in values.keys():
        cfg.set_value(section,k,values[k])
    cfg.save(PATH)

## DEVELOPER > RESET DEFAULTS: every developer / test option back to its
## default (the file is removed); the player's settings stay.
static func reset_defaults() -> void:
    _migrate()
    if FileAccess.file_exists(PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))

## Text of the current developer settings (preset export / bug reports).
static func as_text() -> String:
    var cfg: ConfigFile = _cfg()
    var lines: PackedStringArray = ["; Nitro Wheelz developer preset %s" % str(ProjectSettings.get_setting("application/config/version",""))]
    for section in cfg.get_sections():
        lines.append("[%s]" % section)
        for key in cfg.get_section_keys(section):
            lines.append("%s=%s" % [key,var_to_str(cfg.get_value(section,key))])
    if cfg.get_sections().is_empty():
        lines.append("; all defaults")
    return "\n".join(lines)

## DEVELOPER > EXPORT PRESET: writes user://nitro_dev_preset_<time>.cfg and
## copies the same text to the clipboard (paste it into a bug report).
static func export_preset() -> String:
    var stamp: String = Time.get_datetime_string_from_system(false,true).replace(":","").replace("-","").replace(" ","_")
    var path: String = "user://nitro_dev_preset_%s.cfg" % stamp
    var text: String = as_text()
    var f := FileAccess.open(path,FileAccess.WRITE)
    if f != null:
        f.store_string(text+"\n")
        f.close()
    if DisplayServer.get_name() != "headless":
        DisplayServer.clipboard_set(text)
    return path

static func _migrate() -> void:
    if _migrated:
        return
    _migrated = true
    var player := ConfigFile.new()
    if player.load(PLAYER_PATH) != OK:
        return
    var moved: bool = false
    var dev := ConfigFile.new()
    dev.load(PATH)
    for section in LEGACY_SECTIONS:
        if not player.has_section(section):
            continue
        for key in player.get_section_keys(section):
            if not dev.has_section_key(section,key):
                dev.set_value(section,key,player.get_value(section,key))
        player.erase_section(section)
        moved = true
    if moved:
        dev.save(PATH)
        player.save(PLAYER_PATH)
