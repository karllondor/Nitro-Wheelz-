extends RefCounted
## One first-pass progress frontier per lap, including invalid and missed
## metres. Reversing cannot reopen a spent metre or recover a missed clip.
var frontier := -1.0
var cursor := 0
var covered := {}
var claimed := {}
var quality_metres := {}
var faulted := {}
var complete := 0
var missed := 0
var potential := 0
var technical := 0.0
var last_slip := 0
var flip_at := -1000.0
var initiation_at := -1000.0
var sector_results: Array[Dictionary] = []
var age_since_drift := 10.0
var last_lap := 1
var cue := ""
var valid_base := false

func tick(dt: float, track, model, info: Dictionary, contact: Dictionary, lap: int, scorer) -> float:
    var s: float = info.progress*track.length_metres
    var zones: Array = track.event_layout.zones
    if lap != last_lap and frontier>track.length_metres*0.9 and s<track.length_metres*0.1:
        frontier = 0
        cursor = 0
        covered.clear()
        claimed.clear()
        quality_metres.clear()
        faulted.clear()
        flip_at = -1000.0
        initiation_at = -1000.0
        age_since_drift = 10.0
        last_slip = 0
    last_lap = lap
    var from := s if frontier<0 else frontier
    var advance := clampf(s-from,0.0,model.speed_mps()*dt*1.6)
    frontier = maxf(frontier,s)
    var tangent: Vector2 = info.tangent
    var angle: float = model.drift_angle
    var impact := float(contact.get("impact_speed",0))
    var eligible: bool = advance>0 and model.velocity.dot(tangent)>2 and model.forward().dot(tangent)>0.22 and info.distance<info.width and impact<2.0
    valid_base = eligible and model.is_drifting()
    age_since_drift += dt
    if valid_base and absf(angle)>=10:
        if last_slip == 0 or age_since_drift >= 0.25:
            initiation_at = s
        if last_slip == -signi(int(angle)) and age_since_drift<0.65:
            flip_at=s
        last_slip=signi(int(angle))
        age_since_drift=0
    while cursor<zones.size() and s>float(zones[cursor].b):
        var done: Dictionary=zones[cursor]
        potential+=1
        var fraction := clampf(float(covered.get(done.id,0))/(done.b-done.a),0,1)
        var filled := fraction >= (0.55 if track.event_mode=="pro" else 0.33)
        var quality := clampf(float(quality_metres.get(done.id,0))/(done.b-done.a),0,1)
        sector_results.append({"id":done.id,"lap":lap,"coverage":fraction,"quality":quality,"complete":filled})
        if filled:
            complete+=1
        else:
            missed+=1
            scorer._event("MISSED "+str(done.kind))
        cursor+=1
    if cursor>=zones.size():
        cue="FINISH"
        return 0
    var z: Dictionary=zones[cursor]
    var kind: String=z.kind
    cue=("%s  %d m" % [kind,maxi(0,roundi(z.a-s))]) if s<z.a else kind
    if track.event_mode=="pro" and s>=z.a and (impact>=scorer.WALL_LOSS_SPEED or absf(angle)>=scorer.SPIN_ANGLE):
        faulted[z.id]=true
        covered[z.id]=0.0
        quality_metres[z.id]=0.0
    if faulted.has(z.id) or not valid_base or signf(angle)!=-float(z.turn) or absf(angle)<(14 if track.event_mode=="pro" else 10) or absf(angle)>83:
        return 0
    var normal:=Vector2(-tangent.y,tangent.x)
    var side:=signf(z.d)
    var end_offset: float=track.body_half_length*(1 if kind=="CLIP" else -1)
    var footprint: Vector2=model.position+model.forward()*end_offset
    var d: float=(footprint-Vector2(info.point)).dot(normal)+side*absf(model.right().dot(normal))*track.body_half_width
    var gap:=maxf(0,absf(d-z.d)-z.band*0.5)
    var reach:=2.4 if track.event_mode=="club" else 1.4
    var accuracy:=clampf(1.0-gap/reach,0,1)
    if side!=0 and d*side<=0:
        accuracy=0
    var along:=clampf(1.0-maxf(0,z.a-s)/5.0,0,1)
    if kind in ["FLICK","INIT"]:
        var change_at := initiation_at if kind=="INIT" else flip_at
        if change_at<z.a-6 or change_at>s:
            return 0
        accuracy=clampf(1.0-gap/reach,0,1)
    if along*accuracy<=0:
        return 0
    var pace:=clampf(1.0-absf(model.speed_mps()-z.pace)/(z.pace*1.4),0.15,1.0)
    var award:=advance*along*accuracy*(3+pace*3)
    if s>=z.a and gap==0:
        var metres:=minf(advance,s-z.a)
        covered[z.id]=float(covered.get(z.id,0))+metres
        quality_metres[z.id]=float(quality_metres.get(z.id,0))+metres*accuracy*pace*minf(absf(angle)/35,1.0)
        award+=metres*accuracy*(6+minf(absf(angle)/35,1.0)*5)
        if not claimed.has(z.id):
            claimed[z.id]=true
            award+=20
            scorer._event(kind+"  +20")
        if kind=="OUTSIDE" and impact>0.03 and impact<0.8 and not claimed.has(z.id+"kiss"):
            claimed[z.id+"kiss"]=true
            award+=12
            scorer._event("WALL KISS  +12")
    technical+=award
    return award
