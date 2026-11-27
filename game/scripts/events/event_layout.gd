extends RefCounted
## Arc stations are metres in the driving direction. Positive offset is the
## road's right edge. Layout, paint and judgement share the same intervals.
const MODES = {"practice":"Practice","club":"Club Event","pro":"Pro Event"}
const ROAD_WIDTH = 12.0

static func generate(track, mode: String, wide_prototype: bool = true) -> Dictionary:
    var zones: Array[Dictionary] = []
    var warnings: Array[String] = []
    var layout := {"zones":zones,"warnings":warnings,"version":1,"mode":mode}
    if mode not in ["club","pro"] or track.centerline.size() < 3:
        return layout
    var start := 0.0
    var turn := 0
    var radians := 0.0
    var wide: bool = wide_prototype and track.road_style == "circuit"
    var previous_turn := 0
    var previous_end := -INF
    var count: int = track.centerline.size()
    for i in range(1,count):
        var s: float = track.arc_lengths[i]
        var curvature := 0.0
        if i < count-1:
            var before: Vector2 = track.centerline[i]-track.centerline[i-1]
            var after: Vector2 = track.centerline[i+1]-track.centerline[i]
            curvature = before.angle_to(after)/maxf(0.01,(before.length()+after.length())*0.5)
        var direction := int(signf(curvature)) if absf(curvature)>0.007 else 0
        if direction != turn:
            var span := s-start
            if turn != 0 and absf(radians)>0.28 and span>8.0:
                var radius := span/absf(radians)
                if radius < 8.0 or radius > 110.0:
                    warnings.append("%d m: %s bend" % [int(start),"open tight" if radius<8 else "tighten sweeping"])
                else:
                    var linked := previous_turn == -turn and start-previous_end<36
                    var pro := mode=="pro"
                    var width: float = track.halfwidths[i-1]
                    var band := minf(width*0.47,3.0) if not pro else minf(width*0.28,1.9)
                    var edge := width-(2.1 if track.road_style=="circuit" else 0.65)-band*0.5
                    var pace := clampf(sqrt(radius*6.0),7.0,22.0)
                    var entry := start+span*0.16
                    if wide and width > ROAD_WIDTH*0.5:
                        _wide_bend(zones,start,span,turn,width,edge,band,pace,linked,pro,previous_end)
                    else:
                        if linked or pro:
                            _add(zones,"FLICK" if linked else "INIT",start,entry,0.0,width*1.35,turn,pace)
                        # Alternate the target on short linked turns. Crossing the
                        # whole road twice within one tight corner is infeasible.
                        if linked and span < 48:
                            _add(zones,"CLIP",start+span*0.40,start+span*0.70,edge*turn,band,turn,pace)
                        else:
                            var outside_end := start+span*(0.52 if span>55 else 0.90)
                            var sectors := maxi(1,ceili((outside_end-entry)/(13.0 if pro else 32.0)))
                            for j in range(sectors):
                                _add(zones,"OUTSIDE",lerpf(entry,outside_end,float(j)/sectors),lerpf(entry,outside_end,float(j+1)/sectors),-turn*edge,band,turn,pace)
                            if span>55:
                                _add(zones,"CLIP",start+span*0.86,start+span*0.96,turn*edge,band,turn,pace)
                    previous_turn = turn
                    previous_end = s
            turn = direction
            start = s
            radians = 0
        radians += curvature*(s-float(track.arc_lengths[i-1]))
    if zones.is_empty():
        return layout
    var accepted: Array[Dictionary]=[]
    var probe = preload("res://scripts/events/event_probe.gd")
    var speeds := {"e30":probe.launch_speeds("e30"),"blue":probe.launch_speeds("blue")}
    var grade_force := int(NitroPhysicsDev.load_settings().grade_force)
    for z in zones:
        if not track.closed_loop and (z.a<track.arc_lengths[track.start_index] or z.b>track.arc_lengths[track.finish_index]):
            continue
        var legacy_start: float = z.get("legacy_start",-1.0)
        var legacy_end: float = z.get("legacy_end",-1.0)
        z.erase("legacy_start")
        z.erase("legacy_end")
        if _feasible(probe,track,z,mode,speeds,grade_force,wide):
            accepted.append(z)
            continue
        # Tight linked bends can still use their proven transfer at turn-in.
        if legacy_start >= 0.0 and (track.closed_loop or legacy_start >= track.arc_lengths[track.start_index]):
            var fallback: Array[Dictionary] = []
            _add(fallback,"FLICK",legacy_start,legacy_end,0.0,z.band,z.turn,z.pace)
            if not fallback.is_empty() and _feasible(probe,track,fallback[0],mode,speeds,grade_force,false):
                accepted.append(fallback[0])
                continue
        warnings.append("%d m: ease bend or widen road" % int(z.a))
    layout.zones=accepted
    return layout

static func _feasible(probe, track, zone: Dictionary, mode: String, speeds: Dictionary,
        grade_force: int, extended: bool) -> bool:
    for car in speeds:
        if not probe.verify(track,zone,mode,car,speeds[car],grade_force,extended):
            return false
    return true

## Use the legacy outside-sector count as the reward budget. Allocate
## metres by approach pace, lane crossing time and the bend's available arc.
static func _wide_bend(zones: Array[Dictionary], start: float, span: float, turn: int,
        width: float, edge: float, band: float, pace: float, linked: bool, pro: bool,
        previous_end: float) -> void:
    var finish := start+span
    var lateral_speed := maxf(4.0,pace*sin(deg_to_rad(33.0)))
    var transfer := minf(maxf(7.0,(2.0*edge/lateral_speed)*pace),span*0.27)
    var legacy_entry := start+span*0.16
    var entry := start+minf(span*0.12,pace*0.28)
    if linked or pro:
        var gate: float = start+minf(span*0.06,pace*0.19) if linked else start-minf(span*0.16,pace*0.45)
        gate = maxf(gate,maxf(0.0,previous_end))
        if linked:
            entry = maxf(legacy_entry,gate+minf(span*0.12,pace*0.40))
            _add(zones,"FLICK",gate,entry,0.0,width*1.35,turn,pace)
            zones.back()["legacy_start"] = start
            zones.back()["legacy_end"] = legacy_entry
        else:
            entry = maxf(entry,gate+minf(span*0.12,pace*0.35))
            _add(zones,"INIT",gate,entry,0.0,width*1.35,turn,pace)
    if linked and span < 48.0:
        var clip_start := maxf(entry+minf(transfer,span*0.22),start+span*0.57)
        _add(zones,"CLIP",clip_start,finish-span*0.07,edge*turn,band,turn,pace)
        return

    var legacy_end := start+span*(0.52 if span>55.0 else 0.90)
    var clip_length := minf(span*0.13,pace*0.56)
    var clip_begin := finish-span*0.025-clip_length
    var outside_limit := clip_begin-transfer if span>55.0 else finish-span*0.045
    var outside_end := minf(outside_limit,entry+(legacy_end-legacy_entry)*1.95)
    var sectors := maxi(1,ceili((legacy_end-legacy_entry)/(13.0 if pro else 32.0)))
    for j in range(sectors):
        _add(zones,"OUTSIDE",lerpf(entry,outside_end,float(j)/sectors),
            lerpf(entry,outside_end,float(j+1)/sectors),-turn*edge,band,turn,pace)
    if span>55.0:
        _add(zones,"CLIP",clip_begin,clip_begin+clip_length,edge*turn,band,turn,pace)

static func _add(zones: Array[Dictionary],kind: String,a: float,b: float,d: float,band: float,turn: int,pace: float) -> void:
    if b-a < 0.3:
        return
    zones.append({"kind":kind,"a":a,"b":b,"d":d,"band":band,"turn":turn,"pace":pace,
        "id":"%s:%d:%d" % [kind,roundi(a*100),turn]})
