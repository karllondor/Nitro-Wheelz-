extends RefCounted
class_name NitroHudStyle
## Shared drawing kit for the approved Nitro Wheelz driving HUD reference:
## dark glass parallelogram panels, accent-colour neon edge glow, bold italic
## type (Exo 2, SIL OFL 1.1), gold stars and metal controls.
## Everything is drawn with CanvasItem primitives: no textures, one font.

const BOLD = preload("res://assets/fonts/Exo2-ExtraBoldItalic.woff2")
const SEMI = preload("res://assets/fonts/Exo2-SemiBoldItalic.woff2")

# Accent colour is a player setting (pause menu). Every panel edge, glow,
# bar and highlight reads STYLE.PINK at draw time, so changing it recolours
# the whole interface. Name kept for compatibility: it is the accent.
static var PINK: Color = Color(1.0,0.16,0.56)
static var PINK_SOFT: Color = Color(1.0,0.42,0.72)
static var accent_name: String = "pink"
static var sound_on: bool = true
static var vol_engine: float = 1.0
static var vol_tyres: float = 1.0
static var vol_fx: float = 1.0
## Music default sits under the engine: at 0.45 "Night Drift" plays at about
## -26 LUFS in the game, ~1 dB under an idling engine and ~9 dB under the
## car while driving (measured v0.1.21). No ducking: the music just plays.
const MUSIC_DEFAULT: float = 0.45
static var vol_music: float = MUSIC_DEFAULT
static var settings_loaded: bool = false
const ACCENTS: Dictionary = {
    "pink":Color(1.0,0.16,0.56),"violet":Color(0.64,0.34,1.0),"cyan":Color(0.10,0.80,1.0),
    "lime":Color(0.56,0.94,0.18),"orange":Color(1.0,0.52,0.08),"red":Color(1.0,0.16,0.20)}
const ACCENT_ORDER: Array[String] = ["pink","violet","cyan","lime","orange","red"]
const SETTINGS_PATH: String = "user://nitro_settings.cfg"
const WHITE := Color(0.985,0.985,1.0)
const MUTED := Color(0.80,0.81,0.86)
const DIM := Color(0.56,0.57,0.63)
const GOLD := Color(1.0,0.74,0.16)
const GOLD_LIGHT := Color(1.0,0.90,0.48)
const GLASS_TOP := Color(0.085,0.085,0.105,0.90)
const GLASS_BOTTOM := Color(0.020,0.020,0.030,0.90)
const EDGE := Color(0.86,0.87,0.92,0.42)
const SKEW: float = 0.20

static func set_accent(name: String) -> void:
    if not ACCENTS.has(name):
        name = "pink"
    accent_name = name
    PINK = ACCENTS[name]
    PINK_SOFT = PINK.lerp(Color.WHITE,0.35)

static func set_sound(enabled: bool) -> void:
    sound_on = enabled
    var bus: int = AudioServer.get_bus_index("Master")
    if bus >= 0:
        AudioServer.set_bus_mute(bus,not enabled)

static func load_settings() -> void:
    var cfg := ConfigFile.new()
    if cfg.load(SETTINGS_PATH) == OK:
        set_accent(str(cfg.get_value("ui","accent","pink")))
        set_sound(bool(cfg.get_value("audio","sound_on",true)))
        vol_engine = clampf(float(cfg.get_value("audio","engine",1.0)),0.0,1.0)
        vol_tyres = clampf(float(cfg.get_value("audio","tyres",1.0)),0.0,1.0)
        vol_fx = clampf(float(cfg.get_value("audio","effects",1.0)),0.0,1.0)
        vol_music = clampf(float(cfg.get_value("audio","music",MUSIC_DEFAULT)),0.0,1.0)
        # v0.1.20 saved its 0.6 default with every settings change; move an
        # untouched old default to the new mix level once.
        if int(cfg.get_value("audio","mix_rev",0)) < 1 and absf(vol_music-0.6) < 0.001:
            vol_music = MUSIC_DEFAULT
    else:
        set_accent("pink")
        set_sound(true)
    settings_loaded = true

static func ensure_settings() -> void:
    ensure_fonts()
    if not settings_loaded:
        load_settings()

## v0.1.37: the shipped Exo 2 subset has no Polish letters except "ó" (a nickname
## like "Łukasz" or the Park lessons would fall back to a system font on the
## phone and to nothing on other platforms). The official Exo 2 variable font
## (same family, SIL OFL, game/assets/fonts/OFL-Exo2.txt) is registered as the
## fallback of both weights, so missing glyphs are drawn in the same typeface.
const FONT_FALLBACK = preload("res://assets/fonts/Exo2-ItalicVF.ttf")
static var _fonts_ready: bool = false

static func ensure_fonts() -> void:
    if _fonts_ready:
        return
    _fonts_ready = true
    for pair in [[BOLD,800.0],[SEMI,600.0]]:
        var variation := FontVariation.new()
        variation.base_font = FONT_FALLBACK
        var server: TextServer = TextServerManager.get_primary_interface()
        var tag: int = server.name_to_tag("weight") if server != null else 2003265652   # 'wght'
        variation.variation_opentype = {tag:pair[1]}
        (pair[0] as FontFile).fallbacks = [variation]

static func save_settings() -> void:
    var cfg := ConfigFile.new()
    cfg.load(SETTINGS_PATH)  # keep other sections (editor help flag)
    cfg.set_value("ui","accent",accent_name)
    cfg.set_value("audio","sound_on",sound_on)
    cfg.set_value("audio","engine",vol_engine)
    cfg.set_value("audio","tyres",vol_tyres)
    cfg.set_value("audio","effects",vol_fx)
    cfg.set_value("audio","music",vol_music)
    cfg.set_value("audio","mix_rev",1)
    cfg.save(SETTINGS_PATH)

## Layout shared by HUD drawing and touch hit-testing so visuals and
## touch targets always coincide (HUD v3, owner feedback 2026-11-19):
## header = minimap | name + CHASING pill | TOTAL SCORE + clock, LAP in the
## top band beside a centred keep-out for front-camera punch holes, and a
## thin three-lap progress line. Live chain centred under the header (only
## while scoring); round speedometer with the drift angle on the left.
## Native platform profiles keep the approved mobile HUD untouched. Web gets a
## separate profile even when its viewport is portrait (resizable browser).
static func platform_profile() -> String:
    if OS.has_feature("mobile"):
        return "mobile"
    if OS.has_feature("web"):
        return "web"
    return "pc"

## Compact desktop geometry uses bounded pixel dimensions instead of percentages
## of the entire display: ultrawide and small browser windows stay readable.
## The rects are shared with the separate mouse-action control layer.
static func desktop_metrics(s: Vector2, profile: String = "pc") -> Dictionary:
    var w: float = s.x
    var h: float = s.y
    var edge: float = clampf(minf(w,h)*0.018,9.0,19.0)
    if profile == "web":
        edge = maxf(edge,14.0)  # extra browser-canvas inset
    var gap: float = clampf(w*0.009,7.0,14.0)
    var button_w: float = clampf(w*0.059,61.0,86.0)
    var button_h: float = clampf(h*0.062,35.0,43.0)
    var pause_r := Rect2(w-edge-button_w,edge,button_w,button_h)
    var camera_r := Rect2(pause_r.position.x-gap-button_w,edge,button_w,button_h)
    var header_w: float = clampf(w*0.30,170.0,320.0)
    var header_h: float = clampf(h*0.13,72.0,100.0)
    var header := Rect2(edge,edge,header_w,header_h)
    var map_w: float = header_w*0.335
    var map_r := Rect2(header.position.x+8.0,header.position.y+9.0,map_w,header_h*0.66)
    var info_x: float = map_r.end.x+8.0
    var info_w: float = maxf(42.0,header.end.x-info_x-8.0)
    var name_r := Rect2(info_x,header.position.y+7.0,info_w,header_h*0.29)
    var lap_r := Rect2(info_x,header.position.y+header_h*0.34,info_w,header_h*0.25)
    var chase_r := Rect2(info_x,header.position.y+header_h*0.64,info_w,header_h*0.22)
    var bank_w: float = clampf(w*0.20,145.0,224.0)
    var bank_h: float = clampf(h*0.13,74.0,95.0)
    var bank_r := Rect2(camera_r.position.x-gap-bank_w,edge,bank_w,bank_h)
    # Tiny Web viewports: move the banked card to a second row, keeping the
    # camera/pause pair fixed at the top-right.
    if bank_r.position.x < header.end.x+gap:
        bank_r.position = Vector2(w-edge-bank_w,edge+button_h+gap)
    var total_label_r := Rect2(bank_r.position.x+10.0,bank_r.position.y+6.0,bank_w-20.0,bank_h*0.24)
    var total_r := Rect2(bank_r.position.x+10.0,bank_r.position.y+bank_h*0.28,bank_w-20.0,bank_h*0.62)
    var chain_w: float = clampf(w*0.24,178.0,260.0)
    var chain_h: float = clampf(h*0.085,43.0,61.0)
    var chain_r := Rect2(w*0.5-chain_w*0.5,maxf(header.end.y,bank_r.end.y)+gap,chain_w,chain_h)
    var speed_w: float = clampf(w*0.16,135.0,180.0)
    var speed_h: float = clampf(h*0.105,68.0,78.0)
    var speed_r := Rect2(edge,h-edge-speed_h,speed_w,speed_h)
    return {
        "profile":profile,"desktop":true,"portrait":h > w,"header":header,
        "dead":Rect2(),"map":map_r,"lap":lap_r,"name":name_r,"chase":chase_r,
        "total_label":total_label_r,"total":total_r,"bank_panel":bank_r,
        "score":chain_r,"callout":Vector2(w*0.5,h*0.47),
        "pause":pause_r,"camera":camera_r,"speed":speed_r,
        "gauge_centre":speed_r.get_center(),"gauge_radius":0.0,
        "angle":Rect2(speed_r.end.x-62.0,speed_r.position.y+30.0,56.0,30.0),
        "unit":clampf(h/800.0,0.72,1.08)
    }

## Callers that do not request a profile keep the original mobile layout.
## In particular, the touch hit-test and v0.1.21 phone layout tests still
## receive the exact same rectangles as before.
static func metrics(s: Vector2, profile: String = "mobile") -> Dictionary:
    if profile != "mobile":
        return desktop_metrics(s,profile)
    var portrait: bool = s.y > s.x
    if portrait:
        var w: float = s.x
        var mx: float = w*0.022
        var top: float = maxf(s.y*0.016,w*0.03)
        var header := Rect2(mx,top,w-2.0*mx,w*0.215)
        var hy: float = header.position.y
        var hh: float = header.size.y
        # Nothing is drawn in the top-centre band: phones put the front
        # camera there (it cut the old TOTAL SCORE label on the owner's phone).
        var dead := Rect2(w*0.5-w*0.09,0.0,w*0.18,hy+hh*0.30)
        var map := Rect2(header.position.x+w*0.016,hy+hh*0.09,w*0.285,hh*0.76)
        # v0.1.21 owner: LAP sits beside the minimap (left of the camera
        # keep-out, "LAP" over "1/3"); the top band right of the keep-out
        # holds only the BANKED SCORE label.
        var lap := Rect2(map.end.x+w*0.010,hy+hh*0.03,dead.position.x-map.end.x-w*0.016,dead.end.y-hy-hh*0.03)
        var total_label := Rect2(dead.end.x+w*0.012,hy+hh*0.05,header.end.x-w*0.022-dead.end.x-w*0.012,hh*0.24)
        var total := Rect2(w*0.665,hy+hh*0.30,header.end.x-w*0.022-w*0.665,hh*0.57)
        # Centre column under the keep-out: bigger track name, and the chase
        # line drawn straight on the header (no frame inside the frame).
        var name := Rect2(map.end.x+w*0.012,dead.end.y+hh*0.02,total.position.x-map.end.x-w*0.024,hh*0.22)
        var chase := Rect2(name.position.x,name.end.y+hh*0.04,name.size.x,hh*0.26)
        var buttons_y: float = header.end.y+w*0.014
        var gauge_r: float = w*0.135
        # Speedometer lower on the screen (owner, v0.1.21), always clear of
        # the steering joystick (top at 0.853 h - 0.175 w) on wide portraits.
        var gauge_c := Vector2(mx+gauge_r+w*0.012,minf(s.y*0.63,s.y*0.853-w*0.413))
        return {
            "portrait":true,"header":header,"dead":dead,"map":map,"lap":lap,
            "total_label":total_label,"total":total,"name":name,"chase":chase,
            "score":Rect2(w*0.5-w*0.22,header.end.y+w*0.014,w*0.44,w*0.13),
            "callout":Vector2(w*0.5,s.y*0.36),
            "pause":Rect2(w*0.735,buttons_y,w*0.110,w*0.070),
            "camera":Rect2(w*0.862,buttons_y,w*0.116,w*0.070),
            "gauge_centre":gauge_c,"gauge_radius":gauge_r,
            "speed":Rect2(gauge_c-Vector2(gauge_r,gauge_r),Vector2(gauge_r,gauge_r)*2.0),
            "angle":Rect2(gauge_c.x-w*0.075,gauge_c.y+gauge_r+w*0.020,w*0.150,w*0.058),
            "unit":w/700.0
        }
    var h: float = s.y
    var m: float = s.x*0.016
    var header_l := Rect2(m,h*0.016,s.x*0.56,h*0.215)
    var hy_l: float = header_l.position.y
    var hh_l: float = header_l.size.y
    var map_l := Rect2(header_l.position.x+h*0.02,hy_l+hh_l*0.09,s.x*0.14,hh_l*0.76)
    var total_l := Rect2(header_l.end.x-s.x*0.175,hy_l+hh_l*0.30,s.x*0.16,hh_l*0.55)
    var lap_l := Rect2(map_l.end.x+s.x*0.012,hy_l+hh_l*0.05,s.x*0.10,hh_l*0.24)
    var total_label_l := Rect2(total_l.position.x,hy_l+hh_l*0.05,total_l.size.x,hh_l*0.24)
    var name_l := Rect2(map_l.end.x+s.x*0.012,hy_l+hh_l*0.31,total_l.position.x-map_l.end.x-s.x*0.024,hh_l*0.16)
    var chase_l := Rect2(name_l.position.x,name_l.end.y+hh_l*0.03,name_l.size.x,hh_l*0.28)
    # Landscape (desktop / touch laptops): speedometer slightly smaller and
    # higher so it and the drift-angle box clear the joystick (top 0.633 h).
    var gr: float = h*0.13
    var gc := Vector2(m+gr+h*0.02,h*0.40)
    return {
        "portrait":false,"header":header_l,"dead":Rect2(),"map":map_l,"lap":lap_l,
        "total_label":total_label_l,"total":total_l,"name":name_l,"chase":chase_l,
        "score":Rect2(s.x*0.60,h*0.03,s.x*0.22,h*0.14),
        "callout":Vector2(s.x*0.5,h*0.36),
        "pause":Rect2(s.x*0.921,h*0.030,s.x*0.057,h*0.125),
        "camera":Rect2(s.x*0.846,h*0.030,s.x*0.062,h*0.125),
        "gauge_centre":gc,"gauge_radius":gr,
        "speed":Rect2(gc-Vector2(gr,gr),Vector2(gr,gr)*2.0),
        "angle":Rect2(gc.x-h*0.06,gc.y+gr+h*0.015,h*0.12,h*0.06),
        "unit":h/700.0
    }

## Neon glow along an arc (the lower-right edge of round controls), same
## layering as glow_line so circles match the panels.
static func glow_arc(ci: CanvasItem, centre: Vector2, radius: float, a0: float, a1: float,
        colour: Color, width: float, intensity: float = 1.0) -> void:
    var layers: Array = [[7.0,0.05],[4.2,0.10],[2.4,0.24],[1.0,1.0]]
    for layer in layers:
        var c: Color = colour
        c.a = colour.a*float(layer[1])*intensity
        ci.draw_arc(centre,radius,a0,a1,40,c,width*float(layer[0]),true)
    ci.draw_arc(centre,radius,a0,a1,40,colour.lerp(Color.WHITE,0.45),width*0.42,true)

## Font size that fits `txt` into `width` (never larger than `size`).
static func fit_size(txt: String, size: float, width: float, bold: bool = true) -> float:
    var tw: float = text_width(txt,size,bold)
    return size if tw <= width else maxf(8.0,size*width/tw)

static func skew_point(p: Vector2, rect: Rect2, skew: float) -> Vector2:
    return Vector2(p.x+(rect.get_center().y-p.y)*skew,p.y)

## Rounded rectangle outline, optionally sheared like italic type.
static func shape(rect: Rect2, radius: float, skew: float = SKEW, segments: int = 6) -> PackedVector2Array:
    var r: float = minf(radius,minf(rect.size.x,rect.size.y)*0.5)
    var pts := PackedVector2Array()
    var corners: Array = [
        [Vector2(rect.end.x-r,rect.position.y+r),-PI*0.5],
        [Vector2(rect.end.x-r,rect.end.y-r),0.0],
        [Vector2(rect.position.x+r,rect.end.y-r),PI*0.5],
        [Vector2(rect.position.x+r,rect.position.y+r),PI]]
    for corner in corners:
        var c: Vector2 = corner[0]
        var a0: float = corner[1]
        for k in range(segments+1):
            var a: float = a0+PI*0.5*float(k)/float(segments)
            pts.append(skew_point(c+Vector2(cos(a),sin(a))*r,rect,skew))
    return pts

## Path along the lower-right edge (where the reference glows pink).
static func glow_path(rect: Rect2, radius: float, skew: float = SKEW,
        bottom_from: float = 0.52, side_to: float = 0.30) -> PackedVector2Array:
    var r: float = minf(radius,minf(rect.size.x,rect.size.y)*0.5)
    var pts := PackedVector2Array()
    pts.append(skew_point(Vector2(rect.position.x+rect.size.x*bottom_from,rect.end.y),rect,skew))
    var c := Vector2(rect.end.x-r,rect.end.y-r)
    for k in range(9):
        var a: float = PI*0.5-PI*0.5*float(k)/8.0
        pts.append(skew_point(c+Vector2(cos(a),sin(a))*r,rect,skew))
    pts.append(skew_point(Vector2(rect.end.x,rect.position.y+rect.size.y*side_to),rect,skew))
    return pts

static func glow_line(ci: CanvasItem, pts: PackedVector2Array, colour: Color,
        width: float, intensity: float = 1.0) -> void:
    var layers: Array = [[7.0,0.05],[4.2,0.10],[2.4,0.24],[1.0,1.0]]
    for layer in layers:
        var c: Color = colour
        c.a = colour.a*float(layer[1])*intensity
        ci.draw_polyline(pts,c,width*float(layer[0]),true)
    ci.draw_polyline(pts,colour.lerp(Color.WHITE,0.45),width*0.42,true)

static func panel(ci: CanvasItem, rect: Rect2, unit: float, radius: float = 14.0,
        skew: float = SKEW, glow: bool = true, glow_strength: float = 1.0) -> void:
    var pts: PackedVector2Array = shape(rect,radius*unit,skew)
    var cols := PackedColorArray()
    for p in pts:
        var t: float = clampf((p.y-rect.position.y)/maxf(rect.size.y,1.0),0.0,1.0)
        cols.append(GLASS_TOP.lerp(GLASS_BOTTOM,t))
    ci.draw_polygon(pts,cols)
    var outline: PackedVector2Array = pts.duplicate()
    outline.append(pts[0])
    ci.draw_polyline(outline,EDGE,maxf(1.0,1.5*unit),true)
    # Thin specular along the top edge for the glass look.
    var top_edge := PackedVector2Array()
    for k in range(pts.size()):
        if pts[k].y <= rect.position.y+radius*unit*0.35:
            top_edge.append(pts[k])
    if top_edge.size() > 1:
        ci.draw_polyline(top_edge,Color(1,1,1,0.22),maxf(1.0,1.2*unit),true)
    if glow:
        glow_line(ci,glow_path(rect,radius*unit,skew),PINK,2.2*unit,glow_strength)

static func text(ci: CanvasItem, pos: Vector2, txt: String, size: float,
        colour: Color = WHITE, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT,
        width: float = -1.0, bold: bool = true) -> void:
    var font: Font = BOLD if bold else SEMI
    var px: int = maxi(8,int(size))
    # Soft drop shadow keeps numbers readable over bright kerbs.
    ci.draw_string(font,pos+Vector2(1.5,2.0)*maxf(1.0,size/30.0),txt,align,width,px,Color(0,0,0,0.45))
    ci.draw_string(font,pos,txt,align,width,px,colour)

static func text_width(txt: String, size: float, bold: bool = true) -> float:
    var font: Font = BOLD if bold else SEMI
    return font.get_string_size(txt,HORIZONTAL_ALIGNMENT_LEFT,-1,maxi(8,int(size))).x

static func ascent(size: float, bold: bool = true) -> float:
    var font: Font = BOLD if bold else SEMI
    return font.get_ascent(maxi(8,int(size)))

static func star(ci: CanvasItem, centre: Vector2, radius: float, filled: bool, unit: float) -> void:
    var pts := PackedVector2Array()
    for k in range(10):
        var a: float = -PI*0.5+PI*float(k)/5.0
        var r: float = radius if k%2 == 0 else radius*0.47
        pts.append(centre+Vector2(cos(a),sin(a))*r)
    var outline: PackedVector2Array = pts.duplicate()
    outline.append(pts[0])
    if filled:
        var cols := PackedColorArray()
        for p in pts:
            var t: float = clampf((p.y-(centre.y-radius))/(radius*2.0),0.0,1.0)
            cols.append(GOLD_LIGHT.lerp(GOLD,t))
        ci.draw_polygon(pts,cols)
        ci.draw_polyline(outline,Color(0.55,0.33,0.02,0.9),1.3*unit,true)
    else:
        ci.draw_polygon(pts,PackedColorArray([Color(0.16,0.16,0.19,0.95)]))
        ci.draw_polyline(outline,Color(0.42,0.43,0.48,0.95),1.4*unit,true)

## Slanted separator used inside the header bar.
static func separator(ci: CanvasItem, x: float, y0: float, y1: float, unit: float) -> void:
    var lean: float = (y1-y0)*SKEW*0.9
    ci.draw_line(Vector2(x+lean*0.5,y0),Vector2(x-lean*0.5,y1),Color(0.80,0.81,0.86,0.55),
        maxf(1.0,1.6*unit),true)

static func time_string(seconds: float) -> String:
    return "%02d:%05.2f" % [int(seconds/60.0),fmod(seconds,60.0)]

static func short_time(seconds: float) -> String:
    return "%d:%05.2f" % [int(seconds/60.0),fmod(seconds,60.0)]

## Menu/garage/pause/editor buttons in the same visual language as the HUD.
static func button_box(unit: float, state: String = "normal") -> StyleBoxFlat:
    var box := StyleBoxFlat.new()
    box.skew = Vector2(SKEW*0.6,0.0)
    box.set_corner_radius_all(int(12.0*unit))
    box.anti_aliasing = true
    box.content_margin_left = 14.0*unit
    box.content_margin_right = 14.0*unit
    box.content_margin_top = 8.0*unit
    box.content_margin_bottom = 8.0*unit
    match state:
        "hover","focus":
            box.bg_color = Color(0.11,0.06,0.10,0.96)
            box.border_color = PINK
            box.set_border_width_all(int(maxf(2.0,2.2*unit)))
            box.shadow_color = Color(1.0,0.16,0.56,0.40)
            box.shadow_size = int(9.0*unit)
        "pressed":
            box.bg_color = Color(0.30,0.04,0.17,0.98)
            box.border_color = PINK_SOFT
            box.set_border_width_all(int(maxf(2.0,2.4*unit)))
            box.shadow_color = Color(1.0,0.16,0.56,0.55)
            box.shadow_size = int(12.0*unit)
        "selected":
            box.bg_color = Color(0.17,0.05,0.12,0.98)
            box.border_color = PINK
            box.set_border_width_all(int(maxf(2.0,2.6*unit)))
            box.shadow_color = Color(1.0,0.16,0.56,0.45)
            box.shadow_size = int(10.0*unit)
        _:
            box.bg_color = Color(0.045,0.045,0.06,0.94)
            box.border_color = Color(0.86,0.87,0.92,0.45)
            box.set_border_width_all(int(maxf(1.0,1.5*unit)))
            box.border_width_bottom = int(maxf(2.0,2.6*unit))
    return box

static func style_button(button: Button, unit: float, selected: bool = false) -> void:
    button.add_theme_stylebox_override("normal",button_box(unit,"selected" if selected else "normal"))
    button.add_theme_stylebox_override("hover",button_box(unit,"hover"))
    button.add_theme_stylebox_override("focus",button_box(unit,"focus"))
    button.add_theme_stylebox_override("pressed",button_box(unit,"pressed"))
    button.add_theme_font_override("font",BOLD)
    button.add_theme_color_override("font_color",WHITE)
    button.add_theme_color_override("font_hover_color",WHITE)
    button.add_theme_color_override("font_focus_color",WHITE)
    button.add_theme_color_override("font_pressed_color",Color(1.0,0.82,0.92))

static func modal_box(unit: float) -> StyleBoxFlat:
    var box := StyleBoxFlat.new()
    box.bg_color = Color(0.035,0.035,0.05,0.985)
    box.border_color = PINK
    box.set_border_width_all(int(maxf(2.0,2.0*unit)))
    box.set_corner_radius_all(int(18.0*unit))
    box.shadow_color = Color(1.0,0.16,0.56,0.30)
    box.shadow_size = int(16.0*unit)
    return box

## Theme for whole screens: Exo 2 italic everywhere and HUD-style buttons.
static func screen_theme(unit: float) -> Theme:
    var theme := Theme.new()
    theme.default_font = SEMI
    for state in ["normal","hover","focus","pressed"]:
        theme.set_stylebox(state,"Button",button_box(unit,state))
    theme.set_font("font","Button",BOLD)
    theme.set_color("font_color","Button",WHITE)
    theme.set_color("font_hover_color","Button",WHITE)
    theme.set_color("font_focus_color","Button",WHITE)
    theme.set_color("font_pressed_color","Button",Color(1.0,0.82,0.92))
    theme.set_stylebox("panel","PanelContainer",modal_box(unit))
    return theme
