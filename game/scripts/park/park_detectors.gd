extends RefCounted
class_name NitroParkDetectors
## Manoeuvre detectors of the Park tutorial (issue #27). Pure logic: they are fed
## the REAL vehicle state each physics tick (position, heading, drift angle, speed)
## and decide from what the car actually did - never from a button tap or a timer.
## Tolerance based, so a weak starter car and a sloppy first try still pass when the
## manoeuvre really happened, and driving straight never does.
##
## Conventions: the planar frame of the drive model (x east, z south). `turn` is
## +1 for a LEFT turn (counter-clockwise seen from above) and -1 for a RIGHT turn.

const DRIFT_MIN_DEG: float = 14.0         # slip angle that counts as "sliding"

## Accumulated turning of the car around a centre, restricted to a ring.
class Orbit extends RefCounted:
    var centre: Vector2
    var r_min: float
    var r_max: float
    var turn: int                          # wanted direction (+1 left / -1 right)
    var need_rad: float                    # accumulated angle that counts as done
    var drift_share_needed: float
    var accumulated: float = 0.0           # signed so that `turn` is positive
    var time_in: float = 0.0
    var time_drifting: float = 0.0
    var drift_sign_sum: float = 0.0
    var _last_angle: float = 0.0
    var _have_last: bool = false
    var _outside: float = 0.0

    func _init(c: Vector2, rmin: float, rmax: float, t: int, need_deg: float, drift_share: float) -> void:
        centre = c
        r_min = rmin
        r_max = rmax
        turn = t
        need_rad = deg_to_rad(need_deg)
        drift_share_needed = drift_share

    func reset() -> void:
        accumulated = 0.0
        time_in = 0.0
        time_drifting = 0.0
        drift_sign_sum = 0.0
        _have_last = false
        _outside = 0.0

    func update(pos: Vector2, dt: float, drift_angle_deg: float, speed_kmh: float) -> void:
        var d: Vector2 = pos-centre
        var dist: float = d.length()
        if dist < r_min or dist > r_max or speed_kmh < 6.0:
            _outside += dt
            _have_last = false
            if _outside > 2.0:
                # left the ring for good: start the circle again
                accumulated = 0.0
                time_in = 0.0
                time_drifting = 0.0
                drift_sign_sum = 0.0
            return
        _outside = 0.0
        var a: float = atan2(d.y,d.x)           # grows clockwise seen from above (z south)
        if _have_last:
            var delta: float = wrapf(a-_last_angle,-PI,PI)
            # counter-clockwise (a LEFT turn) = decreasing a; the wanted turn counts positive
            accumulated += -delta*float(turn)
        _last_angle = a
        _have_last = true
        time_in += dt
        if absf(drift_angle_deg) >= DRIFT_MIN_DEG:
            time_drifting += dt
            drift_sign_sum += signf(drift_angle_deg)*dt

    func progress() -> float:
        return clampf(accumulated/need_rad,0.0,1.0)

    func drift_share() -> float:
        return time_drifting/maxf(time_in,0.001)

    func done() -> bool:
        return accumulated >= need_rad and drift_share() >= drift_share_needed

## Two-lobe figure-eight: each lobe is circled in its own direction, the car drifts in
## both, and the SIDE of the slip flips between the lobes (a real transition).
class Eight extends RefCounted:
    var lobes: Array[Orbit] = []
    var last_lobe: int = -1
    var transitions: int = 0
    var started_at: float = -1.0
    var clock: float = 0.0

    func _init(centres: Array, radius: float, spread_ring: Vector2, need_deg: float, drift_share: float) -> void:
        for i in range(2):
            lobes.append(Orbit.new(Vector2(centres[i]),radius*spread_ring.x,radius*spread_ring.y,1 if i == 0 else -1,need_deg,drift_share))

    func reset() -> void:
        for l in lobes:
            l.reset()
        last_lobe = -1
        transitions = 0
        clock = 0.0

    func update(pos: Vector2, dt: float, drift_angle_deg: float, speed_kmh: float) -> void:
        clock += dt
        # the car belongs to the lobe whose centre is nearer (the crossing is the middle)
        var d0: float = pos.distance_to(lobes[0].centre)
        var d1: float = pos.distance_to(lobes[1].centre)
        var near: int = 0 if d0 <= d1 else 1
        if speed_kmh > 6.0 and near != last_lobe:
            if last_lobe != -1:
                transitions += 1
            last_lobe = near
        lobes[near].update(pos,dt,drift_angle_deg,speed_kmh)
        # the other lobe keeps its accumulated angle but is not fed

    func progress() -> float:
        return (lobes[0].progress()+lobes[1].progress())*0.5

    ## Slip sides differ between the lobes (the drift changed direction).
    func slip_flipped() -> bool:
        var a: float = lobes[0].drift_sign_sum
        var b: float = lobes[1].drift_sign_sum
        return absf(a) > 0.3 and absf(b) > 0.3 and signf(a) != signf(b)

    func done() -> bool:
        return lobes[0].done() and lobes[1].done() and transitions >= 1 and slip_flipped()

## Follow a closed painted line: progress is the length driven along it, only while
## the car is inside the corridor. Either direction counts.
class Route extends RefCounted:
    var path: PackedVector2Array
    var length: float = 0.0
    var half_width: float
    var along: PackedFloat32Array = PackedFloat32Array()
    var cursor: int = -1
    var driven: float = 0.0                # metres driven along the line (always >= 0)
    var time_in: float = 0.0
    var time_total: float = 0.0
    var time_drifting: float = 0.0
    var need_share: float
    var need_drift_share: float
    var direction: int = 0

    func _init(p: PackedVector2Array, corridor_width: float, corridor_share: float, drift_share: float) -> void:
        path = p
        half_width = corridor_width*0.5+1.2
        need_share = corridor_share
        need_drift_share = drift_share
        var acc: float = 0.0
        along.append(0.0)
        for i in range(1,path.size()):
            acc += path[i-1].distance_to(path[i])
            along.append(acc)
        length = acc+path[path.size()-1].distance_to(path[0])

    func reset() -> void:
        cursor = -1
        driven = 0.0
        time_in = 0.0
        time_total = 0.0
        time_drifting = 0.0
        direction = 0

    func _nearest(pos: Vector2, from: int, window: int) -> int:
        var n: int = path.size()
        var best: int = from
        var best_d: float = INF
        for k in range(-window,window+1):
            var i: int = posmod(from+k,n)
            var d: float = pos.distance_squared_to(path[i])
            if d < best_d:
                best_d = d
                best = i
        return best

    func update(pos: Vector2, dt: float, drift_angle_deg: float, speed_kmh: float) -> void:
        var n: int = path.size()
        if cursor < 0:
            # join the line where the car first is close to it
            var best: int = 0
            var best_d: float = INF
            for i in range(n):
                var d: float = pos.distance_squared_to(path[i])
                if d < best_d:
                    best_d = d
                    best = i
            if sqrt(best_d) > half_width*2.0 or speed_kmh < 6.0:
                return
            cursor = best
            return
        var nxt: int = _nearest(pos,cursor,14)
        var dist: float = pos.distance_to(path[nxt])
        time_total += dt
        if dist <= half_width:
            time_in += dt
            if absf(drift_angle_deg) >= DRIFT_MIN_DEG:
                time_drifting += dt
            var step: int = posmod(nxt-cursor+n/2,n)-n/2     # signed samples moved
            if step != 0:
                var metres: float = 0.0
                for k in range(absi(step)):
                    var i1: int = posmod(cursor+k*signi(step),n)
                    var i2: int = posmod(cursor+(k+1)*signi(step),n)
                    metres += path[i1].distance_to(path[i2])
                if direction == 0:
                    direction = signi(step)
                if signi(step) == direction:
                    driven += metres
            cursor = nxt
        else:
            cursor = nxt

    func progress() -> float:
        return clampf(driven/(length*0.92),0.0,1.0)

    func corridor_share() -> float:
        return time_in/maxf(time_total,0.001)

    func drift_share() -> float:
        return time_drifting/maxf(time_in,0.001)

    func done() -> bool:
        return driven >= length*0.92 and corridor_share() >= need_share and drift_share() >= need_drift_share

## First controlled slide: slip >= 18 deg for 0.6 s, then recovered below 8 deg for 0.5 s.
class FirstSlide extends RefCounted:
    var slide_time: float = 0.0
    var slid: bool = false
    var recovered_time: float = 0.0
    var finished: bool = false

    func reset() -> void:
        slide_time = 0.0
        slid = false
        recovered_time = 0.0
        finished = false

    func update(dt: float, drift_angle_deg: float, speed_kmh: float) -> void:
        if finished:
            return
        var a: float = absf(drift_angle_deg)
        if not slid:
            if a >= 18.0 and speed_kmh >= 12.0:
                slide_time += dt
                if slide_time >= 0.6:
                    slid = true
            else:
                slide_time = maxf(0.0,slide_time-dt*2.0)
        else:
            if a <= 8.0:
                recovered_time += dt
                if recovered_time >= 0.5:
                    finished = true
            else:
                recovered_time = 0.0

    func progress() -> float:
        if finished:
            return 1.0
        if slid:
            return 0.5+0.5*clampf(recovered_time/0.5,0.0,1.0)
        return 0.5*clampf(slide_time/0.6,0.0,1.0)

    func done() -> bool:
        return finished
