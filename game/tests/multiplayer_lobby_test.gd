extends SceneTree
## Offline local multiplayer (issue #31): the LOCAL MULTIPLAYER lobby screen, driven through its buttons.
## Two lobby screens in one process (a host and a guest) talk through a real ENet loopback connection.
## NOT proven here: touch typing of the address on a real phone keyboard, Wi-Fi / hotspot reachability (owner QA).
const P = preload("res://scripts/net/net_protocol.gd")
const SESSION = preload("res://scripts/net/net_session.gd")
const LOBBY = preload("res://scenes/multiplayer_lobby.tscn")
const BOOT = preload("res://scenes/boot.tscn")
const RACE = preload("res://scenes/race.tscn")
const FUJI = "res://tracks/fuji_speedway_short.json"
const CARS = preload("res://scripts/vehicles/car_catalog.gd")

var _track_before: Variant = null

func _initialize() -> void:
    _track_before = ProjectSettings.get_setting("nitro/selected_track","")
    call_deferred("_run")

func _fail(message: String) -> void:
    ProjectSettings.set_setting("nitro/selected_track",_track_before)
    printerr("FAIL: "+message)
    quit(1)

func _until(cond: Callable, seconds: float = 6.0) -> bool:
    var t0: int = Time.get_ticks_msec()
    while Time.get_ticks_msec()-t0 < int(seconds*1000.0):
        if cond.call():
            return true
        await process_frame
    return cond.call()

func _button(lobby: Control, caption: String) -> Button:
    var b: Node = lobby.find_child(caption,true,false)
    return b as Button

func _press(lobby: Control, caption: String) -> bool:
    var b: Button = _button(lobby,caption)
    if b == null or b.disabled:
        return false
    b.pressed.emit()
    return true

func _make() -> Control:
    var l: Control = LOBBY.instantiate()
    l.set("navigate_enabled",false)
    root.add_child(l)
    return l

func _run() -> void:
    # the main menu has the entry and it opens the lobby scene
    var menu: Control = BOOT.instantiate()
    menu.set("navigate_enabled",false)
    root.add_child(menu)
    await process_frame
    var entry: Button = menu.find_child("LOCAL MULTIPLAYER",true,false) as Button
    if entry == null:
        _fail("the main menu needs a LOCAL MULTIPLAYER entry")
        return
    entry.pressed.emit()
    if str(menu.get("last_scene")) != "res://scenes/multiplayer_lobby.tscn":
        _fail("the menu entry must open the lobby scene (got %s)" % str(menu.get("last_scene")))
        return
    menu.queue_free()
    await process_frame
    # menu page
    var host_ui: Control = _make()
    await process_frame
    for caption in ["HOST GAME","JOIN GAME","NO WI-FI? HOTSPOT HOW-TO","BACK"]:
        if _button(host_ui,caption) == null:
            _fail("lobby menu is missing "+caption)
            return
    if SESSION.current != null:
        _fail("opening the lobby must not start any networking")
        return
    # owner report (v0.1.44): "it said we need Wi-Fi, we did not know a hotspot works" -> the menu says it in plain words,
    # and one button explains both phones' steps
    var hint: Label = host_ui.find_child("Hotspot hint",true,false) as Label
    if hint == null or not hint.text.contains("NO WI-FI") or not hint.text.contains("HOTSPOT"):
        _fail("the lobby menu must say in a visible line that a hotspot is enough (no Wi-Fi needed)")
        return
    _press(host_ui,"NO WI-FI? HOTSPOT HOW-TO")
    await process_frame
    var host_steps: Label = host_ui.find_child("Host steps",true,false) as Label
    var guest_steps: Label = host_ui.find_child("Guest steps",true,false) as Label
    if host_steps == null or guest_steps == null or not host_steps.text.contains("HOTSPOT") or not host_steps.text.contains("HOST GAME") \
            or not guest_steps.text.contains("JOIN") or not guest_steps.text.contains("CONNECT"):
        _fail("the hotspot how-to must give the steps for BOTH phones (hotspot on > HOST GAME / join the hotspot > JOIN GAME > CONNECT)")
        return
    if SESSION.current != null:
        _fail("reading the how-to must not start any networking")
        return
    _press(host_ui,"BACK")
    await process_frame
    if _button(host_ui,"HOST GAME") == null or host_ui.find_child("Host steps",true,false) != null:
        _fail("BACK on the how-to page must return to the lobby menu (not leave the lobby)")
        return
    # a malformed address is refused before any socket is opened
    var guest_ui: Control = _make()
    await process_frame
    _press(guest_ui,"JOIN GAME")
    await process_frame
    var ip: LineEdit = guest_ui.find_child("IP input",true,false) as LineEdit
    if ip == null or _button(guest_ui,"CONNECT") == null:
        _fail("JOIN GAME must show an address field and CONNECT")
        return
    ip.text = "hello"
    _press(guest_ui,"CONNECT")
    if guest_ui.get("session") != null or String(guest_ui.status.text) == "":
        _fail("a malformed address must be refused with a message and without a session")
        return
    ip.text = "8.8.8.8"
    _press(guest_ui,"CONNECT")
    if guest_ui.get("session") != null:
        _fail("a public Internet address must be refused (local network only)")
        return
    # HOST GAME
    _press(host_ui,"HOST GAME")
    await process_frame
    var hs: NitroNetSession = host_ui.get("session")
    if hs == null or hs.state != NitroNetSession.State.HOSTING or _button(host_ui,"LEAVE") == null:
        _fail("HOST GAME must open a room and offer LEAVE")
        return
    if hs.track_path != P.TRACKS[0]:
        _fail("the first hosted track must be the oval test track")
        return
    # JOIN (loopback stands for the Wi-Fi address)
    ip = guest_ui.find_child("IP input",true,false) as LineEdit
    ip.text = "127.0.0.1"
    _press(guest_ui,"CONNECT")
    var gs: NitroNetSession = guest_ui.get("session")
    if gs == null:
        _fail("CONNECT must start a connection: "+String(guest_ui.status.text))
        return
    var ok: bool = await _until(func(): return hs.state == NitroNetSession.State.LOBBY and gs.state == NitroNetSession.State.LOBBY and not hs.other.is_empty() and not gs.other.is_empty())
    if not ok:
        _fail("host and guest did not reach the ready room")
        return
    await process_frame
    await process_frame
    for caption in ["READY","LEAVE"]:
        if _button(host_ui,caption) == null or _button(guest_ui,caption) == null:
            _fail("the ready room needs "+caption)
            return
    var start: Button = _button(host_ui,"START")
    if start == null or not start.disabled:
        _fail("START must be disabled until both are READY")
        return
    if _button(guest_ui,"START") != null:
        _fail("only the host may start")
        return
    # the host changes the track: the guest sees it, READY resets
    var before_track: String = hs.track_path
    _press(host_ui,"TRACK NEXT")
    ok = await _until(func(): return gs.track_path == hs.track_path and hs.track_path != before_track)
    if not ok:
        _fail("the track choice did not reach the guest")
        return
    _press(host_ui,"TRACK PREVIOUS")
    ok = await _until(func(): return gs.track_path == before_track and hs.track_path == before_track)
    if not ok:
        _fail("the track choice (back) did not reach the guest")
        return
    # Visit every circuit in the real lobby before finishing the test on Fuji.
    for expected in P.TRACKS.slice(1):
        await process_frame
        if not _press(host_ui,"TRACK NEXT") or not await _until(func(): return gs.track_path == expected):
            _fail("the host track choice did not reach the guest: "+expected)
            return
    if hs.track_path != FUJI or gs.track_path != FUJI or hs.track_fp != gs.track_fp:
        _fail("both peers must agree on the built-in Fuji file and fingerprint")
        return
    await process_frame
    _press(host_ui,"READY")
    _press(guest_ui,"READY")
    ok = await _until(func(): return hs.can_start())
    if not ok:
        _fail("READY of both players must enable START")
        return
    await process_frame
    await process_frame
    start = _button(host_ui,"START")
    if start == null or start.disabled:
        _fail("the START button did not enable")
        return
    var stamps: Array = []
    host_ui.get("session").start_requested.connect(func(t: String): stamps.append(t))
    _press(host_ui,"START")
    ok = await _until(func(): return String(guest_ui.get("last_scene")).ends_with("race.tscn") and String(host_ui.get("last_scene")).ends_with("race.tscn"))
    if not ok:
        _fail("START must send both phones to the race scene (host %s, guest %s)" % [str(host_ui.get("last_scene")),str(guest_ui.get("last_scene"))])
        return
    if str(ProjectSettings.get_setting("nitro/selected_track","")) != FUJI:
        _fail("the race must load the agreed track")
        return
    # the session stays alive for the race scene when the lobby goes away
    host_ui.queue_free()
    guest_ui.queue_free()
    await process_frame
    await process_frame
    if not is_instance_valid(hs) or hs.state == NitroNetSession.State.CLOSED:
        _fail("leaving the lobby for the race must not close the session")
        return
    SESSION.current = hs
    var race = RACE.instantiate()
    root.add_child(race)
    if race.net == null or race.track.terrain == null or race.track.track_data_path != FUJI \
            or not str(race.track.event_mode).is_empty() or not race.track.event_layout.zones.is_empty():
        _fail("Fuji must load with the same terrain and ordinary drift scoring in LAN")
        return
    race.free()
    hs.leave()
    gs.leave()
    hs.queue_free()
    gs.queue_free()
    await process_frame
    # LEAVE returns to a clean menu; the room is closed (nothing keeps listening)
    var a: Control = _make()
    await process_frame
    _press(a,"HOST GAME")
    await process_frame
    var s2: NitroNetSession = a.get("session")
    if s2 == null:
        _fail("HOST GAME (second time)")
        return
    _press(a,"LEAVE")
    await process_frame
    if a.get("session") != null or is_instance_valid(s2) and s2.state != NitroNetSession.State.CLOSED and not s2.is_queued_for_deletion():
        _fail("LEAVE must close the room")
        return
    if _button(a,"HOST GAME") == null:
        _fail("LEAVE must return to the lobby menu")
        return
    # a lost host is explained and the guest can retry
    var h2: Control = _make()
    var g2: Control = _make()
    await process_frame
    _press(h2,"HOST GAME")
    await process_frame
    _press(g2,"JOIN GAME")
    await process_frame
    (g2.find_child("IP input",true,false) as LineEdit).text = "127.0.0.1"
    _press(g2,"CONNECT")
    var hs2: NitroNetSession = h2.get("session")
    var gs2: NitroNetSession = g2.get("session")
    ok = await _until(func(): return hs2.state == NitroNetSession.State.LOBBY and gs2.state == NitroNetSession.State.LOBBY)
    if not ok:
        _fail("second pair did not connect")
        return
    h2.queue_free()
    ok = await _until(func(): return g2.get("session") == null and _button(g2,"CONNECT") != null)
    if not ok or String(g2.status.text) == "":
        _fail("a guest whose host went away must see why and get the address field back (status '%s')" % String(g2.status.text))
        return
    g2.queue_free()
    a.queue_free()
    await process_frame
    ProjectSettings.set_setting("nitro/selected_track",_track_before)
    print("PASS: LOCAL MULTIPLAYER lobby - main menu entry, HOST GAME / JOIN GAME / READY / START / LEAVE through real loopback sessions, malformed and public addresses refused, START only when both READY, all circuit choices reach the guest, START keeps the session and Fuji loads with terrain and standard LAN scoring, LEAVE closes the room, a lost host is explained")
    print("NOT RUN: typing the address with a phone keyboard, Wi-Fi / hotspot reachability on two Android phones (owner QA)")
    quit(0)
