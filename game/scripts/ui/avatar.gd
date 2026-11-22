extends Control
class_name NitroAvatar
## The player's profile picture (v0.1.35): a small cartoon character drawn with
## vectors (no art assets): skin tone, hair colour + style, t-shirt colour. The
## look is a dictionary of palette indexes (NitroDriverProfile.avatar()).
const PROFILE = preload("res://scripts/player/driver_profile.gd")
const STYLE = preload("res://scripts/ui/hud_style.gd")

var look: Dictionary = {"skin":1,"hair":1,"shirt":0,"style":0}

func _init() -> void:
    clip_contents = true
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    custom_minimum_size = Vector2(64,64)

func set_look(value: Dictionary) -> void:
    look = value.duplicate()
    queue_redraw()

func _col(part: String, key: String) -> Color:
    var pal: Array[Color] = PROFILE.palette(part)
    return pal[clampi(int(look.get(key,0)),0,pal.size()-1)]

func _draw() -> void:
    var s: float = minf(size.x,size.y)
    if s <= 1.0:
        return
    var o: Vector2 = (size-Vector2(s,s))*0.5
    var p := func(x: float, y: float) -> Vector2: return o+Vector2(x,y)*s
    var skin: Color = _col("skin","skin")
    var hair: Color = _col("hair","hair")
    var shirt: Color = _col("shirt","shirt")
    var style: int = clampi(int(look.get("style",0)),0,PROFILE.HAIR_STYLES.size()-1)
    # Glass background with the accent ring.
    var bg := StyleBoxFlat.new()
    bg.bg_color = Color(0.09,0.08,0.14)
    bg.set_corner_radius_all(int(s*0.24))
    bg.border_color = STYLE.PINK
    bg.set_border_width_all(maxi(2,int(s*0.035)))
    draw_style_box(bg,Rect2(o,Vector2(s,s)))
    # Hair behind the head (long hair falls to the shoulders).
    if style == 1:
        draw_rect(Rect2(p.call(0.235,0.38),Vector2(0.53,0.40)*s),hair)
    # T-shirt: shoulders + collar.
    var body := PackedVector2Array([p.call(0.10,1.02),p.call(0.14,0.80),p.call(0.30,0.72),p.call(0.70,0.72),p.call(0.86,0.80),p.call(0.90,1.02)])
    draw_colored_polygon(body,shirt)
    draw_colored_polygon(PackedVector2Array([p.call(0.42,0.72),p.call(0.58,0.72),p.call(0.50,0.80)]),skin.darkened(0.12))
    # Neck + head + ears.
    draw_rect(Rect2(p.call(0.44,0.60),Vector2(0.12,0.16)*s),skin.darkened(0.10))
    draw_circle(p.call(0.255,0.47),0.045*s,skin.darkened(0.06))
    draw_circle(p.call(0.745,0.47),0.045*s,skin.darkened(0.06))
    draw_circle(p.call(0.5,0.45),0.245*s,skin)
    # Hair on top.
    var c: Vector2 = p.call(0.5,0.45)
    match style:
        0, 1:   # SHORT / LONG: cap of hair with a fringe
            draw_polygon_arc(c,0.265*s,PI,TAU,hair)
            draw_colored_polygon(PackedVector2Array([p.call(0.27,0.40),p.call(0.38,0.30),p.call(0.62,0.30),p.call(0.73,0.40),p.call(0.66,0.36),p.call(0.34,0.36)]),hair)
        2:      # BUZZ: a thin cap
            draw_polygon_arc(c,0.252*s,PI*1.12,TAU-PI*0.12,hair.darkened(0.05))
        3:      # CAP: dome in the shirt colour + a brim
            draw_polygon_arc(c,0.27*s,PI,TAU,shirt.lightened(0.05))
            draw_colored_polygon(PackedVector2Array([p.call(0.50,0.36),p.call(0.86,0.38),p.call(0.84,0.43),p.call(0.50,0.42)]),shirt.darkened(0.25))
    # Face.
    draw_circle(p.call(0.42,0.47),0.024*s,Color(0.10,0.08,0.10))
    draw_circle(p.call(0.58,0.47),0.024*s,Color(0.10,0.08,0.10))
    draw_arc(p.call(0.5,0.52),0.075*s,0.25*PI,0.75*PI,10,Color(0.45,0.16,0.20),maxf(1.5,0.016*s),true)

## Filled circular segment between two angles (a polygon fan from the centre).
func draw_polygon_arc(center: Vector2, radius: float, a0: float, a1: float, col: Color) -> void:
    var pts := PackedVector2Array([center])
    var steps: int = 20
    for i in range(steps+1):
        var a: float = lerpf(a0,a1,float(i)/float(steps))
        pts.append(center+Vector2(cos(a),sin(a))*radius)
    draw_colored_polygon(pts,col)
