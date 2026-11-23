extends Node3D
## Deterministic review scene only. Not used by the shipped main scene.
## A race is rendered with fixed representative telemetry, so Linux and Web
## snapshots compare the actual HUD/control code (not a Figma mock-up).
const RACE = preload("res://scenes/race.tscn")

var race: Node3D

func _ready() -> void:
    ProjectSettings.set_setting("nitro/selected_track","res://tracks/shin_kawa_v2.json")
    ProjectSettings.set_setting("nitro/car_variant","red")
    race = RACE.instantiate()
    add_child(race)
    await get_tree().process_frame
    race.set_physics_process(false)
    var view: NitroRaceHUD = race.get("hud")
    if view != null:
        view.race_time = 57.24
        view.lap = 2
        view.lap_limit = 3
        view.track_progress = 0.43
        view.speed = 86.0
        view.drift_degrees = 26.0
        view.score = 12850
        view.best_score = 22500
        view.drift_score = 720
        view.combo = 2.3
        view.track_name = "SHIN-KAWA"
        view.queue_redraw()
