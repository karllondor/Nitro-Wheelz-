extends SceneTree
## Run this same script against each checkout. Measures the remote countdown render callback only.
const SESSION = preload("res://scripts/net/net_session.gd")
const RACE = preload("res://scenes/race.tscn")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var session := SESSION.new()
    root.add_child(session)
    session.other = {"name":"GUEST","car":"blue"}
    session.state = SESSION.State.COUNTDOWN
    session._go_usec = Time.get_ticks_usec()+3000000
    SESSION.current = session
    var race := RACE.instantiate()
    root.add_child(race)
    var net = race.net
    net.remote_view.feed({"ms":0,"x":0.0,"z":0.0,"heading":0.0,"vx":0.0,"vz":0.0,
        "steer":0.0,"yaw":0.0},0.0)
    var batches: Array[float] = []
    for batch in 31:
        var began := Time.get_ticks_usec()
        for frame in 600:
            net._process(1.0/60.0)
        if batch > 0:
            batches.append((Time.get_ticks_usec()-began)/600.0)
    batches.sort()
    print("Countdown callback, us/call, median %.2f, p95 %.2f" % [batches[15],batches[28]])
    race.free()
    quit()
