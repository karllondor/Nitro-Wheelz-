extends SceneTree
const RACE = preload("res://scenes/race.tscn")
func _initialize() -> void:
    call_deferred("run")
func run() -> void:
    ProjectSettings.set_setting("nitro/selected_track","res://tracks/shin_kawa_v2.json")
    for i in range(9):
        var race=RACE.instantiate()
        root.add_child(race)
        race.set_physics_process(false)
        Input.action_press("throttle",0.5)
        var t=Time.get_ticks_usec()
        for tick in range(120):
            race._physics_process(1.0/120.0)
        var elapsed=int(Time.get_ticks_usec()-t)
        Input.action_release("throttle")
        race.queue_free()
        for j in range(10):
            await process_frame
        print("cycle ",i+1," objects ",int(Performance.get_monitor(Performance.OBJECT_COUNT))," static_bytes ",int(Performance.get_monitor(Performance.MEMORY_STATIC))," tick120_us ",elapsed)
    quit()
