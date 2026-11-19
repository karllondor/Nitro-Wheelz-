extends SceneTree
const SYNTH = preload("res://scripts/audio/engine_synth.gd")
func _initialize() -> void:
    var s = SYNTH.new()
    var acc := 0.0
    var acc2 := 0.0
    var t := 0.0
    var n := 0
    while t < 6.0:
        var speed: float = minf(t*30.0,150.0)
        var gas: float = 1.0 if t < 4.0 else 0.0
        s.set_state(speed,gas,0.4 if (t > 2.0 and t < 3.0) else 0.0,1.0/60.0)
        var buf: PackedVector2Array = s.render(367)
        for v in buf:
            acc += v.x
            acc2 += v.x*v.x*float(n%97)
            n += 1
        t += 1.0/60.0
    print("AUDIO_TRACE %.9f %.9f %d %d %d" % [acc,acc2,n,s.limiter_hits,s.shifts])
    quit(0)
