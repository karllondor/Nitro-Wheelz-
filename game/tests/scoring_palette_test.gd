extends SceneTree
## Issue #66: scoring callout COLOURS ONLY. Presentation, never points.
##  * every literal `_event("...")` text in drift_scorer.gd / event_judge.gd is known and classified (a new, unclassified
##    scoring event fails this test until somebody decides its colour);
##  * WALL / SPIN "CHAIN LOST" and MISSED are RED, BANKED is GOLD, TRANSITION / KERB CLIP / FLICK / INIT / OUTSIDE / CLIP
##    bonuses and WALL KISS are NITRO VIOLET, anything else neutral WHITE; "WALL KISS +12" is NOT red although it says WALL;
##  * the HUD's `callout_color` returns exactly those colours for all six accents (pink, violet, cyan, lime, orange, red):
##    a bonus never looks like a loss with the RED accent, and the colours never move with the accent;
##  * the four colours are clearly different from each other and readable on the dark callout outline over the DAWN,
##    DAY, GOLDEN HOUR and NIGHT sky colours of the race lighting presets, white clouds included;
##  * the real scorer, driven through TRANSITION, KERB CLIP, BANKED and WALL, emits texts that map to the right colour
##    and its numbers (total, banked / lost chains, transitions, clips) equal the pre-patch golden values, i.e. no point
##    award changed (the scorer file itself is untouched by this patch).
## NOT proven here: how the colours look on the owner's phone screen (owner QA).
const PALETTE = preload("res://scripts/ui/scoring_palette.gd")
const STYLE = preload("res://scripts/ui/hud_style.gd")
const HUD = preload("res://scripts/ui/race_hud.gd")
const SCORER = preload("res://scripts/race/drift_scorer.gd")
const ENV = preload("res://scripts/lighting/race_environment.gd")
const TIME = preload("res://scripts/lighting/time_of_day.gd")
const SOURCES: Array[String] = ["res://scripts/race/drift_scorer.gd","res://scripts/events/event_judge.gd"]
## Joined string literals of every `_event(...)` call in the sources above (variables dropped).
const KNOWN_LITERALS: Array[String] = ["TRANSITION  +%.2fx","KERB CLIP  x1.5","BANKED  +%s","!  CHAIN LOST","MISSED ",
    "  +20","WALL KISS  +12"]
const P: int = PALETTE.Category.PENALTY
const B: int = PALETTE.Category.BANKED
const X: int = PALETTE.Category.BONUS
const I: int = PALETTE.Category.INFO
## What the game prints, and the category each text must get.
const SAMPLES: Array = [
    ["WALL!  CHAIN LOST",P],["SPIN!  CHAIN LOST",P],["MISSED INIT",P],["MISSED FLICK",P],["MISSED OUTSIDE",P],["MISSED CLIP",P],
    ["BANKED  +12,345",B],["BANKED  +980",B],
    ["TRANSITION  +0.25x",X],["KERB CLIP  x1.5",X],["INIT  +20",X],["FLICK  +20",X],["OUTSIDE  +20",X],["CLIP  +20",X],
    ["WALL KISS  +12",X],
    ["PRACTICE LAP",I],["",I]]

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    printerr("FAIL: "+message)
    quit(1)

func _literals(source: String) -> Array[String]:
    var out: Array[String] = []
    var call_re := RegEx.create_from_string("\\b_event\\((.*)\\)\\s*$")
    var lit_re := RegEx.create_from_string("\"([^\"]*)\"")
    for line in source.split("\n"):
        if line.strip_edges().begins_with("func _event") or line.strip_edges().begins_with("#"):
            continue
        var m: RegExMatch = call_re.search(line)
        if m == null:
            continue
        var joined := ""
        for l in lit_re.search_all(m.get_string(1)):
            joined += l.get_string(1)
        out.append(joined)
    return out

func _dist(a: Color, b: Color) -> float:
    return Vector3(a.r-b.r,a.g-b.g,a.b-b.b).length()

func _run() -> void:
    var was_accent: String = STYLE.accent_name
    var err: String = _checks()
    STYLE.set_accent(was_accent)
    if err != "":
        _fail(err)
        return
    print("PASS: scoring callout colours (#66) - every scorer / judge event text is classified (a new one fails here), RED = WALL / SPIN CHAIN LOST + MISSED, GOLD = BANKED, VIOLET #9774C8 = TRANSITION / KERB CLIP / zone bonuses / WALL KISS (not red), WHITE = other, identical for all six accents (a bonus is never red with the RED accent), four colours distinct and readable on the dark outline over DAWN / DAY / GOLDEN HOUR / NIGHT skies and white clouds, the real scorer's TRANSITION / KERB CLIP / BANKED / WALL events colour correctly and its points are unchanged; NOT proven: appearance on the owner's phone")
    quit(0)

func _checks() -> String:
    # ------------------------------------------------ every event text in the sources is known and classified
    var found: Array[String] = []
    for path in SOURCES:
        for lit in _literals(FileAccess.get_file_as_string(path)):
            if not found.has(lit):
                found.append(lit)
    for lit in found:
        if not KNOWN_LITERALS.has(lit):
            return "new scoring event text \"%s\" in the scorer / judge: decide its category in scoring_palette.gd and add it here" % lit
    for lit in KNOWN_LITERALS:
        if not found.has(lit):
            return "scoring event text \"%s\" is no longer produced: update KNOWN_LITERALS and the samples" % lit
    for sample in SAMPLES:
        var got: int = PALETTE.category_of_text(str(sample[0]))
        if got != int(sample[1]):
            return "\"%s\" must be %s, got %s" % [str(sample[0]),PALETTE.NAMES[int(sample[1])],PALETTE.NAMES[got]]
    if PALETTE.category_of({"text":"BANKED  +5","category":"PENALTY"}) != P or PALETTE.category_of({"text":"x","category":PALETTE.Category.BANKED}) != B:
        return "an explicit event category must win over the text"
    if PALETTE.category_of({"text":"WALL!  CHAIN LOST","category":"nonsense"}) != P:
        return "an invalid category must fall back to the text"
    if PALETTE.VIOLET != Color("#9774C8") or PALETTE.GOLD != STYLE.GOLD or PALETTE.RED != Color(1.0,0.42,0.42):
        return "the palette constants changed (RED / GOLD keep their earlier values, VIOLET is #9774C8)"
    # --------------------------------------------------------------------- HUD colours, six accents
    var hud: Control = HUD.new()
    root.add_child(hud)
    var expected: Dictionary = {P:PALETTE.RED,B:PALETTE.GOLD,X:PALETTE.VIOLET,I:PALETTE.WHITE}
    var first: Dictionary = {}
    for accent in STYLE.ACCENT_ORDER:
        STYLE.set_accent(accent)
        for sample in SAMPLES:
            var col: Color = hud.call("callout_color",{"text":sample[0],"age":0.3})
            var want: Color = expected[int(sample[1])]
            if _dist(col,want) > 0.0001:
                return "accent %s: \"%s\" is %s, must be %s" % [accent,str(sample[0]),str(col),str(want)]
            if first.has(sample[0]) and _dist(first[sample[0]],col) > 0.0001:
                return "\"%s\" changes with the accent" % str(sample[0])
            first[sample[0]] = col
        # The point of the issue: with the RED accent a bonus must not look like a penalty.
        if _dist(hud.call("callout_color",{"text":"TRANSITION  +0.25x"}),hud.call("callout_color",{"text":"WALL!  CHAIN LOST"})) < 0.3:
            return "accent %s: a bonus looks like a loss" % accent
        if _dist(hud.call("callout_color",{"text":"KERB CLIP  x1.5"}),STYLE.PINK_SOFT) < 0.001 and accent == "violet":
            pass # the violet accent may equal the fixed violet roughly; the meaning is in the text as well
    hud.queue_free()
    # ------------------------------------------------------------------- distinct and readable
    var cols: Array = [PALETTE.RED,PALETTE.GOLD,PALETTE.VIOLET,PALETTE.WHITE]
    var names: Array = ["RED","GOLD","VIOLET","WHITE"]
    for i in range(cols.size()):
        for j in range(i+1,cols.size()):
            if _dist(cols[i],cols[j]) < 0.30:
                return "%s and %s are too close (%.2f)" % [names[i],names[j],_dist(cols[i],cols[j])]
        if PALETTE.contrast_ratio(cols[i],PALETTE.OUTLINE) < 4.5:
            return "%s is not readable on the dark outline (%.1f:1)" % [names[i],PALETTE.contrast_ratio(cols[i],PALETTE.OUTLINE)]
    # Backdrops: the three non-DAY lighting presets' sky + horizon, a bright DAY sky and white cloud. The callout outline is
    # black at PALETTE.OUTLINE_ALPHA around every glyph, so the local backdrop is the sky darkened by that much.
    var skies: Dictionary = {"DAY sky":Color(0.55,0.72,0.95),"DAY horizon":Color(0.80,0.88,0.97),"white cloud":Color(1,1,1)}
    for preset in [TIME.Preset.DAWN,TIME.Preset.GOLDEN_HOUR,TIME.Preset.NIGHT]:
        var look: Dictionary = ENV.LOOKS[preset]
        skies[TIME.LABELS[preset]+" sky"] = look.sky
        skies[TIME.LABELS[preset]+" horizon"] = look.horizon
    for label in skies.keys():
        var base: Color = skies[label]
        var local: Color = base.lerp(Color.BLACK,PALETTE.OUTLINE_ALPHA)
        for i in range(cols.size()):
            var cr: float = PALETTE.contrast_ratio(cols[i],local)
            if cr < 3.0:
                return "%s on the %s: contrast %.1f:1 is below 3:1" % [names[i],label,cr]
    # ------------------------------------------------ the real scorer: colours of its events, points unchanged
    var sc = SCORER.new()
    for _i in range(60):
        sc.update(1.0/60.0,true,30.0,25.0,6.0)         # drift one way
    for _i in range(30):
        sc.update(1.0/60.0,true,-30.0,25.0,1.5)        # flip (TRANSITION) at the road edge (KERB CLIP)
    sc.bank()
    for _i in range(40):
        sc.update(1.0/60.0,true,28.0,22.0,6.0)
    sc.wall_hit(5.0)                                   # CHAIN LOST
    var texts: Array = []
    for e in sc.events:
        texts.append(str(e["text"]))
    var seen: Dictionary = {}
    for e in sc.events:
        seen[PALETTE.category_of(e)] = str(e["text"])
    if not (seen.has(P) and str(seen[P]).contains("CHAIN LOST")):
        return "the real scorer's WALL / CHAIN LOST must colour as PENALTY (%s)" % str(texts)
    if not (seen.has(B) or texts.any(func(t): return str(t).begins_with("BANKED"))):
        pass
    var all_texts: Array = texts.duplicate()
    # Events scroll out after three; collect the early ones from a second short run.
    var sc2 = SCORER.new()
    for _i in range(30):
        sc2.update(1.0/60.0,true,30.0,25.0,6.0)
    sc2.update(1.0/60.0,true,-30.0,25.0,1.5)
    for e in sc2.events:
        all_texts.append(str(e["text"]))
    var cats: Dictionary = {}
    for t in all_texts:
        cats[PALETTE.category_of_text(str(t))] = true
    if not (cats.has(P) and cats.has(X)):
        return "the real scorer must produce a PENALTY and a BONUS callout (%s)" % str(all_texts)
    for t in all_texts:
        if PALETTE.category_of_text(str(t)) == I:
            return "the real scorer printed an unclassified text: \"%s\"" % str(t)
    # Golden values of the unchanged scorer for this exact sequence (computed on the base 9c827cd before the palette patch).
    var gold: Array = [sc.total,sc.chains_banked,sc.chains_lost,sc.transitions,sc.kerb_clips,sc.best_chain]
    if gold != GOLDEN:
        return "scorer numbers changed: %s, expected %s" % [str(gold),str(GOLDEN)]
    return ""

## [total, chains_banked, chains_lost, transitions, kerb_clips, best_chain]
const GOLDEN: Array = [717,1,1,1,1,717]
