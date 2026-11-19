extends SceneTree
## Finish screen (v0.1.16 redesign): ranking by points, best/delta logic,
## per-lap splits recorded by the race, and a clean non-overlapping layout.
const RESULTS = preload("res://scripts/ui/race_results.gd")
const ID: String = "qa_results_screen"

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    _clear()
    var prev: Array = [
        {"track_id":ID,"seconds":59.71,"score":7259,"stars":3,"date":"2026-11-19T10:40:00"},
        {"track_id":ID,"seconds":61.28,"score":7105,"stars":2,"date":"2026-11-19T10:41:00"},
        {"track_id":ID,"seconds":54.24,"score":2460,"stars":3,"date":"2026-11-19T10:42:00"}]
    var stamp: String = "2026-11-19T11:00:00"
    var mine: Dictionary = {"track_id":ID,"seconds":61.92,"score":7680,"stars":2,"date":stamp}
    var laps: Array = [{"time":21.84,"score":2210},{"time":19.66,"score":2890},{"time":20.42,"score":2580}]
    var sm: Dictionary = RESULTS.summarize(ID,"QA",61.92,7680,2,prev,prev+[mine],stamp,{"laps":laps})
    if int(sm["rank"]) != 1 or not bool(sm["new_best"]) or int(sm["prior_best_score"]) != 7259:
        _fail("Best run by points must rank #1 and read NEW BEST: "+str(sm["rank"]))
        return
    if int(sm["best_lap"]) != 1:
        _fail("Fastest lap must be lap 2")
        return
    var low: Dictionary = {"track_id":ID,"seconds":61.0,"score":1407,"stars":2,"date":stamp}
    sm = RESULTS.summarize(ID,"QA",61.0,1407,2,prev,prev+[low],stamp,{})
    if int(sm["rank"]) != 4 or bool(sm["new_best"]) or bool(sm["first_run"]):
        _fail("Lower score must rank by points (#4), not by time")
        return
    var many: Array = []
    for i in range(7):
        many.append({"track_id":ID,"seconds":60.0+i,"score":9000-i*100,"stars":2,"date":"2026-11-19T09:%02d:00" % i})
    sm = RESULTS.summarize(ID,"QA",70.0,100,1,many,many+[{"track_id":ID,"seconds":70.0,"score":100,"stars":1,"date":stamp}],stamp,{})
    if int(sm["rank"]) != 8 or (sm["top"] as Array).size() != 5:
        _fail("A run outside the top 5 must keep its real rank")
        return
    if RESULTS.points(1234567) != "1,234,567" or RESULTS.points(950) != "950":
        _fail("Point formatting")
        return
    # Race records per-lap splits that add up to the total.
    var race: Node3D = (load("res://scenes/race.tscn") as PackedScene).instantiate()
    root.add_child(race)
    await process_frame
    race.set_physics_process(false)
    var model = race.get("model")
    var scorer = race.get("scorer")
    var tangent := Vector2(0,-1)
    model.velocity = tangent*20.0
    for lap_i in range(3):
        race.set("time_elapsed",float(race.get("time_elapsed"))+20.0+lap_i)
        scorer.total += 1000*(lap_i+1)
        race.set("last_progress",0.97)
        race.call("_lap_logic",0.01,tangent,1.0/120.0)
    var splits: Array = race.get("lap_splits")
    if splits.size() != 3 or not bool(race.get("finished")):
        _fail("Race must record three lap splits and finish (%d)" % splits.size())
        return
    var sum_pts: int = 0
    for sp in splits:
        sum_pts += int(sp["score"])
        if float(sp["time"]) <= 0.0:
            _fail("Lap split time must be positive")
            return
    if sum_pts != int(scorer.total):
        _fail("Lap points must add up to the total (%d vs %d)" % [sum_pts,int(scorer.total)])
        return
    race.queue_free()
    await process_frame
    # Layout: sections and buttons on screen, no overlaps, portrait + landscape.
    var view: NitroRaceResults = RESULTS.new()
    root.add_child(view)
    for screen in [Vector2(720,1600),Vector2(1280,2276),Vector2(1280,720),Vector2(1080,1920)]:
        var lay: Dictionary = view.layout(screen)
        var full := Rect2(Vector2.ZERO,screen)
        var keys: Array[String] = ["title","hero","laps","chips","top","restart","menu"]
        for key in keys:
            if not full.encloses(Rect2(lay[key])):
                _fail("Results section off-screen: %s at %s" % [key,str(screen)])
                return
        for i in range(keys.size()):
            for j in range(i+1,keys.size()):
                if Rect2(lay[keys[i]]).intersects(Rect2(lay[keys[j]])):
                    _fail("Results sections overlap: %s / %s at %s" % [keys[i],keys[j],str(screen)])
                    return
        if Rect2(lay["restart"]).size.y < screen.y*0.05:
            _fail("Buttons too small to tap at "+str(screen))
            return
    view.show_race(ID,"QA",61.92,7680,90.0,func(): pass,func(): pass,{"laps":laps,"best_chain":956})
    await process_frame
    if view.buttons.size() != 2 or view.buttons[0].text != "RESTART":
        _fail("Finish screen must offer RESTART and GARAGE / MENU")
        return
    view.queue_free()
    _clear()
    print("PASS: results ranked by points with this run highlighted, best/delta logic, per-lap splits sum to total, layout fits portrait + landscape")
    print("NOT RUN: readability check on the owner's phone")
    quit(0)

func _clear() -> void:
    var keep: Array = []
    for run in RESULTS.read_runs():
        if str(run.get("track_id","")) != ID:
            keep.append(run)
    var f := FileAccess.open(RESULTS.STORAGE,FileAccess.WRITE)
    f.store_string(JSON.stringify(keep,"  "))
    f.close()

func _fail(msg: String) -> void:
    printerr("FAIL: "+msg)
    _clear()
    quit(1)
