extends SceneTree
## Offline local multiplayer, v0.1.45: the remote car must glide under uneven Wi-Fi / hotspot delivery and uneven phone
## frame times (owner report, v0.1.44: "the other car jumped at the start").
##
## A deterministic network + two-phone simulation (no sockets, seeded): a car that leaves the line at GO and weaves
## through a drift circuit is sampled by a SENDER that runs 120 Hz physics inside 30-60 fps frames with hitches (the first
## drift compiles shaders), is sent as 20 Hz snapshots through a modelled link (clean, Wi-Fi power-save bursts, spikes +
## loss, both), and drawn by a RECEIVER with its own frame times and hitches. The SAME packets feed
##   * LEGACY = a faithful copy of the v0.1.44 receiver (clock offset = min of the last 40 transits, fixed 120 ms delay,
##     raw interpolated pose, snapshots stamped with the wall clock of the sender frame), and
##   * NEW    = NitroNetRemoteView (snapshots stamped with simulation time).
## Per drawn frame it measures the POP = |distance moved - what the real car moved in that time| (frames longer than
## 40 ms are the phone's own hitch and are not counted) and the display lag, and asserts the new receiver never pops.
## This is a MODEL of the radio, not a Wi-Fi measurement: it proves the smoothing logic, not the owner's routers.
const VIEW = preload("res://scripts/net/net_remote_view.gd")

const TICK_MS: float = 1000.0/120.0
const GO_SIM_MS: float = 3000.0
const RUN_MS: float = 15000.0
const POP_M: float = 0.5

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    printerr("FAIL: "+message)
    quit(1)

# ----------------------------------------------------------------------------------------------- the car (truth)

static func _dist(t_s: float) -> float:
    var acc: float = 6.0
    var vmax: float = 22.0
    if t_s <= 0.0:
        return 0.0
    var ta: float = vmax/acc
    if t_s < ta:
        return 0.5*acc*t_s*t_s
    return 0.5*acc*ta*ta+vmax*(t_s-ta)

## Position of the car at sim time t (ms): weaving circle, standing until GO.
static func _pos(t_ms: float) -> Vector2:
    var th: float = _dist((t_ms-GO_SIM_MS)/1000.0)/45.0
    var r: float = 45.0+8.0*sin(2.3*th)
    return Vector2(r*cos(th),r*sin(th))

static func _state(t_ms: float) -> Dictionary:
    var d: float = 0.5
    var v: Vector2 = (_pos(t_ms+d)-_pos(t_ms-d))/(d*2.0/1000.0)
    var v2: Vector2 = (_pos(t_ms+d+10.0)-_pos(t_ms-d+10.0))/(d*2.0/1000.0)
    var h0: float = atan2(v.y,v.x)+PI*0.5
    var h1: float = atan2(v2.y,v2.x)+PI*0.5
    var yaw: float = wrapf(h1-h0,-PI,PI)/0.010 if v.length() > 0.5 else 0.0
    return {"x":_pos(t_ms).x,"z":_pos(t_ms).y,"heading":h0 if v.length() > 0.5 else 0.0,"vx":v.x,"vz":v.y,"yaw":yaw,
        "steer":0.3*sin(t_ms/700.0)*minf(1.0,v.length()/8.0)}

static func _speed(t_ms: float) -> float:
    var d: float = 0.5
    return ((_pos(t_ms+d)-_pos(t_ms-d))/(d*2.0/1000.0)).length()

# ---------------------------------------------------------------------------------------- frames, link, phones

## Frame start times (ms, true clock) of a phone at `fps` with +-15 % unevenness and one-off hitches {at_ms: extra_ms}.
static func _frames(rng: RandomNumberGenerator, fps: float, hitches: Dictionary) -> PackedFloat64Array:
    var out := PackedFloat64Array()
    var t: float = 0.0
    var pending: Array = hitches.keys()
    pending.sort()
    while t < RUN_MS+2000.0:
        out.append(t)
        var d: float = 1000.0/fps*(1.0+rng.randf_range(-0.15,0.15))
        if not pending.is_empty() and t >= float(pending[0]):
            d += float(hitches[pending[0]])
            pending.pop_front()
        t += d
    return out

## One-way delivery time (true clock) of a packet sent at t_ms; -1 = lost.
static func _deliver(rng: RandomNumberGenerator, net: String, t_ms: float, phase: float, stalls: Array = []) -> float:
    for st in stalls:                                  # the link is dead (Wi-Fi scan / roaming): everything waits for the end
        if t_ms >= float(st[0]) and t_ms < float(st[0])+float(st[1]):
            return float(st[0])+float(st[1])+rng.randf()*3.0
    match net:
        "clean":
            return t_ms+5.0+rng.randf()*4.0
        "burst":                                   # Wi-Fi power-save: everything waits for the next 100 ms beacon
            return ceil((t_ms-phase)/100.0)*100.0+phase+3.0+rng.randf()*3.0
        "spiky":
            if rng.randf() < 0.02:
                return -1.0
            return t_ms+8.0+rng.randf()*10.0+(80.0+rng.randf()*170.0 if rng.randf() < 0.04 else 0.0)
        _:                                         # "bad": beacon batching + spikes + loss
            if rng.randf() < 0.03:
                return -1.0
            return ceil((t_ms-phase)/100.0)*100.0+phase+3.0+rng.randf()*3.0+(80.0+rng.randf()*170.0 if rng.randf() < 0.05 else 0.0)

## What the v0.1.44 receiver did, line for line.
class Legacy:
    var buf: Array[Dictionary] = []
    var offsets: Array[float] = []
    var offset_ms: float = 0.0
    func feed(s: Dictionary, recv_ms: float) -> void:
        var sent: float = float(s["wall_ms"])
        offsets.append(recv_ms-sent)
        if offsets.size() > 40:
            offsets.pop_front()
        offset_ms = offsets.min()
        var t: Dictionary = s.duplicate()
        t["ms"] = sent
        if not buf.is_empty():
            var last: Dictionary = buf.back()
            var dt: float = maxf(0.0,(sent-float(last["ms"]))/1000.0)
            if Vector2(float(t["x"])-float(last["x"]),float(t["z"])-float(last["z"])).length() > 160.0*dt+10.0:
                return
        buf.append(t)
        while buf.size() > 40:
            buf.pop_front()
    func step(now_ms: float) -> Dictionary:
        if buf.is_empty():
            return {}
        return VIEW.interpolate(buf,now_ms-offset_ms-120.0)

## One scenario: returns {"legacy":{...}, "new":{...}} metrics.
func _simulate(seed_v: int, send_fps: float, recv_fps: float, net: String, hitches: bool, stalls: Array = []) -> Dictionary:
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_v
    var phase: float = rng.randf()*100.0
    var clock_s: float = 123456.0+rng.randf()*1000.0     # the two phones' clocks have nothing to do with each other
    var clock_r: float = 987654.0+rng.randf()*1000.0
    var sh: Dictionary = {3300.0:250.0,5000.0:120.0} if hitches else {}
    var rh: Dictionary = {3150.0:400.0,5200.0:150.0} if hitches else {}
    var sframes: PackedFloat64Array = _frames(rng,send_fps,sh)
    var rframes: PackedFloat64Array = _frames(rng,recv_fps,rh)
    # ---- sender: 120 Hz physics inside the frames (8 ticks per frame at most, the rest of the time is dropped)
    var packets: Array[Dictionary] = []
    var acc: float = 0.0
    var tick: int = 0
    var seq: int = 0
    var tick_wall: Array = []                              # [sim_ms, true_ms] per snapshot, for the lag measurement
    for i in range(sframes.size()-1):
        var dt: float = float(sframes[i+1])-float(sframes[i])
        acc += dt
        var n: int = int(acc/TICK_MS)
        if n > 8:
            n = 8
            acc = 0.0
        else:
            acc -= float(n)*TICK_MS
        for _j in range(n):
            tick += 1
            if tick%6 == 0:
                var sim_ms: float = round(float(tick)*TICK_MS)
                var s: Dictionary = _state(sim_ms)
                s["ms"] = sim_ms
                s["wall_ms"] = floor(float(sframes[i])+clock_s)    # what v0.1.44 stamped: the frame's wall clock
                s["seq"] = seq
                var arr: float = _deliver(rng,net,float(sframes[i]),phase,stalls)
                if arr >= 0.0:
                    s["arrive"] = arr
                    packets.append(s)
                tick_wall.append([sim_ms,float(sframes[i])])
                seq += 1
    packets.sort_custom(func(a, b): return float(a["arrive"]) < float(b["arrive"]))
    # ---- receiver
    var legacy := Legacy.new()
    var view := VIEW.new()
    var m_old := {"pops":0,"pops_big":0,"max":0.0,"lag_sum":0.0,"lag_n":0,"lag_max":0.0,"frames":0,"dev":0.0}
    var m_new := {"pops":0,"pops_big":0,"max":0.0,"lag_sum":0.0,"lag_n":0,"lag_max":0.0,"frames":0,"dev":0.0}
    var pi: int = 0
    var last_seq: int = -1
    var prev_old: Vector2 = Vector2.ZERO
    var prev_new: Vector2 = Vector2.ZERO
    var have_old: bool = false
    var have_new: bool = false
    for i in range(1,rframes.size()):
        var t_true: float = float(rframes[i])
        if t_true > RUN_MS:
            break
        var local: float = floor(t_true+clock_r)
        var dt_r: float = (float(rframes[i])-float(rframes[i-1]))/1000.0
        while pi < packets.size() and float(packets[pi]["arrive"]) <= t_true:
            var p: Dictionary = packets[pi]
            pi += 1
            if int(p["seq"]) < last_seq:
                continue                                   # unreliable-ordered: an older packet that arrives late is dropped
            last_seq = int(p["seq"])
            legacy.feed(p,local)
            view.feed(p,local)
        var sim_now: float = _sim_at(tick_wall,t_true)
        _measure(m_old,legacy.step(local),prev_old,have_old,dt_r,tick_wall,t_true,sim_now)
        var po: Dictionary = legacy.step(local)
        if not po.is_empty():
            prev_old = Vector2(float(po["x"]),float(po["z"]))
            have_old = true
        var pn: Dictionary = view.step(local,dt_r)
        _measure(m_new,pn,prev_new,have_new,dt_r,tick_wall,t_true,sim_now)
        if not pn.is_empty():
            prev_new = Vector2(float(pn["x"]),float(pn["z"]))
            have_new = true
    m_new["stats"] = view.stats_line()
    m_new["quality"] = view.quality()
    return {"legacy":m_old,"new":m_new}

## Sender sim time at true time t (table lookup by the wall time of the snapshot ticks).
static func _sim_at(table: Array, t_true: float) -> float:
    var lo: int = 0
    var hi: int = table.size()-1
    while lo < hi:
        var mid: int = (lo+hi+1)/2
        if float(table[mid][1]) <= t_true:
            lo = mid
        else:
            hi = mid-1
    return float(table[lo][0])

func _measure(m: Dictionary, pose: Dictionary, prev: Vector2, have_prev: bool, dt: float, table: Array, t_true: float, sim_now: float) -> void:
    if pose.is_empty():
        return
    m["frames"] = int(m["frames"])+1
    var cur := Vector2(float(pose["x"]),float(pose["z"]))
    # where on the real path is the drawn car? (search the last 1.2 s of sender sim time, 10 ms steps)
    var best_t: float = sim_now
    var best_d: float = 1e9
    var t: float = maxf(0.0,sim_now-1200.0)
    while t <= sim_now+50.0:
        var d: float = _pos(t).distance_to(cur)
        if d < best_d:
            best_d = d
            best_t = t
        t += 10.0
    var t_fine: float = best_t-10.0
    while t_fine <= best_t+10.0:
        var d2: float = _pos(t_fine).distance_to(cur)
        if d2 < best_d:
            best_d = d2
            best_t = t_fine
        t_fine += 1.0
    var v: float = _speed(best_t)
    if t_true > 3500.0 and dt <= 0.040:
        m["dev"] = maxf(float(m["dev"]),best_d)        # how far the drawn car is from where the real car has been
    if have_prev and dt <= 0.040 and t_true > 3500.0:
        var pop: float = absf(cur.distance_to(prev)-v*dt)
        m["max"] = maxf(float(m["max"]),pop)
        if pop > POP_M:
            m["pops"] = int(m["pops"])+1
        if pop > 1.0:
            m["pops_big"] = int(m["pops_big"])+1
    if v > 5.0 and t_true > 5000.0:
        # display lag = how long ago (true time) the sender was where the drawn car is now
        var lag: float = t_true-_wall_at(table,best_t)
        m["lag_sum"] = float(m["lag_sum"])+lag
        m["lag_n"] = int(m["lag_n"])+1
        m["lag_max"] = maxf(float(m["lag_max"]),lag)

static func _wall_at(table: Array, sim_ms: float) -> float:
    var lo: int = 0
    var hi: int = table.size()-1
    while lo < hi:
        var mid: int = (lo+hi)/2
        if float(table[mid][0]) < sim_ms:
            lo = mid+1
        else:
            hi = mid
    return float(table[lo][1])

# ------------------------------------------------------------------------------------------------------------ run

func _run() -> void:
    # ---- unit behaviour first
    var view := VIEW.new()
    if not view.step(1000.0,0.016).is_empty():
        _fail("no snapshot yet must draw nothing")
        return
    var ok: bool = view.feed({"ms":1000.0,"x":0.0,"z":0.0,"heading":0.0,"vx":10.0,"vz":0.0,"yaw":0.0,"steer":0.0},5000.0)
    if not ok or view.step(5200.0,0.016).is_empty():
        _fail("first snapshot must be accepted and drawn")
        return
    if view.feed({"ms":1050.0,"x":900.0,"z":0.0,"heading":0.0,"vx":10.0,"vz":0.0,"yaw":0.0,"steer":0.0},5050.0):
        _fail("an impossible jump (900 m in 50 ms) must be refused")
        return
    view.reset()
    if view.has_data():
        _fail("reset must forget the path")
        return
    # ---- the sender stops for 2 s (long hitch / app in the background) and its snapshots resume 2 s "later" on the
    # receiver's clock: the receiver must re-sync within ~1.5 s and never draw the car ahead of the data it has
    var pv := VIEW.new()
    var now: float = 100000.0
    var sim: float = 0.0
    var seq_n: int = 0
    var resumed_at: float = -1.0
    var worst_ahead: float = -1e9
    var hz_t: float = 0.0
    var next_snap: float = 0.0
    var last_x: float = 0.0
    while hz_t < 9000.0:
        if hz_t >= 3000.0 and hz_t < 5000.0:
            now += 16.0
            hz_t += 16.0
            if pv.has_data():
                pv.step(now,0.016)
            continue
        if resumed_at < 0.0 and hz_t >= 5000.0:
            resumed_at = hz_t
        while next_snap <= hz_t:
            if not (next_snap >= 3000.0 and next_snap < 5000.0):
                var sx: float = 20.0*sim/1000.0
                pv.feed({"ms":sim,"x":sx,"z":0.0,"heading":0.0,"vx":20.0,"vz":0.0,"yaw":0.0,"steer":0.0},now)
                last_x = sx
                sim += 50.0
                seq_n += 1
            next_snap += 50.0
        var pose: Dictionary = pv.step(now,0.016)
        if resumed_at >= 0.0 and hz_t > resumed_at+1500.0 and not pose.is_empty():
            worst_ahead = maxf(worst_ahead,float(pose["x"])-last_x)
        now += 16.0
        hz_t += 16.0
    if pv.resyncs < 1:
        _fail("a 2 s sender stop must re-sync the render clock (resyncs %d)" % pv.resyncs)
        return
    if worst_ahead > 0.5:
        _fail("1.5 s after the sender resumed the car is still drawn %.1f m ahead of the data it has (%s)" % [worst_ahead,pv.stats_line()])
        return
    # ---- the simulated radio
    var scen: Array = [
        {"n":"calm: 60/60 fps, clean link, no hitches","sf":60.0,"rf":60.0,"net":"clean","h":false},
        {"n":"start hitches: 60/60 fps, clean link","sf":60.0,"rf":60.0,"net":"clean","h":true},
        {"n":"Wi-Fi bursts (100 ms beacon): 60/60 fps","sf":60.0,"rf":60.0,"net":"burst","h":true},
        {"n":"Wi-Fi spikes + 2% loss: 60/60 fps","sf":60.0,"rf":60.0,"net":"spiky","h":true},
        {"n":"weak phones: 30/30 fps, bursts","sf":30.0,"rf":30.0,"net":"burst","h":true},
        {"n":"bad: 45/45 fps, bursts + spikes + 3% loss","sf":45.0,"rf":45.0,"net":"bad","h":true},
        {"n":"link stalls 0.4 s + 0.6 s (scan / roaming)","sf":60.0,"rf":60.0,"net":"clean","h":true,"stalls":[[4500.0,400.0],[9000.0,600.0]]},
    ]
    var seeds: Array = [11,23,37,41,59]
    var tot_old: int = 0
    var tot_new: int = 0
    var worst_new: float = 0.0
    var lag_new_worst: float = 0.0
    var lines: Array = []
    for sc in scen:
        var o_pops: int = 0
        var n_pops: int = 0
        var o_big: int = 0
        var n_big: int = 0
        var o_max: float = 0.0
        var n_max: float = 0.0
        var o_dev: float = 0.0
        var n_dev: float = 0.0
        var o_lag: float = 0.0
        var n_lag: float = 0.0
        var lag_cnt: int = 0
        var stats: String = ""
        var qual: String = ""
        for sd in seeds:
            var r: Dictionary = _simulate(int(sd),float(sc["sf"]),float(sc["rf"]),str(sc["net"]),bool(sc["h"]),sc.get("stalls",[]))
            var o: Dictionary = r["legacy"]
            var n: Dictionary = r["new"]
            if int(n["frames"]) < 400 or int(o["frames"]) < 400:
                _fail("scenario '%s' drew too few frames (new %d, old %d)" % [sc["n"],int(n["frames"]),int(o["frames"])])
                return
            o_pops += int(o["pops"])
            n_pops += int(n["pops"])
            o_big += int(o["pops_big"])
            n_big += int(n["pops_big"])
            o_max = maxf(o_max,float(o["max"]))
            n_max = maxf(n_max,float(n["max"]))
            o_dev = maxf(o_dev,float(o["dev"]))
            n_dev = maxf(n_dev,float(n["dev"]))
            if int(o["lag_n"]) > 0 and int(n["lag_n"]) > 0:
                o_lag += float(o["lag_sum"])/float(o["lag_n"])
                n_lag += float(n["lag_sum"])/float(n["lag_n"])
                lag_cnt += 1
            lag_new_worst = maxf(lag_new_worst,float(n["lag_max"]))
            stats = str(n["stats"])
            qual = str(n["quality"])
        tot_old += o_pops
        tot_new += n_pops
        worst_new = maxf(worst_new,n_max)
        var line: String = "  %-46s | pops>0.5 m: old %4d  new %3d | pops>1 m: old %3d  new %3d | worst pop: old %5.2f m  new %4.2f m | off-path: old %5.2f m  new %4.2f m | mean lag: old %3d ms  new %3d ms | new: %s (%s)" % [
            sc["n"],o_pops,n_pops,o_big,n_big,o_max,n_max,o_dev,n_dev,int(o_lag/maxf(1.0,float(lag_cnt))),int(n_lag/maxf(1.0,float(lag_cnt))),stats,qual]
        lines.append(line)
        print(line)
        if sc.has("stalls") and o_pops < 1:
            _fail("scenario '%s': the model no longer reproduces the v0.1.44 jump after a link stall - the test proves nothing" % sc["n"])
            return
        if n_pops > 0 or n_max > 0.5:
            _fail("scenario '%s': the NEW receiver popped %d times (worst %.2f m); the car must glide" % [sc["n"],n_pops,n_max])
            return
        if n_lag/maxf(1.0,float(lag_cnt)) > 360.0:
            _fail("scenario '%s': the NEW receiver lags %.0f ms behind the real car (adaptive delay too deep)" % [sc["n"],n_lag/maxf(1.0,float(lag_cnt))])
            return
    if tot_old <= 0:
        _fail("the model does not reproduce the v0.1.44 pops at all: the simulation proves nothing (old total %d)" % tot_old)
        return
    print("PASS: remote car smoothing under a simulated Wi-Fi / phone-hitch model (%d scenarios x %d seeds, 15 s each) - v0.1.44 receiver: %d visible pops (> %.1f m in one frame), v0.1.45 NitroNetRemoteView: %d, worst new pop %.2f m, worst new display lag %d ms; model of the radio, NOT a Wi-Fi measurement" % [scen.size(),seeds.size(),tot_old,POP_M,tot_new,worst_new,int(lag_new_worst)])
    quit(0)
