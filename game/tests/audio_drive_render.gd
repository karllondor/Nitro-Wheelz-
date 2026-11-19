extends SceneTree
## Developer tool (not in the automated suite): drives a fixed script in the
## real race scene so the game's own audio mix can be recorded with Godot's
## Movie Maker for listening tests:
##   xvfb-run godot --path game --write-movie out.avi --fixed-fps 60 \
##     --resolution 360x800 --script res://tests/audio_drive_render.gd -- red recorded
## Args: car variant (red|white|blue), audio mode (recorded|synth).
## Prints every mixer decision with its time so the recording can be checked.
var race: Node3D
var t: float = 0.0
var seen: int = 0
var variant: String = "red"
var mode: String = "recorded"

func _initialize() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() > 0:
        variant = args[0]
    if args.size() > 1:
        mode = args[1]
    load("res://scripts/audio/drive_audio.gd").set_audio_mode(mode)
    ProjectSettings.set_setting("nitro/car_variant",variant)
    ProjectSettings.set_setting("nitro/selected_track","res://tracks/benchmark_oval.json")
    race = (load("res://scenes/race.tscn") as PackedScene).instantiate()
    root.add_child(race)

func _inputs(steer: float, gas: float, brake: float, hb: float) -> void:
    for a in ["steer_left","steer_right","throttle","brake","handbrake"]:
        Input.action_release(a)
    if steer < 0.0:
        Input.action_press("steer_left",-steer)
    elif steer > 0.0:
        Input.action_press("steer_right",steer)
    if gas > 0.0:
        Input.action_press("throttle",gas)
    if brake > 0.0:
        Input.action_press("brake",brake)
    if hb > 0.0:
        Input.action_press("handbrake",hb)

func _process(delta: float) -> bool:
    t += delta
    # Same script for every car / mode. Steering follows the track line
    # (look-ahead autopilot); throttle, handbrake and lifts are scripted.
    var st: float = _autopilot()
    if t < 2.0: _inputs(0.0,0.0,0.0,0.0)           # idle
    elif t < 5.0: _inputs(st,1.0,0.0,0.0)          # launch through the gears
    elif t < 5.3: _inputs(st*1.6,0.6,0.0,1.0)      # handbrake flick
    elif t < 9.0: _inputs(st,0.85,0.0,0.0)         # drift / power
    elif t < 10.2: _inputs(st,0.0,0.0,0.0)         # lift off: pops / blow-off, regrip
    elif t < 14.0: _inputs(st,1.0,0.0,0.0)         # back on the power, upshifts
    elif t < 15.2: _inputs(st,0.0,0.0,0.0)         # lift at speed
    elif t < 17.0: _inputs(st,0.9,0.0,0.0)         # power again
    elif t < 19.0: _inputs(st,0.0,1.0,0.0)         # brake
    else:
        _inputs(0.0,0.0,0.0,0.0)
        _dump()
        return true
    _collect()
    return false

## Pure-pursuit steering towards a point ~22 m ahead on the centreline.
func _autopilot() -> float:
    var model = race.get("model")
    var track = race.get("track")
    if model == null or track == null:
        return 0.0
    var info: Dictionary = track.sample_info(model.position)
    var n: int = track.centerline.size()
    var i: int = int(info["index"])
    var ahead: Vector2 = model.position
    var dist: float = 0.0
    var k: int = i
    while dist < 22.0:
        var a: Vector2 = track.centerline[k%n]
        var b: Vector2 = track.centerline[(k+1)%n]
        dist += a.distance_to(b)
        ahead = b
        k += 1
    var to: Vector2 = (ahead-model.position).normalized()
    var f: Vector2 = model.forward()
    var err: float = atan2(f.x*to.y-f.y*to.x,f.dot(to))
    return clampf(err*1.8,-1.0,1.0)

func _collect() -> void:
    var sfx = race.get("sfx")
    if sfx == null:
        return
    var n: int = sfx.log.size()
    # The mixer keeps a short ring log; print entries not printed yet.
    var printed: int = 0
    for e in sfx.log:
        var key: String = "%.4f%s%s" % [float(e["t"]),str(e["clip"]),str(e["action"])]
        if not _done.has(key):
            _done[key] = true
            print("EVENT %6.2f %-5s %-20s %s" % [float(e["t"]),str(e["action"]),str(e["clip"]),str(e["reason"])])
            printed += 1
    var model = race.get("model")
    if int(t*2.0) != _last_half:
        _last_half = int(t*2.0)
        print("STATE %5.1fs %5.1f km/h drift %5.1f deg rpm %5d" % [t,model.speed_kmh(),model.drift_angle,int(sfx.synth.rpm)])

var _done: Dictionary = {}
var _last_half: int = -1

func _dump() -> void:
    var sfx = race.get("sfx")
    print("PLAYS ",JSON.stringify(sfx.play_count))
    print("WALL HITS ",race.get("wall_collision_count"))
