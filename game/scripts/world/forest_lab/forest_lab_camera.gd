extends Camera3D
class_name NitroForestLabCamera
## Inspection camera of the FOREST LAB Tree Designer (developer tool, never in a race).
##  * ORBIT: left mouse drag / one finger around the target, mouse wheel / two-finger pinch to zoom;
##  * FLY: hold the RIGHT mouse button and use W A S D (Q / E down / up, Shift faster, wheel = speed), release to orbit again
##    around the point in front of the camera.
## Everything is plain code: no Input Map entries needed.
var target: Vector3 = Vector3(0.0,4.0,0.0)
var distance: float = 22.0
var yaw: float = 0.6
var pitch: float = 0.28
var fly_speed: float = 14.0
var _fly: bool = false
var _touches: Dictionary = {}
var _pinch_prev: float = 0.0

func focus(t: Vector3, d: float) -> void:
    target = t
    distance = clampf(d,1.5,300.0)
    _fly = false
    _apply()

func _ready() -> void:
    current = true
    _apply()

func _apply() -> void:
    pitch = clampf(pitch,-0.15,1.45)
    position = target+Vector3(cos(pitch)*sin(yaw),sin(pitch),cos(pitch)*cos(yaw))*distance
    look_at(target)

func _zoom(factor: float) -> void:
    distance = clampf(distance*factor,1.5,300.0)
    _apply()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        var mb: InputEventMouseButton = event
        if mb.button_index == MOUSE_BUTTON_RIGHT:
            _fly = mb.pressed
            if _fly:
                Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
            else:
                Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
                target = position-global_transform.basis.z*distance
                var d: Vector3 = (position-target).normalized()
                yaw = atan2(d.x,d.z)
                pitch = asin(clampf(d.y,-1.0,1.0))
                _apply()
        elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
            if _fly:
                fly_speed = minf(90.0,fly_speed*1.2)
            else:
                _zoom(0.9)
        elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            if _fly:
                fly_speed = maxf(2.0,fly_speed/1.2)
            else:
                _zoom(1.1)
    elif event is InputEventMouseMotion:
        var mm: InputEventMouseMotion = event
        if _fly:
            rotation = Vector3(clampf(rotation.x-mm.relative.y*0.003,-1.5,1.5),rotation.y-mm.relative.x*0.003,0.0)
        elif mm.button_mask&MOUSE_BUTTON_MASK_LEFT != 0:
            yaw -= mm.relative.x*0.006
            pitch += mm.relative.y*0.006
            _apply()
    elif event is InputEventScreenTouch:
        var st: InputEventScreenTouch = event
        if st.pressed:
            _touches[st.index] = st.position
        else:
            _touches.erase(st.index)
        _pinch_prev = 0.0
    elif event is InputEventScreenDrag:
        var sd: InputEventScreenDrag = event
        _touches[sd.index] = sd.position
        if _touches.size() == 1:
            yaw -= sd.relative.x*0.008
            pitch += sd.relative.y*0.008
            _apply()
        elif _touches.size() == 2:
            var pts: Array = _touches.values()
            var dist: float = (pts[0] as Vector2).distance_to(pts[1] as Vector2)
            if _pinch_prev > 0.0 and dist > 1.0:
                _zoom(clampf(_pinch_prev/dist,0.8,1.25))
            _pinch_prev = dist
    elif event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
        _fly = false
        Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _process(delta: float) -> void:
    if not _fly:
        return
    var dir := Vector3.ZERO
    if Input.is_key_pressed(KEY_W):
        dir -= global_transform.basis.z
    if Input.is_key_pressed(KEY_S):
        dir += global_transform.basis.z
    if Input.is_key_pressed(KEY_A):
        dir -= global_transform.basis.x
    if Input.is_key_pressed(KEY_D):
        dir += global_transform.basis.x
    if Input.is_key_pressed(KEY_Q):
        dir.y -= 1.0
    if Input.is_key_pressed(KEY_E):
        dir.y += 1.0
    if dir.length_squared() > 0.0:
        global_position += dir.normalized()*fly_speed*(3.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0)*delta
