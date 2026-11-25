extends RefCounted
class_name NitroNetProtocol
## Offline local multiplayer (issue #31): wire protocol of the two-phone prototype.
##
## Transport = ENet (UDP) between two phones on the same Wi-Fi / hotspot, no Internet, no server, no account.
## The first byte identifies reliable control, car snapshots, or Park cone snapshots:
##   KIND_CONTROL  (1) + var_to_bytes(Dictionary): lobby / handshake / countdown, RELIABLE, rare, decoded with
##                 bytes_to_var (no object decoding), with validated fields (validate_control).
##   KIND_SNAPSHOT (2) + 43 bytes: the sender's own car, UNRELIABLE ORDERED, 20 Hz.
##   KIND_PARK_CONES (3): bounded host object state, unreliable in motion and reliable when settled.
## Peers report their own driving pose. The Park host resolves optional contacts.
## Competitive races keep remote cars visual-only.
const TIME = preload("res://scripts/lighting/time_of_day.gd")
const PROTOCOL_VERSION: int = 6
const LAMP_POSITION_BIT := 16
const LAMP_BRAKE_BIT := 32
const DEFAULT_PORT: int = 47821
const MAX_PLAYERS: int = 2
const SNAPSHOT_HZ: float = 20.0
const KIND_CONTROL: int = 1
const KIND_SNAPSHOT: int = 2
const KIND_PARK_CONES: int = 3
const KIND_PARK_OBJECTS: int = 4
const PARK_OBJECT_BYTES := 13
const PARK_CAR_BYTES := 52
const PARK_CONE_HEADER := 11
const PARK_CONE_BYTES := 11
const MAX_PARK_CONES := 80
const PARK_PATH := "res://tracks/nitro_wheelz_park.json"
const PARK_SITE = preload("res://scripts/park/park_site.gd")
const PARK_LAYOUT = preload("res://scripts/park/park_layout.gd")
const SNAPSHOT_SIZE: int = 44
const MAX_CONTROL_BYTES: int = 1024
const MAX_NAME_CHARS: int = 16

enum Msg { HELLO = 1, WELCOME = 2, REJECT = 3, INFO = 4, START = 5, LOADED = 6, COUNTDOWN = 7, LEAVE = 8, PING = 10, PONG = 11, TRACK = 12, RESTART = 13, FINISH = 14, PARK_OPEN = 15, PARK_EVENT = 16, PARK_LOBBY = 17, PARK_TIME = 18 }

## Reserved event IDs become valid only when their implementation and validator ship.
enum ParkEvent { RESET_TRAINING = 1, OBJECT_IMPULSE, PLAYER_CONTACT, BUMPER_DAMAGE, DETACH_COMPONENT, SERVICE_REPAIR }

## Built-in circuits both phones carry in the same APK. The host's choice travels as one of these paths
## (never an arbitrary path, never a user:// file) plus the SHA-256 of the file, so a different build or an
## edited copy is refused with a clear message.
const TRACKS: Array[String] = [
    "res://tracks/benchmark_oval.json","res://tracks/benchmark_sweepers.json",
    "res://tracks/shin_kawa_v2.json","res://tracks/shin_kawa_full_circuit.json",
    "res://tracks/driftwood_circuit.json",
    "res://tracks/testandori_raceway.json",
    "res://tracks/fuji_speedway_short.json"]
const TRACK_NAMES: Dictionary = {
    "res://tracks/benchmark_oval.json":"OVAL","res://tracks/benchmark_sweepers.json":"SWEEPERS",
    "res://tracks/shin_kawa_v2.json":"SHIN-KAWA","res://tracks/shin_kawa_full_circuit.json":"SHIN-KAWA • FULL CIRCUIT",
    "res://tracks/driftwood_circuit.json":"DRIFTWOOD CIRCUIT",
    "res://tracks/testandori_raceway.json":"TESTANDORI RACEWAY",
    "res://tracks/fuji_speedway_short.json":"FUJI SPEEDWAY SHORT"}

static func game_version() -> String:
    return str(ProjectSettings.get_setting("application/config/version","unknown"))

static func track_allowed(path: String) -> bool:
    return path == PARK_PATH or TRACKS.has(path)

## SHA-256 of a whitelisted track file ("" for anything else): the layout identity both phones must share.
static func track_fingerprint(path: String) -> String:
    if not track_allowed(path) or not FileAccess.file_exists(path):
        return ""
    if path == PARK_PATH:
        var layout_bytes := var_to_bytes([PARK_SITE.LAN_LAYOUT_REVISION, PARK_SITE.BOUNDS,
            PARK_SITE.LOOP, PARK_SITE.ENTRY_LANE, PARK_SITE.EXIT_LANE, PARK_SITE.STUNT_ACCESS,
            PARK_SITE.PAVED, PARK_SITE.RAMPS, PARK_SITE.REPAIR, PARK_LAYOUT.cones(), PARK_SITE.stunt_props()])
        var hash_context := HashingContext.new()
        hash_context.start(HashingContext.HASH_SHA256)
        hash_context.update(FileAccess.get_file_as_bytes(path))
        hash_context.update(layout_bytes)
        return hash_context.finish().hex_encode()
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
    if m["t"] in [Msg.START, Msg.RESTART, Msg.LOADED, Msg.COUNTDOWN, Msg.FINISH, Msg.PARK_OPEN, Msg.PARK_EVENT, Msg.PARK_LOBBY, Msg.PARK_TIME]:
        if not (m.get("round") is int) or m.round < 1 or m.round > 0xffffffff:
            return "round"
    if m["t"] in [Msg.WELCOME, Msg.INFO, Msg.START, Msg.PARK_OPEN, Msg.PARK_TIME] and not TIME.valid(m.get("tod")):
        return "time of day"
    match int(m["t"]):
        Msg.HELLO:
            if not (m.get("proto",null) is int) or not _is_str(m,"ver",24) or not _is_str(m,"name",MAX_NAME_CHARS+4) or not _is_str(m,"car",16):
                return "HELLO fields"
        Msg.WELCOME:
            if not (m.get("collisions") is bool): return "collision mode"
            if not _is_str(m,"track",96) or not _is_str(m,"fp",80) or not _is_str(m,"name",MAX_NAME_CHARS+4) or not _is_str(m,"car",16) or not (m.get("idx",null) is int):
                return "WELCOME fields"
        Msg.REJECT:
            if not _is_str(m,"code",24) or not _is_str(m,"text",160):
                return "REJECT fields"
        Msg.INFO:
            if not (m.get("collisions") is bool): return "collision mode"
            if not _is_str(m,"name",MAX_NAME_CHARS+4) or not _is_str(m,"car",16) or not (m.get("ready",null) is bool) or not _is_str(m,"fp",80):
                return "INFO fields"
            if not (m.get("look") is Dictionary) or m.look.size() > 5:
                return "appearance"
            for key in m.look:
                if key not in ["paint_color_hex","paint_finish","wheel_asset_id","wheel_finish","livery_id"] or not _is_str(m.look,key,48):
                    return "appearance field"
        Msg.TRACK, Msg.START:
            if not _is_str(m,"track",96) or not _is_str(m,"fp",80):
                return "TRACK fields"
        Msg.COUNTDOWN:
            if not (m.get("secs",null) is float) or m.secs != 3.0 or not (m.get("go_ms") is int):
                return "COUNTDOWN seconds"
        Msg.PING:
            if not (m.get("c",null) is int):
                return "PING"
        Msg.PONG:
            if not (m.get("c",null) is int):
                return "PONG"
            if not (m.get("host_ms") is int):
                return "host clock"
        Msg.FINISH:
            if not (m.get("points") is int) or m.points < 0 or m.points > 100000000:
                return "finish points"
            if not (m.get("time_ms") is int) or m.time_ms < 0 or m.time_ms > 0x7fffffff:
                return "finish time"
        Msg.PARK_OPEN:
            if not (m.get("collisions") is bool) or not (m.get("mounts") is PackedByteArray) or m.mounts.size()!=4:
                return "Park car state"
            for mask in m.mounts:
                if mask > 3: return "Park mounts"
            var host_at: Variant = m.get("host_at")
            if not _valid_revision(m.get("revision")) or not (host_at is Vector2) or not host_at.is_finite() or not PARK_SITE.BOUNDS.has_point(host_at):
                return "Park open state"
        Msg.PARK_EVENT:
            if not _valid_revision(m.get("revision")) or not (m.get("event") is int) or not (m.get("payload") is Dictionary):
                return "Park event"
            if not valid_park_event(m.event,m.payload):
                return "Unsupported Park event"
        Msg.RESTART, Msg.LOADED, Msg.LEAVE, Msg.PARK_LOBBY, Msg.PARK_TIME:
            pass
        _:
            return "unknown type %d" % int(m["t"])
    return ""

static func valid_park_event(kind: int, data: Dictionary) -> bool:
    match kind:
        ParkEvent.RESET_TRAINING:
            return data.is_empty()
        ParkEvent.PLAYER_CONTACT:
            # delta and separation are applied once, with opposite signs for the two slots.
            return data.get("dv") is Vector2 and data.dv.is_finite() and data.dv.length() <= 12.01 \
                and data.get("shift") is Vector2 and data.shift.is_finite() and data.shift.length() <= 0.51 \
                and data.get("guest_at") is Vector2 and PARK_SITE.BOUNDS.has_point(data.guest_at)
        ParkEvent.SERVICE_REPAIR:
            return data.get("slot") is int and data.slot in [0,1]
        ParkEvent.BUMPER_DAMAGE, ParkEvent.DETACH_COMPONENT:
            if not (data.get("slot") is int and data.slot in [0,1] and data.get("part") is int and data.part in [0,1]):
                return false
            if kind == ParkEvent.BUMPER_DAMAGE:
                return data.get("mask") is int and data.mask in [1,2]
            return data.get("at") is Vector3 and data.at.is_finite() and absf(data.at.y)<25.0 \
                and PARK_SITE.BOUNDS.grow(4.0).has_point(Vector2(data.at.x,data.at.z)) \
                and data.get("angle") is float and is_finite(data.angle) and data.get("velocity") is Vector2 \
                and data.velocity.is_finite() and data.velocity.length() <= 18.01
    return false

static func _valid_revision(value: Variant) -> bool:
    return value is int and value >= 0 and value <= 0xffffffff

## Full sparse cone state. Each record is index, float32 x/z, tilt u8 and direction u8.
## At most 891 bytes including round/revision/sequence, below the control packet cap.
static func pack_park_cones(round_id: int, revision: int, seq: int, poses: Array) -> PackedByteArray:
    var b := PackedByteArray()
    b.resize(PARK_CONE_HEADER + PARK_CONE_BYTES * poses.size())
    b[0] = KIND_PARK_CONES
    b.encode_u32(1,round_id)
    b.encode_u32(5,revision)
    b.encode_u16(9,seq)
    var offset := PARK_CONE_HEADER
    for pose in poses:
        b[offset] = pose.index
        b.encode_float(offset+1,pose.pos.x)
        b.encode_float(offset+5,pose.pos.y)
        b[offset+9] = roundi(clampf(pose.tilt/(PI*0.5),0.0,1.0)*255.0)
        b[offset+10] = roundi(fposmod(pose.angle,TAU)*256.0/TAU) & 0xff
        offset += PARK_CONE_BYTES
    return b

static func unpack_park_cones(b: PackedByteArray) -> Dictionary:
    if b.size() < PARK_CONE_HEADER or b[0] != KIND_PARK_CONES:
        return {}
    var bytes := b.size()-PARK_CONE_HEADER
    if bytes % PARK_CONE_BYTES != 0 or bytes > MAX_PARK_CONES*PARK_CONE_BYTES:
        return {}
    var poses: Array = []
    var seen := {}
    for offset in range(PARK_CONE_HEADER,b.size(),PARK_CONE_BYTES):
        var index := int(b[offset])
        var at := Vector2(b.decode_float(offset+1),b.decode_float(offset+5))
        if index >= MAX_PARK_CONES or seen.has(index) or not at.is_finite() or maxf(absf(at.x),absf(at.y)) > 900.0:
            return {}
        seen[index] = true
        poses.append({"index":index,"pos":at,"tilt":float(b[offset+9])/255.0*PI*0.5,
            "angle":float(b[offset+10])*TAU/256.0})
    return {"round":b.decode_u32(1),"revision":b.decode_u32(5),"seq":b.decode_u16(9),"poses":poses}

## Sparse positions use 2.5 cm steps and signed 16-bit Euler angles.
static func pack_park_objects(round_id: int, revision: int, seq: int, poses: Array) -> PackedByteArray:
    var b := PackedByteArray()
    b.resize(PARK_CONE_HEADER+PARK_OBJECT_BYTES*poses.size())
    b[0] = KIND_PARK_OBJECTS
    b.encode_u32(1,round_id)
    b.encode_u32(5,revision)
    b.encode_u16(9,seq)
    var at := PARK_CONE_HEADER
    for pose in poses:
        b[at] = pose.id
        for axis in 3:
            b.encode_s16(at+1+axis*2,roundi(float(pose.position[axis])*40.0))
            b.encode_s16(at+7+axis*2,roundi(wrapf(float(pose.rotation[axis]),-PI,PI)*8192.0))
        at += PARK_OBJECT_BYTES
    return b

static func unpack_park_objects(b: PackedByteArray) -> Dictionary:
    if b.size() < PARK_CONE_HEADER or b[0] != KIND_PARK_OBJECTS:
        return {}
    var bytes := b.size()-PARK_CONE_HEADER
    if bytes % PARK_OBJECT_BYTES != 0 or bytes > PARK_SITE.STUNT_PROP_CAP*PARK_OBJECT_BYTES:
        return {}
    var poses := []
    var seen := {}
    for at in range(PARK_CONE_HEADER,b.size(),PARK_OBJECT_BYTES):
        var id := int(b[at])
        var pos := Vector3(b.decode_s16(at+1),b.decode_s16(at+3),b.decode_s16(at+5))/40.0
        var rot := Vector3(b.decode_s16(at+7),b.decode_s16(at+9),b.decode_s16(at+11))/8192.0
        if id >= PARK_SITE.STUNT_PROP_CAP or seen.has(id) or maxf(absf(rot.x),maxf(absf(rot.y),absf(rot.z))) > PI+0.001:
            return {}
        if pos != Vector3(0,-8,0) and (pos.y < -0.55 or pos.y > 28.0 or not PARK_SITE.STUNT.grow(16.0).has_point(Vector2(pos.x,pos.z))):
            return {}
        seen[id] = true
        poses.append({"id":id,"position":pos,"rotation":rot})
    return {"round":b.decode_u32(1),"revision":b.decode_u32(5),"seq":b.decode_u16(9),"poses":poses}

# ---------------------------------------------------------------- snapshot packets

## Layout (little endian, 44 bytes): [0] kind=2, [1] flags, [2..3] u16 seq, [4..7] u32 sender ms,
## [8] x, [12] z, [16] heading, [20] vx, [24] vz, [28] yaw rate, [32] steering angle (f32), [36] s32 score, [40] u32 round.
## flags: 1 drifting, 2 paused, 4 reset, 16 position/headlights, 32 brake lamps.
static func pack_snapshot(s: Dictionary, park := false) -> PackedByteArray:
    var b := PackedByteArray()
    b.resize(PARK_CAR_BYTES if park else SNAPSHOT_SIZE)
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
    b.encode_u32(40,int(s.get("round",0)))
    if park:
        b.encode_float(44,float(s.get("height",0.0)))
        b.encode_float(48,float(s.get("pitch",0.0)))
    return b

## {} for anything malformed: wrong size / kind, NaN / infinity, absurd position / speed / angle / score.
static func unpack_snapshot(b: PackedByteArray) -> Dictionary:
    if b.size() not in [SNAPSHOT_SIZE,PARK_CAR_BYTES] or b[0] != KIND_SNAPSHOT:
        return {}
    var s: Dictionary = {"round":b.decode_u32(40),"flags":int(b[1]),"seq":b.decode_u16(2),"ms":b.decode_u32(4),"x":b.decode_float(8),"z":b.decode_float(12),
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
    if b.size() == PARK_CAR_BYTES:
        var height := b.decode_float(44)
        var pitch := b.decode_float(48)
        if not is_finite(height) or not is_finite(pitch) or height < 0.0 or height > 7.0 or absf(pitch) > 0.40:
            return {}
        s["height"] = height
        s["pitch"] = pitch
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
    # LOCAL network only (RFC 1918: 10.x, 172.16-31.x, 192.168.x) plus loopback for tests: never a public Internet address.
    if not is_private_ipv4(t) and not t.begins_with("127."):
        return {}
    return {"ip":t,"port":port}
