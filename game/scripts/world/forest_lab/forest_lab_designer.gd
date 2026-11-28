extends Control
class_name NitroForestLabDesigner
## FOREST LAB Tree Designer (issue #54): a developer-only tool to look at, tune and save the eight tree species. It is reached
## from DEVELOPER > TREE DESIGNER, never from a race, and it touches nothing of the game: edits regenerate ONLY the preview
## meshes of this scene, presets are JSON files under user://forest_lab_presets/ (a name that exists is never overwritten
## silently), and "USE ON TOUGE" only sets the developer preset the Touge FOREST LAB reads when it builds a world.
## Views: EDITED, COMPARE (stock | edited), GALLERY (all eight species with their edits), STAND (30 trees of the species).
## Camera: drag / one finger = orbit, wheel / pinch = zoom, right mouse + W A S D Q E = fly (see NitroForestLabCamera).
const F = preload("res://scripts/world/forest_lab/nitro_tree_factory.gd")
const S = preload("res://scripts/world/forest_lab/forest_lab_settings.gd")
const CAM = preload("res://scripts/world/forest_lab/forest_lab_camera.gd")
const STYLE = preload("res://scripts/ui/hud_style.gd")
const BOOT_SCENE: String = "res://scenes/boot.tscn"
## [key, label, min, max, step]
const SLIDERS: Array = [["height","HEIGHT",0.6,1.6,0.02],["crown","CROWN WIDTH",0.6,1.6,0.02],["density","FOLIAGE DENSITY",0.5,1.6,0.05],
    ["trunk","TRUNK",0.6,1.8,0.02],["lean","LEAN",0.0,0.18,0.01],["blossom","BLOSSOM / BERRIES",0.0,1.6,0.1],
    ["saturation","SATURATION",0.5,1.5,0.02],["brightness","BRIGHTNESS",0.7,1.3,0.02],["tiers","CONIFER TIERS (0 = AUTO)",0,12,1],["variant","SHAPE VARIANT",0,7,1]]
const VIEWS: Array[String] = ["EDITED","COMPARE  STOCK | EDITED","GALLERY  ALL 8","STAND  30 TREES"]
const LODS: Array[String] = ["NEAR","FAR","BOTH"]

var navigate_enabled: bool = true
var last_scene: String = ""
var species: int = F.Type.OAK
var season: int = F.Season.SUMMER
var view: int = 0
var lod_mode: int = 0
var density: int = 1
var scale_all: float = 1.0
var edits: Dictionary = {}            # species id -> params dict (only the keys that were changed)
var status_text: String = ""
var ui_unit: float = 1.0
var cam: Camera3D
var stage: Node3D
var _mat: ShaderMaterial
var _dirty: bool = true
var _viewport: SubViewport
var _sliders: Dictionary = {}
var _slider_labels: Dictionary = {}
var _info: Label
var _status: Label
var _name_edit: LineEdit
var _load_pick: OptionButton
var _confirm_overwrite: String = ""
var _mesh_cache: Dictionary = {}

func _ready() -> void:
    STYLE.ensure_settings()
    var vp: Vector2 = get_viewport_rect().size
    var portrait: bool = vp.y > vp.x
    ui_unit = clampf(vp.x/700.0,1.0,2.2) if portrait else 1.0
    theme = STYLE.screen_theme(ui_unit)
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var bg := ColorRect.new()
    bg.color = Color(0.05,0.045,0.08)
    add_child(bg)
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _build_viewport(portrait)
    _build_panel(portrait)
    _sync_ui()

func _process(_delta: float) -> void:
    if _dirty:
        _dirty = false
        _rebuild()

# ----------------------------------------------------------------------------------------- 3D side

func _build_viewport(portrait: bool) -> void:
    var cont := SubViewportContainer.new()
    cont.name = "Preview"
    cont.stretch = true
    add_child(cont)
    if portrait:
        cont.anchor_left = 0.0
        cont.anchor_right = 1.0
        cont.anchor_top = 0.0
        cont.anchor_bottom = 0.46
    else:
        cont.anchor_left = 0.0
        cont.anchor_right = 0.62
        cont.anchor_top = 0.0
        cont.anchor_bottom = 1.0
    cont.offset_left = 0.0
    cont.offset_right = 0.0
    cont.offset_top = 0.0
    cont.offset_bottom = 0.0
    _viewport = SubViewport.new()
    _viewport.name = "Viewport"
    _viewport.handle_input_locally = false
    _viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    cont.add_child(_viewport)
    var env := Environment.new()
    var sky := Sky.new()
    var sm := ProceduralSkyMaterial.new()
    sm.sky_top_color = Color("4b5f94")
    sm.sky_horizon_color = Color("f0b985")
    sm.ground_horizon_color = Color("7d8362")
    sm.ground_bottom_color = Color("3a4a31")
    sky.sky_material = sm
    env.sky = sky
    env.background_mode = Environment.BG_SKY
    env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    env.ambient_light_energy = 0.9
    var we := WorldEnvironment.new()
    we.environment = env
    _viewport.add_child(we)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-40.0,38.0,0.0)
    sun.light_energy = 1.5
    sun.shadow_enabled = false          # #48: no dynamic shadows
    _viewport.add_child(sun)
    var ground := MeshInstance3D.new()
    var disc := CylinderMesh.new()
    disc.top_radius = 140.0
    disc.bottom_radius = 140.0
    disc.height = 0.2
    ground.mesh = disc
    var gm := StandardMaterial3D.new()
    gm.albedo_color = Color("5f7a3f")
    gm.roughness = 1.0
    ground.material_override = gm
    ground.position.y = -0.11
    _viewport.add_child(ground)
    stage = Node3D.new()
    stage.name = "Stage"
    _viewport.add_child(stage)
    cam = CAM.new()
    cam.fov = 45.0
    cam.far = 600.0
    _viewport.add_child(cam)
    _mat = F.make_material(0.0)          # no sway in the studio: shapes stand still

func _mesh(t: int, lod: int, p: Dictionary) -> ArrayMesh:
    var key: String = F.params_key(t,lod,season,p)
    if _mesh_cache.has(key):
        return _mesh_cache[key]
    if _mesh_cache.size() > 160:
        _mesh_cache.clear()
    var m: ArrayMesh = F.make_mesh(t,lod,season,p)
    _mesh_cache[key] = m
    return m

func current_params(t: int = -1) -> Dictionary:
    return F.clamp_params(edits.get(species if t < 0 else t,{}))

func _lods() -> Array[int]:
    if lod_mode == 0:
        return [F.LOD.NEAR]
    if lod_mode == 1:
        return [F.LOD.FAR]
    return [F.LOD.NEAR,F.LOD.FAR]

func _tree(t: int, lod: int, p: Dictionary, pos: Vector3, label: String = "") -> void:
    var mi := MeshInstance3D.new()
    mi.mesh = _mesh(t,lod,p)
    mi.material_override = _mat
    mi.position = pos
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    stage.add_child(mi)
    if label != "":
        var l := Label3D.new()
        l.text = label
        l.font_size = 40
        l.pixel_size = 0.012
        l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        l.no_depth_test = true
        l.modulate = Color("f1e9f7")
        l.outline_modulate = Color("15131f")
        l.outline_size = 10
        l.position = pos+Vector3(0.0,F.BASE_HEIGHT[t]*float(p["height"])+1.6,0.0)
        stage.add_child(l)

func _rebuild() -> void:
    for c in stage.get_children():
        stage.remove_child(c)
        c.queue_free()
    var lods: Array[int] = _lods()
    var h: float = F.BASE_HEIGHT[species]*float(current_params()["height"])
    var focus: Vector3 = Vector3(0.0,maxf(h*0.45,0.7),0.0)
    var dist: float = maxf(h,4.0)*2.7
    var gap: float = maxf(h*0.9,6.0)
    match view:
        0:
            for i in range(lods.size()):
                _tree(species,lods[i],current_params(),Vector3((float(i)-float(lods.size()-1)*0.5)*gap,0.0,0.0),
                    "FAR" if lods[i] == F.LOD.FAR else ("NEAR" if lods.size() > 1 else ""))
            dist *= 1.0 if lods.size() == 1 else 1.6
        1:
            for i in range(lods.size()):
                var z: float = (float(i)-float(lods.size()-1)*0.5)*gap*1.4
                _tree(species,lods[i],F.clamp_params({"variant":int(current_params()["variant"])}),Vector3(-gap*0.65,0.0,z),"STOCK")
                _tree(species,lods[i],current_params(),Vector3(gap*0.65,0.0,z),"EDITED")
            dist *= 1.8
        2:
            for t in range(8):
                var tl: int = lods[0]
                _tree(t,tl,current_params(t),Vector3((float(t)-3.5)*13.0,0.0,0.0),F.species_name(t).to_upper())
            focus = Vector3(0.0,5.0,0.0)
            dist = 96.0
        3:
            var near_mm := MultiMesh.new()
            var far_mm := MultiMesh.new()
            var np: Array[Transform3D] = []
            var fp: Array[Transform3D] = []
            var p: Dictionary = current_params()
            var n: int = 30
            for i in range(n):
                var a: float = float(i)*2.399963
                var r: float = 6.0+22.0*sqrt(float(i)/float(n))
                var sc: float = 0.85+0.3*fposmod(sin(float(i)*12.9898)*43758.5453,1.0)
                var xf := Transform3D(Basis(Vector3.UP,float(i)*1.7).scaled(Vector3.ONE*sc),Vector3(cos(a)*r,0.0,sin(a)*r))
                (np if r < 17.0 else fp).append(xf)
            for pair in [[near_mm,np,F.LOD.NEAR],[far_mm,fp,F.LOD.FAR]]:
                var mm: MultiMesh = pair[0]
                var arr: Array = pair[1]
                if arr.is_empty():
                    continue
                mm.transform_format = MultiMesh.TRANSFORM_3D
                mm.mesh = _mesh(species,int(pair[2]),p)
                mm.instance_count = arr.size()
                for k in range(arr.size()):
                    mm.set_instance_transform(k,arr[k])
                var inst := MultiMeshInstance3D.new()
                inst.multimesh = mm
                inst.material_override = _mat
                stage.add_child(inst)
            focus = Vector3(0.0,h*0.4,0.0)
            dist = 62.0
    cam.focus(focus,dist)
    var near_t: int = F.tri_count(_mesh(species,F.LOD.NEAR,current_params()))
    var far_t: int = F.tri_count(_mesh(species,F.LOD.FAR,current_params()))
    _info.text = "%s  •  %s\nNEAR %d tris  •  FAR %d tris  •  %.1f m tall  •  100 trees = %d k tris" % [
        F.species_name(species).to_upper(),F.SEASON_NAMES[season].to_upper(),near_t,far_t,h,int(round(float(near_t)/10.0))]

# ------------------------------------------------------------------------------------------ UI side

func _build_panel(portrait: bool) -> void:
    var panel := PanelContainer.new()
    panel.name = "Panel"
    add_child(panel)
    if portrait:
        panel.anchor_left = 0.0
        panel.anchor_right = 1.0
        panel.anchor_top = 0.46
        panel.anchor_bottom = 1.0
    else:
        panel.anchor_left = 0.62
        panel.anchor_right = 1.0
        panel.anchor_top = 0.0
        panel.anchor_bottom = 1.0
    panel.offset_left = 0.0
    panel.offset_right = 0.0
    panel.offset_top = 0.0
    panel.offset_bottom = 0.0
    var scroll := ScrollContainer.new()
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    panel.add_child(scroll)
    var col := VBoxContainer.new()
    col.name = "Controls"
    col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    col.add_theme_constant_override("separation",int(7.0*ui_unit))
    scroll.add_child(col)
    var title := Label.new()
    title.text = "FOREST LAB  •  TREE DESIGNER"
    title.add_theme_font_override("font",STYLE.BOLD)
    title.add_theme_font_size_override("font_size",int(24.0*ui_unit))
    col.add_child(title)
    _info = Label.new()
    _info.add_theme_font_size_override("font_size",int(15.0*ui_unit))
    _info.add_theme_color_override("font_color",STYLE.GOLD_LIGHT)
    col.add_child(_info)
    var pick := HFlowContainer.new()
    col.add_child(pick)
    pick.add_child(_option("Species",F.SPECIES_NAMES,species,func(i: int): _on_species(i)))
    pick.add_child(_option("Season",F.SEASON_NAMES,season,func(i: int): season = i; _dirty = true))
    pick.add_child(_option("View",VIEWS,view,func(i: int): view = i; _dirty = true))
    pick.add_child(_option("Lod",LODS,lod_mode,func(i: int): lod_mode = i; _dirty = true))
    for sp in SLIDERS:
        col.add_child(_slider_row(str(sp[0]),str(sp[1]),float(sp[2]),float(sp[3]),float(sp[4])))
    var forest := Label.new()
    forest.text = "FOREST (Touge preset)"
    forest.add_theme_font_size_override("font_size",int(16.0*ui_unit))
    forest.add_theme_color_override("font_color",STYLE.MUTED)
    col.add_child(forest)
    var frow := HFlowContainer.new()
    col.add_child(frow)
    frow.add_child(_option("Density",S.DENSITY_NAMES,density,func(i: int): density = i))
    var sc_row := _slider_row("__scale","TREE SCALE",0.7,1.4,0.02)
    col.add_child(sc_row)
    var acts := HFlowContainer.new()
    col.add_child(acts)
    _btn(acts,"RESET TREE",func(): reset_species())
    _btn(acts,"RESET ALL",func(): reset_all())
    _name_edit = LineEdit.new()
    _name_edit.name = "Preset name"
    _name_edit.placeholder_text = "preset name"
    _name_edit.max_length = 32
    _name_edit.custom_minimum_size = Vector2(190.0*ui_unit,48.0*ui_unit)
    col.add_child(_name_edit)
    var prow := HFlowContainer.new()
    col.add_child(prow)
    _btn(prow,"SAVE PRESET",func(): save_preset(_name_edit.text))
    _load_pick = OptionButton.new()
    _load_pick.name = "Load preset"
    _load_pick.custom_minimum_size = Vector2(190.0*ui_unit,48.0*ui_unit)
    prow.add_child(_load_pick)
    _btn(prow,"LOAD",func(): load_preset(_load_pick.get_item_text(_load_pick.selected) if _load_pick.item_count > 0 else ""))
    _btn(prow,"DELETE",func(): delete_preset(_load_pick.get_item_text(_load_pick.selected) if _load_pick.item_count > 0 else ""))
    var trow := HFlowContainer.new()
    col.add_child(trow)
    _btn(trow,"USE ON TOUGE",func(): use_on_touge(_name_edit.text if _name_edit.text != "" else (_load_pick.get_item_text(_load_pick.selected) if _load_pick.item_count > 0 else "")))
    _btn(trow,"STOCK GEOMETRY",func(): stock_geometry())
    _btn(trow,"COPY JSON",func(): DisplayServer.clipboard_set(JSON.stringify(preset_data(),"  ")); _say("PRESET COPIED TO THE CLIPBOARD"))
    _btn(trow,"PASTE JSON",func(): paste_json(DisplayServer.clipboard_get()))
    _status = Label.new()
    _status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _status.add_theme_font_size_override("font_size",int(15.0*ui_unit))
    _status.add_theme_color_override("font_color",Color(1.0,0.78,0.45))
    col.add_child(_status)
    _btn(col,"BACK",func(): back())
    _refresh_preset_list()

func _btn(parent: Node, caption: String, action: Callable) -> Button:
    var b := Button.new()
    b.text = caption
    b.name = caption
    b.custom_minimum_size = Vector2(118.0*ui_unit,48.0*ui_unit)
    b.add_theme_font_size_override("font_size",int(15.0*ui_unit))
    STYLE.style_button(b,ui_unit)
    b.pressed.connect(action)
    parent.add_child(b)
    return b

func _option(nm: String, items: Array, selected: int, on_pick: Callable) -> OptionButton:
    var o := OptionButton.new()
    o.name = nm
    o.custom_minimum_size = Vector2(150.0*ui_unit,48.0*ui_unit)
    o.add_theme_font_size_override("font_size",int(15.0*ui_unit))
    for it in items:
        o.add_item(str(it))
    o.select(selected)
    o.item_selected.connect(on_pick)
    return o

func _slider_row(key: String, label: String, lo: float, hi: float, step: float) -> Control:
    var row := HBoxContainer.new()
    row.name = "Row "+key
    var l := Label.new()
    l.text = label
    l.custom_minimum_size.x = 170.0*ui_unit
    l.add_theme_font_size_override("font_size",int(14.0*ui_unit))
    row.add_child(l)
    var s := HSlider.new()
    s.name = key
    s.min_value = lo
    s.max_value = hi
    s.step = step
    s.custom_minimum_size = Vector2(150.0*ui_unit,40.0*ui_unit)
    s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    s.value_changed.connect(func(v: float): set_param(key,v))
    row.add_child(s)
    var vl := Label.new()
    vl.custom_minimum_size.x = 52.0*ui_unit
    vl.add_theme_font_size_override("font_size",int(14.0*ui_unit))
    row.add_child(vl)
    _sliders[key] = s
    _slider_labels[key] = vl
    return row

func _say(t: String) -> void:
    status_text = t
    if _status != null:
        _status.text = t

## Slider / test entry: one knob of the selected species (or the forest-wide scale).
func set_param(key: String, value: float) -> void:
    if key == "__scale":
        scale_all = clampf(value,0.7,1.4)
    else:
        var e: Dictionary = edits.get(species,{})
        e[key] = value
        edits[species] = e
    if _slider_labels.has(key):
        (_slider_labels[key] as Label).text = ("%d" % int(value)) if key == "tiers" or key == "variant" else "%.2f" % value
    _dirty = true

func _on_species(i: int) -> void:
    species = i
    _sync_ui()
    _dirty = true

## Slider values follow the selected species / loaded preset.
func _sync_ui() -> void:
    var p: Dictionary = current_params()
    for sp in SLIDERS:
        var k: String = str(sp[0])
        var s: HSlider = _sliders.get(k)
        if s != null:
            s.set_value_no_signal(float(p[k]))
            (_slider_labels[k] as Label).text = ("%d" % int(p[k])) if k == "tiers" or k == "variant" else "%.2f" % float(p[k])
    var sc: HSlider = _sliders.get("__scale")
    if sc != null:
        sc.set_value_no_signal(scale_all)
        (_slider_labels["__scale"] as Label).text = "%.2f" % scale_all

func reset_species() -> void:
    edits.erase(species)
    _sync_ui()
    _dirty = true
    _say("%s BACK TO STOCK" % F.species_name(species).to_upper())

func reset_all() -> void:
    edits.clear()
    scale_all = 1.0
    density = 1
    _sync_ui()
    _dirty = true
    _say("ALL SPECIES BACK TO STOCK")

# ---------------------------------------------------------------------------------------------- presets

func preset_data() -> Dictionary:
    var sp: Dictionary = {}
    for t in edits.keys():
        sp[str(t)] = F.clamp_params(edits[t])
    var mix: Dictionary = {}
    for k in S.DEFAULT_MIX.keys():
        mix[str(k)] = S.DEFAULT_MIX[k]
    return {"version":1,"season":season,"density":density,"scale":scale_all,"mix":mix,"species":sp}

func _refresh_preset_list() -> void:
    if _load_pick == null:
        return
    _load_pick.clear()
    for n in S.list_presets():
        _load_pick.add_item(n)

func save_preset(nm: String) -> void:
    var overwrite: bool = _confirm_overwrite != "" and _confirm_overwrite == S.safe_name(nm)
    var err: String = S.save_preset(nm,preset_data(),overwrite)
    if err == "":
        _confirm_overwrite = ""
        _say("SAVED PRESET '%s'" % S.safe_name(nm))
        _refresh_preset_list()
    elif err.contains("ALREADY EXISTS"):
        _confirm_overwrite = S.safe_name(nm)
        _say(err+"\nOR PRESS SAVE PRESET AGAIN TO OVERWRITE IT")
    else:
        _say(err)

func apply_data(d: Dictionary) -> void:
    var cfg: Dictionary = S.apply_preset(S.defaults(),d)
    season = int(cfg["season"])
    density = int(cfg["density"])
    scale_all = float(cfg["scale"])
    edits = (cfg["params"] as Dictionary).duplicate(true)
    _sync_ui()
    _dirty = true

func load_preset(nm: String) -> void:
    var d: Dictionary = S.load_preset(nm)
    if d.is_empty():
        _say("NO PRESET NAMED '%s'" % nm)
        return
    apply_data(d)
    _name_edit.text = S.safe_name(nm)
    _say("LOADED PRESET '%s'" % S.safe_name(nm))

func delete_preset(nm: String) -> void:
    if nm == "":
        return
    S.delete_preset(nm)
    _refresh_preset_list()
    _say("DELETED PRESET '%s'" % S.safe_name(nm))

func paste_json(text: String) -> void:
    var d: Dictionary = S.parse_json_text(text)
    if d.is_empty():
        _say("THE CLIPBOARD HOLDS NO FOREST LAB PRESET")
        return
    apply_data(d)
    _say("PRESET PASTED")

func use_on_touge(nm: String) -> void:
    var n: String = S.safe_name(nm)
    if n == "" or S.load_preset(n).is_empty():
        _say("SAVE THE PRESET FIRST, THEN USE IT")
        return
    S.write_value("preset",n)
    S.write_value("mode","lab")
    _say("TOUGE ROUTES NOW BUILD WITH FOREST LAB + PRESET '%s'" % n)

func stock_geometry() -> void:
    S.write_value("preset","")
    _say("TOUGE USES THE STOCK TREES (FOREST LAB MODE IS UNCHANGED)")

func back() -> void:
    last_scene = BOOT_SCENE
    if navigate_enabled:
        get_tree().change_scene_to_file(BOOT_SCENE)

func _enter_tree() -> void:
    add_to_group("own_go_back") # Android BACK = back() below; android_back.gd leaves this screen alone

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_GO_BACK_REQUEST:
        back()
