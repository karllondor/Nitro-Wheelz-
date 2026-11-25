extends RefCounted
## Provisional Park 2.0 masterplan. x east, z south, metres.
const BOUNDS := Rect2(-354, -545, 716, 705)
const CIRCUIT_WIDTH := 14.0
const ENTRANCE := Vector2(-233, -193)
const EXIT := Vector2(225, -175)
const LOOP := [
    ENTRANCE, Vector2(-203, -190), Vector2(-147, -206), Vector2(-102, -176),
    Vector2(-66, -160), Vector2(-25, -185), Vector2(13, -214), Vector2(53, -194),
    Vector2(86, -158), Vector2(116, -177), Vector2(154, -207), Vector2(191, -204),
    EXIT, Vector2(254, -165), Vector2(280, -192), Vector2(291, -239),
    Vector2(272, -279), Vector2(236, -299), Vector2(142, -307), Vector2(42, -304),
    Vector2(-63, -299), Vector2(-144, -306), Vector2(-223, -304), Vector2(-267, -287),
    Vector2(-286, -255), Vector2(-287, -225), Vector2(-272, -200),
]
const ENTRY_LANE := [Vector2(-142, -107), Vector2(-162, -123), Vector2(-190, -158),
    Vector2(-247, -173), Vector2(-248, -188), ENTRANCE]
const EXIT_LANE := [EXIT, Vector2(232, -156), Vector2(221, -138), Vector2(195, -124), Vector2(150, -110)]
const STUNT_ACCESS := [Vector2(194, -50), Vector2(233, -84), Vector2(292, -102), Vector2(325, -139),
    Vector2(328, -301), Vector2(304, -341), Vector2(253, -358), Vector2(129, -358)]
const STUNT := Rect2(-135, -520, 278, 187)
const PARKING := Rect2(-315, -41, 116, 121)
const STATION := Rect2(189, -61, 116, 76)
const INDUSTRIAL := Rect2(174, 31, 157, 75)
const EAST_ACCESS := Rect2(143, -67, 57, 177)
const WEST_ACCESS := Rect2(-215, -35, 61, 105)
const NORTH_APRON := Rect2(-226, -116, 452, 54)
const PAVED := [STUNT, PARKING, STATION, INDUSTRIAL, EAST_ACCESS, WEST_ACCESS, NORTH_APRON]
const REPAIR := Rect2(269, -28, 8, 10)
const STOP_SPEED_MPS := 1.0
const STOP_SECONDS := 0.65
const CARDBOARD := Rect2(89, -457, 38, 63)
const RAMP_DIR := Vector2.UP
const RAMPS := [
    {"id": "small", "start": Vector2(-92, -449), "width": 6.0, "run": 7.0, "rise": 1.2,
        "approach": Rect2(-101, -449, 18, 85), "landing": Rect2(-103, -507, 22, 49)},
    {"id": "medium", "start": Vector2(-40, -448), "width": 8.0, "run": 10.0, "rise": 2.4,
        "approach": Rect2(-52, -448, 24, 91), "landing": Rect2(-54, -512, 28, 51)},
    {"id": "large", "start": Vector2(30, -449), "width": 10.0, "run": 14.0, "rise": 3.8,
        "approach": Rect2(16, -449, 28, 98), "landing": Rect2(14, -516, 32, 49)},
]

static func road(points: Array, closed := false) -> PackedVector2Array:
    var curve := Curve2D.new()
    curve.bake_interval = 2.0
    var count := points.size()
    for i in range(count):
        var p: Vector2 = points[i]
        var prev: Vector2 = points[(i + count - 1) % count] if closed or i > 0 else p
        var next: Vector2 = points[(i + 1) % count] if closed or i < count - 1 else p
        var tangent := (next - prev).normalized()
        curve.add_point(p, -tangent * p.distance_to(prev) * 0.29, tangent * p.distance_to(next) * 0.29)
    if closed:
        curve.add_point(curve.get_point_position(0), curve.get_point_in(0), curve.get_point_out(0))
    var baked := curve.get_baked_points()
    if closed and baked[0].is_equal_approx(baked[-1]):
        baked.remove_at(baked.size() - 1)
    return baked
