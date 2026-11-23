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
    if race.hud != null:
        race.hud.race_time = 57.24
        race.hud.lap = 2
        race.hud.lap_limit = 3
        race.hud.track_progress = 0.43
        race.hud.speed = 86.0
        race.hud.drift_degrees = 26.0
        race.hud.score = 12850
        race.hud.best_score = 22500
        race.hud.drift_score = 720
        race.hud.combo = 2.3
        race.hud.track_name = "SHIN-KAWA"
        race.hud.queue_redraw()
