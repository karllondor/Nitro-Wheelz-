extends RefCounted
class_name NitroNetRemoteView
## Receiver side of the offline local multiplayer (v0.1.45): turns the other phone's 20 Hz snapshots into a car that
## glides on THIS phone's screen, however uneven the Wi-Fi / hotspot delivery and the two phones' frame times are.
##
## The owner's first real-phone test (v0.1.44, Wi-Fi) showed the remote car jumping at the start of a race. The old
## receiver had a fixed 120 ms delay, a clock offset that stepped whenever a faster packet arrived, and it drew the raw
## interpolated pose, so every late packet, every offset step and every extrapolation that turned out wrong became a
## visible pop. This class replaces that with the usual snapshot-interpolation recipe, kept small and testable:
##   1. a RENDER CLOCK (sender time) that is steered towards "now - clock offset - delay" by speeding up / slowing down
##      by at most +-15 %, so a change of the offset or of the delay becomes a gentle speed change, never a jump;
##   2. an ADAPTIVE DELAY = the oldest the newest snapshot got in the last ~1.5 s (peak-held, measured per frame, so a
##      phone's own frame hitch does not count as network jitter) + a margin, clamped to 110..340 ms: a bursty Wi-Fi gets
##      a deeper buffer, a clean one stays responsive;
##   3. a DISCONTINUITY SMOOTHER: when new data changes the path the car was on (a wrong extrapolation, a late packet),
##      the difference is not shown as a jump but bled off over ~0.1 s (only a deliberate reset / > 6 m error snaps);
##   4. the same bracketing Hermite interpolation, <= 250 ms velocity extrapolation and heading wrap as before.
## Snapshots are stamped with SIMULATION time by the sender (tick x tick length), not with the wall clock of the frame
## they happened to run in, so uneven sender frames do not look like uneven car speed.
## Pure data: no nodes, no engine objects, so the whole thing runs in a headless test with a simulated network.
const SEND_INTERVAL_MS: float = 50.0
const MIN_DELAY_MS: float = 110.0
const MAX_DELAY_MS: float = 340.0
const EXTRAPOLATE_MAX_S: float = 0.25
const MAX_BUFFER: int = 40
const OFFSET_WINDOW: int = 60                   # ~3 s of snapshots
const RATE_SPAN: float = 0.15                   # the render clock runs 0.85 .. 1.15 x
const RATE_GAIN_MS: float = 700.0
const RESYNC_MS: float = 700.0                  # a bigger clock error than this re-syncs instead of slewing
const ERROR_TAU_S: float = 0.10
const SNAP_M: float = 6.0

var buf: Array[Dictionary] = []
var offset_ms: float = 0.0                      # recv - sent, fastest of the recent window
var late_ms: float = SEND_INTERVAL_MS           # age of the newest snapshot, peak-held (slowly decaying)
var delay_ms: float = MIN_DELAY_MS
var underrun_frames: int = 0                    # frames drawn after the newest snapshot (extrapolating / standing)
var resyncs: int = 0
var snaps: int = 0
var _offsets: Array[float] = []
var _step_run: int = 0
var _rt: float = 0.0
var _rt_prev: float = 0.0
var _have_rt: bool = false
var _disp: Dictionary = {}
var _have_disp: bool = false

## A deliberate jump (restart): forget the path, show the next snapshot where it is.
func reset() -> void:
    buf.clear()
    _have_disp = false

func has_data() -> bool:
    return not buf.is_empty()

## Add one received snapshot (`recv_ms` = local time it was taken off the socket). False = refused as an impossible jump.
func feed(s: Dictionary, recv_ms: float) -> bool:
    var sent: float = float(s["ms"])
    if not buf.is_empty():
        var last: Dictionary = buf[buf.size()-1]
        var dt: float = maxf(0.0,(sent-float(last["ms"]))/1000.0)
        var jump: float = Vector2(float(s["x"])-float(last["x"]),float(s["z"])-float(last["z"])).length()
        if jump > 160.0*dt+10.0:
            return false                         # impossible at drift speeds: ignore this packet
    var transit: float = recv_ms-sent
    # the sender's clock fell behind for good (a long hitch, the app in the background): every snapshot for half a second
    # is far later than the best of the window -> forget the old window instead of trusting it for another 3 s
    if not _offsets.is_empty() and transit-offset_ms > RESYNC_MS:
        _step_run += 1
        if _step_run >= 10:
            _offsets.clear()
            _step_run = 0
    else:
        _step_run = 0
    _offsets.append(transit)
    if _offsets.size() > OFFSET_WINDOW:
        _offsets.pop_front()
    offset_ms = _offsets.min()
    buf.append(s)
    while buf.size() > MAX_BUFFER:
        buf.pop_front()
    return true

## Pose to draw at local time `now_ms` for a frame of `dt` seconds ({} until the first snapshot arrived).
func step(now_ms: float, dt: float) -> Dictionary:
    if buf.is_empty():
        return {}
    var age: float = maxf(0.0,now_ms-offset_ms-float(buf[buf.size()-1]["ms"]))
    late_ms = maxf(age,lerpf(late_ms,age,1.0-exp(-dt/1.5)))
    delay_ms = clampf(late_ms*1.1+20.0,MIN_DELAY_MS,MAX_DELAY_MS)
    var target: float = now_ms-offset_ms-delay_ms
    if not _have_rt:
        _rt = target
        _rt_prev = target
        _have_rt = true
    else:
        _rt_prev = _rt
        var err: float = target-_rt
        if absf(err) > RESYNC_MS:
            _rt = target
            resyncs += 1
        else:
            _rt += dt*1000.0*(1.0+clampf(err/RATE_GAIN_MS,-RATE_SPAN,RATE_SPAN))
    if _rt > float(buf[buf.size()-1]["ms"])+20.0:
        underrun_frames += 1
    var pose: Dictionary = interpolate(buf,_rt)
    if not _have_disp:
        _disp = pose
        _have_disp = true
        return _disp
    # the same (possibly just changed) path one frame earlier: what is left between it and what was drawn is the error
    var before: Dictionary = interpolate(buf,_rt_prev)
    var ex: float = float(_disp["x"])-float(before["x"])
    var ez: float = float(_disp["z"])-float(before["z"])
    var eh: float = wrapf(float(_disp["heading"])-float(before["heading"]),-PI,PI)
    if Vector2(ex,ez).length() > SNAP_M:
        snaps += 1
        ex = 0.0
        ez = 0.0
        eh = 0.0
    var k: float = exp(-dt/ERROR_TAU_S)
    _disp = {"x":float(pose["x"])+ex*k,"z":float(pose["z"])+ez*k,"heading":float(pose["heading"])+eh*k,
        "steer":float(pose["steer"]),"speed":float(pose["speed"]),"height":pose.height,"pitch":pose.pitch}
    return _disp

## "GOOD" / "FAIR" / "POOR" from the peak age of the newest snapshot (shown next to the other player's score).
func quality() -> String:
    if late_ms <= 110.0:
        return "GOOD"
    return "FAIR" if late_ms <= 200.0 else "POOR"

func stats_line() -> String:
    return "delay %d ms, newest-data age %d ms, underrun frames %d, clock re-syncs %d, snaps %d" % [int(delay_ms),int(late_ms),underrun_frames,resyncs,snaps]

## Pose of the remote car at `render_ms` (sender clock) from the buffered snapshots: Hermite between the two
## snapshots that bracket it, velocity extrapolation (<= 250 ms) after the newest one, the oldest before the first.
static func interpolate(b: Array[Dictionary], render_ms: float) -> Dictionary:
    var first: Dictionary = b[0]
    var last: Dictionary = b[b.size()-1]
    if render_ms <= float(first["ms"]):
        return _pose(first)
    if render_ms >= float(last["ms"]):
        var dt: float = minf((render_ms-float(last["ms"]))/1000.0,EXTRAPOLATE_MAX_S)
        var out: Dictionary = _pose(last)
        out["x"] = float(last["x"])+float(last["vx"])*dt
        out["z"] = float(last["z"])+float(last["vz"])*dt
        out["heading"] = float(last["heading"])+float(last["yaw"])*dt
        return out
    for i in range(b.size()-1):
        var a: Dictionary = b[i]
        var c: Dictionary = b[i+1]
        if render_ms >= float(a["ms"]) and render_ms <= float(c["ms"]):
            var span: float = maxf(float(c["ms"])-float(a["ms"]),1.0)
            var t: float = (render_ms-float(a["ms"]))/span
            var h: float = span/1000.0
            var t2: float = t*t
            var t3: float = t2*t
            var h00: float = 2.0*t3-3.0*t2+1.0
            var h10: float = t3-2.0*t2+t
            var h01: float = -2.0*t3+3.0*t2
            var h11: float = t3-t2
            var out2: Dictionary = {}
            out2["x"] = h00*float(a["x"])+h10*h*float(a["vx"])+h01*float(c["x"])+h11*h*float(c["vx"])
            out2["z"] = h00*float(a["z"])+h10*h*float(a["vz"])+h01*float(c["z"])+h11*h*float(c["vz"])
            out2["heading"] = float(a["heading"])+wrapf(float(c["heading"])-float(a["heading"]),-PI,PI)*t
            out2["steer"] = lerpf(float(a["steer"]),float(c["steer"]),t)
            out2["speed"] = lerpf(Vector2(float(a["vx"]),float(a["vz"])).length(),Vector2(float(c["vx"]),float(c["vz"])).length(),t)
            out2["height"] = lerpf(float(a.get("height",0.0)),float(c.get("height",0.0)),t)
            out2["pitch"] = lerpf(float(a.get("pitch",0.0)),float(c.get("pitch",0.0)),t)
            return out2
    return _pose(last)

static func _pose(s: Dictionary) -> Dictionary:
    return {"x":float(s["x"]),"z":float(s["z"]),"heading":float(s["heading"]),"steer":float(s["steer"]),
        "speed":Vector2(float(s["vx"]),float(s["vz"])).length(),
        "height":float(s.get("height",0.0)),"pitch":float(s.get("pitch",0.0))}
