extends ColorRect
## Live, session-only result board. Never opens the solo record store.
const STYLE = preload("res://scripts/ui/hud_style.gd")
const CARS = preload("res://scripts/vehicles/car_catalog.gd")
const RESULTS = preload("res://scripts/ui/race_results.gd")

var session: NitroNetSession
var table: GridContainer
var cells: Array[Label] = []
var restart: Button

func show_round(active: NitroNetSession, track_name: String, replay: Callable, leave: Callable) -> void:
    session = active
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    color = Color(0.025,0.025,0.04,0.98)
    var center := CenterContainer.new()
    add_child(center)
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var stack := VBoxContainer.new()
    center.add_child(stack)
    var viewport_size := get_viewport_rect().size
    var scale_ui := clampf(minf(viewport_size.x/620.0,viewport_size.y/420.0),0.6,2.2)
    stack.theme = STYLE.screen_theme(scale_ui)
    stack.add_theme_constant_override("separation",roundi(14*scale_ui))
    _label(stack,"%s  •  ROUND %d" % [track_name,session.round_id],24*scale_ui)
    _label(stack,"TANDEM RESULTS",32*scale_ui)
    table = GridContainer.new()
    table.columns = 4
    table.add_theme_constant_override("h_separation",roundi(12*scale_ui))
    stack.add_child(table)
    for title in ["DRIVER","CAR","POINTS","TIME"]:
        _label(table,title,17*scale_ui).modulate = STYLE.PINK_SOFT
    for i in 8:
        var cell := _label(table,"",18*scale_ui)
        if i%4 == 0:
            cell.custom_minimum_size.x = 142*scale_ui
            cell.clip_text = true
            cell.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
        cells.append(cell)
    restart = Button.new()
    restart.text = "RESTART RACE"
    restart.pressed.connect(replay)
    STYLE.style_button(restart,scale_ui,true)
    stack.add_child(restart)
    var menu := Button.new()
    menu.text = "GARAGE / MENU"
    menu.pressed.connect(leave)
    STYLE.style_button(menu,scale_ui,false)
    stack.add_child(menu)
    session.standings_changed.connect(_refresh)
    session.state_changed.connect(func(_state: int): _refresh())
    _refresh()

func _label(parent: Node, value: String, px: float) -> Label:
    var label := Label.new()
    label.text = value
    label.add_theme_font_size_override("font_size",roundi(px))
    parent.add_child(label)
    return label

func _refresh() -> void:
    if is_queued_for_deletion() or session == null:
        return
    var rows := session.standings()
    for i in rows.size():
        var row := rows[i]
        var idx := i*4
        cells[idx].text = "%d. %s" % [i+1,row.name]
        cells[idx+1].text = CARS.info(row.car).short
        cells[idx+2].text = RESULTS.points(row.points)
        cells[idx+3].text = RESULTS.clock(row.time_ms/1000.0) if row.time_ms >= 0 else row.status
    restart.disabled = not session.is_host or session.state != session.State.RACING
    if restart.disabled:
        restart.text = "CONNECTION CLOSED" if session.state == session.State.LOST else "WAITING FOR HOST"
