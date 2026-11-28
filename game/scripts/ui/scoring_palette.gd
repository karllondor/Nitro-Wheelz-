extends RefCounted
class_name NitroScoringPalette
## Fixed, accent-independent colours of the scoring callouts above the car (issue #66, owner decision 2026-11-27).
##
## Before: red when the text contained LOST, gold for BANKED, and everything else used the player's HUD accent
## (`STYLE.PINK_SOFT`). With the RED accent every bonus looked like a loss. Now the meaning of a callout has ONE colour
## that never follows the accent; the accent keeps colouring the rest of the interface.
##
##   RED     WALL / SPIN "CHAIN LOST", MISSED sectors            penalty, failure
##   GOLD    BANKED +N                                           points secured
##   VIOLET  TRANSITION, KERB CLIP, FLICK / INIT / OUTSIDE / CLIP zone bonuses, WALL KISS   positive technical extras
##   WHITE   anything else (informational)
##
## The colour is never the only carrier of meaning: every callout keeps its text ("CHAIN LOST", "BANKED +", "x1.5" ...).
## The category comes from the event dictionary's optional "category" key when the scorer provides one; otherwise it is
## read from the event text here, so the scoring code does not have to change. `drift_scorer.gd` and `event_judge.gd`
## stay untouched by this patch (a test lists every literal `_event("...")` text and fails on an unclassified one).
enum Category { INFO, PENALTY, BANKED, BONUS }

const NAMES: Array[String] = ["INFO","PENALTY","BANKED","BONUS"]
const RED: Color = Color(1.0,0.42,0.42)
const GOLD: Color = Color(1.0,0.74,0.16)
const VIOLET: Color = Color("#9774C8")
const WHITE: Color = Color(0.985,0.985,1.0)
## Dark outline the HUD draws behind every callout (race_hud.gd): the contrast is computed against it, not the sky.
const OUTLINE: Color = Color(0.0,0.0,0.0)
## Opacity of that outline. It was 0.65; over a white cloud in DAY the violet only reached ~1.9:1 against it, so it is
## 0.85 now (one value for all four colours; violet reaches >= 4:1 on every lighting preset's sky and on white cloud).
const OUTLINE_ALPHA: float = 0.85
## Event texts that start with one of these are positive technical extras.
const BONUS_PREFIXES: Array[String] = ["TRANSITION","KERB CLIP","WALL KISS","FLICK","INIT","OUTSIDE","CLIP"]
const PENALTY_MARKERS: Array[String] = ["LOST","MISSED"]

static func category_of_text(text: String) -> int:
    var t: String = text.strip_edges().to_upper()
    for marker in PENALTY_MARKERS:
        if t.contains(marker):
            return Category.PENALTY
    if t.begins_with("BANKED"):
        return Category.BANKED
    for prefix in BONUS_PREFIXES:
        if t.begins_with(prefix):
            return Category.BONUS
    return Category.INFO

## `event` is one entry of `DriftScorer.events`: {"text": String, "age": float, optional "category": int or name}.
static func category_of(event: Dictionary) -> int:
    var given: Variant = event.get("category",null)
    if given is int and int(given) >= 0 and int(given) < NAMES.size():
        return int(given)
    if given is String and NAMES.has(str(given).to_upper()):
        return NAMES.find(str(given).to_upper())
    return category_of_text(str(event.get("text","")))

static func color_of(category: int) -> Color:
    match category:
        Category.PENALTY:
            return RED
        Category.BANKED:
            return GOLD
        Category.BONUS:
            return VIOLET
    return WHITE

static func color_for(event: Dictionary) -> Color:
    return color_of(category_of(event))

## WCAG contrast ratio of a colour against the callout outline.
static func contrast_ratio(a: Color, b: Color) -> float:
    var la: float = _luminance(a)
    var lb: float = _luminance(b)
    return (maxf(la,lb)+0.05)/(minf(la,lb)+0.05)

static func _luminance(c: Color) -> float:
    var lin := PackedFloat32Array([_lin(c.r),_lin(c.g),_lin(c.b)])
    return 0.2126*lin[0]+0.7152*lin[1]+0.0722*lin[2]

static func _lin(v: float) -> float:
    return v/12.92 if v <= 0.04045 else pow((v+0.055)/1.055,2.4)
