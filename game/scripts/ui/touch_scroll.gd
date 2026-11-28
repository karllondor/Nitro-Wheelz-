extends ScrollContainer
class_name NitroTouchScroll
## Phone-first vertical scroll for menu pages (issue #65 / #59, v0.1.52).
## Owner report: My Tracks / DEVELOPER scrolled "only sometimes". The list is almost all buttons; a drag that starts
## on a button was either eaten by the button (no scroll) or, once the list moved, released as a TAP on whatever
## button ended up under the finger (accidental DRIVE / DELETE). This container decides itself, before the GUI:
##  * a finger that moves more than DRAG_SLOP (and more vertically than sideways) is a SCROLL: the content follows
##    the finger, a short fling keeps gliding, and the button that was touched is cancelled (no press on release);
##  * a finger that stays within DRAG_SLOP is a TAP: the button works exactly as before;
##  * horizontal drags (sliders) are left alone; mouse wheel / scroll bar keep the engine behaviour.
## The engine's own drag-to-scroll is disabled (huge dead zone) so the two never fight.
const DRAG_SLOP_UNITS: float = 14.0
const FRICTION: float = 5.5

var unit: float = 1.0
## True from the moment the current (or last) gesture became a scroll until the next press.
var moved: bool = false
var _active: bool = false
var _index: int = -1
var _start: Vector2 = Vector2.ZERO
var _last: Vector2 = Vector2.ZERO
var _velocity: float = 0.0
var _last_t: int = 0

func _init() -> void:
    horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll_deadzone = 1000000
    follow_focus = true

func drag_slop() -> float:
    return DRAG_SLOP_UNITS*unit

func _input(event: InputEvent) -> void:
    if not is_visible_in_tree():
        return
    if event is InputEventScreenTouch:
        var t: InputEventScreenTouch = event
        if t.pressed:
            if not _active and get_global_rect().has_point(t.position):
                _press(t.index,t.position)
        elif _active and t.index == _index:
            _release()
    elif event is InputEventScreenDrag:
        var d: InputEventScreenDrag = event
        if _active and d.index == _index:
            _drag(d.position)
    elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
        # A real mouse (desktop / web). Touch arrives above as screen events; its emulated mouse copy is ignored.
        var mb: InputEventMouseButton = event
        if mb.button_index != MOUSE_BUTTON_LEFT:
            return
        if mb.pressed:
            if not _active and get_global_rect().has_point(mb.position):
                _press(-2,mb.position)
        elif _active and _index == -2:
            _release()
    elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
        if _active and _index == -2:
            _drag((event as InputEventMouseMotion).position)

func _press(index: int, p: Vector2) -> void:
    _active = true
    _index = index
    _start = p
    _last = p
    _velocity = 0.0
    _last_t = Time.get_ticks_usec()
    moved = false

func _drag(p: Vector2) -> void:
    var total: Vector2 = p-_start
    if not moved and absf(total.y) > drag_slop() and absf(total.y) > absf(total.x):
        moved = true
        _cancel_touched_buttons()
    if moved:
        var dy: float = p.y-_last.y
        scroll_vertical = int(round(float(scroll_vertical)-dy))
        var now: int = Time.get_ticks_usec()
        var dt: float = maxf(0.001,float(now-_last_t)/1000000.0)
        _velocity = lerpf(_velocity,-dy/dt,0.5)
        _last_t = now
    _last = p

func _release() -> void:
    _active = false
    _index = -1
    if not moved or float(Time.get_ticks_usec()-_last_t)/1000000.0 > 0.08:
        _velocity = 0.0

func _process(delta: float) -> void:
    if _active or absf(_velocity) < 20.0:
        return
    var before: int = scroll_vertical
    scroll_vertical = int(round(float(scroll_vertical)+_velocity*delta))
    _velocity *= exp(-FRICTION*delta)
    if scroll_vertical == before:
        _velocity = 0.0 # hit the top or the bottom

## The button under the finger must not fire when the finger lifts after a scroll. Toggling `disabled` clears a
## BaseButton's press attempt (engine behaviour), so its release is no longer a press; its state is restored at once.
func _cancel_touched_buttons() -> void:
    for n in find_children("*","BaseButton",true,false):
        var b: BaseButton = n
        if b.is_visible_in_tree() and not b.disabled and b.get_global_rect().has_point(_start):
            b.disabled = true
            b.disabled = false
