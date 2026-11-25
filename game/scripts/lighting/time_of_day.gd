extends RefCounted
## Preset IDs are shared with LAN. Append to the enum to preserve wire values.

enum Preset { DAWN, DAY, GOLDEN_HOUR, NIGHT }
const LABELS := ["DAWN", "DAY", "GOLDEN HOUR", "NIGHT"]
const SETTING := "nitro/selected_time_of_day"

static func valid(value: Variant) -> bool:
    return value is int and value >= Preset.DAWN and value <= Preset.NIGHT

static func selected() -> int:
    var value: Variant = ProjectSettings.get_setting(SETTING, Preset.DAY)
    return int(value) if valid(value) else Preset.DAY

static func select(value: int) -> void:
    if valid(value):
        ProjectSettings.set_setting(SETTING, value)

static func requires_headlights(value: int) -> bool:
    return value in [Preset.DAWN, Preset.NIGHT]
