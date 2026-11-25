extends Node3D
## Park-only modular scenery. Solid footprints are registered with their props
## for the planar driving model. Paint, slopes beyond closures and foliage
## canopies can be replaced without changing contacts or the Park controller.
const SITE = preload("res://scripts/park/park_site.gd")
const MESH = preload("res://scripts/park/park_site_mesh.gd")
const ASPHALT = preload("res://assets/surfaces/asphalt.webp")
const LOGO = preload("res://assets/brand/nitro_wheelz_logo_pavement.png")
const PAVEMENT := Color(1.88, 1.88, 1.99)
const PAINT := 0.099
const WHITE := Color("#dce1ea")
const YELLOW := Color("#ffcf4f")
const PURPLE := Color("#923cdf")
const PINK := Color("#ee91ba")
const STEEL := Color("#434959")
const BLACK := Color("#252631")
const CELL := 32.0
var _solids: Dictionary = {}
var _roofs: Dictionary = {}

func build() -> void:
    name = "Park 2 Environment"
    _roads()
    _stunts()
    _parking()
    _service()
    _industrial()
    _landscape()

func _zone(label: String) -> Node3D:
    var node := Node3D.new()
    node.name = label
    add_child(node)
    return node

func _roads() -> void:
    var zone := _zone("Technical Drift Circuit")
    var asphalt = MESH.new()
    var paint = MESH.new()
    var signs = MESH.new()
    for rect: Rect2 in SITE.PAVED:
        asphalt.rect(rect, 0.041, PAVEMENT)
    var loops := [SITE.road(SITE.LOOP, true), SITE.road(SITE.ENTRY_LANE),
        SITE.road(SITE.EXIT_LANE), SITE.road(SITE.STUNT_ACCESS)]
    var gaps := PackedVector2Array([SITE.ENTRANCE, SITE.EXIT])
    for index in range(loops.size()):
        var line: PackedVector2Array = loops[index]
        var width := SITE.CIRCUIT_WIDTH if index == 0 else 12.5
        asphalt.strip(line, width, 0.0, 0.043, PAVEMENT, index == 0)
        for side in [-1.0, 1.0]:
            paint.strip(line, 0.29, side * (width * 0.5 - 0.55), PAINT, WHITE, index == 0, false, gaps)
        if index in [0, 3]:
            paint.strip(line, 0.22, 0.0, PAINT, YELLOW, index == 0, true, gaps)
        for i in range(22, line.size() - 1, 49):
            _arrow(paint, line[i], (line[i + 1] - line[i]).normalized(), WHITE)
    _arrow(paint, Vector2(-151, -113), Vector2(-1, -1).normalized(), YELLOW)
    _arrow(paint, Vector2(167, -115), Vector2(-1, 0.3).normalized(), WHITE)
    _arrow(paint, Vector2(200, -56), Vector2(1, -1).normalized(), YELLOW)
    _arrow(paint, Vector2(-177, -17), Vector2.LEFT, WHITE)
    _arrow(paint, Vector2(165, -31), Vector2.RIGHT, WHITE)
    _text_on_ground(zone, Vector2(-132, -106), "CIRCUIT IN ↖", YELLOW, 2.2)
    _text_on_ground(zone, Vector2(139, -99), "CIRCUIT OUT ↙", WHITE, 2.1)
    _text_on_ground(zone, Vector2(205, -61), "STUNT ↑", YELLOW, 2.0)
    _text_on_ground(zone, Vector2(-172, -28), "← PARKING", WHITE, 1.9)
    _text_on_ground(zone, Vector2(168, -41), "SERVICE →", WHITE, 1.9)
    _text_on_ground(zone, Vector2(181, 47), "CARGO →", PURPLE.lightened(0.35), 1.9)
    _board(zone, signs, Vector2(-172, -119), "CIRCUIT IN   /   入口", YELLOW, 9.2)
    _board(zone, signs, Vector2(185, -133), "CIRCUIT OUT   /   出口", WHITE, 9.2)
    asphalt.commit(zone, "Site asphalt", ASPHALT, false)
    paint.commit(zone, "Circuit and access paint", null, false)
    signs.commit(zone, "Circuit sign supports")

func _stunts() -> void:
    var zone := _zone("Stunt Area")
    var decks = MESH.new()
    var signs = MESH.new()
    var paint = MESH.new()
    for ramp in SITE.RAMPS:
        var at: Vector2 = ramp.start
        var width: float = ramp.width
        var rise: float = ramp.rise
        var run: float = ramp.run
        var approach: Rect2 = ramp.approach
        _outline(paint, approach, WHITE, 0.22)
        _outline(paint, ramp.landing, YELLOW, 0.24)
        for dist in [18.0, 41.0, 67.0]:
            _arrow(paint, at - SITE.RAMP_DIR * dist, SITE.RAMP_DIR, WHITE)
        _text_on_ground(zone, at + Vector2(0, 13), str(ramp.id).to_upper(), YELLOW, 2.2)
        _text_on_ground(zone, at + Vector2(0, 7.0), "JUMP", WHITE, 1.1)
        var lower := Vector3(at.x - width * 0.5, 0.09, at.y)
        var upper := lower + Vector3(0, rise, -run)
        var base := lower + Vector3(0, 0, -run)
        var span := Vector3(width, 0, 0)
        var normal := Vector3(0, run, rise).normalized()
        decks.triangle(lower, upper, lower + span, normal, STEEL)
        decks.triangle(lower + span, upper, upper + span, normal, STEEL)
        decks.triangle(lower, base, upper, Vector3.LEFT, PURPLE)
        decks.triangle(lower + span, base + span, upper + span, Vector3.RIGHT, PURPLE)
        decks.box(upper + Vector3(width * 0.5, -rise * 0.5, 0.0), Vector3(width, rise, 0.16), PURPLE)
        decks.box(upper + Vector3(width * 0.5, 0.05, 0.21), Vector3(width, 0.12, 0.30), YELLOW)
    _outline(paint, SITE.CARDBOARD, PINK, 0.32)
    _text_on_ground(zone, SITE.CARDBOARD.get_center(), "OBSTACLE PAD", PINK, 2.25)
    _text_on_ground(zone, Vector2(-32, -504), "LANDING ZONES", YELLOW, 2.4)
    _board(zone, signs, Vector2(74, -365), "STUNT AREA   /   THREE JUMP LANES", YELLOW, 14.5)
    decks.commit(zone, "Modular ramp decks")
    signs.commit(zone, "Stunt signs")
    paint.commit(zone, "Approach and landing paint", null, false)

func _parking() -> void:
    var zone := _zone("Car Park")
    var paint = MESH.new()
    var cars = MESH.new()
    var props = MESH.new()
    var colors := [Color("#bd544f"), Color("#e2dfd4"), Color("#387fa2"), Color("#ceae41"), Color("#6d438f")]
    for row in range(2):
        for i in range(12):
            var at := Vector2(-287.0 + i * 6.4, -2.0 + row * 40.0)
            _outline(paint, Rect2(at - Vector2(2.95, 4.5), Vector2(5.9, 9)), WHITE, 0.17)
            if posmod(i + row * 3, 5) < 2:
                _parked_car(cars, at, colors[(i + row) % colors.size()], row == 1)
    for i in range(7):
        _arrow(paint, Vector2(-293 + i * 12.0, 18), Vector2.LEFT, WHITE, 0.72)
    _text_on_ground(zone, Vector2(-252, -17), "P  /  PADDOCK", WHITE, 2.5)
    _board(zone, props, Vector2(-293, -14), "P   /   駐車場", WHITE, 7.6)
    _lamp(props, Vector2(-303, -11))
    _lamp(props, Vector2(-303, 54))
    _lamp(props, Vector2(-208, 56))
    paint.commit(zone, "Parking spaces", null, false)
    cars.commit(zone, "Parked cars")
    props.commit(zone, "Paddock furniture")

func _service() -> void:
    var zone := _zone("Japanese Service Station")
    var walls = MESH.new()
    var canopy = MESH.new()
    var workshop_roof = MESH.new()
    var equipment = MESH.new()
    var paint = MESH.new()
    var plaster := Color("#ddd9d1")
    var red := Color("#e64351")
    var glass := Color("#395b6d")
    canopy.box(Vector3(225, 5.53, -18), Vector3(33, 0.45, 22), plaster)
    canopy.box(Vector3(225, 5.23, -18), Vector3(33.18, 0.54, 22.15), red)
    for x in [211.0, 239.0]:
        for z in [-26.0, -10.0]:
            _solid_box(walls, Rect2(x - 0.47, z - 0.47, 0.94, 0.94), 5.15, plaster)
    for x in [216.0, 232.0]:
        _solid_box(equipment, Rect2(x - 1.0, -19.2, 2.0, 2.4), 0.24, STEEL)
        _solid_box(equipment, Rect2(x - 0.68, -18.62, 1.36, 1.24), 1.85, red)
        equipment.box(Vector3(x, 1.38, -17.93), Vector3(1.05, 0.57, 0.09), plaster)
        equipment.box(Vector3(x, 1.42, -17.87), Vector3(0.66, 0.31, 0.07), glass)
        equipment.box(Vector3(x + 0.76, 0.95, -18), Vector3(0.14, 1.19, 0.18), BLACK)
    _solid_box(walls, Rect2(259, -37, 36, 1.3), 5.6, plaster)
    _solid_box(walls, Rect2(259, -36, 1, 18), 5.6, plaster)
    _solid_box(walls, Rect2(294, -36, 1, 18), 5.6, plaster)
    _solid_box(walls, Rect2(259, -19, 9, 1.5), 5.6, glass)
    _solid_box(walls, Rect2(278, -19, 17, 1.5), 5.6, STEEL)
    _solid_box(walls, Rect2(278.05, -35, 0.55, 16), 4.5, plaster)
    workshop_roof.box(Vector3(277, 5.73, -27), Vector3(37, 0.50, 21), STEEL)
    walls.box(Vector3(277, 4.94, -17.42), Vector3(36.7, 0.9, 0.24), PURPLE)
    walls.box(Vector3(273, 4.14, -17.38), Vector3(10, 0.36, 0.28), BLACK)
    for x in [268.2, 277.85]:
        walls.box(Vector3(x, 1.93, -17.4), Vector3(0.25, 3.78, 0.21), YELLOW)
    for slat in range(6):
        walls.box(Vector3(287.1, 0.54 + slat * 0.66, -17.43), Vector3(14.0, 0.09, 0.09), Color("#677184"))
    for x in [281.0, 284.0]:
        _solid_box(equipment, Rect2(x - 0.63, -17.0, 1.25, 0.83), 1.89, plaster if x < 282.0 else red)
        equipment.box(Vector3(x, 1.19, -16.56), Vector3(1.03, 0.86, 0.085), glass)
        for shelf in [0.97, 1.21, 1.45]:
            equipment.box(Vector3(x, shelf, -16.51), Vector3(0.80, 0.075, 0.06), Color("#f9e7bc"))
    _label(zone, "REPAIR BAY  /  整備", Vector3(273, 4.99, -17.28), WHITE, 0.50)
    _board(zone, equipment, Vector2(204, -45), "NITRO SERVICE   /   給油所", red, 12.0)
    _lamp(equipment, Vector2(208, -40))
    _outline(paint, SITE.REPAIR, YELLOW, 0.24)
    _arrow(paint, Vector2(273, -10), Vector2.UP, YELLOW)
    _text_on_ground(zone, Vector2(273, -3), "STOP IN BAY", YELLOW, 1.7)
    _text_on_ground(zone, Vector2(227, 0), "SERVICE", WHITE, 2.4)
    paint.commit(zone, "Forecourt and repair paint", null, false)
    walls.commit(zone, "Workshop walls and canopy posts")
    equipment.commit(zone, "Fuel pumps and workshop fixtures")
    var canopy_node: MeshInstance3D = canopy.commit(zone, "Canopy roof")
    _label(canopy_node, "NITRO   /   給油所", Vector3(225, 5.25, -6.86), WHITE, 0.50)
    _roofs[Rect2(206, -32, 38, 28)] = canopy_node
    _roofs[Rect2(257, -40, 40, 25)] = workshop_roof.commit(zone, "Workshop roof")

func _industrial() -> void:
    var zone := _zone("Industrial Yard")
    var cargo = MESH.new()
    var fence = MESH.new()
    var paint = MESH.new()
    for i in range(9):
        var at := Vector2(188.0 + i * 15.1, 46.0 if i < 5 else 60.0)
        var tint: Color = [BLACK, PURPLE, YELLOW][i % 3]
        _container(zone, cargo, at, tint, 0.0, i in [1, 2, 5, 7])
        if i in [0, 1, 6, 7]:
            _container(zone, cargo, at, tint.darkened(0.15), 2.65, false)
    _fence(fence, Vector2(175, 33), Vector2(328, 33))
    _fence(fence, Vector2(328, 33), Vector2(328, 105))
    _fence(fence, Vector2(211, 105), Vector2(321, 105))
    for i in range(8):
        _arrow(paint, Vector2(192 + i * 16.0, 80), Vector2.RIGHT, YELLOW, 0.73)
    _board(zone, fence, Vector2(222, 93), "CONTAINER YARD   /   倉庫", PURPLE, 14.4)
    _text_on_ground(zone, Vector2(266, 92), "CARGO 01", WHITE, 3.0)
    _lamp(fence, Vector2(258, 100))
    _lamp(fence, Vector2(316, 100))
    cargo.commit(zone, "Corrugated purple, yellow and black containers")
    fence.commit(zone, "Industrial fences and fixtures")
    paint.commit(zone, "Cargo access paint", null, false)

func _landscape() -> void:
    var zone := _zone("Japanese Landscape")
    var mountains = MESH.new()
    var peaks := [
        [Vector2(-820, -824), Vector3(510, 214, 320)], [Vector2(-477, -901), Vector3(390, 240, 294)],
        [Vector2(-80, -926), Vector3(396, 286, 300)], [Vector2(275, -876), Vector3(380, 218, 275)],
        [Vector2(660, -810), Vector3(440, 193, 280)], [Vector2(-780, -400), Vector3(333, 200, 399)],
        [Vector2(720, -375), Vector3(352, 178, 422)], [Vector2(-690, 509), Vector3(326, 153, 340)],
        [Vector2(683, 520), Vector3(361, 162, 310)], [Vector2(12, 711), Vector3(420, 159, 315)],
    ]
    for i in range(peaks.size()):
        _mountain(mountains, peaks[i][0], peaks[i][1], i, i == 2)
    mountains.commit(zone, "Distant mountain ridges", null, false)

    var rng := RandomNumberGenerator.new()
    rng.seed = 272024
    var road := SITE.road(SITE.LOOP, true)
    road.append_array(SITE.road(SITE.ENTRY_LANE))
    road.append_array(SITE.road(SITE.EXIT_LANE))
    road.append_array(SITE.road(SITE.STUNT_ACCESS))
    var plantings := PackedVector2Array([
        Vector2(-193, -49), Vector2(-177, -42), Vector2(-185, 78), Vector2(-184, 94),
        Vector2(-130, -157), Vector2(-108, -145), Vector2(-71, -141), Vector2(20, -144),
        Vector2(63, -137), Vector2(109, -138), Vector2(156, -141), Vector2(167, -154),
        Vector2(157, 121), Vector2(195, 116), Vector2(227, 117), Vector2(209, 22),
        Vector2(239, 22), Vector2(268, 23), Vector2(300, 24), Vector2(-303, 90),
        Vector2(-266, 91), Vector2(-232, 89), Vector2(-203, 87), Vector2(-306, -214),
        Vector2(-305, -247), Vector2(307, -217), Vector2(306, -257),
        Vector2(147, -397), Vector2(-147, -390), Vector2(-151, -444), Vector2(147, -455),
    ])
    # Spatial batches limit draw calls while allowing whole quadrants to cull.
    for quadrant in range(4):
        var plants = MESH.new()
        var east := (quadrant & 1) != 0
        var south := (quadrant & 2) != 0
        for at in plantings:
            if (at.x >= 0.0) == east and (at.y >= 0.0) == south:
                _sakura(plants, at, rng.randf_range(0.77, 1.12), rng)
        for i in range(125):
            var at := Vector2(rng.randf_range(0, 345) * (1.0 if east else -1.0),
                rng.randf_range(0, 147 if south else 530) * (1.0 if south else -1.0))
            if not _verge(at, road, plantings):
                continue
            var size := rng.randf_range(0.66, 1.33)
            if i % 5 == 0:
                _pine(plants, at, size)
            else:
                var tint := Color("#445c49").lerp(Color("#718255"), rng.randf())
                plants.round_shape(_point(at, 0.14), Vector3(1.48, 0.52, 0.99) * size, tint)
        plants.commit(zone, "Vegetation quadrant %d" % quadrant)

func _verge(at: Vector2, road: PackedVector2Array, plantings: PackedVector2Array) -> bool:
    if Rect2(-178, -138, 356, 276).has_point(at):
        return false
    for rect: Rect2 in SITE.PAVED:
        if rect.grow(5).has_point(at):
            return false
    for p in road:
        if at.distance_squared_to(p) < 196.0:
            return false
    for p in plantings:
        if at.distance_squared_to(p) < 64.0:
            return false
    return true

func _sakura(mesh, at: Vector2, size: float, rng: RandomNumberGenerator) -> void:
    var p := _point(at)
    var wood := Color("#51404b")
    mesh.round_shape(p + Vector3.UP * (2.08 * size), Vector3(0.35, 2.15, 0.35) * size, wood, 0.55)
    _solid(Rect2(at - Vector2.ONE * 0.30 * size, Vector2.ONE * 0.60 * size))
    var petals := [Color("#cd779f"), Color("#e69ab9"), Color("#ffc2d7"), Color("#eda1c2")]
    for i in range(5):
        var angle := TAU * i / 5.0
        var dir := Vector3(cos(angle), 0, sin(angle))
        mesh.box(p + (Vector3.UP * 3.3 + dir * 0.91) * size, Vector3(0.25, 2.7, 0.25) * size, wood,
            Basis(Vector3.UP.cross(dir), 0.53))
        mesh.round_shape(p + (Vector3.UP * rng.randf_range(4.0, 5.05) + dir * 1.72) * size,
            Vector3(1.82, 1.45, 1.69) * size, petals[i % petals.size()])
    mesh.round_shape(p + Vector3.UP * (5.5 * size), Vector3(2.05, 1.45, 2.0) * size, petals[2])

func _pine(mesh, at: Vector2, size: float) -> void:
    var trunk := Rect2(at - Vector2.ONE * 0.25 * size, Vector2.ONE * 0.50 * size)
    _solid_box(mesh, trunk, 3.0 * size, Color("#483d39"))
    for layer in range(3):
        var radius := (2.3 - layer * 0.54) * size
        var base := _point(at, (1.6 + layer * 1.35) * size)
        var tip := base + Vector3.UP * (3.2 * size)
        for i in range(9):
            var a := TAU * i / 9.0
            var b := TAU * (i + 1) / 9.0
            mesh.triangle(base + Vector3(cos(a), 0, sin(a)) * radius,
                base + Vector3(cos(b), 0, sin(b)) * radius, tip,
                Vector3(cos(a), 0.46, sin(a)).normalized(),
                Color("#3e5b4e").lightened(float(i % 3) * 0.025 + layer * 0.02))

func _mountain(mesh, centre: Vector2, size: Vector3, seed: int, snow: bool) -> void:
    var rows: Array[PackedVector3Array] = []
    var rng := RandomNumberGenerator.new()
    rng.seed = 1037 + seed
    for band in range(5):
        var row := PackedVector3Array()
        var radius: float = [1.0, 0.64, 0.37, 0.19, 0.04][band]
        var height: float = [0.0, 0.21, 0.51, 0.79, 0.97][band]
        for i in range(22):
            var angle := TAU * i / 22.0
            var irregular := rng.randf_range(0.81, 1.15)
            row.append(_point(centre, size.y * height * rng.randf_range(0.90, 1.08) - 0.30) +
                Vector3(cos(angle) * size.x, 0, sin(angle) * size.z) * radius * irregular)
        rows.append(row)
    for band in range(4):
        for i in range(22):
            var next := (i + 1) % 22
            var a := rows[band][i]
            var b := rows[band][next]
            var c := rows[band + 1][i]
            var d := rows[band + 1][next]
            var tint := Color("#56607a").lerp(Color("#79859f"), band / 4.0)
            if snow and (band == 3 or (band == 2 and i % 3 == 0)):
                tint = Color("#bbc3d4")
            tint = tint.lightened(rng.randf_range(-0.045, 0.055))
            var normal := Vector3(a.x - centre.x, 100, a.z - centre.y).normalized()
            mesh.triangle(a, b, c, normal, tint)
            mesh.triangle(c, b, d, normal, tint.lightened(0.025))
    for i in range(22):
        mesh.triangle(rows[4][i], rows[4][(i + 1) % 22], _point(centre, size.y), Vector3.UP,
            Color("#c8ccd9") if snow else Color("#8391ac"))

func _container(zone: Node3D, mesh, at: Vector2, tint: Color, lift: float, branded: bool) -> void:
    var c := _point(at, 1.39 + lift)
    mesh.box(c, Vector3(12.16, 2.65, 2.53), tint)
    for i in range(20):
        mesh.box(c + Vector3(-5.74 + i * 0.604, 0, 0), Vector3(0.13, 2.37, 2.67), tint.darkened(0.18))
    for end in [-1.0, 1.0]:
        mesh.box(c + Vector3(0, end * 1.26, 0), Vector3(12.25, 0.13, 2.73), tint.lightened(0.09))
        mesh.box(c + Vector3(end * 6.04, 0, 0), Vector3(0.12, 2.56, 2.73), tint.darkened(0.27))
    if is_zero_approx(lift):
        _solid(Rect2(at - Vector2(6.13, 1.37), Vector2(12.26, 2.74)))
    if branded:
        var decal := Sprite3D.new()
        decal.name = "Nitro Wheelz container livery"
        decal.texture = LOGO
        decal.pixel_size = 0.0034
        decal.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
        decal.position = c + Vector3(0, 0.04, 1.37)
        zone.add_child(decal)

func _parked_car(mesh, at: Vector2, tint: Color, reverse: bool) -> void:
    var body := _point(at, 0.66)
    var cab := _point(at + Vector2(0, 0.12 if reverse else -0.12), 1.14)
    mesh.round_shape(body, Vector3(1.03, 0.43, 2.35), tint, 0.32)
    mesh.round_shape(cab, Vector3(0.85, 0.54, 1.19), Color("#253646"), 0.42)
    mesh.round_shape(cab + Vector3.UP * 0.35, Vector3(0.72, 0.19, 0.83), tint.lightened(0.06), 0.42)
    for side in [-1.0, 1.0]:
        for end in [-1.0, 1.0]:
            mesh.round_shape(body + Vector3(side * 0.93, -0.30, end * 1.43),
                Vector3(0.18, 0.36, 0.36), BLACK, 0.53)
            var light := Color("#e75b55") if (end < 0.0) == reverse else WHITE
            mesh.box(body + Vector3(side * 0.65, 0.14, end * 2.29), Vector3(0.45, 0.18, 0.10), light)
    _solid(Rect2(at - Vector2(1.11, 2.33), Vector2(2.22, 4.66)))

func _fence(mesh, from: Vector2, to: Vector2) -> void:
    var length := from.distance_to(to)
    var basis := Basis(Vector3.UP, -(to - from).angle())
    _solid(Rect2(from.min(to) - Vector2.ONE * 0.085, (to - from).abs() + Vector2.ONE * 0.17))
    for y in [0.32, 1.15, 2.39]:
        mesh.box(_point((from + to) * 0.5, y), Vector3(length, 0.09, 0.12), STEEL, basis)
    var spans := ceili(length / 3.5)
    for i in range(spans + 1):
        mesh.box(_point(from.lerp(to, float(i) / spans), 1.32), Vector3(0.14, 2.56, 0.14), STEEL)
        if i < spans:
            for bar in range(1, 6):
                mesh.box(_point(from.lerp(to, (i + bar / 6.0) / spans), 1.31),
                    Vector3(0.05, 2.11, 0.05), STEEL)

func _lamp(mesh, at: Vector2) -> void:
    _solid_box(mesh, Rect2(at - Vector2.ONE * 0.14, Vector2.ONE * 0.28), 6.5, STEEL)
    mesh.box(_point(at + Vector2(0, -0.72), 6.40), Vector3(0.39, 0.22, 1.71), STEEL)
    mesh.box(_point(at + Vector2(0, -1.10), 6.25), Vector3(0.33, 0.12, 0.80), Color("#ffe3ae"))

func _board(zone: Node3D, mesh, at: Vector2, text: String, tint: Color, width: float) -> void:
    for end in [-1.0, 1.0]:
        var pole := at + Vector2(end * (width * 0.5 - 0.55), 0)
        _solid_box(mesh, Rect2(pole - Vector2.ONE * 0.13, Vector2.ONE * 0.26), 2.65, STEEL)
    mesh.box(_point(at, 2.55), Vector3(width, 1.15, 0.20), BLACK)
    mesh.box(_point(at, 1.98), Vector3(width, 0.13, 0.22), tint)
    _label(zone, text, _point(at + Vector2(0, 0.115), 2.57), WHITE, 0.54)

func _label(zone: Node3D, text: String, at: Vector3, tint: Color, size: float) -> Label3D:
    var label := Label3D.new()
    label.text = text
    label.font_size = 64
    label.pixel_size = size / 64.0
    label.modulate = tint
    label.outline_size = 0
    label.double_sided = false
    label.position = at
    zone.add_child(label)
    return label

func _text_on_ground(zone: Node3D, at: Vector2, text: String, tint: Color, size: float) -> void:
    _label(zone, text, _point(at, PAINT + 0.004), tint, size).rotation.x = -PI * 0.5

func _outline(mesh, rect: Rect2, tint: Color, width: float) -> void:
    var a := rect.position
    var b := rect.end
    mesh.rect(Rect2(a, Vector2(rect.size.x, width)), PAINT, tint)
    mesh.rect(Rect2(a.x, b.y - width, rect.size.x, width), PAINT, tint)
    mesh.rect(Rect2(a, Vector2(width, rect.size.y)), PAINT, tint)
    mesh.rect(Rect2(b.x - width, a.y, width, rect.size.y), PAINT, tint)

func _arrow(mesh, at: Vector2, dir: Vector2, tint: Color, size := 1.0) -> void:
    var side := Vector2(-dir.y, dir.x) * size
    var base := at - dir * (1.65 * size)
    mesh.quad(base - side * 0.22, base + side * 0.22, at - side * 0.22, at + side * 0.22, PAINT, tint)
    mesh.triangle(_point(at + dir * (2.12 * size), PAINT), _point(at - side * 0.83, PAINT),
        _point(at + side * 0.83, PAINT), Vector3.UP, tint)

static func _point(at: Vector2, y := 0.0) -> Vector3:
    return Vector3(at.x, y, at.y)

func _solid_box(mesh, rect: Rect2, height: float, tint: Color) -> void:
    mesh.box(_point(rect.get_center(), height * 0.5 + 0.07), Vector3(rect.size.x, height, rect.size.y), tint)
    _solid(rect)

func _cell(at: Vector2) -> Vector2i:
    return Vector2i((at / CELL).floor())

func _solid(rect: Rect2) -> void:
    # Four metres cover the largest current car's half-diagonal, allowing
    # a single cell lookup even when the body straddles a cell boundary.
    var padded := rect.grow(4.0)
    var lo := _cell(padded.position)
    var hi := _cell(padded.end)
    for x in range(lo.x, hi.x + 1):
        for z in range(lo.y, hi.y + 1):
            var key := Vector2i(x, z)
            if not _solids.has(key):
                _solids[key] = []
            _solids[key].append(rect)

func impact_point(pos: Vector2, normal: Vector2) -> Vector2:
    var nearest := pos-normal*2.35
    var distance := INF
    for rect: Rect2 in _solids.get(_cell(pos), []):
        var point := pos.clamp(rect.position,rect.end)
        var offset := point-pos
        if offset.dot(normal)<0 and offset.length_squared()<distance:
            nearest = point
            distance = offset.length_squared()
    return nearest

func resolve_contact(pos: Vector2, heading: float, half_width: float, half_length: float,
        open_deck := -1, vehicle_height := 0.0) -> Vector2:
    var contacts: Array = _solids.get(_cell(pos), [])
    var near_decks := SITE.STUNT.grow(4.0).has_point(pos)
    if contacts.is_empty() and not near_decks:
        return Vector2.ZERO
    var forward := Vector2(sin(heading), -cos(heading))
    var right := Vector2(-forward.y, forward.x)
    var correction := Vector2.ZERO
    for obstacle: Rect2 in contacts:
        correction += _separate(pos + correction, forward, right, half_width, half_length, obstacle)
    if near_decks:
        for i in SITE.RAMPS.size():
            var ramp: Dictionary = SITE.RAMPS[i]
            if i == open_deck or vehicle_height > float(ramp.rise) + 0.1:
                continue
            var rect := Rect2(ramp.start.x-ramp.width*0.5,ramp.start.y-ramp.run,ramp.width,ramp.run)
            correction += _separate(pos+correction, forward, right, half_width, half_length, rect)
    return correction

static func _separate(pos: Vector2, forward: Vector2, right: Vector2,
        half_width: float, half_length: float, obstacle: Rect2) -> Vector2:
    var half := obstacle.size * 0.5
    var delta := pos - obstacle.get_center()
    var best_depth := INF
    var best_axis := Vector2.ZERO
    for axis: Vector2 in [Vector2.RIGHT, Vector2.DOWN, forward, right]:
        var projected := delta.dot(axis)
        var reach := half.dot(axis.abs()) + half_width * absf(axis.dot(right)) + half_length * absf(axis.dot(forward))
        var depth := reach - absf(projected)
        if depth <= 0.0:
            return Vector2.ZERO
        if depth < best_depth:
            best_depth = depth
            best_axis = axis if projected >= 0.0 else -axis
    return best_axis * (best_depth + 0.001)

func update_roofs(player: Vector2, camera: Vector2) -> void:
    var sightline := player.lerp(camera, 0.21)
    for rect: Rect2 in _roofs:
        _roofs[rect].visible = not rect.has_point(sightline)
