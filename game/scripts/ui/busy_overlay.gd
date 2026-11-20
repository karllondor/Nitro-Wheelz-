extends CanvasLayer
class_name NitroBusy
## v0.1.27 loading / processing overlay (owner: long operations looked like
## the app froze). Dims the screen, blocks touches, shows a title
## ("GENERATING TERRAIN…", "LOADING TRACK…") with eight spinning dots and a
## chequered-flag progress strip. The long jobs themselves run in slices
## (NitroSteps.run_sliced), so the animation keeps moving while they work.
## compact = a small pill at the top instead of a full dim (quick terrain
## updates after a stroke), still blocking input.
const STYLE = preload("res://scripts/ui/hud_style.gd")

var title: String = "PROCESSING"
var detail: String = ""
var progress: float = -1.0          # < 0 = unknown (moving chequers)
var compact: bool = false
var _view: Control
var _t0: int = 0

static func open(parent: Node, text: String, small: bool = false) -> NitroBusy:
    var b: NitroBusy = load("res://scripts/ui/busy_overlay.gd").new()
    b.title = text
    b.compact = small
    b.layer = 90
    b.name = "Busy overlay"
    parent.add_child(b)
    return b

func _ready() -> void:
    _t0 = Time.get_ticks_msec()
    _view = Control.new()
    _view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _view.mouse_filter = Control.MOUSE_FILTER_STOP
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
    var strip := Rect2(box.position+Vector2(36.0*u,box.size.y-50.0*u),Vector2(box.size.x-72.0*u,18.0*u))
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
