extends RefCounted
class_name NitroTrackGenerator
## Minimal deterministic on-device Track DNA creator (beta, not an editor).
## Create one closed loop variant from validated authored reference data.
## Invalid variants are rejected; only a successful loop is saved to user://.
const DNA = preload("res://scripts/world/track_dna.gd")
const SOURCE: String = "res://tracks/shin_kawa_full_circuit.json"
const OUTPUT: String = "user://nitro_generated_track.json"

static func generate(seed: int) -> Dictionary:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
    if not (parsed is Dictionary):
        return {"ok":false,"error":"Missing source track"}
    var source: Dictionary = parsed
    var base_points: Array = source["control_points"]
    for attempt in range(24):
        var rng: RandomNumberGenerator = RandomNumberGenerator.new()
        rng.seed = seed + attempt*1009
        var stretch_x: float = rng.randf_range(0.90,1.10)
        var stretch_y: float = rng.randf_range(0.91,1.09)
        var points: Array = []
        for i in range(base_points.size()):
            var src: Array = base_points[i]
            var jitter: Vector2 = Vector2(rng.randf_range(-2.4,2.4),rng.randf_range(-2.4,2.4))
            var p: Vector2 = Vector2(float(src[0])*stretch_x,float(src[1])*stretch_y)+jitter
            points.append([snappedf(p.x,0.001),snappedf(p.y,0.001)])
        var data: Dictionary = source.duplicate(true)
        data["id"] = "generated_%d" % seed
        data["name"] = "CREATED TRACK #%d" % (seed%100000)
        data["seed"] = seed
        data["generator_version"] = 2
        data["control_points"] = points
        data["description"] = "Local beta generated track; validated closed circuit."
        var result: Dictionary = DNA.compile(data)
        if not bool(result.get("ok",false)):
            continue
        var file: FileAccess = FileAccess.open(OUTPUT,FileAccess.WRITE)
        if file == null:
            return {"ok":false,"error":"Storage unavailable"}
        file.store_string(JSON.stringify(data,"  "))
        file.close()
        var checked: Dictionary = DNA.read_track(OUTPUT)
        if not bool(checked.get("ok",false)):
            return {"ok":false,"error":"Saved track failed validation"}
        return {"ok":true,"path":OUTPUT,"seed":seed,"length_metres":result["length_metres"]}
    return {"ok":false,"error":"Could not generate a collision-free closed loop"}
