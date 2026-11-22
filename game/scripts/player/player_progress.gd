extends RefCounted
class_name NitroPlayerProgress
## What the player card shows (v0.1.35): the tracks this player has driven with
## their best time / points / stars, and the total of the best stars per track.
## Built from the local run history (user://nitro_local_runs.json) and the list
## of tracks that can still be loaded (built-ins + MY TRACKS): a track that no
## longer exists is not listed, because it could not be driven again.
const RESULTS = preload("res://scripts/ui/race_results.gd")

## known: [{"id": record id, "name": display name, "path": track file}].
## Returns the driven tracks, most recently driven first:
## [{id, name, path, best_seconds, best_points, best_stars, runs, last}].
static func rows(known: Array) -> Array:
    var by_track: Dictionary = {}
    for r in RESULTS.read_runs():
        if not (r is Dictionary):
            continue
        var run: Dictionary = r
        var id: String = str(run.get("track_id",""))
        if id == "":
            continue
        if not by_track.has(id):
            by_track[id] = {"best_seconds":INF,"best_points":0,"best_stars":0,"runs":0,"last":""}
        var acc: Dictionary = by_track[id]
        acc["best_seconds"] = minf(float(acc["best_seconds"]),float(run.get("seconds",INF)))
        acc["best_points"] = maxi(int(acc["best_points"]),int(run.get("score",0)))
        acc["best_stars"] = maxi(int(acc["best_stars"]),int(run.get("stars",0)))
        acc["runs"] = int(acc["runs"])+1
        if str(run.get("date","")) > str(acc["last"]):
            acc["last"] = str(run.get("date",""))
    var out: Array = []
    for t in known:
        var track: Dictionary = t
        var id2: String = str(track.get("id",""))
        if not by_track.has(id2):
            continue
        var row: Dictionary = (by_track[id2] as Dictionary).duplicate()
        row["id"] = id2
        row["name"] = str(track.get("name",id2))
        row["path"] = str(track.get("path",""))
        out.append(row)
    out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["last"]) > str(b["last"]))
    return out

## Total stars collected = the best stars of every driven track, summed.
static func total_stars(rows_in: Array) -> int:
    var total: int = 0
    for r in rows_in:
        total += int((r as Dictionary).get("best_stars",0))
    return total

## "★★☆" for 0..3 stars.
static func star_text(stars: int) -> String:
    return "★".repeat(clampi(stars,0,3))+"☆".repeat(3-clampi(stars,0,3))
