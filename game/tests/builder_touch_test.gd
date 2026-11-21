extends SceneTree
## v0.1.32 mobile QA (owner's v0.1.28 phone test): Track Builder touch.
##  * the strip above the BUILD buttons (bottom-left) was outside the map
##    rectangle (dead for one finger AND for a second pinch finger);
##  * MOVE + one finger: the ground point under the finger stays under the
##    finger for the whole drag (Tatry mountains, no inversion, no jump);
##  * release: the map stops (no fling throwing the camera away);
##  * two fingers in that strip pinch-zoom and pan;
##  * moving the camera never runs a terrain fit and keeps the view pitch;
##  * while the terrain adapts (UPDATING pill) the map still moves; world
##    changing buttons wait, FIT / MOVE / VIEW work.
const BUILDER = preload("res://scenes/terrain_builder.tscn")
const TT = preload("res://scripts/world/terrain/terrain_track.gd")
const DIAG = preload("res://scripts/ui/touch_diagnostics.gd")

func _initialize() -> void:
    call_deferred("_run")

func _touch(b: Node, index: int, pos: Vector2, pressed: bool) -> void:
    var e := InputEventScreenTouch.new()
    e.index = index
    e.position = pos
    e.pressed = pressed
    b._unhandled_input(e)

func _drag(b: Node, index: int, pos: Vector2, rel: Vector2) -> void:
    var e := InputEventScreenDrag.new()
    e.index = index
    e.position = pos
    e.relative = rel
    b._unhandled_input(e)

func _run() -> void:
    DirAccess.remove_absolute("user://nitro_terrain_builder_draft.json")
    var b: Node3D = BUILDER.instantiate()
    root.add_child(b)
    await process_frame
    b._pick_country("poland")
    b._pick_landscape("pl_tatry")
    b.terrain_seed = 3
    b.generate_terrain(false)
    b._enter_build()
    TT.generate_loop(b.grid,b.world.field,b.descriptor(),5)
    b.route_start = TT.route_order(b.grid)["order"][0]
    b._after_edit()
    for i in range(3):
        await process_frame
    var err: String = await _checks(b)
    root.remove_child(b)
    b.free()
    DirAccess.remove_absolute("user://nitro_terrain_builder_draft.json")
    if not err.is_empty():
        printerr("FAIL: "+err)
        quit(1)
        return
    print("PASS: Track Builder touch - the strip above the BUILD buttons belongs to the map (one finger + pinch), MOVE drag keeps the ground point under the finger in the Tatry (no inversion / jump), no fling on release, pinch + pan in that strip, no terrain fit and a fixed pitch while the camera moves, map moves during UPDATING while world-changing buttons wait")
    for _f in range(3):
        await process_frame
    quit(0)

func _checks(b: Node) -> String:
    var mr: Rect2 = b.map_rect
    var s: Vector2 = root.get_visible_rect().size
    var move_btn: Button = b.buttons["MOVE"]
    var draw_btn: Button = b.buttons["DRAW"]
    var old_bottom: float = (b.map_rect_setup as Rect2).end.y
    if mr.end.y < draw_btn.get_global_rect().position.y-s.y*0.02:
        return "BUILD map rectangle ends %.0f px above the button rows" % (draw_btn.get_global_rect().position.y-mr.end.y)
    # The formerly dead strip, left of the MOVE button.
    var p := Vector2(s.x*0.20,(old_bottom+move_btn.get_global_rect().end.y)*0.5)
    if p.y <= old_bottom or not mr.has_point(p):
        return "Test point %s is not in the old dead strip / new map rect" % str(p)
    var diag: NitroTouchDiag = DIAG.new()
    root.add_child(diag)
    await process_frame
    var who: String = diag.who_takes(p)
    var who_btn: String = diag.who_takes(move_btn.get_global_rect().get_center())
    diag.free()
    if who != "SCENE":
        return "A control takes touches in the map strip: %s" % who
    if not who_btn.begins_with("MOVE"):
        return "The MOVE button must take its own touches (got %s)" % who_btn
    # DRAW mode: one finger in the strip starts a stroke.
    b.pan_mode = false
    _touch(b,0,p,true)
    var drew: bool = b.stroke_active
    _touch(b,0,p,false)
    if not drew:
        return "One finger in the strip above the buttons must draw in DRAW mode"
    if b.grid.tile_count() > 0 and not b.undo_stack.is_empty():
        b._undo()
    # MOVE mode: the ground point under the finger stays under the finger.
    b.pan_mode = true
    var adapts: int = b.diag_rebuilds
    var start: Vector2 = Vector2(s.x*0.30,mr.position.y+mr.size.y*0.55)
    _touch(b,0,start,true)
    var anchor: Vector3 = b.pan_anchor
    var pitch0: float = b.view_pitch
    var worst: float = 0.0
    var pos: Vector2 = start
    for k in range(24):
        var step := Vector2(9.0,-6.0) if k < 12 else Vector2(-4.0,11.0)
        pos += step
        _drag(b,0,pos,step)
        var under: Vector3 = b._plane_hit(pos,b.pan_plane_y)
        worst = maxf(worst,Vector2(under.x-anchor.x,under.z-anchor.z).length())
        if absf(b.view_pitch-pitch0) > 0.001:
            return "The view pitch changed during a drag (%.2f -> %.2f)" % [pitch0,b.view_pitch]
    var tol: float = maxf(0.5,b.cam_dist*0.002)
    if worst > tol:
        return "Ground under the finger drifted %.2f m during the drag (tolerance %.2f m)" % [worst,tol]
    var before: Vector3 = b.cam_target
    _touch(b,0,pos,false)
    for i in range(20):
        await process_frame
    if b.cam_target.distance_to(before) > 0.01 or b.goal_target.distance_to(before) > 0.01:
        return "The map kept moving after the finger lifted (%.2f m)" % b.cam_target.distance_to(before)
    # Two fingers in the old dead strip: pinch out = zoom in, pan.
    b.pan_mode = false
    var a := Vector2(s.x*0.18,p.y)
    var c := Vector2(s.x*0.42,p.y)
    var d0: float = b.cam_dist
    _touch(b,0,a,true)
    _touch(b,1,c,true)
    if not b.gesture_active:
        return "Two fingers in the strip above the buttons must start a pinch"
    for k in range(10):
        a += Vector2(-6.0,0.0)
        c += Vector2(6.0,0.0)
        _drag(b,0,a,Vector2(-6.0,0.0))
        _drag(b,1,c,Vector2(6.0,0.0))
    _touch(b,0,a,false)
    _touch(b,1,c,false)
    if b.cam_dist >= d0-1.0:
        return "Pinching out must zoom in (%.0f -> %.0f m)" % [d0,b.cam_dist]
    if b.stroke_active or b.grid.tile_count() == 0:
        return "A pinch must not draw or erase road"
    if b.diag_rebuilds != adapts:
        return "Moving the camera ran a terrain fit (%d -> %d): %s" % [adapts,b.diag_rebuilds,str(b.diag_events)]
    # While the terrain adapts: the map moves, drawing and world changes wait.
    b.busy_running = true
    var t0: Vector3 = b.cam_target
    _touch(b,0,start,true)
    if b.stroke_active:
        return "Drawing must wait while the terrain adapts"
    _drag(b,0,start+Vector2(30.0,0.0),Vector2(30.0,0.0))
    _touch(b,0,start+Vector2(30.0,0.0),false)
    if b.cam_target.distance_to(t0) < 0.5:
        return "The map must still move while the terrain adapts"
    var tiles: int = b.grid.tile_count()
    (b.buttons["CLEAR"] as Button).pressed.emit()
    if b.grid.tile_count() != tiles:
        return "CLEAR must wait while the terrain adapts"
    var view_before: int = b.view_index
    (b.buttons["MOVE"] as Button).pressed.emit()
    if not b.pan_mode:
        return "MOVE must work while the terrain adapts"
    b.busy_running = false
    b.pan_mode = false
    print("builder touch: map rect %s (old SETUP bottom %.0f), strip point %s -> %s, drag drift %.3f m over 24 steps, pinch %.0f -> %.0f m, view %d" % [
        str(mr),old_bottom,str(p),who,worst,d0,b.cam_dist,view_before])
    return ""
