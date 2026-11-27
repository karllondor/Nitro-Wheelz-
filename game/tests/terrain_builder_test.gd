extends SceneTree
## v0.1.25 terrain-first builder: Country -> Landscape -> GENERATE TERRAIN
## -> draw -> automatic terrain adaptation -> SAVE / LOAD / DRIVE.
##  * three countries, their landscapes, event modes; GENERATE again = new seed
##  * red tiles refuse road (with the reason), amber accepted
##  * DRAW / ERASE / UNDO / REDO / CLEAR restore the exact road AND world
##  * CLOSE LOOP connects the ends over buildable tiles; ROUTE mode drives
##    an open start-finish road
##  * multi-touch: pinch zoom + twist rotate never paint a tile
##  * SAVE -> the race rebuilds the IDENTICAL world (terrain heights,
##    structures, scenery) and road; EDIT reopens it in the builder.
const CAT = preload("res://scripts/world/terrain/terrain_catalog.gd")
const TT = preload("res://scripts/world/terrain/terrain_track.gd")
const TRACK = preload("res://scripts/world/drift_track.gd")
const DNA = preload("res://scripts/world/track_dna.gd")
const SCENE = preload("res://scenes/terrain_builder.tscn")
const DRAFT: String = "user://nitro_terrain_builder_draft.json"

var b: Node3D

func _initialize() -> void:
    call_deferred("_run")

func _fail(msg: String) -> void:
    print("FAIL: "+msg)
    quit(1)

static func height_hash(w: NitroTerrainWorld) -> int:
    var acc: int = 17
    for k in range(0,w.field.height.size(),3):
        acc = (acc*31+int(round(w.field.height[k]*100.0))) & 0x7fffffff
    return acc

static func same_links(a: Dictionary, b2: Dictionary) -> bool:
    if a.size() != b2.size():
        return false
    for k in a.keys():
        if not b2.has(k):
            return false
        var x: Array = (a[k] as Array).duplicate()
        var y: Array = (b2[k] as Array).duplicate()
        x.sort()
        y.sort()
        if x != y:
            return false
    return true

func _cells(state: int, limit: int) -> Array[Vector2i]:
    var out: Array[Vector2i] = []
    for c in b.build_map.keys():
        if int(b.build_map[c]["state"]) == state:
            out.append(c)
            if out.size() >= limit:
                break
    return out

func _run() -> void:
    DirAccess.remove_absolute(DRAFT)
    b = SCENE.instantiate()
    root.add_child(b)
    await process_frame
    if b.stage != "setup" or not b.setup_box.visible or b.build_box.visible:
        _fail("Builder must open on the COUNTRY / LANDSCAPE setup sheet")
        return
    for c in ["country_japan","country_poland","country_ireland","event_practice","event_club","event_pro",
            "GENERATE TERRAIN","VIEW","DRAW ROAD ▶"]:
        if not b.buttons.has(c):
            _fail("Setup button missing: "+c)
            return
    # Every country lists exactly its own landscapes (8 in total).
    var total: int = 0
    for country in CAT.COUNTRIES:
        b._pick_country(country)
        for a in CAT.of_country(country):
            if not b.buttons.has("land_"+a):
                _fail("Landscape button missing for "+a)
                return
            total += 1
    if total != 8:
        _fail("Expected 8 landscapes, got %d" % total)
        return
    # GENERATE TERRAIN = separate step; GENERATE again = a NEW landscape.
    b._pick_country("ireland")
    b._pick_landscape("ie_coast")
    b._pick_event("pro")
    b._generate_pressed()
    var seed1: int = b.terrain_seed
    var fp1: int = b.world.field.fingerprint()
    if b.world.desc["archetype"] != "ie_coast" or b.world.desc["event_mode"] != "pro":
        _fail("GENERATE TERRAIN must build the selected landscape + event")
        return
    b._generate_pressed()
    if b.terrain_seed == seed1 or b.world.field.fingerprint() == fp1:
        _fail("GENERATE again must roll a new landscape")
        return
    # --- build stage
    b._enter_build()
    if b.stage != "build" or b.setup_box.visible or not b.build_box.visible:
        _fail("DRAW ROAD must switch to the build bar")
        return
    for c2 in ["DRAW","ERASE","↶ UNDO","↷ REDO","CLEAR","b_LOOP","b_CLOSE","b_AUTO","b_VIEW","b_SAVE","b_DRIVE"]:
        if not b.buttons.has(c2):
            _fail("Build button missing: "+c2)
            return
    # Red tiles (sea / cliff edge) refuse road, with a reason in the status.
    var reds: Array[Vector2i] = _cells(2,1)
    if reds.is_empty():
        _fail("Coastal cliffs need red (sea / cliff edge) tiles")
        return
    b.begin_stroke(reds[0])
    b.end_stroke()
    if b.grid.is_road(reds[0]) or not b.status_label.text.begins_with("NOT BUILDABLE"):
        _fail("A red tile must be refused with its reason (%s)" % b.status_label.text)
        return
    # Draw a straight strip on buildable tiles.
    var strip: Array[Vector2i] = []
    for y in range(2,b.grid.rows-2):
        for x in range(b.grid.cols-1,-1,-1):
            var run: Array[Vector2i] = []
            for k in range(4):
                var c3 := Vector2i(x-k,y)
                if b.build_map.has(c3) and int(b.build_map[c3]["state"]) < 2:
                    run.append(c3)
            if run.size() == 4:
                strip = run
                break
        if not strip.is_empty():
            break
    if strip.is_empty():
        _fail("No 4-tile buildable strip found")
        return
    var flat_hash: int = height_hash(b.world)
    b.begin_stroke(strip[0])
    for c4 in strip.slice(1):
        b.move_stroke(c4)
    b.end_stroke()
    if b.grid.tile_count() != 4:
        _fail("Stroke must lay 4 linked tiles (got %d)" % b.grid.tile_count())
        return
    var drawn_hash: int = height_hash(b.world)
    if drawn_hash == flat_hash:
        _fail("Drawing a road must adapt the terrain around it")
        return
    var drawn_links: Dictionary = b.grid.snapshot()
    b._undo()
    if b.grid.tile_count() != 0 or height_hash(b.world) != flat_hash:
        _fail("UNDO must restore the empty road AND the untouched terrain")
        return
    b._redo()
    if not same_links(b.grid.snapshot(),drawn_links) or height_hash(b.world) != drawn_hash:
        _fail("REDO must restore the same road and the same adapted terrain")
        return
    b._set_erase()
    b.begin_stroke(strip[3])
    b.end_stroke()
    b._set_draw()
    if b.grid.tile_count() != 3:
        _fail("ERASE must remove the touched tile")
        return
    b._clear()
    if b.grid.tile_count() != 0 or height_hash(b.world) != flat_hash:
        _fail("CLEAR must remove the road and restore the terrain")
        return
    # Multi-touch: pinch + twist zoom/rotate and never paint.
    b.cam_dist = 900.0
    b.goal_dist = 900.0
    var vp: Vector2 = b.get_viewport().get_visible_rect().size
    var mid: Vector2 = b.map_rect.get_center()
    var e0 := InputEventScreenTouch.new()
    e0.index = 0
    e0.pressed = true
    e0.position = mid-Vector2(80,0)
    b._unhandled_input(e0)
    var e1 := InputEventScreenTouch.new()
    e1.index = 1
    e1.pressed = true
    e1.position = mid+Vector2(80,0)
    b._unhandled_input(e1)
    var d1 := InputEventScreenDrag.new()
    d1.index = 1
    d1.position = mid+Vector2(0,200)
    b._unhandled_input(d1)
    var yaw_after: float = b.cam_yaw
    var dist_after: float = b.cam_dist
    for e in [e0,e1]:
        e.pressed = false
        b._unhandled_input(e)
    if b.grid.tile_count() != 0:
        _fail("A two-finger gesture must not paint road")
        return
    if absf(yaw_after) < 10.0 or absf(dist_after-900.0) < 1.0:
        _fail("Twist must rotate (yaw %.1f) and pinch must zoom (dist %.1f)" % [yaw_after,dist_after])
        return
    # CLOSE LOOP: an open U of tiles + auto connection over buildable tiles.
    b._auto()
    if not b.track_ok or not bool(TT.route_order(b.grid)["closed"]):
        _fail("AUTO must produce a drivable loop on this terrain: "+b.status_label.text)
        return
    var loop: Array = TT.route_order(b.grid)["order"]
    var a0: Vector2i = loop[0]
    var a1: Vector2i = loop[1]
    var a2: Vector2i = loop[2]
    (b.grid.links[a0] as Array).erase(a1)
    (b.grid.links[a1] as Array).erase(a0)
    b.grid.erase(a1)
    b.route_start = a2
    b._after_edit()
    if b.track_ok:
        _fail("An open chain is not a drivable LOOP")
        return
    b._close_loop()
    if not bool(TT.route_order(b.grid)["closed"]) or not b.track_ok:
        _fail("CLOSE LOOP must reconnect the ends over buildable tiles: "+b.status_label.text)
        return
    # SAVE: the race rebuilds the identical world.
    var builder_hash: int = height_hash(b.world)
    var builder_struct: Dictionary = b.world.structure_counts()
    var builder_scen: Dictionary = b.world.scenery.summary()["counts"]
    var builder_len: float = float(b.last_eval["compiled"]["length_metres"])
    var before: Array = []
    for f in DirAccess.get_files_at("user://"):
        before.append(f)
    if b._persist_track("Terrain Test Circuit") != "":
        _fail("SAVE failed: "+b.status_label.text)
        return
    var saved: String = ""
    for f2 in DirAccess.get_files_at("user://"):
        if not before.has(f2) and f2.begins_with("nitro_track_terrain_"):
            saved = "user://"+f2
    if saved == "":
        _fail("SAVE must write a nitro_track_terrain_*.json listed in MY TRACKS")
        return
    var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(saved))
    if TT.world_of(raw).is_empty() or not (raw.get("elevation",null) is Dictionary):
        _fail("Saved track must carry the world descriptor and knot heights")
        return
    var race_track: NitroDriftTrack = TRACK.new()
    race_track.track_data_path = saved
    root.add_child(race_track)
    if race_track.terrain == null:
        _fail("Race track must rebuild the terrain world")
        return
    if height_hash(race_track.terrain) != builder_hash:
        _fail("Race terrain differs from the builder terrain")
        return
    if race_track.terrain.structure_counts() != builder_struct:
        _fail("Race structures differ: %s vs %s" % [race_track.terrain.structure_counts(),builder_struct])
        return
    if race_track.terrain.scenery.summary()["counts"] != builder_scen:
        _fail("Race scenery differs from the builder scenery")
        return
    if absf(race_track.length_metres-builder_len) > 0.01:
        _fail("Race road length differs from the builder road")
        return
    var preview: NitroDriftTrack = b.road_root.get_child(0)
    for i in range(0,race_track.centerline.size(),37):
        if race_track.centerline[i].distance_to(preview.centerline[i]) > 0.001 \
                or absf(race_track.heights[i]-preview.heights[i]) > 0.001:
            _fail("Builder road != race road at sample %d" % i)
            return
    root.remove_child(race_track)
    race_track.free()
    # LOAD: EDIT reopens the saved track in the builder (same world + road).
    var links_saved: Dictionary = b.grid.snapshot()
    root.remove_child(b)
    b.free()
    ProjectSettings.set_setting("nitro/terrain_edit_track",saved)
    b = SCENE.instantiate()
    root.add_child(b)
    await process_frame
    if b.stage != "build" or not same_links(b.grid.snapshot(),links_saved) or height_hash(b.world) != builder_hash:
        _fail("EDIT / LOAD must reopen the same road on the same adapted terrain")
        return
    # ROUTE mode: open start-finish road, DRIVE writes and selects it.
    b._toggle_topology()
    if b.topology != "route":
        _fail("ROUTE toggle failed")
        return
    b._auto()
    if not b.track_ok or bool(TT.route_order(b.grid)["closed"]):
        _fail("AUTO in ROUTE mode must give a drivable open route: "+b.status_label.text)
        return
    var data: Dictionary = b.current_track_data("t","t")
    if bool(data["closed"]) or str(data["topology"]) != "open":
        _fail("Route data must be saved as an open topology")
        return
    ProjectSettings.set_setting("nitro/selected_track","")
    b._write(b.DRIVE_PATH,"drive","drive")
    var dc: Dictionary = DNA.read_track(b.DRIVE_PATH)
    if not bool(dc.get("ok",false)) or bool(dc["closed"]):
        _fail("DRIVE file must compile as an open route")
        return
    DirAccess.remove_absolute(saved)
    DirAccess.remove_absolute(b.DRIVE_PATH)
    DirAccess.remove_absolute(DRAFT)
    print("PASS: terrain builder - 3 countries / 8 landscapes / events, GENERATE + new landscape, red tiles refused with reason, draw adapts terrain, UNDO/REDO/ERASE/CLEAR restore road + terrain, pinch/twist without painting, AUTO loop, CLOSE LOOP, SAVE -> race world identical (terrain, structures, scenery, road), EDIT reopens, ROUTE mode + DRIVE file")
    quit(0)
