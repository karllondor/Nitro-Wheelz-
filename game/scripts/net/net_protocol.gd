extends RefCounted
class_name NitroNetProtocol
## Offline local multiplayer (issue #31): wire protocol of the two-phone prototype.
##
## Transport = ENet (UDP) between two phones on the same Wi-Fi / hotspot, no Internet, no server, no account.
## Two packet kinds, the first byte says which:
##   KIND_CONTROL  (1) + var_to_bytes(Dictionary): lobby / handshake / countdown, RELIABLE, rare, decoded with
##                 bytes_to_var (NO object decoding) and validated field by field (validate_control).
##   KIND_SNAPSHOT (2) + 39 bytes of fixed binary layout: the sender's own car, UNRELIABLE ORDERED, 20 Hz.
## Remote positions are CLIENT-REPORTED: they are for the other player's eyes only. They are never trusted for
## ranking, records or stars (prototype, collisionless).
const PROTOCOL_VERSION: int = 1
const DEFAULT_PORT: int = 47821
const MAX_PLAYERS: int = 2
const SNAPSHOT_HZ: float = 20.0
const KIND_CONTROL: int = 1
const KIND_SNAPSHOT: int = 2
const SNAPSHOT_SIZE: int = 40
const MAX_CONTROL_BYTES: int = 1024
const MAX_NAME_CHARS: int = 16

enum Msg { HELLO = 1, WELCOME = 2, REJECT = 3, INFO = 4, START = 5, LOADED = 6, COUNTDOWN = 7, LEAVE = 8, PING = 10, PONG = 11, TRACK = 12 }

## Built-in circuits both phones carry in the same APK. The host's choice travels as one of these paths
## (never an arbitrary path, never a user:// file) plus the SHA-256 of the file, so a different build or an
## edited copy is refused with a clear message.
const TRACKS: Array[String] = [
    "res://tracks/benchmark_oval.json","res://tracks/benchmark_sweepers.json",
    "res://tracks/shin_kawa_v2.json","res://tracks/shin_kawa_full_circuit.json"]
const TRACK_NAMES: Dictionary = {
    "res://tracks/benchmark_oval.json":"OVAL","res://tracks/benchmark_sweepers.json":"SWEEPERS",
    "res://tracks/shin_kawa_v2.json":"SHIN-KAWA","res://tracks/shin_kawa_full_circuit.json":"SHIN-KAWA • FULL CIRCUIT"}

static func game_version() -> String:
    return str(ProjectSettings.get_setting("application/config/version","unknown"))

static func track_allowed(path: String) -> bool:
    return TRACKS.has(path)

## SHA-256 of a whitelisted track file ("" for anything else): the layout identity both phones must share.
static func track_fingerprint(path: String) -> String:
    if not track_allowed(path) or not FileAccess.file_exists(path):
        return ""
    return FileAccess.get_sha256(path)

static func clean_name(raw: String) -> String:
    var out: String = ""
    for ch in raw.strip_edges():
        if out.length() >= MAX_NAME_CHARS:
            break
        if ch.unicode_at(0) >= 32 and ch.unicode_at(0) != 127:
            out += ch
    return out if out != "" else "PLAYER"

# ------------------------------------------------------------------ control packets

static func pack_control(msg: Dictionary) -> PackedByteArray:
    var body: PackedByteArray = var_to_bytes(msg)
    var out := PackedByteArray([KIND_CONTROL])
    out.append_array(body)
    return out

## Dictionary of a control packet, or {} when it is not one / too big / not a plain Dictionary with an int "t".
static func unpack_control(bytes: PackedByteArray) -> Dictionary:
    if bytes.size() < 9 or bytes.size() > MAX_CONTROL_BYTES or bytes[0] != KIND_CONTROL:
        return {}
    # The Variant header must be exactly "Dictionary" (type 27, no flags): garbage, objects and every
    # other type are refused BEFORE the decoder runs (it would only log errors for them).
    if bytes.decode_u32(1) != TYPE_DICTIONARY:
        return {}
    var v: Variant = bytes_to_var(bytes.slice(1))          # never bytes_to_var_with_objects
    if not (v is Dictionary) or not ((v as Dictionary).get("t",null) is int):
        return {}
    return v

static func _is_str(d: Dictionary, key: String, max_len: int) -> bool:
    return d.get(key,null) is String and (d[key] as String).length() <= max_len

## "" when the message is well-formed, else the reason (the packet is dropped and counted, never executed).
static func validate_control(m: Dictionary) -> String:
    match int(m["t"]):
        Msg.HELLO:
            if not (m.get("proto",null) is int) or not _is_str(m,"ver",24) or not _is_str(m,"name",MAX_NAME_CHARS+4) or not _is_str(m,"car",16):
                return "HELLO fields"
        Msg.WELCOME:
            if not _is_str(m,"track",96) or not _is_str(m,"fp",80) or not _is_str(m,"name",MAX_NAME_CHARS+4) or not _is_str(m,"car",16) or not (m.get("idx",null) is int):
                return "WELCOME fields"
        Msg.REJECT:
            if not _is_str(m,"code",24) or not _is_str(m,"text",160):
                return "REJECT fields"
        Msg.INFO:
            if not _is_str(m,"name",MAX_NAME_CHARS+4) or not _is_str(m,"car",16) or not (m.get("ready",null) is bool) or not _is_str(m,"fp",80):
                return "INFO fields"
        Msg.TRACK, Msg.START:
            if not _is_str(m,"track",96) or not _is_str(m,"fp",80):
                return "TRACK fields"
        Msg.COUNTDOWN:
            if not (m.get("secs",null) is float) or float(m["secs"]) < 0.5 or float(m["secs"]) > 10.0:
                return "COUNTDOWN seconds"
        Msg.PING:
            if not (m.get("c",null) is int):
                return "PING"
        Msg.PONG:
            if not (m.get("c",null) is int):
                return "PONG"
        Msg.LOADED, Msg.LEAVE:
            pass
        _:
            return "unknown type %d" % int(m["t"])
    return ""

# ---------------------------------------------------------------- snapshot packets

## Layout (little endian, 40 bytes): [0] kind=2, [1] flags, [2..3] u16 seq, [4..7] u32 sender ms,
## [8] x, [12] z, [16] heading, [20] vx, [24] vz, [28] yaw rate, [32] steering angle (f32), [36] s32 score.
## flags: 1 drifting, 2 paused, 4 reset (a deliberate jump: restart), 8 handbrake.
static func pack_snapshot(s: Dictionary) -> PackedByteArray:
    var b := PackedByteArray()
    b.resize(SNAPSHOT_SIZE)
    b[0] = KIND_SNAPSHOT
    b[1] = int(s.get("flags",0)) & 0xFF
    b.encode_u16(2,int(s.get("seq",0)) & 0xFFFF)
    b.encode_u32(4,int(s.get("ms",0)) & 0xFFFFFFFF)
    b.encode_float(8,float(s.get("x",0.0)))
    b.encode_float(12,float(s.get("z",0.0)))
    b.encode_float(16,float(s.get("heading",0.0)))
    b.encode_float(20,float(s.get("vx",0.0)))
    b.encode_float(24,float(s.get("vz",0.0)))
    b.encode_float(28,float(s.get("yaw",0.0)))
    b.encode_float(32,float(s.get("steer",0.0)))
    b.encode_s32(36,int(s.get("score",0)))
    return b

## {} for anything malformed: wrong size / kind, NaN / infinity, absurd position / speed / angle / score.
static func unpack_snapshot(b: PackedByteArray) -> Dictionary:
    if b.size() != SNAPSHOT_SIZE or b[0] != KIND_SNAPSHOT:
        return {}
    var s: Dictionary = {"flags":int(b[1]),"seq":b.decode_u16(2),"ms":b.decode_u32(4),"x":b.decode_float(8),"z":b.decode_float(12),
        "heading":b.decode_float(16),"vx":b.decode_float(20),"vz":b.decode_float(24),"yaw":b.decode_float(28),
        "steer":b.decode_float(32),"score":b.decode_s32(36)}
    for key in ["x","z","heading","vx","vz","yaw","steer"]:
        var f: float = float(s[key])
        if is_nan(f) or is_inf(f):
            return {}
    if absf(float(s["x"])) > 6000.0 or absf(float(s["z"])) > 6000.0 or absf(float(s["heading"])) > 50.0:
        return {}
    if Vector2(float(s["vx"]),float(s["vz"])).length() > 160.0 or absf(float(s["yaw"])) > 30.0 or absf(float(s["steer"])) > 3.0:
        return {}
    if int(s["score"]) < 0 or int(s["score"]) > 100000000:
        return {}
    return s

## u16 sequence "a is newer than b" with wrap-around.
static func seq_newer(a: int, b: int) -> bool:
    return a != b and ((a-b) & 0xFFFF) < 0x8000

# --------------------------------------------------------------------- local address

## Private IPv4 addresses of this phone, best first: the Wi-Fi / hotspot interface before anything else.
## (loopback, link-local and mobile-data interfaces are left out.) [{"ip","iface","rank"}]
static func lan_addresses() -> Array[Dictionary]:
    var out: Array[Dictionary] = []
    for itf in IP.get_local_interfaces():
        var name: String = str(itf.get("name","")).to_lower()
        var friendly: String = str(itf.get("friendly","")).to_lower()
        for addr in itf.get("addresses",[]):
            var ip: String = str(addr)
            if not is_private_ipv4(ip):
                continue
            if name.begins_with("rmnet") or name.begins_with("ccmni") or name.begins_with("tun") or name.begins_with("dummy") or name.begins_with("lo") or name.begins_with("p2p"):
                continue
            var rank: int = 1
            for key in ["wlan","swlan","wifi","wi-fi","ap","softap"]:
                if name.begins_with(key) or friendly.contains(key):
                    rank = 3
            if rank == 1 and (name.begins_with("eth") or name.begins_with("en") or friendly.contains("ethernet")):
                rank = 2
            out.append({"ip":ip,"iface":str(itf.get("friendly",name)) if str(itf.get("friendly","")) != "" else name,"rank":rank})
    out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["rank"]) > int(b["rank"]))
    return out

static func is_private_ipv4(ip: String) -> bool:
    var p: PackedStringArray = ip.split(".")
    if p.size() != 4:
        return false
    for part in p:
        if not part.is_valid_int() or int(part) < 0 or int(part) > 255:
            return false
    var a: int = int(p[0])
    var b: int = int(p[1])
    if a == 10 or (a == 192 and b == 168) or (a == 172 and b >= 16 and b <= 31):
        return true
    return false

## "ip" or "ip:port" typed by the player -> {"ip","port"} or {} when it is not a dotted IPv4 address.
static func parse_endpoint(text: String) -> Dictionary:
    var t: String = text.strip_edges()
    var port: int = DEFAULT_PORT
    if t.contains(":"):
        var parts: PackedStringArray = t.split(":")
        if parts.size() != 2 or not parts[1].is_valid_int():
            return {}
        port = int(parts[1])
        t = parts[0]
    var p: PackedStringArray = t.split(".")
    if p.size() != 4:
        return {}
    for part in p:
        if not part.is_valid_int() or int(part) < 0 or int(part) > 255 or part.length() > 3:
            return {}
    if port < 1024 or port > 65535 or t == "0.0.0.0":
        return {}
    return {"ip":t,"port":port}
