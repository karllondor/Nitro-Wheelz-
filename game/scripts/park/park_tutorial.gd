extends RefCounted
class_name NitroParkTutorial
## The guided lessons of NITRO WHEELZ PARK (issue #27) as a small state machine.
## Optional: FREE DRIVE / SKIP TUTORIAL never creates one. Every lesson is judged by
## what the car and the real controls actually did (park_detectors.gd), and the next
## lesson starts by itself the moment the manoeuvre is genuinely done - no timers,
## no "tap to continue" for the success itself. Lesson progress is saved
## (park_progress.gd) and any lesson can be repeated.
##
## Order (owner brief): GAS -> steering -> BRAKE -> HANDBRAKE -> first controlled slide
## -> DONUT left -> DONUT right -> large eight -> small eight -> the long flattened-eight
## route. The exact script is not owner-final; the list below is the one place to edit.
const LAYOUT = preload("res://scripts/park/park_layout.gd")
const DET = preload("res://scripts/park/park_detectors.gd")
const PROGRESS = preload("res://scripts/park/park_progress.gd")

## "pl" is the owner's wording (issue #27 comments), "en" the same in English.
const LANG: String = "pl"

const LESSONS: Array[Dictionary] = [
    {"id":"gas","kind":"control","highlight":"gas","schematic":false,
        "title":{"pl":"GAZ","en":"GAS"},
        "prompt":{"pl":"To jest GAZ — naciśnij i przytrzymaj","en":"This is the GAS — press and hold"},
        "hint":{"pl":"Przytrzymaj GAZ po prawej, aż auto ruszy.","en":"Hold the GAS on the right until the car moves."}},
    {"id":"steer","kind":"control","highlight":"joystick","schematic":false,
        "title":{"pl":"KIEROWNICA","en":"STEERING"},
        "prompt":{"pl":"Jedź i skręć w lewo, potem w prawo. Joystick to kierownica.","en":"Drive and steer left, then right. The joystick is the wheel."},
        "hint":{"pl":"Trzymaj gaz i przesuń joystick w lewo, potem w prawo.","en":"Hold the gas and move the joystick left, then right."}},
    {"id":"brake","kind":"control","highlight":"brake","schematic":false,
        "title":{"pl":"HAMULEC","en":"BRAKE"},
        "prompt":{"pl":"To jest HAMULEC. Rozpędź się, potem go wciśnij.","en":"This is the BRAKE. Speed up, then press it."},
        "hint":{"pl":"Najpierw dodaj gazu, potem wciśnij HAMULEC.","en":"Add gas first, then press the BRAKE."}},
    {"id":"handbrake","kind":"control","highlight":"drift","schematic":false,
        "title":{"pl":"RĘCZNY","en":"HANDBRAKE"},
        "prompt":{"pl":"To jest RĘCZNY. W biegu pociągnij go na chwilę — tył auta ucieknie.","en":"This is the HANDBRAKE. Pull it briefly at speed - the rear steps out."},
        "hint":{"pl":"Rozpędź się i na moment pociągnij dźwignię RĘCZNEGO.","en":"Speed up and pull the HANDBRAKE lever briefly."}},
    {"id":"slide","kind":"slide","highlight":"","schematic":false,
        "title":{"pl":"PIERWSZY POŚLIZG","en":"FIRST SLIDE"},
        "prompt":{"pl":"Dodaj gaz i delikatnie skręć. Poczuj, jak reaguje auto. Ręczny zaczyna poślizg.","en":"Add gas and steer gently. Feel how the car reacts. The handbrake starts the slide."},
        "hint":{"pl":"Skręć i pociągnij ręczny, potem puść go i wyprowadź auto.","en":"Steer, pull the handbrake, then release and straighten up."}},
    {"id":"donut_left","kind":"donut","highlight":"","schematic":true,"exercise":"donut_left",
        "title":{"pl":"DONUT W LEWO","en":"DONUT LEFT"},
        "prompt":{"pl":"Skręć i utrzymuj gaz. Utrzymaj poślizg wokół pachołka.","en":"Steer and hold the gas. Keep the slide around the cone."},
        "hint":{"pl":"Skręć w lewo, daj gaz i krąż wokół środkowego pachołka.","en":"Steer left, add gas and circle the centre cone."}},
    {"id":"donut_right","kind":"donut","highlight":"","schematic":true,"exercise":"donut_right",
        "title":{"pl":"DONUT W PRAWO","en":"DONUT RIGHT"},
        "prompt":{"pl":"Dobrze! Teraz wykonaj zakręt w drugą stronę.","en":"Good! Now turn the other way."},
        "hint":{"pl":"Skręć w prawo, daj gaz i krąż wokół prawego pachołka.","en":"Steer right, add gas and circle the right cone."}},
    {"id":"eight_large","kind":"eight","highlight":"","schematic":true,"exercise":"eight_large",
        "title":{"pl":"DUŻA ÓSEMKA","en":"LARGE EIGHT"},
        "prompt":{"pl":"Przejedź wokół dwóch pachołków. W środku zmień kierunek skrętu.","en":"Drive around the two cones. Change the steering direction in the middle."},
        "hint":{"pl":"Okrąż jeden pachołek, w środku zmień kierunek i okrąż drugi.","en":"Circle one cone, change direction in the middle and circle the other."}},
    {"id":"eight_small","kind":"eight","highlight":"","schematic":true,"exercise":"eight_small",
        "title":{"pl":"MAŁA ÓSEMKA","en":"SMALL EIGHT"},
        "prompt":{"pl":"Teraz zacieśnij ósemkę: zmniejsz promień, kontrolując gaz i kierownicę.","en":"Now tighten the eight: smaller radius, controlling gas and steering."},
        "hint":{"pl":"Mniej gazu i mocniejszy skręt dają mniejszy promień.","en":"Less gas and more steering give a smaller radius."}},
    {"id":"route","kind":"route","highlight":"","schematic":true,"exercise":"route",
        "title":{"pl":"DŁUGA ÓSEMKA","en":"LONG EIGHT"},
        "prompt":{"pl":"Jedź wzdłuż żółtej linii między pachołkami. Szerokie, płynne łuki.","en":"Follow the yellow line between the cones. Wide, smooth arcs."},
        "hint":{"pl":"Trzymaj się linii i pachołków; łuki są szerokie, nie spiesz się.","en":"Stay on the line and between the cones; the arcs are wide, take your time."}}]

const SUCCESS_TEXT: Array[Dictionary] = [
    {"pl":"DOBRZE!","en":"GOOD!"},{"pl":"ŚWIETNIE!","en":"GREAT!"},{"pl":"TAK TRZYMAJ!","en":"KEEP IT UP!"}]
const CONE_TEXT: Dictionary = {"pl":"Spokojnie, pachołek jest lekki. Spróbuj jeszcze raz.","en":"Easy, the cone is light. Try again."}
## Welcome card before the very first lesson (full size, tap to start; also starts by itself).
const WELCOME_TITLE: Dictionary = {"pl":"WITAJ W NITRO WHEELZ PARK","en":"WELCOME TO NITRO WHEELZ PARK"}
const WELCOME_BODY: Dictionary = {
    "pl":"Lekcje przechodzą dalej same, gdy wykonasz ćwiczenie. POMIŃ możesz w każdej chwili.",
    "en":"Lessons advance by themselves when you do the exercise. You can SKIP at any time."}
const WELCOME_LABELS: Dictionary = {
    "steer":{"pl":"KIEROWNICA","en":"STEERING"},"gas":{"pl":"GAZ","en":"GAS"},
    "brake":{"pl":"HAMULEC","en":"BRAKE"},"drift":{"pl":"RĘCZNY (DRIFT)","en":"HANDBRAKE (DRIFT)"}}
const TAP_TEXT: Dictionary = {"pl":"DOTKNIJ, ABY ZACZĄĆ","en":"TAP TO START"}
## Navigation texts (the exercise is somewhere on a 340 m pad: say WHERE it is).
const NAV_GO: Dictionary = {"pl":"JEDŹ DO PIERŚCIENIA","en":"DRIVE TO THE RING"}
const NAV_GO_EIGHT: Dictionary = {"pl":"JEDŹ DO PACHOŁKÓW","en":"DRIVE TO THE CONES"}
const NAV_GO_ROUTE: Dictionary = {"pl":"JEDŹ NA POCZĄTEK TRASY","en":"DRIVE TO THE START OF THE ROUTE"}
const NAV_SIDE: Dictionary = {
    "ahead":{"pl":"PROSTO","en":"AHEAD"},"left":{"pl":"NA LEWO","en":"TO THE LEFT"},
    "right":{"pl":"NA PRAWO","en":"TO THE RIGHT"},"behind":{"pl":"ZA TOBĄ","en":"BEHIND YOU"}}
const NAV_HERE_LEFT: Dictionary = {"pl":"JESTEŚ NA MIEJSCU — KRĄŻ W LEWO ↺","en":"YOU ARE THERE — CIRCLE LEFT ↺"}
const NAV_HERE_RIGHT: Dictionary = {"pl":"JESTEŚ NA MIEJSCU — KRĄŻ W PRAWO ↻","en":"YOU ARE THERE — CIRCLE RIGHT ↻"}
const NAV_HERE_EIGHT: Dictionary = {"pl":"JESTEŚ NA MIEJSCU — JEDŹ ÓSEMKĄ","en":"YOU ARE THERE — DRIVE THE EIGHT"}
const NAV_HERE_ROUTE: Dictionary = {"pl":"JESTEŚ NA MIEJSCU — JEDŹ TRASĄ","en":"YOU ARE THERE — DRIVE THE ROUTE"}
const NAV_LINE_HINT: Dictionary = {"pl":"Jedź wzdłuż niebieskiej linii na asfalcie.","en":"Follow the blue line on the asphalt."}
const WRONG_WAY_LEFT: Dictionary = {"pl":"Kręć w LEWO — przeciwnie do ruchu wskazówek zegara.","en":"Circle LEFT — counter-clockwise."}
const WRONG_WAY_RIGHT: Dictionary = {"pl":"Kręć w PRAWO — zgodnie z ruchem wskazówek zegara.","en":"Circle RIGHT — clockwise."}
const OVERLAY_SECONDS: float = 8.0
const WELCOME_SECONDS: float = 14.0
const NAV_HINT_AFTER: float = 25.0
const FINISHED_TEXT: Dictionary = {"pl":"Gotowe! Masz wszystkie lekcje. Jedź swobodnie.","en":"Done! All lessons complete. Drive freely."}

signal lesson_started(index: int)
signal lesson_completed(index: int)
signal hint_shown(text: String)
signal tutorial_finished

## "off" (skipped / free), "welcome" (full-size first card, car frozen), "intro" (schematic overlay,
## car frozen), "active", "success", "finished"
var phase: String = "off"
var nav_hint_given: bool = false
## Process frame in which a card was dismissed. A touch also arrives as an emulated mouse press that
## can dismiss the card first, so the touch layer ignores new presses for this frame and the next.
var dismissed_frame: int = -100
var wrong_way_clock: float = 0.0
var lesson_index: int = 0
var phase_time: float = 0.0
var lesson_time: float = 0.0
var idle_time: float = 0.0
var last_progress: float = 0.0
var detector: RefCounted = null
var _t_gas: float = 0.0
var _t_left: float = 0.0
var _t_right: float = 0.0
var _brake_speed_start: float = -1.0
var _t_brake: float = 0.0
var _max_speed: float = 0.0
var _t_hand: float = 0.0
var _success_pick: int = 0

static func txt(entry: Dictionary) -> String:
    return str(entry.get(LANG,entry.get("en","")))

static func lesson_ids() -> PackedStringArray:
    var out := PackedStringArray()
    for l in LESSONS:
        out.append(str(l["id"]))
    return out

func lesson() -> Dictionary:
    return LESSONS[clampi(lesson_index,0,LESSONS.size()-1)]

func is_active() -> bool:
    return phase != "off" and phase != "finished"

## True while the car must stand still (a full-screen card is up).
func freezes_car() -> bool:
    return phase == "intro" or phase == "welcome"

## True while a NEW touch press must not reach the pedals: a card is up, or one was just dismissed.
func blocks_presses() -> bool:
    return freezes_car() or Engine.get_process_frames()-dismissed_frame <= 1

## Start the tutorial at lesson `from_index`. Starting at the very first lesson shows the
## full-size welcome card first (controls + how the lessons work).
var persist_progress := true

func start(from_index: int = 0) -> void:
    if persist_progress:
        PROGRESS.set_seen()
    if from_index >= LESSONS.size():
        phase = "finished"
        tutorial_finished.emit()
        return
    var index: int = clampi(from_index,0,LESSONS.size()-1)
    if index == 0:
        _begin_lesson(0)
        phase = "welcome"
        phase_time = 0.0
    else:
        _begin_lesson(index)

## SKIP TUTORIAL: free practice, nothing is reset, nothing is gated.
func skip() -> void:
    phase = "off"
    detector = null

func _begin_lesson(index: int) -> void:
    lesson_index = index
    lesson_time = 0.0
    idle_time = 0.0
    last_progress = 0.0
    phase_time = 0.0
    _t_gas = 0.0
    _t_left = 0.0
    _t_right = 0.0
    _t_brake = 0.0
    _brake_speed_start = -1.0
    _max_speed = 0.0
    _t_hand = 0.0
    detector = _make_detector(lesson())
    phase = "intro" if bool(lesson()["schematic"]) else "active"
    nav_hint_given = false
    wrong_way_clock = 0.0
    lesson_started.emit(index)

func _make_detector(l: Dictionary) -> RefCounted:
    match str(l["kind"]):
        "slide":
            return DET.FirstSlide.new()
        "donut":
            var e: Dictionary = LAYOUT.exercise(str(l["exercise"]))
            var r: float = float(e["radius"])
            return DET.Orbit.new(Vector2(e["centre"]),maxf(2.5,r*0.22),r*1.7,int(e["turn"]),320.0,0.5)
        "eight":
            var e2: Dictionary = LAYOUT.exercise(str(l["exercise"]))
            return DET.Eight.new(e2["lobes"],float(e2["radius"]),Vector2(0.3,1.7),235.0,0.35)
        "route":
            var e3: Dictionary = LAYOUT.exercise(str(l["exercise"]))
            return DET.Route.new(LAYOUT.route_path(1.5),float(e3["width"]),0.7,0.12)
    return null

## The player tapped the card / schematic away (or it timed out): driving starts.
func dismiss_intro() -> void:
    if phase == "intro" or phase == "welcome":
        phase = "active"
        phase_time = 0.0
        dismissed_frame = Engine.get_process_frames()

## Clock of the full-screen cards. The physics tick does not run while the car is frozen,
## so the controller feeds this every frame: the card can never stay up forever.
func tick_overlay(dt: float) -> void:
    if phase == "intro":
        phase_time += dt
        if phase_time > OVERLAY_SECONDS:
            dismiss_intro()
    elif phase == "welcome":
        phase_time += dt
        if phase_time > WELCOME_SECONDS:
            dismiss_intro()

func repeat_lesson() -> void:
    _begin_lesson(lesson_index)

## One physics tick with the REAL vehicle + input state:
## {pos, speed_kmh, drift_angle, steer, gas, brake, handbrake}.
func update(dt: float, st: Dictionary) -> void:
    match phase:
        "off", "finished":
            return
        "intro", "welcome":
            tick_overlay(dt)
            return
        "success":
            phase_time += dt
            if phase_time >= 1.7:
                _advance()
            return
    lesson_time += dt
    phase_time += dt
    var done: bool = _update_lesson(dt,st)
    var p: float = progress()
    if p > last_progress+0.01:
        idle_time = 0.0
    else:
        idle_time += dt
    last_progress = maxf(last_progress,p)
    if idle_time > 15.0:
        idle_time = 0.0
        hint_shown.emit(txt(lesson()["hint"]))
    if detector != null and detector.has_method("wrong_way") and bool(detector.wrong_way()):
        wrong_way_clock += dt
        if wrong_way_clock > 6.0:
            wrong_way_clock = 0.0
            var left: bool = str(lesson()["id"]) == "donut_left"
            hint_shown.emit(txt(WRONG_WAY_LEFT if left else WRONG_WAY_RIGHT))
    else:
        wrong_way_clock = 0.0
    if done:
        if persist_progress:
            PROGRESS.mark_completed(str(lesson()["id"]))
        _success_pick = (lesson_index)%SUCCESS_TEXT.size()
        phase = "success"
        phase_time = 0.0
        lesson_completed.emit(lesson_index)

func _advance() -> void:
    if lesson_index+1 >= LESSONS.size():
        phase = "finished"
        tutorial_finished.emit()
    else:
        _begin_lesson(lesson_index+1)

func _update_lesson(dt: float, st: Dictionary) -> bool:
    var speed: float = float(st["speed_kmh"])
    _max_speed = maxf(_max_speed,speed)
    match str(lesson()["id"]):
        "gas":
            if float(st["gas"]) >= 0.5 and speed > 10.0:
                _t_gas += dt
            return _t_gas >= 1.0
        "steer":
            if speed > 10.0:
                var s: float = float(st["steer"])
                if s <= -0.45:
                    _t_left += dt
                elif s >= 0.45:
                    _t_right += dt
            return _t_left >= 0.4 and _t_right >= 0.4
        "brake":
            if _brake_speed_start < 0.0:
                if float(st["brake"]) >= 0.5 and speed >= 22.0:
                    _brake_speed_start = speed
                    _t_brake = 0.0
            else:
                if float(st["brake"]) >= 0.5:
                    _t_brake += dt
                    if _t_brake >= 0.35 and speed <= _brake_speed_start-8.0:
                        return true
                else:
                    _brake_speed_start = -1.0
            return false
        "handbrake":
            if float(st["handbrake"]) >= 0.5 and speed >= 20.0:
                _t_hand += dt
            return _t_hand >= 0.12
    if detector == null:
        return false
    var kind: String = str(lesson()["kind"])
    if kind == "slide":
        detector.update(dt,float(st["drift_angle"]),speed)
    else:
        detector.update(Vector2(st["pos"]),dt,float(st["drift_angle"]),speed)
    return bool(detector.done())

## 0..1 progress of the current lesson (for the progress bar).
func progress() -> float:
    match str(lesson()["id"]):
        "gas":
            return clampf(_t_gas/1.0,0.0,1.0)
        "steer":
            return (clampf(_t_left/0.4,0.0,1.0)+clampf(_t_right/0.4,0.0,1.0))*0.5
        "brake":
            if _brake_speed_start < 0.0:
                return clampf(_max_speed/22.0,0.0,1.0)*0.4
            return 0.4+0.6*clampf(_t_brake/0.35,0.0,1.0)
        "handbrake":
            return clampf(_t_hand/0.12,0.0,1.0)
    if detector != null:
        return float(detector.progress())
    return 0.0

func success_text() -> String:
    return txt(SUCCESS_TEXT[_success_pick])

func prompt_text() -> String:
    return txt(lesson()["prompt"])

func title_text() -> String:
    return txt(lesson()["title"])
