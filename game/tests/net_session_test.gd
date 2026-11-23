extends SceneTree
## Offline local multiplayer (issue #31): the network layer on the LOOPBACK of one desktop process, two real
## ENet sessions (host + joiner, each with its own SceneMultiplayer). Nothing here needs the Internet.
## What this does NOT prove: Wi-Fi / hotspot behaviour on two Android phones (owner QA).
const P = preload("res://scripts/net/net_protocol.gd")
const SESSION = preload("res://scripts/net/net_session.gd")

func _initialize() -> void:
    call_deferred("_run")

var _created: Array = []

func _fail(message: String) -> void:
    for s in _created:
        if is_instance_valid(s):
            s.leave()
    printerr("FAIL: "+message)
    quit(1)

func _make() -> NitroNetSession:
    var s: NitroNetSession = SESSION.new()
    root.add_child(s)
    _created.append(s)
    return s

func _until(cond: Callable, seconds: float = 6.0) -> bool:
    var t0: int = Time.get_ticks_msec()
    while Time.get_ticks_msec()-t0 < int(seconds*1000.0):
        if cond.call():
            return true
        await process_frame
    return cond.call()

func _run() -> void:
    # ------------------------------------------------------------------ protocol
    var snap: Dictionary = {"flags":5,"seq":65535,"ms":123456789,"x":-120.5,"z":33.25,"heading":-1.5,"vx":12.0,"vz":-3.5,"yaw":0.7,"steer":-0.3,"score":8450}
    var bytes: PackedByteArray = P.pack_snapshot(snap)
    var back: Dictionary = P.unpack_snapshot(bytes)
    if bytes.size() != 40 or back.is_empty() or absf(float(back["x"])+120.5) > 0.001 or int(back["score"]) != 8450 or int(back["seq"]) != 65535 or int(back["flags"]) != 5:
        _fail("snapshot round trip: %s" % str(back))
        return
    var bad: Array = []
    var short := bytes.slice(0,39)
    bad.append(short)
    var nan := bytes.duplicate()
    nan.encode_float(8,NAN)
    bad.append(nan)
    var far := bytes.duplicate()
    far.encode_float(12,1.0e9)
    bad.append(far)
    var fast := bytes.duplicate()
    fast.encode_float(20,900.0)
    bad.append(fast)
    var wrong_kind := bytes.duplicate()
    wrong_kind[0] = 7
    bad.append(wrong_kind)
    var neg_score := bytes.duplicate()
    neg_score.encode_s32(36,-5)
    bad.append(neg_score)
    for b in bad:
        if not P.unpack_snapshot(b).is_empty():
            _fail("a malformed snapshot was accepted")
            return
    if not (P.seq_newer(1,65535) and P.seq_newer(5,3) and not P.seq_newer(3,5) and not P.seq_newer(7,7)):
        _fail("sequence comparison with wrap-around")
        return
    if not P.unpack_control(PackedByteArray([1,2,3])).is_empty() or not P.unpack_control(PackedByteArray([2])).is_empty():
        _fail("garbage control packet accepted")
        return
    var objectish: PackedByteArray = PackedByteArray([P.KIND_CONTROL])
    var leak_probe := Node.new()
    objectish.append_array(var_to_bytes_with_objects(leak_probe))
    leak_probe.free()
    if not P.unpack_control(objectish).is_empty():
        _fail("an object-carrying packet was decoded")
        return
    var big := PackedByteArray([P.KIND_CONTROL])
    big.resize(2000)
    big[0] = P.KIND_CONTROL
    if not P.unpack_control(big).is_empty():
        _fail("an oversized control packet was accepted")
        return
    for m in [{"t":P.Msg.HELLO,"proto":"x","ver":"1","name":"a","car":"red"},{"t":P.Msg.COUNTDOWN,"secs":99.0},{"t":P.Msg.INFO,"name":"a","car":"red","ready":1,"fp":""},{"t":999},{"t":P.Msg.HELLO,"proto":1,"ver":"1","name":"x".repeat(60),"car":"red"}]:
        if P.validate_control(m) == "":
            _fail("an invalid control message passed validation: "+str(m))
            return
    if P.validate_control({"t":P.Msg.HELLO,"proto":1,"ver":"0.1.41","name":"ANNA","car":"red"}) != "":
        _fail("a valid HELLO was refused")
        return
    for ip in ["192.168.43.1","10.0.0.5","172.20.1.9"]:
        if not P.is_private_ipv4(ip):
            _fail("private address not recognised: "+ip)
            return
    for ip in ["127.0.0.1","169.254.1.1","8.8.8.8","172.40.0.1","1.2.3","a.b.c.d","192.168.1.256"]:
        if P.is_private_ipv4(ip):
            _fail("a non-LAN address counted as LAN: "+ip)
            return
    if P.parse_endpoint("192.168.43.1").get("port",0) != P.DEFAULT_PORT or P.parse_endpoint("192.168.43.1:50000").get("port",0) != 50000 \
            or not P.parse_endpoint("192.168.43").is_empty() or not P.parse_endpoint("0.0.0.0").is_empty() or not P.parse_endpoint("1.2.3.4:80").is_empty() \
            or not P.parse_endpoint("hello").is_empty() or not P.parse_endpoint("8.8.8.8").is_empty() or not P.parse_endpoint("169.254.1.1").is_empty() \
            or P.parse_endpoint("127.0.0.1").is_empty() or P.parse_endpoint("172.20.10.1:47821").is_empty():
        _fail("endpoint parsing")
        return
    for a in P.lan_addresses():
        if not P.is_private_ipv4(str(a["ip"])):
            _fail("lan_addresses returned a non-private address")
            return
    for t in P.TRACKS:
        if P.track_fingerprint(t).length() != 64:
            _fail("no fingerprint for the built-in track "+t)
            return
    if P.track_fingerprint("user://nitro_track_x.json") != "" or P.track_fingerprint("res://tracks/nitro_wheelz_park.json") != "":
        _fail("only the whitelisted built-in circuits may be shared")
        return
    # --------------------------------------------------------- host + join + lobby
    var host: NitroNetSession = _make()
    var client: NitroNetSession = _make()
    if host.host(47911,"ANNA","e30","res://tracks/benchmark_oval.json") != OK:
        _fail("host() failed: "+host.last_error)
        return
    if host.state != NitroNetSession.State.HOSTING:
        _fail("the host must wait for a player")
        return
    if client.join("127.0.0.1",47911,"BORYS","blue") != OK:
        _fail("join() failed: "+client.last_error)
        return
    var ok: bool = await _until(func(): return host.state == NitroNetSession.State.LOBBY and client.state == NitroNetSession.State.LOBBY)
    if not ok:
        _fail("host and joiner did not reach the lobby (host %d, joiner %d, %s)" % [host.state,client.state,client.last_error])
        return
    ok = await _until(func(): return str(host.other.get("name","")) == "BORYS" and str(client.other.get("name","")) == "ANNA")
    if not ok or str(host.other["car"]) != "blue" or str(client.other["car"]) != "e30" or client.track_path != host.track_path:
        _fail("roster not exchanged: host sees %s, joiner sees %s" % [str(host.other),str(client.other)])
        return
    if host.local_index != 0 or client.local_index != 1:
        _fail("start slots: host 0, joiner 1")
        return
    if host.can_start():
        _fail("START must not be possible before both are READY")
        return
    host.set_ready(true)
    client.set_ready(true)
    ok = await _until(func(): return host.can_start() and bool(client.other.get("ready",false)))
    if not ok:
        _fail("READY did not reach the host (host other=%s)" % str(host.other))
        return
    # ------------------------------------------------------------- start + countdown
    var started: Array = []
    host.start_requested.connect(func(t: String): started.append("host"))
    client.start_requested.connect(func(t: String): started.append("client"))
    if not host.start_race():
        _fail("START refused although both are READY")
        return
    ok = await _until(func(): return started.size() == 2 and client.state == NitroNetSession.State.STARTING)
    if not ok:
        _fail("the joiner did not get START: "+str(started))
        return
    host.report_loaded()
    if host.state != NitroNetSession.State.STARTING:
        _fail("the countdown must wait until the joiner reports LOADED")
        return
    client.report_loaded()
    ok = await _until(func(): return host.state == NitroNetSession.State.COUNTDOWN and client.state == NitroNetSession.State.COUNTDOWN)
    if not ok:
        _fail("both phones must enter the countdown after both are loaded (host %d, joiner %d)" % [host.state,client.state])
        return
    var host_left: float = host.countdown_remaining()
    var client_left: float = client.countdown_remaining()
    if host_left > 3.0 or host_left < 2.0 or client_left > 3.05 or client_left < 1.9:
        _fail("countdown seconds: host %.2f, joiner %.2f" % [host_left,client_left])
        return
    ok = await _until(func(): return host.state == NitroNetSession.State.RACING and client.state == NitroNetSession.State.RACING,6.0)
    if not ok:
        _fail("GO never happened on both phones")
        return
    var go_gap_ms: float = absf(float(host.go_local_usec-client.go_local_usec))/1000.0
    if go_gap_ms > 120.0:
        _fail("host and joiner GO are %.0f ms apart on the loopback" % go_gap_ms)
        return
    # -------------------------------------------------------------------- snapshots
    var got: Array = []
    host.remote_snapshot.connect(func(s: Dictionary): got.append(s))
    for k in range(30):
        client.send_snapshot({"flags":1,"ms":SESSION.now_ms(),"x":float(k),"z":2.0,"heading":0.5,"vx":10.0,"vz":0.0,"yaw":0.1,"steer":0.2,"score":k*10})
        await process_frame
    ok = await _until(func(): return got.size() >= 25)
    if not ok:
        _fail("snapshots did not arrive (%d of 30)" % got.size())
        return
    for i in range(1,got.size()):
        if not P.seq_newer(int(got[i]["seq"]),int(got[i-1]["seq"])):
            _fail("snapshots arrived out of order")
            return
    var before: int = host.dropped_packets
    client.api.send_bytes(PackedByteArray([2,1,2,3]),1,MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED,0)
    client.api.send_bytes(PackedByteArray([9,9,9]),1,MultiplayerPeer.TRANSFER_MODE_RELIABLE,0)
    var evil: PackedByteArray = P.pack_snapshot({"x":0.0,"z":0.0})
    evil.encode_float(8,INF)
    client.api.send_bytes(evil,1,MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED,0)
    ok = await _until(func(): return host.dropped_packets >= before+3)
    if not ok:
        _fail("malformed packets were not dropped and counted (%d)" % (host.dropped_packets-before))
        return
    var count_before: int = got.size()
    var dup: PackedByteArray = P.pack_snapshot({"seq":3,"x":1.0,"z":1.0})
    client.api.send_bytes(dup,1,MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED,0)
    for i in range(20):
        await process_frame
    if got.size() != count_before or host.stale_snapshots < 1:
        _fail("a stale (old sequence) snapshot was accepted")
        return
    # ------------------------------------------------------------------- disconnects
    var lost: Array = []
    host.peer_lost.connect(func(r: String): lost.append(r))
    client.leave()
    ok = await _until(func(): return not lost.is_empty())
    if not ok or host.state != NitroNetSession.State.LOST or not host.other.is_empty():
        _fail("the host did not notice that the joiner left (state %d)" % host.state)
        return
    if client.state != NitroNetSession.State.CLOSED or client.api != null or client.peer != null:
        _fail("leave() must close the socket and forget the API")
        return
    host.leave()
    if host.state != NitroNetSession.State.CLOSED or host.api != null:
        _fail("the host did not close")
        return
    # ---------------------------------------------------- waiting room survives a leave
    var h2: NitroNetSession = _make()
    var c2: NitroNetSession = _make()
    h2.host(47912,"HOST","red","res://tracks/benchmark_sweepers.json")
    c2.join("127.0.0.1",47912,"GUEST","red")
    ok = await _until(func(): return h2.state == NitroNetSession.State.LOBBY and c2.state == NitroNetSession.State.LOBBY)
    if not ok:
        _fail("second session did not connect")
        return
    var c2_lost: Array = []
    c2.peer_lost.connect(func(r: String): c2_lost.append(r))
    var h2_lost: Array = []
    h2.peer_lost.connect(func(r: String): h2_lost.append(r))
    c2.leave()
    ok = await _until(func(): return not h2_lost.is_empty() and h2.state == NitroNetSession.State.HOSTING)
    if not ok:
        _fail("a host in the lobby must keep the room open after the joiner left (state %d)" % h2.state)
        return
    var c3: NitroNetSession = _make()
    c3.join("127.0.0.1",47912,"AGAIN","red")
    ok = await _until(func(): return h2.state == NitroNetSession.State.LOBBY and c3.state == NitroNetSession.State.LOBBY)
    if not ok:
        _fail("rejoin to the same host failed")
        return
    # a third phone is refused with a readable message
    var c4: NitroNetSession = _make()
    var c4_err: Array = []
    c4.error_raised.connect(func(t: String): c4_err.append(t))
    c4.join("127.0.0.1",47912,"THIRD","red")
    ok = await _until(func(): return c4.state == NitroNetSession.State.FAILED)
    if not ok or c4_err.is_empty() or not str(c4_err[0]).contains("FULL"):
        _fail("a third player must be refused with 'FULL' (state %d, %s)" % [c4.state,str(c4_err)])
        return
    if h2.state != NitroNetSession.State.LOBBY or str(h2.other.get("name","")) != "AGAIN":
        _fail("the refused third player disturbed the running session")
        return
    # silence = lost (timeout path), the host goes to LOST in a race
    c3._last_rx_msec = SESSION.now_ms()-(SESSION.SILENCE_TIMEOUT_MS+500)
    h2._last_rx_msec = SESSION.now_ms()-(SESSION.SILENCE_TIMEOUT_MS+500)
    ok = await _until(func(): return c3.state == NitroNetSession.State.LOST and h2.state == NitroNetSession.State.HOSTING)
    if not ok:
        _fail("silence did not end the connection (joiner %d, host %d)" % [c3.state,h2.state])
        return
    h2.leave()
    c3.leave()
    # ---------------------------------------------------- mismatch + errors
    var h3: NitroNetSession = _make()
    var c5: NitroNetSession = _make()
    h3.host(47913,"HOST","red","res://tracks/benchmark_oval.json")
    c5.version_override = "0.0.1"
    var c5_err: Array = []
    c5.error_raised.connect(func(t: String): c5_err.append(t))
    c5.join("127.0.0.1",47913,"OLD","red")
    ok = await _until(func(): return c5.state == NitroNetSession.State.FAILED)
    if not ok or not str(c5_err[0]).contains("VERSION"):
        _fail("a different game version must be refused clearly (%s)" % str(c5_err))
        return
    if h3.state != NitroNetSession.State.HOSTING:
        _fail("the host must keep waiting after refusing a wrong version")
        return
    h3.fingerprint_override = "0".repeat(64)
    var c6: NitroNetSession = _make()
    var c6_err: Array = []
    c6.error_raised.connect(func(t: String): c6_err.append(t))
    c6.join("127.0.0.1",47913,"MISMATCH","red")
    ok = await _until(func(): return c6.state == NitroNetSession.State.FAILED)
    if not ok or not str(c6_err[0]).contains("TRACK MISMATCH"):
        _fail("a different track layout must be refused clearly (%s)" % str(c6_err))
        return
    h3.leave()
    var nobody: NitroNetSession = _make()
    var nobody_err: Array = []
    nobody.error_raised.connect(func(t: String): nobody_err.append(t))
    nobody.join("127.0.0.1",47919,"LONELY","red")
    ok = await _until(func(): return nobody.state == NitroNetSession.State.FAILED,12.0)
    if not ok or nobody_err.is_empty():
        _fail("joining an address nobody hosts must fail with a message, not hang")
        return
    var bad_ip: NitroNetSession = _make()
    if bad_ip.join("not.an.ip",47921,"X","red") == OK or bad_ip.last_error == "":
        _fail("a malformed IP must be refused with a message")
        return
    for s in _created:
        if is_instance_valid(s):
            s.leave()
    if SESSION.current != null:
        _fail("no session may stay registered after leaving")
        return
    print("PASS: local multiplayer network layer on the loopback - protocol (40-byte snapshots, malformed / NaN / huge / stale / oversized / object packets dropped), host + join + roster + READY + START + LOADED + synchronized countdown (host and joiner GO %.1f ms apart on the loopback, NOT a Wi-Fi measurement), snapshot stream in order, leave / lost host / lost joiner / silence timeout, the room stays open after a leave, a third player refused (FULL), wrong version + wrong track layout + unreachable host + malformed IP all end in readable messages" % go_gap_ms)
    print("NOT RUN: two real Android phones on Wi-Fi or a hotspot without Internet (owner QA)")
    quit(0)
