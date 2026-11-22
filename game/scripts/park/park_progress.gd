extends RefCounted
class_name NitroParkProgress
## Tutorial progress of NITRO WHEELZ PARK (issue #27): which lessons were completed.
## Local file only. NO stars, NO scores, NO records: the Park never feeds the global
## star total or the leaderboards (owner decision: no farmable stars in the Park).
const PATH: String = "user://nitro_park.cfg"

static func _cfg() -> ConfigFile:
    var cfg := ConfigFile.new()
    cfg.load(PATH)
    return cfg

## Lesson ids completed so far, in the order they were completed.
static func completed() -> PackedStringArray:
    var raw: Variant = _cfg().get_value("tutorial","completed",PackedStringArray())
    var out := PackedStringArray()
    if raw is Array or raw is PackedStringArray:
        for v in raw:
            out.append(str(v))
    return out

static func is_completed(id: String) -> bool:
    return completed().has(id)

static func mark_completed(id: String) -> void:
    var list: PackedStringArray = completed()
    if list.has(id):
        return
    list.append(id)
    var cfg := _cfg()
    cfg.set_value("tutorial","completed",list)
    cfg.save(PATH)

## Forget the tutorial progress (RESTART TUTORIAL). Cones and paint are untouched.
static func reset() -> void:
    var cfg := _cfg()
    cfg.set_value("tutorial","completed",PackedStringArray())
    cfg.save(PATH)

## True once the player has seen the tutorial start at least once.
static func seen() -> bool:
    return bool(_cfg().get_value("tutorial","seen",false))

static func set_seen() -> void:
    var cfg := _cfg()
    cfg.set_value("tutorial","seen",true)
    cfg.save(PATH)

## Index of the first lesson that is not completed yet (lesson_ids.size() = all done).
static func first_open(lesson_ids: PackedStringArray) -> int:
    var done: PackedStringArray = completed()
    for i in range(lesson_ids.size()):
        if not done.has(lesson_ids[i]):
            return i
    return lesson_ids.size()
