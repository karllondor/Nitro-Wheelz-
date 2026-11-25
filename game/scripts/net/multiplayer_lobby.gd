extends Control
class_name NitroMultiplayerLobby
## LOCAL MULTIPLAYER (issue #31): the isolated UI entry. Two phones on the same Wi-Fi or on one phone's hotspot,
## no Internet: one phone HOSTS (and shows its local address), the other JOINS by typing that address.
##   menu  -> HOST GAME / JOIN GAME / BACK
##   host  -> own address + port, waiting, roster, track choice (host only), READY, START, LEAVE
##   join  -> address field, CONNECT (retry after an error), roster, READY, LEAVE
## The session node lives under the SceneTree root (not under this scene) so it survives the change to the race scene;
## NitroNetRace ends it when the race scene is left. The main menu has exactly one line that opens this scene.
const P = preload("res://scripts/net/net_protocol.gd")
const SESSION = preload("res://scripts/net/net_session.gd")
const STYLE = preload("res://scripts/ui/hud_style.gd")
const CARS = preload("res://scripts/vehicles/car_catalog.gd")
const DRIVER = preload("res://scripts/player/driver_profile.gd")
const CONFIG: String = "user://nitro_local_mp.cfg"

var ui_unit: float = 1.0
var page: VBoxContainer
var status: Label
var ping_label: Label = null
var session: NitroNetSession = null
var mode: String = "menu"
var ip_input: LineEdit = null
var ip_text: String = ""
var starting: bool = false
const RACE_PATH = "res://scenes/race.tscn"
var _race_preload: bool = false
## Tests: do not really change scene; the request is recorded instead.
var navigate_enabled: bool = true
var last_scene: String = ""
var _ping_clock: float = 0.0

func _ready() -> void:
    STYLE.ensure_settings()
    var s: Vector2 = get_viewport_rect().size
    var portrait: bool = s.y > s.x
    ui_unit = clampf(s.x/700.0,1.0,2.2) if portrait else 1.0
    theme = STYLE.screen_theme(ui_unit)
    var background := ColorRect.new()
    background.color = Color(0.016,0.014,0.024)
    add_child(background)
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var center := CenterContainer.new()
    add_child(center)
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var column := VBoxContainer.new()
    column.custom_minimum_size = Vector2(s.x*(0.88 if portrait else 0.46),0)
    column.add_theme_constant_override("separation",int(10*ui_unit))
    center.add_child(column)
    page = VBoxContainer.new()
    page.name = "Lobby page"
    page.add_theme_constant_override("separation",int(10*ui_unit))
    column.add_child(page)
    status = Label.new()
    status.name = "Status"
    status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status.add_theme_font_size_override("font_size",int(19*ui_unit))
    status.add_theme_color_override("font_color",Color(1.0,0.55,0.5))
    status.custom_minimum_size.y = 56.0*ui_unit
    column.add_child(status)
    var stamp := Label.new()
    stamp.text = "NITRO WHEELZ v%s  •  PROTOCOL %d  •  NO INTERNET NEEDED" % [P.game_version(),P.PROTOCOL_VERSION]
    stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    stamp.add_theme_font_size_override("font_size",int(14*ui_unit))
    stamp.add_theme_color_override("font_color",STYLE.DIM)
    column.add_child(stamp)
    _refresh()

# ------------------------------------------------------------------------ helpers

func _label(txt: String, size: float, col: Color, bold: bool = false) -> Label:
    var l := Label.new()
    l.text = txt
    l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    if bold:
        l.add_theme_font_override("font",STYLE.BOLD)
    l.add_theme_font_size_override("font_size",int(size*ui_unit))
    l.add_theme_color_override("font_color",col)
    page.add_child(l)
    return l

func _big(caption: String, action: Callable, primary: bool = false) -> Button:
    var b := Button.new()
    b.text = caption
    b.name = caption
    b.custom_minimum_size.y = 72.0*ui_unit
    b.add_theme_font_size_override("font_size",int(25.0*ui_unit))
    STYLE.style_button(b,ui_unit,primary)
    b.pressed.connect(action)
    page.add_child(b)
    return b

func _small(caption: String, action: Callable, parent: Node = null) -> Button:
    var b := Button.new()
    b.text = caption
    b.name = caption
    b.custom_minimum_size = Vector2(110.0,56.0)*ui_unit
    b.add_theme_font_size_override("font_size",int(20.0*ui_unit))
    STYLE.style_button(b,ui_unit)
    b.pressed.connect(action)
    (parent if parent != null else page).add_child(b)
    return b

func _clear() -> void:
    ping_label = null
    ip_input = null
    for child in page.get_children():
        page.remove_child(child)
        child.queue_free()

static func car_text(id: String) -> String:
    return str(CARS.CARS.get(id,CARS.CARS["red"]).get("short",id)).to_upper()

func _my_name() -> String:
    if DRIVER.has_profile():
        return DRIVER.get_driver_name()
    return "PLAYER 2" if mode == "join" else "PLAYER 1"

## Screenshots / tests only: replaces the detected addresses (a container has no Wi-Fi interface). Empty = real ones.
static var address_override: Array[String] = []

## "WI-FI / HOTSPOT" for the interfaces a phone uses for both, the interface name for anything else.
static func address_lines() -> Array[String]:
    var out: Array[String] = []
    if not address_override.is_empty():
        return address_override.duplicate()
    for a in P.lan_addresses():
        var kind: String = "WI-FI / HOTSPOT" if int(a["rank"]) >= 3 else "NETWORK " + str(a["iface"]).to_upper()
        out.append("%s   (%s)" % [a["ip"],kind])
        if out.size() >= 3:
            break
    return out

func _own_prefix() -> String:
    var addrs: Array[Dictionary] = P.lan_addresses()
    if addrs.is_empty():
        return ""
    var parts: PackedStringArray = str(addrs[0]["ip"]).split(".")
    return "%s.%s.%s." % [parts[0],parts[1],parts[2]]

static func saved_ip() -> String:
    var cfg := ConfigFile.new()
    if cfg.load(CONFIG) == OK:
        return str(cfg.get_value("join","last_ip",""))
    return ""

static func remember_ip(ip: String) -> void:
    if not P.is_private_ipv4(ip):
        return
    var cfg := ConfigFile.new()
    cfg.load(CONFIG)
    cfg.set_value("join","last_ip",ip)
    cfg.save(CONFIG)

## Whatever the keyboard produced: "192,168,43,1 " -> "192.168.43.1".
static func clean_address(raw: String) -> String:
    return raw.strip_edges().replace(",",".").replace(" ","").replace("。",".")

# -------------------------------------------------------------------- session

func _new_session() -> NitroNetSession:
    _drop_session()
    if navigate_enabled and not _race_preload:
        _race_preload = ResourceLoader.load_threaded_request(RACE_PATH) == OK
    session = SESSION.new()
    session.name = "Local multiplayer session"
    get_tree().root.add_child(session)
    session.state_changed.connect(_on_state)
    session.roster_changed.connect(_refresh)
    session.error_raised.connect(_on_error)
    session.start_requested.connect(_on_start)
    return session

func _disconnect_signals() -> void:
    if session == null or not is_instance_valid(session):
        return
    for pair in [[session.state_changed,_on_state],[session.roster_changed,_refresh],[session.error_raised,_on_error],[session.start_requested,_on_start]]:
        if pair[0].is_connected(pair[1]):
            pair[0].disconnect(pair[1])

func _drop_session() -> void:
    if session != null and is_instance_valid(session):
        _disconnect_signals()
        if not starting:
            session.leave()
            session.queue_free()
    session = null

func _on_error(text: String) -> void:
    status.text = text

func _on_state(st: int) -> void:
    if st == NitroNetSession.State.FAILED or st == NitroNetSession.State.LOST or st == NitroNetSession.State.CLOSED:
        call_deferred("_after_end")
    else:
        _refresh()

## The session ended by itself (error, host left): show why, go back to a state the player can act from.
func _after_end() -> void:
    if session == null or not is_instance_valid(session):
        return
    if starting:
        return # The race owns an in-flight disconnect once START has been accepted.
    var st: int = session.state
    if st != NitroNetSession.State.FAILED and st != NitroNetSession.State.LOST and st != NitroNetSession.State.CLOSED:
        return
    var why: String = session.last_error
    var was_join: bool = not session.is_host
    _drop_session()
    mode = "join" if was_join else "menu"
    _refresh()
    status.text = why

func _on_start(track: String) -> void:
    starting = true
    ProjectSettings.set_setting("nitro/selected_track",track)
    status.text = "STARTING..."
    _go("res://scenes/race.tscn")

func _go(scene: String) -> void:
    last_scene = scene
    if not navigate_enabled:
        return
    if get_tree().get_script() == null and scene.ends_with("race.tscn"):
        load("res://scripts/ui/busy_overlay.gd").open(self,"LOADING",false,true)
        await get_tree().process_frame
        await get_tree().process_frame
    if scene == RACE_PATH and _race_preload:
        while ResourceLoader.load_threaded_get_status(scene) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
            await get_tree().process_frame
        if ResourceLoader.load_threaded_get_status(scene) == ResourceLoader.THREAD_LOAD_LOADED:
            var packed: PackedScene = ResourceLoader.load_threaded_get(scene)
            _race_preload = false
            get_tree().change_scene_to_packed(packed)
            return
    get_tree().change_scene_to_file(scene)

# ------------------------------------------------------------------------ actions

func host_game() -> void:
    mode = "host"
    var s: NitroNetSession = _new_session()
    var err: int = s.host(P.DEFAULT_PORT,_my_name(),CARS.selected(),P.TRACKS[0])
    if err != OK:
        var why: String = s.last_error
        _drop_session()
        mode = "menu"
        _refresh()
        status.text = why
        return
    _refresh()

func join_game() -> void:
    mode = "join"
    if ip_text == "":
        ip_text = saved_ip()
        if ip_text == "":
            ip_text = _own_prefix()
    _refresh()

func connect_now() -> void:
    var raw: String = clean_address(ip_input.text if ip_input != null else ip_text)
    ip_text = raw
    var ep: Dictionary = P.parse_endpoint(raw if raw.contains(":") else "%s:%d" % [raw,P.DEFAULT_PORT])
    if ep.is_empty():
        status.text = "THAT IS NOT A LOCAL ADDRESS. TYPE THE ADDRESS SHOWN ON THE HOST'S SCREEN (EXAMPLE 192.168.43.1)"
        return
    var s: NitroNetSession = _new_session()
    var err: int = s.join(str(ep["ip"]),int(ep["port"]),_my_name(),CARS.selected())
    if err != OK:
        var why: String = s.last_error
        _drop_session()
        mode = "join"
        _refresh()
        status.text = why
        return
    remember_ip(str(ep["ip"]))
    _refresh()

func leave_session() -> void:
    _drop_session()
    mode = "menu"
    _refresh()

func ready_toggle() -> void:
    if session != null and is_instance_valid(session):
        session.set_ready(not bool(session.me["ready"]))

func start_game() -> void:
    if session != null and is_instance_valid(session):
        if not session.start_race():
            status.text = "BOTH PLAYERS MUST PRESS READY FIRST"

func cycle_track(step: int) -> void:
    if session == null or not is_instance_valid(session) or not session.is_host:
        return
    var i: int = P.TRACKS.find(session.track_path)
    session.choose_track(P.TRACKS[(i+step+P.TRACKS.size())%P.TRACKS.size()])

func back_to_menu() -> void:
    _drop_session()
    _go("res://scenes/boot.tscn")

# ------------------------------------------------------------------------- pages

func _refresh() -> void:
    if page == null:
        return
    if ip_input != null:
        ip_text = ip_input.text
    _clear()
    status.text = ""
    var st: int = session.state if (session != null and is_instance_valid(session)) else NitroNetSession.State.IDLE
    if session != null and is_instance_valid(session) and (st == NitroNetSession.State.STARTING or st == NitroNetSession.State.COUNTDOWN or st == NitroNetSession.State.RACING):
        _label("LOCAL MULTIPLAYER",30,STYLE.WHITE,true)
        _label("STARTING THE RACE...\nLOADING THE TRACK",24,STYLE.GOLD_LIGHT,true)
        return
    if session == null or not is_instance_valid(session):
        if mode == "join":
            _join_page()
        elif mode == "howto":
            _howto_page()
        else:
            mode = "menu"
            _menu_page()
        return
    if st == NitroNetSession.State.HOSTING:
        _host_waiting_page()
    elif st == NitroNetSession.State.CONNECTING:
        _connecting_page()
    elif st == NitroNetSession.State.LOBBY:
        _lobby_page()
    else:
        _menu_page()

func _title(txt: String) -> void:
    _label(txt,32,STYLE.WHITE,true)

func _menu_page() -> void:
    _title("LOCAL MULTIPLAYER")
    _label("2 PLAYERS  •  NO INTERNET, NO ACCOUNT, NO MOBILE DATA",17,STYLE.MUTED)
    _label("NO WI-FI? NO PROBLEM.\nONE PHONE'S HOTSPOT IS ENOUGH.",22,STYLE.GOLD_LIGHT,true).name = "Hotspot hint"
    _label("YOU DRIVE:  %s\nPLAYER:  %s" % [car_text(CARS.selected()),_my_name()],18,STYLE.WHITE)
    _big("HOST GAME",host_game,true)
    _big("JOIN GAME",join_game)
    _big("NO WI-FI? HOTSPOT HOW-TO",show_howto)
    _big("BACK",back_to_menu)
    _label("CHANGE YOUR CAR IN THE GARAGE, YOUR NAME IN THE PLAYER CARD.\nSCORES OF A MULTIPLAYER DRIVE ARE NOT SAVED.",14,STYLE.DIM)

## Step by step for two phones without any router: one phone's hotspot is the network.
func _howto_page() -> void:
    _title("NO WI-FI? USE A HOTSPOT")
    _label("ONE PHONE MAKES THE NETWORK, THE OTHER JOINS IT.\nNO ROUTER, NO INTERNET. MOBILE DATA CAN BE OFF.",17,STYLE.MUTED)
    _label("PHONE A  =  HOST",22,STYLE.GOLD_LIGHT,true)
    _label("1  PHONE SETTINGS > HOTSPOT / TETHERING > TURN ON THE WI-FI HOTSPOT\n2  IN THE GAME: LOCAL MULTIPLAYER > HOST GAME\n3  IT SHOWS AN ADDRESS (OFTEN 192.168.43.1)",18,STYLE.WHITE).name = "Host steps"
    _label("PHONE B  =  GUEST",22,STYLE.GOLD_LIGHT,true)
    _label("4  WI-FI SETTINGS > JOIN PHONE A'S HOTSPOT (IF ANDROID SAYS \"NO INTERNET\": KEEP THE CONNECTION)\n5  IN THE GAME: LOCAL MULTIPLAYER > JOIN GAME > TYPE THE ADDRESS FROM PHONE A > CONNECT",18,STYLE.WHITE).name = "Guest steps"
    _label("AT HOME YOU CAN USE THE SAME ROUTER WI-FI INSTEAD: BOTH PHONES JOIN IT. INTERNET IS NOT NEEDED.",14,STYLE.DIM)
    _big("BACK",leave_session)

func show_howto() -> void:
    mode = "howto"
    _refresh()

func _host_waiting_page() -> void:
    _title("HOSTING")
    var lines: Array[String] = address_lines()
    if lines.is_empty():
        _label("THIS PHONE IS NOT ON ANY LOCAL NETWORK YET.\nNO WI-FI? TURN ON THIS PHONE'S HOTSPOT (SETTINGS > HOTSPOT / TETHERING), THEN PRESS LEAVE AND HOST AGAIN. WITH A ROUTER: JOIN ITS WI-FI FIRST.\nSTILL NOTHING? READ THIS PHONE'S ADDRESS IN THE HOTSPOT SETTINGS (OFTEN 192.168.43.1) AND TYPE IT ON THE OTHER PHONE.",18,Color(1.0,0.78,0.4)).name = "No address"
    else:
        _label("THE OTHER PHONE TYPES THIS ADDRESS:",17,STYLE.MUTED)
        for l in lines:
            _label(l,30 if l == lines[0] else 20,STYLE.GOLD_LIGHT,true).name = "Address"
        _label("PORT %d  •  JOIN GAME > ADDRESS > CONNECT" % P.DEFAULT_PORT,15,STYLE.DIM)
    _label("WAITING FOR THE OTHER PLAYER...",22,STYLE.WHITE,true)
    _track_row()
    _big("LEAVE",leave_session)
    if session.last_error != "":
        status.text = session.last_error

func _join_page() -> void:
    _title("JOIN GAME")
    var prefix: String = _own_prefix()
    _label(("THIS PHONE: %s*  •  THE HOST SHOWS ITS ADDRESS ON ITS SCREEN" % prefix) if prefix != "" else "THIS PHONE IS NOT ON A WI-FI YET.\nNO ROUTER? JOIN THE HOST PHONE'S HOTSPOT IN THE WI-FI SETTINGS FIRST (MOBILE DATA CAN BE OFF).",17,Color(1.0,0.78,0.4))
    ip_input = LineEdit.new()
    ip_input.name = "IP input"
    ip_input.text = ip_text
    ip_input.placeholder_text = "192.168.43.1"
    ip_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_URL
    ip_input.custom_minimum_size.y = 72.0*ui_unit
    ip_input.add_theme_font_size_override("font_size",int(30.0*ui_unit))
    ip_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
    ip_input.max_length = 21
    _style_input(ip_input)
    ip_input.text_submitted.connect(func(_t: String): connect_now())
    page.add_child(ip_input)
    _big("CONNECT",connect_now,true)
    _big("BACK",leave_session)
    _label("NO INTERNET NEEDED. IF IT FAILS: SAME WI-FI OR THE HOST'S HOTSPOT? HOST ALREADY PRESSED HOST GAME?",14,STYLE.DIM)

func _style_input(le: LineEdit) -> void:
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color(0.07,0.06,0.11)
    normal.border_color = STYLE.PINK_SOFT
    normal.set_border_width_all(maxi(2,int(2.0*ui_unit)))
    normal.set_corner_radius_all(int(12.0*ui_unit))
    normal.content_margin_left = 14.0*ui_unit
    normal.content_margin_right = 14.0*ui_unit
    le.add_theme_stylebox_override("normal",normal)
    var focus: StyleBoxFlat = normal.duplicate()
    focus.border_color = STYLE.PINK
    le.add_theme_stylebox_override("focus",focus)
    le.add_theme_color_override("font_color",STYLE.WHITE)
    le.add_theme_color_override("font_placeholder_color",STYLE.DIM)
    le.add_theme_color_override("caret_color",STYLE.PINK)
    le.add_theme_font_override("font",STYLE.BOLD)

func _connecting_page() -> void:
    _title("CONNECTING")
    _label("TO %s ..." % session.host_address,24,STYLE.GOLD_LIGHT,true)
    _label("IF THIS TAKES LONG: ON THE SAME WI-FI OR THE HOST'S HOTSPOT? HOST ALREADY WAITING?",16,STYLE.MUTED)
    _big("CANCEL",leave_session)

func _lobby_page() -> void:
    _title("READY ROOM")
    var other_name: String = str(session.other.get("name","PLAYER"))
    _player_card("YOU  •  %s" % ("HOST" if session.is_host else "GUEST"),str(session.me["name"]),str(session.me["car"]),bool(session.me["ready"]))
    _player_card("OTHER PLAYER",other_name,str(session.other.get("car","red")),bool(session.other.get("ready",false)))
    _track_row()
    var fp_ok: bool = bool(session.other.get("fp_ok",false)) if session.is_host else true
    if session.is_host and not fp_ok:
        _label("THE OTHER PHONE HAS NOT CONFIRMED THIS TRACK YET",15,Color(1.0,0.78,0.4))
    var ready_caption: String = "NOT READY" if bool(session.me["ready"]) else "READY"
    _big(ready_caption,ready_toggle,not bool(session.me["ready"])).name = "READY"
    if session.is_host:
        var start: Button = _big("START",start_game,true)
        start.disabled = not session.can_start()
        if start.disabled:
            _label("START IS ENABLED WHEN BOTH PLAYERS ARE READY",14,STYLE.DIM)
    else:
        _label("WAITING FOR THE HOST TO START...",18,STYLE.MUTED)
    _big("LEAVE",leave_session)
    ping_label = _label("",14,STYLE.DIM)

func _player_card(role: String, who: String, car: String, ready: bool) -> void:
    var panel := PanelContainer.new()
    panel.add_theme_stylebox_override("panel",STYLE.modal_box(ui_unit*0.6))
    var box := VBoxContainer.new()
    panel.add_child(box)
    page.add_child(panel)
    var a := Label.new()
    a.text = role
    a.add_theme_font_size_override("font_size",int(14*ui_unit))
    a.add_theme_color_override("font_color",STYLE.DIM)
    a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(a)
    var b := Label.new()
    b.text = "%s  •  %s" % [who,car_text(car)]
    b.add_theme_font_override("font",STYLE.BOLD)
    b.add_theme_font_size_override("font_size",int(22*ui_unit))
    b.add_theme_color_override("font_color",STYLE.WHITE)
    b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(b)
    var c := Label.new()
    c.text = "READY" if ready else "NOT READY"
    c.add_theme_font_size_override("font_size",int(16*ui_unit))
    c.add_theme_color_override("font_color",Color(0.36,0.95,0.58) if ready else STYLE.DIM)
    c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(c)

## Host: TRACK < name >; the joiner only reads it (the host decides, both must press READY again after a change).
func _track_row() -> void:
    var name_text: String = str(P.TRACK_NAMES.get(session.track_path,"TRACK"))
    if session.is_host:
        var row := HBoxContainer.new()
        row.alignment = BoxContainer.ALIGNMENT_CENTER
        row.add_theme_constant_override("separation",int(10*ui_unit))
        page.add_child(row)
        var prev: Button = _small("<",func(): cycle_track(-1),row)
        prev.name = "TRACK PREVIOUS"
        var l := Label.new()
        l.text = "TRACK: "+name_text
        l.name = "Track name"
        l.add_theme_font_override("font",STYLE.BOLD)
        l.add_theme_font_size_override("font_size",int(22*ui_unit))
        l.add_theme_color_override("font_color",STYLE.WHITE)
        l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        row.add_child(l)
        var nxt: Button = _small(">",func(): cycle_track(1),row)
        nxt.name = "TRACK NEXT"
    else:
        var l2 := _label("TRACK: "+name_text,22,STYLE.WHITE,true)
        l2.name = "Track name"

func _process(delta: float) -> void:
    _ping_clock += delta
    if _ping_clock >= 0.5:
        _ping_clock = 0.0
        if ping_label != null and session != null and is_instance_valid(session) and session.state == NitroNetSession.State.LOBBY:
            ping_label.text = "CONNECTION: %d ms" % int(round(session.rtt_ms)) if session.rtt_ms > 0.0 else "CONNECTION OK"

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_GO_BACK_REQUEST:
        if mode == "menu" and (session == null or not is_instance_valid(session)):
            back_to_menu()
        else:
            leave_session()

func _exit_tree() -> void:
    if _race_preload:
        ResourceLoader.load_threaded_get(RACE_PATH) # Release the unused request on lobby cancellation.
    # leaving this screen by any other way than START ends the session (nothing keeps listening on the port)
    if not starting and session != null and is_instance_valid(session):
        _disconnect_signals()
        session.leave()
        session.queue_free()
    session = null
