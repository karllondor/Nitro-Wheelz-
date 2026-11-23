extends Node
## Invoked only by an explicit adb run-as marker in a debuggable install.
## The harness drives the normal Builder/DRIVE path and records the APK viewport.
func _ready() -> void:
    run.call_deferred()

func snapshot(label_: String) -> void:
    await RenderingServer.frame_post_draw
    # Android may render straight into the system framebuffer. The host
    # captures the visible compositor surface before advancing the test.
    var marker := FileAccess.open("user://ready-"+label_,FileAccess.WRITE)
    marker.store_line(label_)
    marker.close()
    while not FileAccess.file_exists("user://captured-"+label_):
        await get_tree().create_timer(0.15).timeout

func run() -> void:
    var tree=get_tree()
    var boot=tree.current_scene
    boot.show_page("main")
    boot.page.get_node("TRACK BUILDER").pressed.emit()
    boot.page.get_node("Terrain builder").pressed.emit()
    while tree.current_scene==null or tree.current_scene.scene_file_path!="res://scenes/terrain_builder.tscn":
        await tree.process_frame
    var builder=tree.current_scene
    while builder.busy_running:
        await tree.process_frame
    builder._open_saved("res://tracks/event_workshop_29.json")
    while builder.busy_running:
        await tree.process_frame
    var original: Dictionary=builder._snapshot()
    builder.grid=builder.TT.new_grid()
    builder.mode="draw"
    var cells: Array[Vector2i]=[Vector2i(7,2),Vector2i(7,5),Vector2i(9,5),Vector2i(9,7)]
    var views:=["straight","corner","s-bend"]
    for i in range(3):
        builder.begin_stroke(cells[i])
        builder.move_stroke(cells[i+1])
        builder.end_stroke()
        while builder.busy_running:
            await tree.process_frame
        await snapshot(views[i])
    builder._restore(original)
    builder._toggle_surface()
    while builder.busy_running:
        await tree.process_frame
    await snapshot("circuit")
    builder._toggle_surface()
    while builder.busy_running:
        await tree.process_frame
    builder._write("user://workshop-reload.json","Event workshop","event_workshop_29")
    builder._open_saved("user://workshop-reload.json")
    while builder.busy_running:
        await tree.process_frame
    for mode in ["practice","pro","club"]:
        builder._pick_event(mode)
        while builder.busy_running:
            await tree.process_frame
        await snapshot(mode)
    ProjectSettings.set_setting("nitro/car_variant","e30")
    builder.buttons["b_DRIVE"].pressed.emit()
    while tree.current_scene==null or tree.current_scene.scene_file_path!="res://scenes/race.tscn":
        await tree.process_frame
    var race=tree.current_scene
    while not race.track.pending_terrain.is_empty():
        await tree.process_frame
    # Reproducible rolling entry. Input and all subsequent frames go through
    # the race's normal movement, collision, judging and camera code.
    var z: Dictionary=race.track.event_layout.zones[0]
    var frame: Dictionary=race.track._road_at_arc(z.a+0.25)
    var right: Vector2=frame.across
    var tangent:=Vector2(right.y,-right.x)
    race.model.reset(frame.centre,tangent.angle()+PI/2+deg_to_rad(26)*z.turn)
    var offset: float=z.d+race.model.forward().dot(right)*race.track.body_half_length-signf(z.d)*absf(race.model.right().dot(right))*race.track.body_half_width
    race.model.position+=right*offset
    race.model.velocity=tangent*z.pace
    race.model.rear_traction=0.45
    race._snap_cameras()
    Input.action_press("throttle",0.65)
    Input.action_press("steer_left" if z.turn<0 else "steer_right",0.55)
    for tick in range(42):
        await tree.physics_frame
    race.set_physics_process(false)
    await snapshot("drive")
    var file:=FileAccess.open("user://workshop-verdict.txt",FileAccess.WRITE)
    file.store_line("%s | %s | technical %.2f | pending %d" % ["PASS" if race.judge.technical>0 else "FAIL",OS.get_name(),race.judge.technical,race.scorer.pending_total()])
    file.close()
