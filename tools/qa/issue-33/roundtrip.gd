extends SceneTree
const RACE=preload("res://scenes/race.tscn")
const EDIT=preload("res://scenes/track_editor.tscn")
const TT=preload("res://scripts/world/terrain/terrain_track.gd")
const CAT=preload("res://scripts/world/terrain/terrain_catalog.gd")
const FIELD=preload("res://scripts/world/terrain/terrain_field.gd")
const DNA=preload("res://scripts/world/track_dna.gd")
const FOOT=preload("res://tests/terrain_water_footprint_test.gd")
const INPUT="user://qa33_modes.json"
var errors: Array = []

func _initialize() -> void:
    call_deferred("run")

func ck(ok: bool, msg: String) -> void:
    if not ok:
        errors.append(msg)

func drive_trace(race) -> Array:
    race._restart()
    var ix: int = 32
    var tangent: Vector2 = (race.track.centerline[ix+1]-race.track.centerline[ix]).normalized()
    var best := 1.0
    for side in [1,-1]:
        race.model.reset(race.track.centerline[ix],tangent.angle()+PI/2+deg_to_rad(30)*side)
        race.model.velocity=tangent*16
        race.model.rear_traction=0.4
        Input.action_press("throttle",0.6)
        for t in range(18):
            race._physics_process(1.0/120)
            best=maxf(best,race.scorer.multiplier)
        Input.action_release("throttle")
    race.model.reset(race.track.centerline[ix],tangent.angle()+PI/2)
    for t in range(140):
        race._physics_process(1.0/120)
    return [race.scorer.total,best,race.scorer.chains_banked,race.scorer.transitions]

func run() -> void:
    for mode in ["practice","club","pro"]:
        var desc=CAT.descriptor("pl_ojcow",621727,-1,mode)
        desc.road_style="road" if mode!="pro" else "circuit"
        var gen=TT.generate_loop(TT.new_grid(),FIELD.new("pl_ojcow",621727),desc,3)
        var fh=FileAccess.open(INPUT,FileAccess.WRITE)
        fh.store_string(JSON.stringify(gen.data,"",false,true))
        fh.close()
        var editor=EDIT.instantiate()
        root.add_child(editor)
        editor._load_path(INPUT)
        var src: Dictionary=editor.data.duplicate(true)
        var chosen: int=5
        editor.selected=chosen
        editor._set_start()
        editor._reverse()
        var expected: Dictionary=editor.data.duplicate(true)
        editor._undo()
        editor._reverse()
        ck(editor.data==expected,mode+" undo and reverse")
        ck(editor._persist_track("QA33 "+mode),mode+" save")
        editor._load_path(editor.last_saved_path)
        var saved: Dictionary=editor.data.duplicate(true)
        var max_height_diff:=0.0
        for i in range(src.control_points.size()):
            var orig:int=posmod(chosen-i,src.control_points.size())
            ck(saved.control_points[i]==src.control_points[orig],mode+" reordered knots")
            max_height_diff=maxf(max_height_diff,absf(saved.elevation.knot_heights[i]-src.elevation.knot_heights[orig]))
        var path:String=editor.last_saved_path
        ck(max_height_diff<0.02,mode+" elevation changed after pure permutation")
        ck(saved.world==src.world and saved.width_m==src.width_m,mode+" world width")
        editor.free()
        ProjectSettings.set_setting("nitro/selected_track",INPUT)
        var first=RACE.instantiate()
        root.add_child(first)
        var orig_zones:Array=first.track.event_layout.zones.duplicate(true)
        first.free()
        ProjectSettings.set_setting("nitro/selected_track",path)
        var race=RACE.instantiate()
        root.add_child(race)
        race.set_physics_process(false)
        var zones:Array=race.track.event_layout.zones
        ck(race.track.event_mode==mode,mode+" loaded mode")
        ck((zones.is_empty() if mode=="practice" else zones.size()>0 and orig_zones!=zones),mode+" regenerated")
        var w:Dictionary=FOOT.measure(race.track.terrain,DNA.compile(saved))
        print(mode," width ",2*race.track.halfwidths[0]," zone count ",orig_zones.size()," -> ",zones.size()," max absolute height change ",max_height_diff," water ",w)
        if mode=="practice":
            var active=drive_trace(race)
            race.track.event_mode=""
            var normal=drive_trace(race)
            print("Practice vs legacy [banked, max combo, chains banked, transitions] ",active," ",normal)
            ck(active==normal and active[0]>0 and active[1]>1.0,"Practice parity")
            race.track.event_mode=mode
        var records="user://nitro_local_runs.json"
        var existed=FileAccess.file_exists(records)
        var before=FileAccess.get_file_as_string(records) if existed else ""
        race._show_results()
        ck(FileAccess.file_exists(records)==existed and (not existed or FileAccess.get_file_as_string(records)==before),mode+" touched records")
        race.free()
    print("Checks: ",errors)
    quit(0 if errors.is_empty() else 1)
