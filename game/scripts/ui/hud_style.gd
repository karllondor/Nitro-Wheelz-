extends RefCounted
class_name NitroHudStyle
## Shared drawing kit for the approved Nitro Wheelz driving HUD reference:
## dark glass parallelogram panels, hot-pink neon edge glow, bold italic
## type (Exo 2, SIL OFL 1.1), gold stars and metal controls.
## Everything is drawn with CanvasItem primitives: no textures, one font.

const BOLD = preload("res://assets/fonts/Exo2-ExtraBoldItalic.woff2")
const SEMI = preload("res://assets/fonts/Exo2-SemiBoldItalic.woff2")

const PINK := Color(1.0,0.16,0.56)
const PINK_SOFT := Color(1.0,0.42,0.72)
const WHITE := Color(0.985,0.985,1.0)
const MUTED := Color(0.80,0.81,0.86)
const DIM := Color(0.56,0.57,0.63)
const GOLD := Color(1.0,0.74,0.16)
const GOLD_LIGHT := Color(1.0,0.90,0.48)
const GLASS_TOP := Color(0.085,0.085,0.105,0.90)
const GLASS_BOTTOM := Color(0.020,0.020,0.030,0.90)
const EDGE := Color(0.86,0.87,0.92,0.42)
const SKEW: float = 0.20

## Layout shared by HUD drawing and touch hit-testing so visuals and
## touch targets always coincide. Portrait sizes follow the reference image
## proportions relative to screen WIDTH; vertical anchors stay fractions of
## height so taller 20:9 phones keep the controls in thumb reach.
static func metrics(s: Vector2) -> Dictionary:
    var portrait: bool = s.y > s.x
    if portrait:
        var w: float = s.x
        var mx: float = w*0.022
        var top: float = maxf(s.y*0.016,w*0.03)
        var header := Rect2(mx,top,w-2.0*mx,w*0.112)
        var stats_y: float = header.end.y+w*0.026
        var stats_h: float = w*0.126
        var gap: float = w*0.012
        var inner: float = w-2.0*mx-2.0*gap
        var total := Rect2(mx,stats_y,inner*0.300,stats_h)
        var score := Rect2(total.end.x+gap,stats_y,inner*0.255,stats_h)
        var chase := Rect2(score.end.x+gap,stats_y,inner-total.size.x-score.size.x,stats_h)
        var buttons_y: float = stats_y+stats_h+w*0.028
        return {
            "portrait":true,"header":header,"total":total,"score":score,"chase":chase,
            "pause":Rect2(w*0.690,buttons_y,w*0.126,w*0.074),
            "camera":Rect2(w*0.840,buttons_y,w*0.134,w*0.074),
            "angle":Rect2(mx*1.6,s.y*0.596,w*0.152,w*0.066),
            "speed":Rect2(mx*1.1,s.y*0.596+w*0.088,w*0.318,w*0.094),
            "unit":w/700.0
        }
    var h: float = s.y
    var m: float = s.x*0.016
    var header_l := Rect2(m,h*0.016,s.x*0.46,h*0.150)
    var sy: float = header_l.end.y+h*0.022
    var sh: float = h*0.142
    var g: float = s.x*0.008
    var total_l := Rect2(m,sy,s.x*0.14,sh)
    var score_l := Rect2(total_l.end.x+g,sy,s.x*0.12,sh)
    var chase_l := Rect2(score_l.end.x+g,sy,header_l.end.x-score_l.end.x-g,sh)
    return {
        "portrait":false,"header":header_l,"total":total_l,"score":score_l,"chase":chase_l,
        "pause":Rect2(s.x*0.921,h*0.030,s.x*0.057,h*0.125),
        "camera":Rect2(s.x*0.846,h*0.030,s.x*0.062,h*0.125),
        "angle":Rect2(m*1.5,h*0.545,s.x*0.085,h*0.088),
        "speed":Rect2(m,h*0.645,s.x*0.180,h*0.118),
        "unit":h/700.0
    }

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
