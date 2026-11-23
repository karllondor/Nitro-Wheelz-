extends RefCounted
## Arc stations are metres in the driving direction. Positive offset is the
## road's right edge. Layout, paint and judgement share the same intervals.
const MODES = {"practice":"Practice","club":"Club Event","pro":"Pro Event"}
const ROAD_WIDTH = 12.0

static func generate(track, mode: String) -> Dictionary:
    var zones: Array[Dictionary] = []
    var warnings: Array[String] = []
    var layout := {"zones":zones,"warnings":warnings,"version":1,"mode":mode}
    if mode not in ["club","pro"] or track.centerline.size() < 3:
        return layout
    var start := 0.0
    var turn := 0
    var radians := 0.0
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
        var ok:=true
        for car in ["e30","blue"]:
            if not probe.verify(track,z,mode,car,speeds[car],grade_force):
                warnings.append("%d m: ease bend or widen road (%s)" % [int(z.a),car])
                ok=false
                break
        if ok:
            accepted.append(z)
    layout.zones=accepted
    return layout

static func _add(zones: Array[Dictionary],kind: String,a: float,b: float,d: float,band: float,turn: int,pace: float) -> void:
    zones.append({"kind":kind,"a":a,"b":b,"d":d,"band":band,"turn":turn,"pace":pace,
        "id":"%s:%d:%d" % [kind,roundi(a*100),turn]})
