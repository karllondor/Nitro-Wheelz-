extends CanvasLayer
class_name NitroBusy
## v0.1.27 loading / processing overlay (owner: long operations looked like
## the app froze). Dims the screen, blocks touches, shows a title
## ("GENERATING TERRAIN…", "LOADING TRACK…") with eight spinning dots and a
## chequered-flag progress strip. The long jobs themselves run in slices
## (NitroSteps.run_sliced), so the animation keeps moving while they work.
## compact = a small pill at the top instead of a full dim (quick terrain
## updates after a stroke), still blocking input.
## poster = the game's LOADING SCREEN (owner request 2026-11-22): the NITRO
## WHEELZ key art fills the screen (fitted by height, never stretched) and the
## spinner / title / chequered progress strip sit in a slim bar at the bottom.
const STYLE = preload("res://scripts/ui/hud_style.gd")
const POSTER_PATH: String = "res://assets/brand/loading_screen.jpg"
const POSTER_BG: Color = Color(0.039,0.008,0.075)   # the art's own edge colour

var title: String = "PROCESSING"
var detail: String = ""
var progress: float = -1.0          # < 0 = unknown (moving chequers)
var compact: bool = false
var poster: bool = false
var _poster_tex: Texture2D = null
var _view: Control
var _t0: int = 0

static func open(parent: Node, text: String, small: bool = false, with_poster: bool = false) -> NitroBusy:
    var b: NitroBusy = load("res://scripts/ui/busy_overlay.gd").new()
    b.title = text
    b.compact = small
    b.poster = with_poster and not small
    b.layer = 90
    b.name = "Busy overlay"
    parent.add_child(b)
    return b

## Where the key art is drawn: always fitted by HEIGHT and centred, so nothing
## is stretched and the logo at the top is never cropped. Narrow phones lose a
## little off the sides (the art keeps its subject in the middle 60 %), wide
## screens get dark bars of the art's own edge colour.
static func poster_rect(screen: Vector2, art: Vector2) -> Rect2:
    var k: float = screen.y/maxf(art.y,1.0)
    var size: Vector2 = art*k
    return Rect2((screen-size)*0.5,size)

func _ready() -> void:
    _t0 = Time.get_ticks_msec()
    if poster:
        if ResourceLoader.exists(POSTER_PATH):
            _poster_tex = load(POSTER_PATH) as Texture2D
        if _poster_tex == null:
            poster = false      # art missing: fall back to the plain loading card
    _view = Control.new()
    _view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    # v0.1.32: the compact pill (quick terrain updates) lets touches through
    # so the map can still be moved / zoomed; the full card blocks input.
    _view.mouse_filter = Control.MOUSE_FILTER_IGNORE if compact else Control.MOUSE_FILTER_STOP
    _view.draw.connect(_draw_view)
    add_child(_view)

func set_progress(f: float) -> void:
    progress = clampf(f,0.0,1.0)
    if _view != null:
        _view.queue_redraw()

func set_text(t: String, d: String = "") -> void:
    title = t
    detail = d
    if _view != null:
        _view.queue_redraw()

func close() -> void:
    queue_free()

func _process(_delta: float) -> void:
    if _view != null:
        _view.queue_redraw()

func _draw_view() -> void:
    var s: Vector2 = _view.size
    var u: float = clampf(s.x/720.0,0.6,2.0)
    var t: float = float(Time.get_ticks_msec()-_t0)/1000.0
    var box: Rect2
    if poster:
        _draw_poster(s,u,t)
        return
    if compact:
        box = Rect2(Vector2(s.x*0.5-230.0*u,s.y*0.13),Vector2(460.0*u,74.0*u))
    else:
        _view.draw_rect(Rect2(Vector2.ZERO,s),Color(0.0,0.0,0.02,0.58))
        box = Rect2(Vector2(s.x*0.5-280.0*u,s.y*0.5-130.0*u),Vector2(560.0*u,260.0*u))
    STYLE.panel(_view,box,u)
    # Eight dots on a circle, the lit one runs round (one turn per second).
    var c: Vector2 = box.position+Vector2(56.0*u,box.size.y*0.5) if compact else box.position+Vector2(box.size.x*0.5,78.0*u)
    var r: float = (17.0 if compact else 30.0)*u
    for k in range(8):
        var a: float = TAU*float(k)/8.0
        var phase: float = fposmod(t*8.0-float(k),8.0)
        var lit: float = clampf(1.0-phase/6.0,0.15,1.0)
        var col: Color = STYLE.PINK.lerp(Color.WHITE,0.15*lit)
        col.a = lit
        _view.draw_circle(c+Vector2(cos(a),sin(a))*r,(3.6 if compact else 6.0)*u*(0.75+0.35*lit),col)
    var font: Font = STYLE.BOLD
    var fs: int = int((24.0 if compact else 30.0)*u)
    var dots: String = ".".repeat(1+int(t*2.5)%3)
    var label: String = title+dots
    if compact:
        _view.draw_string(font,box.position+Vector2(96.0*u,box.size.y*0.5+fs*0.36),label,HORIZONTAL_ALIGNMENT_LEFT,-1,fs,STYLE.WHITE)
        return
    var tw: float = font.get_string_size(title+"...",HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x
    _view.draw_string(font,Vector2(box.position.x+(box.size.x-tw)*0.5,box.position.y+152.0*u),label,HORIZONTAL_ALIGNMENT_LEFT,-1,fs,STYLE.WHITE)
    if detail != "":
        var ds: int = int(17.0*u)
        var dw: float = STYLE.SEMI.get_string_size(detail,HORIZONTAL_ALIGNMENT_LEFT,-1,ds).x
        _view.draw_string(STYLE.SEMI,Vector2(box.position.x+(box.size.x-dw)*0.5,box.position.y+182.0*u),detail,HORIZONTAL_ALIGNMENT_LEFT,-1,ds,STYLE.MUTED)
    # Chequered strip: fills with progress, or chequers run when unknown.
    _draw_strip(Rect2(box.position+Vector2(36.0*u,box.size.y-50.0*u),Vector2(box.size.x-72.0*u,18.0*u)),u,t)

## The key art as the loading screen: art fitted by height on the art's own
## edge colour, a dark scrim at the bottom, then a slim bar with the spinner,
## the title / detail and the chequered strip.
func _draw_poster(s: Vector2, u: float, t: float) -> void:
    # Size the bar by the art's width (not the screen's): a wide window must not
    # get a bar bigger than the poster.
    u = clampf(minf(s.x,s.y*0.5625)/720.0,0.5,2.0)
    _view.draw_rect(Rect2(Vector2.ZERO,s),POSTER_BG)
    _view.draw_texture_rect(_poster_tex,poster_rect(s,_poster_tex.get_size()),false)
    # Scrim: the bottom quarter fades to near black so the bar always reads.
    var scrim_h: float = s.y*0.26
    var steps: int = 26
    for k in range(steps):
        var y0: float = s.y-scrim_h+scrim_h*float(k)/float(steps)
        var a: float = pow(float(k+1)/float(steps),1.6)*0.82
        _view.draw_rect(Rect2(0.0,y0,s.x,scrim_h/float(steps)+1.0),Color(0.01,0.0,0.03,a))
    var bw: float = minf(s.x-40.0*u,560.0*u)
    var bh: float = 118.0*u
    var box := Rect2(Vector2((s.x-bw)*0.5,s.y-bh-maxf(s.y*0.035,24.0*u)),Vector2(bw,bh))
    STYLE.panel(_view,box,u)
    var c: Vector2 = box.position+Vector2(46.0*u,box.size.y*0.38)
    var r: float = 15.0*u
    for k2 in range(8):
        var a2: float = TAU*float(k2)/8.0
        var phase: float = fposmod(t*8.0-float(k2),8.0)
        var lit: float = clampf(1.0-phase/6.0,0.15,1.0)
        var col: Color = STYLE.PINK.lerp(Color.WHITE,0.15*lit)
        col.a = lit
        _view.draw_circle(c+Vector2(cos(a2),sin(a2))*r,3.4*u*(0.75+0.35*lit),col)
    var font: Font = STYLE.BOLD
    var fs: int = int(26.0*u)
    var label: String = title+".".repeat(1+int(t*2.5)%3)
    var tx: float = box.position.x+88.0*u
    _view.draw_string(font,Vector2(tx,box.position.y+box.size.y*0.38+fs*0.12),label,HORIZONTAL_ALIGNMENT_LEFT,box.size.x-110.0*u,fs,STYLE.WHITE)
    if detail != "":
        var ds: int = int(15.0*u)
        _view.draw_string(STYLE.SEMI,Vector2(tx,box.position.y+box.size.y*0.38+fs*0.12+ds*1.5),detail,HORIZONTAL_ALIGNMENT_LEFT,box.size.x-110.0*u,ds,STYLE.MUTED)
    _draw_strip(Rect2(box.position+Vector2(28.0*u,box.size.y-30.0*u),Vector2(box.size.x-56.0*u,14.0*u)),u,t)

func _draw_strip(strip: Rect2, u: float, t: float) -> void:
    _view.draw_rect(strip,Color(0.06,0.06,0.08))
    var cell: float = strip.size.y*0.5
    var cols: int = int(strip.size.x/cell)
    var fill: int = cols if progress < 0.0 else int(round(float(cols)*progress))
    var shift: int = int(t*10.0) if progress < 0.0 else 0
    for i in range(fill):
        for j in range(2):
            if (i+j+shift)%2 == 0:
                _view.draw_rect(Rect2(strip.position+Vector2(float(i)*cell,float(j)*cell),Vector2(cell,cell)),Color(0.95,0.95,0.97))
    _view.draw_rect(strip,STYLE.PINK,false,2.0*u)
