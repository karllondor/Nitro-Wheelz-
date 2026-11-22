extends RefCounted
## Local rolling-entry witness. Try deliberate drift poses with the actual
## deterministic model, wheelbase, drive force and grip for each reference.
const DRIVE=preload("res://scripts/driving/drive_model.gd")
const CARS=preload("res://scripts/vehicles/car_catalog.gd")

static func verify(track,z: Dictionary,mode: String,car: String) -> bool:
    var model=DRIVE.new()
    CARS.configure_model(model,car)
    var body: Dictionary=CARS.info(car)
    var half_length: float=body.length*0.575-0.095
    var half_width: float=body.width*0.575-0.048
    var start: float=maxf(0,z.a-1.5)
    var station: Dictionary=track._road_at_arc(start)
    var right: Vector2=station.across
    var forward:=Vector2(right.y,-right.x)
    for speed_factor in [1.15,0.85,1.45]:
        for steer_factor in [0.55,0.0,-0.45]:
            var yaw: float=forward.angle()+PI/2+deg_to_rad(26)*z.turn
            model.reset(station.centre,yaw)
            var side:=signf(z.d)
            var overhang: float=half_length*(1 if z.kind=="CLIP" else -1)*model.forward().dot(right)+side*half_width*absf(model.right().dot(right))
            model.position+=right*(z.d-overhang if side!=0 else 0.0)
            model.velocity=forward*z.pace*speed_factor
            model.rear_traction=0.45
            var coverage:=0.0
            var prev_s:=start
            for k in range(100):
                var dt:=1.0/60
                model.step(dt,z.turn*steer_factor,0.65,0,0.5 if k<8 else 0.0)
                if k%3!=2:
                    continue
                var ix: int=clampi(track.arc_lengths.bsearch(prev_s)-1,0,track._segment_count()-1)
                var next: int=(ix+1)%track.centerline.size()
                var t: Vector2=(track.centerline[next]-track.centerline[ix]).normalized()
                var arc: float=track.arc_lengths[ix]+(model.position-track.centerline[ix]).dot(t)
                if arc<=prev_s or arc>track.length_metres:
                    break
                var frame: Dictionary=track._road_at_arc(arc)
                var n: Vector2=frame.across
                var d: float=(model.position-Vector2(frame.centre)).dot(n)
                var extent: float=absf(model.forward().dot(n))*half_length+absf(model.right().dot(n))*half_width
                if absf(d)+extent>track.halfwidths[ix]-0.12:
                    break
                var footprint:=d+model.forward().dot(n)*half_length*(1 if z.kind=="CLIP" else -1)+side*half_width*absf(model.right().dot(n))
                if arc>=z.a and model.is_drifting() and model.drift_angle*z.turn<-(14 if mode=="pro" else 10) and (side==0 or absf(footprint-z.d)<=z.band*0.5):
                    coverage+=maxf(0,minf(arc,z.b)-maxf(prev_s,z.a))
                if coverage>=(z.b-z.a)*(0.55 if mode=="pro" else 0.33):
                    return true
                if arc>=z.b:
                    break
                prev_s=arc
    return false
