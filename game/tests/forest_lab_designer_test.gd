extends SceneTree
## FOREST LAB Tree Designer (issue #54), developer tool: the scene builds, every control is real (none decorative), edits move the
## preview geometry, the four views build what they say, presets round trip without silent overwrite, USE ON TOUGE / STOCK
## GEOMETRY set the developer preset, and DEVELOPER > FOREST LAB / DENSITY / TREE DESIGNER exist and work.
## NOT proven here: the feel of orbit / pinch on a phone (owner QA).
const F = preload("res://scripts/world/forest_lab/nitro_tree_factory.gd")
const S = preload("res://scripts/world/forest_lab/forest_lab_settings.gd")
const DEV = preload("res://scripts/dev_settings.gd")
const DESIGNER = preload("res://scenes/forest_lab_designer.tscn")
const BOOT = preload("res://scenes/boot.tscn")

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    printerr("FAIL: "+message)
    quit(1)

func _stage_meshes(d: Control) -> Array:
    var out: Array = []
    for c in d.stage.get_children():
        if c is MeshInstance3D:
            out.append(c)
    return out

func _run() -> void:
    var was: Dictionary = {"mode":DEV.get_value(S.SECTION,"mode","classic"),"preset":DEV.get_value(S.SECTION,"preset",""),
        "density":DEV.get_value(S.SECTION,"density",1)}
    var err: String = await _checks()
    DEV.set_value(S.SECTION,"mode",was["mode"])
    DEV.set_value(S.SECTION,"preset",was["preset"])
    DEV.set_value(S.SECTION,"density",was["density"])
    S.delete_preset("designer_test_54")
    if err != "":
        _fail(err)
        return
    for _f in range(3):
        await process_frame
    quit(0)

func _checks() -> String:
    var d: Control = DESIGNER.instantiate()
    d.set("navigate_enabled",false)
    root.add_child(d)
    for _f in range(3):
        await process_frame
    if d.find_child("Preview",true,false) == null or d.find_child("Panel",true,false) == null or d.stage == null:
        return "the Designer needs a 3D preview and a control panel"
    var sp_opt: OptionButton = d.find_child("Species",true,false) as OptionButton
    if sp_opt == null or sp_opt.item_count != 8:
        return "the species picker must list all eight species"
    for k in ["height","crown","density","trunk","lean","blossom","saturation","brightness","tiers","variant","__scale"]:
        if d.find_child(k,true,false) == null or not (d.find_child(k,true,false) is HSlider):
            return "slider missing: "+k
    if not (d._info as Label).text.contains("OAK") or not (d._info as Label).text.contains("tris"):
        return "the info line must name the species and its triangle counts"
    if _stage_meshes(d).size() != 1:
        return "EDITED / NEAR shows one tree (%d)" % _stage_meshes(d).size()
    # -------------------------------------------------------------- an edit moves the preview geometry
    var base_h: float = (_stage_meshes(d)[0] as MeshInstance3D).mesh.get_aabb().size.y
    d.set_param("height",1.4)
    await process_frame
    await process_frame
    var tall_h: float = (_stage_meshes(d)[0] as MeshInstance3D).mesh.get_aabb().size.y
    if tall_h < base_h*1.2:
        return "the HEIGHT slider must change the preview (%.2f -> %.2f)" % [base_h,tall_h]
    var hs: HSlider = d.find_child("height",true,false)
    d._on_species(F.Type.TALL_FIR)
    await process_frame
    if absf(hs.value-1.0) > 0.001:
        return "switching species must show that species' own values (fir height %.2f)" % hs.value
    d._on_species(F.Type.OAK)
    await process_frame
    if absf(hs.value-1.4) > 0.001:
        return "the oak edit must be remembered (%.2f)" % hs.value
    # ------------------------------------------------------------------------------------------ views
    d.view = 1
    d._dirty = true
    await process_frame
    await process_frame
    if _stage_meshes(d).size() != 2:
        return "COMPARE shows stock and edited (%d trees)" % _stage_meshes(d).size()
    var a: float = (_stage_meshes(d)[0] as MeshInstance3D).mesh.get_aabb().size.y
    var b: float = (_stage_meshes(d)[1] as MeshInstance3D).mesh.get_aabb().size.y
    if absf(a-b) < 1.0:
        return "COMPARE must show a stock and an edited tree that differ (%.2f vs %.2f)" % [a,b]
    d.view = 2
    d._dirty = true
    await process_frame
    await process_frame
    if _stage_meshes(d).size() != 8:
        return "GALLERY shows all eight species (%d)" % _stage_meshes(d).size()
    d.view = 3
    d._dirty = true
    await process_frame
    await process_frame
    var stands: int = 0
    for c in d.stage.get_children():
        if c is MultiMeshInstance3D:
            stands += 1
    if stands < 1:
        return "STAND shows a group of trees as MultiMeshes"
    d.view = 0
    d.lod_mode = 2
    d._dirty = true
    await process_frame
    await process_frame
    if _stage_meshes(d).size() != 2:
        return "LOD BOTH shows NEAR and FAR side by side"
    # --------------------------------------------------------------------------------------- presets
    var nm: String = "designer_test_54"
    S.delete_preset(nm)
    d.save_preset(nm)
    if not S.list_presets().has(nm) or not d.status_text.contains("SAVED"):
        return "SAVE PRESET must write the preset (%s)" % d.status_text
    d.set_param("crown",1.5)
    d.save_preset(nm)
    if not d.status_text.contains("ALREADY EXISTS"):
        return "an existing preset must not be overwritten silently (%s)" % d.status_text
    if absf(float(S.load_preset(nm)["species"]["2"]["crown"])-1.0) > 0.001:
        return "the refused save must leave the file as it was"
    d.save_preset(nm)
    if absf(float(S.load_preset(nm)["species"]["2"]["crown"])-1.5) > 0.001:
        return "the confirmed save must overwrite"
    d.reset_all()
    if absf((d.find_child("crown",true,false) as HSlider).value-1.0) > 0.001 or not d.edits.is_empty():
        return "RESET ALL must bring every species back to stock"
    d.load_preset(nm)
    if absf((d.find_child("crown",true,false) as HSlider).value-1.5) > 0.001 or absf((d.find_child("height",true,false) as HSlider).value-1.4) > 0.001:
        return "LOAD must bring the saved edits back into the sliders"
    d.paste_json("garbage")
    if not d.status_text.contains("NO FOREST LAB PRESET"):
        return "a broken clipboard must be refused"
    d.paste_json(JSON.stringify(d.preset_data()))
    if not d.status_text.contains("PASTED"):
        return "a valid preset text must be accepted"
    d.use_on_touge("nonexistent_zz")
    if str(DEV.get_value(S.SECTION,"preset","")) == "nonexistent_zz":
        return "USE ON TOUGE needs a saved preset"
    DEV.set_value(S.SECTION,"mode","classic")
    d.use_on_touge(nm)
    if str(DEV.get_value(S.SECTION,"preset","")) != nm or S.mode() != "lab":
        return "USE ON TOUGE must select the preset and switch FOREST LAB on"
    var cfg: Dictionary = S.read()
    if absf(float(S.params_for(cfg,F.Type.OAK)["crown"])-1.5) > 0.001:
        return "the Touge config must carry the preset's oak edits"
    d.stock_geometry()
    if str(DEV.get_value(S.SECTION,"preset","x")) != "" or not (S.read()["params"] as Dictionary).is_empty():
        return "STOCK GEOMETRY must clear the preset"
    d.back()
    if d.last_scene != "res://scenes/boot.tscn":
        return "BACK returns to the menu"
    d.queue_free()
    await process_frame
    # ------------------------------------------------------------- DEVELOPER page: switch, density, entry
    DEV.set_value(S.SECTION,"mode","classic")
    DEV.set_value(S.SECTION,"density",1)
    var menu: Control = BOOT.instantiate()
    menu.set("navigate_enabled",false)
    root.add_child(menu)
    await process_frame
    menu.call("show_page","dev")
    await process_frame
    var lab_b: Button = menu.find_child("Forest lab mode",true,false) as Button
    if lab_b == null or not lab_b.text.contains("CLASSIC"):
        return "DEVELOPER > FOREST LAB must exist and default to CLASSIC"
    lab_b.pressed.emit()
    await process_frame
    if S.mode() != "lab" or not (menu.find_child("Forest lab mode",true,false) as Button).text.contains("ON"):
        return "the FOREST LAB switch must turn on"
    (menu.find_child("Forest lab mode",true,false) as Button).pressed.emit()
    await process_frame
    if S.mode() != "classic":
        return "the FOREST LAB switch must turn off again"
    (menu.find_child("Forest density",true,false) as Button).pressed.emit()
    await process_frame
    if int(S.read()["density"]) != 2:
        return "FOREST DENSITY must cycle (MEDIUM -> HIGH)"
    var td: Button = menu.find_child("Tree designer",true,false) as Button
    if td == null:
        return "DEVELOPER > TREE DESIGNER must exist"
    td.pressed.emit()
    if str(menu.get("last_scene")) != "res://scenes/forest_lab_designer.tscn":
        return "TREE DESIGNER must open the designer scene (%s)" % str(menu.get("last_scene"))
    menu.queue_free()
    await process_frame
    print("PASS: FOREST LAB Tree Designer - builds (3D preview + panel), eight species, 10 sliders + forest scale all real, an edit moves the preview geometry and is remembered per species, EDITED / COMPARE / GALLERY / STAND / LOD BOTH build what they say, presets save / refuse silent overwrite / confirm / load / paste, USE ON TOUGE and STOCK GEOMETRY set the developer preset, DEVELOPER > FOREST LAB (default CLASSIC) / DENSITY / TREE DESIGNER work; NOT proven: touch orbit and pinch feel on a phone")
    return ""
