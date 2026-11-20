"""Nitro Wheelz Car Factory: E30 Blessed (four-door E30 sedan, lowered drift
build in Blessed Yellow) built from numbers with bpy and exported as GLB.

Run (bpy module or Blender):
  python tools/car_factory/blender/build_e30_blessed.py --out game/assets/cars/e30_blessed

Sources and confidence (see docs/car_factory/E30_BLESSED_PROTOTYPE.md):
  * CONFIRMED factory reference: length 4.325, width 1.645, height 1.380,
    wheelbase 2.570 m (stock E30, owner-manual mirror in the package).
  * VISUAL ESTIMATES from the supplied photos / side illustration (not
    measurements): stance (about 6.5 cm lower than stock), overhang split,
    window layout, wheel diameter, tuck, camber. Stylized illustration is
    used only for side-window proportions, never for scale.
  * No logos, badges or registration numbers are reproduced.
"""
import argparse
import math
import os
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import nwcf  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

# ------------------------------------------------------------ dimensions
LENGTH = 4.325            # confirmed factory reference
WIDTH = 1.645             # confirmed factory reference (body, no mirrors)
WHEELBASE = 2.570         # confirmed factory reference
STOCK_HEIGHT = 1.380      # confirmed factory reference
LOWERED = 0.065           # visual estimate from the photos
FRONT_OVERHANG = 0.765    # visual estimate (illustration ratio applied to real totals)
HALF_L = LENGTH * 0.5
Y_FA = HALF_L - FRONT_OVERHANG            # front axle  +1.3975
Y_RA = Y_FA - WHEELBASE                    # rear axle   -1.1725
BUMPER = 0.085                             # bumper reach beyond the body face
Y_BF = HALF_L - BUMPER                     # body front face
Y_BR = -HALF_L + 0.090                     # body rear face
W = WIDTH * 0.5                            # 0.8225

WHEEL_R = 0.290           # visual estimate: low-profile tyre on ~15" rim
WHEEL_Z = WHEEL_R
TRACK_F = 0.712           # half track: tyre/rim flush with the body side
TRACK_R = 0.716
ARCH_Z = 0.236            # arch centre 5.4 cm below the hub = tucked tyre
ARCH_R_F = 0.345
ARCH_R_R = 0.350

ZB = 0.130                # underside of the body
Y_C = 0.891               # cowl / windshield base
Y_RF = 0.335              # roof front / windshield top
Y_RR = -1.005             # roof rear / rear window top
Y_RW = -1.435             # rear window base
ROOF_RAIL = 1.285
ROOF_CROWN = 0.030
GLASS_CROWN = 0.045
X_BELT = 0.745            # greenhouse bottom (glass plane) at the belt
TUMBLE = 0.26             # side glass lean: dx per dz
WIN_TOP = 1.235


def smoothstep(a, b, x):
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3 - 2 * t)


# --------------------------------------------------------- lower body

def belt_z(y):
    """Window sill height along the cabin (slight wedge to the rear)."""
    return 0.825 + (Y_C - y) * (0.015 / (Y_C - Y_RW))


def crease_z(y):
    return 0.686 + 0.012 * (Y_BF - y) / (Y_BF - Y_BR)


def top_z(y):
    """Top surface edge height: bonnet, belt deck, boot lid."""
    if y >= Y_C:
        s = (Y_BF - y) / (Y_BF - Y_C)
        hood = 0.712 + (0.800 - 0.712) * s ** 0.85
        return hood + (belt_z(Y_C) - 0.800) * smoothstep(Y_C + 0.06, Y_C, y)
    if y >= Y_RW:
        return belt_z(y)
    s = (Y_RW - y) / (Y_RW - Y_BR)
    return 0.842 - 0.016 * s


def crown(y):
    if y >= Y_C:
        return 0.020 + 0.010 * smoothstep(Y_BF, Y_C, y)
    if y >= Y_RW:
        return 0.0
    return 0.018


def half_width(y):
    w = W - 0.006 * max(0.0, (y - 1.6) / (Y_BF - 1.6))
    rf, rr = 0.065, 0.060
    d = y - (Y_BF - rf)
    if d > 0:
        w -= rf - math.sqrt(max(rf * rf - d * d, 0.0))
    d = (Y_BR + rr) - y
    if d > 0:
        w -= rr - math.sqrt(max(rr * rr - d * d, 0.0))
    return w


def lip_drop(y):
    """Rounded leading edge of the bonnet and trailing edge of the boot."""
    r = 0.030
    d = y - (Y_BF - r)
    drop = 0.0
    if d > 0:
        drop = r - math.sqrt(max(r * r - d * d, 0.0))
    d = (Y_BR + 0.025) - y
    if d > 0:
        drop = max(drop, 0.025 - math.sqrt(max(0.025 ** 2 - d * d, 0.0)))
    return drop


def bottom_z(y):
    """Underside: flat floor, rising behind the rear axle to a higher rear
    valance hidden behind the bumper (camera-matched to the rear photo)."""
    t = smoothstep(Y_RA - ARCH_R_R, Y_RA - ARCH_R_R - 0.25, y)
    return ZB + 0.125 * t


def section(y):
    """Right half of the lower-body cross-section, bottom centre -> top
    centre. Same point count everywhere (lofted)."""
    ZB = bottom_z(y)  # noqa: N806 (local floor height)
    w = half_width(y)
    zs = crease_z(y)
    zt = top_z(y) - lip_drop(y)
    zs = min(zs, zt - 0.018)
    cr = crown(y)
    xe = w - 0.064

    def top(x):
        return zt + cr * (1.0 - (x / xe) ** 2)

    pts = [
        (0.0, ZB), (w * 0.5, ZB), (w - 0.10, ZB), (w - 0.045, ZB + 0.006),
        (w - 0.016, ZB + 0.028), (w - 0.004, ZB + 0.065), (w, ZB + 0.12), (w, 0.36),
        (w, 0.52), (w, zs - 0.06), (w - 0.0015, zs - 0.012), (w - 0.004, zs),
        (w - 0.030, zs + 0.45 * (zt - zs)), (w - 0.052, zt - 0.010), (xe, zt),
        (w - 0.090, top(w - 0.090)), (w * 0.62, top(w * 0.62)), (w * 0.35, top(w * 0.35)),
        (w * 0.12, top(w * 0.12)), (0.0, top(0.0)),
    ]
    return pts


def lean(y, z):
    """Shark-nose: the bonnet lip leans forward over the grille panel."""
    if y < Y_BF - 0.004:
        return 0.0
    return 0.018 * smoothstep(0.665, 0.712, z)


def stations():
    ys = [Y_BF - d for d in (0.0, 0.003, 0.009, 0.018, 0.030, 0.045, 0.065, 0.090)]
    y = Y_BF - 0.12
    while y > Y_BR + 0.12:
        ys.append(y)
        y -= 0.065
    ys += [Y_BR + d for d in (0.090, 0.065, 0.045, 0.030, 0.018, 0.009, 0.003, 0.0)]
    return ys


def build_lower_body():
    part = nwcf.Part("lower_body")
    rows = []
    for y in stations():
        half = section(y)
        ring = [(x, y + lean(y, z), z) for x, z in half]
        ring += [(-x, y + lean(y, z), z) for x, z in reversed(half[1:-1])]
        rows.append(ring)
    V, _ = part.grid(rows, "paint", closed_u=True)
    part.cap(V[0], "paint")
    part.cap(list(reversed(V[-1])), "paint")
    return part.to_object(recalc=True)


def side_curve(y, z0, z1, samples=10):
    """Points and outward normals on the body side at station y between
    heights z0..z1 (follows the section polyline)."""
    half = section(y)[4:15]
    pts, nrm = [], []
    for k in range(samples + 1):
        z = z0 + (z1 - z0) * k / samples
        for a, b in zip(half, half[1:]):
            if a[1] <= z <= b[1] or b[1] <= z <= a[1]:
                t = 0.0 if b[1] == a[1] else (z - a[1]) / (b[1] - a[1])
                x = a[0] + (b[0] - a[0]) * t
                n = Vector((b[1] - a[1], 0.0, -(b[0] - a[0]))).normalized()
                pts.append((x, y, z))
                nrm.append(tuple(n))
                break
    return pts, nrm


def top_point(y, x):
    """Point and normal on the bonnet / boot surface."""
    half = section(y)[14:]
    for a, b in zip(half, half[1:]):
        if b[0] <= x <= a[0]:
            t = (x - a[0]) / (b[0] - a[0])
            z = a[1] + (b[1] - a[1]) * t
            n = Vector((-(b[1] - a[1]), 0.0, (a[0] - b[0]))).normalized()
            if n.z < 0:
                n = -n
            return (x, y, z), tuple(n)
    return (x, y, section(y)[-1][1]), (0, 0, 1)


# ------------------------------------------------------------ greenhouse

def rail_z(y):
    zb = belt_z(min(max(y, Y_RW), Y_C))
    if y >= Y_RF:
        s = (Y_C - y) / (Y_C - Y_RF)
        return zb + (ROOF_RAIL - zb) * s + 0.020 * math.sin(math.pi * s)
    if y <= Y_RR:
        s = (y - Y_RW) / (Y_RR - Y_RW)
        return zb + (ROOF_RAIL - zb) * s + 0.015 * math.sin(math.pi * s)
    return ROOF_RAIL


def g_crown(y):
    if y > Y_RF + 0.05 or y < Y_RR - 0.05:
        return GLASS_CROWN
    return ROOF_CROWN


def side_x(y, z):
    """Greenhouse side surface (planar tumblehome) at height z."""
    return X_BELT - (z - belt_z(y)) * TUMBLE


def g_section(y):
    zb = belt_z(y)
    zr = rail_z(y)
    cr = g_crown(y)
    h = max(zr - zb, 0.0)
    rr = min(0.035, 0.5 * h + 0.004)
    xr = side_x(y, zr)
    pts = []
    za = max(zr - rr, zb)
    for k in range(5):
        z = zb + (za - zb) * k / 4.0
        pts.append((side_x(y, z), z))
    a = Vector((side_x(y, za), za))
    c = Vector((xr, zr))
    bx = xr - rr
    b = Vector((bx, zr + cr * (1 - (bx / xr) ** 2)))
    for k in (1, 2, 3):
        t = k / 4.0
        p = a * (1 - t) ** 2 + c * 2 * t * (1 - t) + b * t * t
        pts.append((p.x, p.y))
    for k in range(6):
        x = bx * (1.0 - k / 5.0)
        pts.append((x, zr + cr * (1 - (x / xr) ** 2)))
    return pts


def g_top(y, x):
    zr = rail_z(y)
    xr = side_x(y, zr)
    return zr + g_crown(y) * (1 - (x / xr) ** 2)


def g_stations():
    ys = []
    n = 14
    for k in range(n + 1):
        ys.append(Y_C - (Y_C - Y_RF) * (k / n) ** 1.0)
    y = Y_RF - 0.09
    while y > Y_RR + 0.05:
        ys.append(y)
        y -= 0.09
    for k in range(n + 1):
        ys.append(Y_RR - (Y_RR - Y_RW) * (k / n))
    return ys


def build_greenhouse():
    part = nwcf.Part("greenhouse")
    rows = []
    for y in g_stations():
        half = g_section(y)
        ring = [(x, y, z) for x, z in half] + [(-x, y, z) for x, z in reversed(half[:-1])]
        rows.append(ring)
    part.grid(rows, "paint")
    obj = part.to_object()
    # Make normals point outward (roof faces up) before the inward shell.
    me = obj.data
    roof = max(me.polygons, key=lambda p: p.center.z)
    if roof.normal.z < 0:
        me.flip_normals()
    nwcf.solidify(obj, 0.022, -1.0)
    # Inner skin of the shell (headliner, pillar trims) is interior, not paint.
    me = obj.data
    idx = len(me.materials)
    me.materials.append(nwcf.logical_material("interior"))
    cabin = Vector((0.0, -0.27, 0.80))
    for p in me.polygons:
        if p.normal.dot(p.center - cabin) < 0.0 and p.center.z > 0.86:
            p.material_index = idx
    return obj


# Side windows in (y, z): front door, rear door, rear quarter light.
def windows():
    zb = lambda y: belt_z(y) + 0.010  # noqa: E731
    return {
        "front": [(0.575, zb(0.575)), (-0.135, zb(-0.135)), (-0.135, WIN_TOP), (0.330, WIN_TOP)],
        "rear": [(-0.257, zb(-0.257)), (-0.800, zb(-0.800)), (-0.800, WIN_TOP), (-0.257, WIN_TOP)],
        "quarter": [(-0.825, zb(-0.825)), (-1.045, zb(-1.045)), (-0.880, WIN_TOP), (-0.825, WIN_TOP)],
    }


def ws_half(y):
    return side_x(y, rail_z(y)) - 0.052


def prism_yz(name, poly, x0=-1.2, x1=1.2):
    part = nwcf.Part(name)
    bm = part.bm
    a = [bm.verts.new((x0, y, z)) for y, z in poly]
    b = [bm.verts.new((x1, y, z)) for y, z in poly]
    n = len(poly)
    for k in range(n):
        part.face([a[k], a[(k + 1) % n], b[(k + 1) % n], b[k]], "black_satin")
    part.face(list(reversed(a)), "black_satin")
    part.face(b, "black_satin")
    return part.to_object(recalc=True)


def prism_xy(name, outline, z0, z1, key="rubber"):
    part = nwcf.Part(name)
    bm = part.bm
    a = [bm.verts.new((x, y, z0)) for x, y in outline]
    b = [bm.verts.new((x, y, z1)) for x, y in outline]
    n = len(outline)
    for k in range(n):
        part.face([a[k], a[(k + 1) % n], b[(k + 1) % n], b[k]], key)
    part.face(list(reversed(a)), key)
    part.face(b, key)
    return part.to_object(recalc=True)


def glass_outline(y0, y1, margin=0.0, steps=10):
    right = [(ws_half(y0 + (y1 - y0) * k / steps) + margin, y0 + (y1 - y0) * k / steps)
             for k in range(steps + 1)]
    left = [(-x, y) for x, y in reversed(right)]
    return right + left


WS_Y0, WS_Y1 = Y_C - 0.040, Y_RF + 0.030      # windshield opening (y range)
RW_Y0, RW_Y1 = Y_RR - 0.030, Y_RW + 0.045     # rear window opening


def cut_greenhouse(gh):
    cutters = []
    for name, poly in windows().items():
        cutters.append(prism_yz("win_" + name, poly))
    cutters.append(prism_xy("win_ws", glass_outline(WS_Y0, WS_Y1), 0.70, 1.60))
    cutters.append(prism_xy("win_rw", glass_outline(RW_Y0, RW_Y1), 0.70, 1.60))
    return nwcf.boolean(gh, cutters)


def bilinear(poly, u, v):
    a, b, c, d = [Vector(p) for p in poly]
    bottom = a.lerp(b, u)
    top = d.lerp(c, u)
    return bottom.lerp(top, v)


def expand(poly, m):
    c = Vector((0, 0))
    for p in poly:
        c += Vector(p)
    c /= len(poly)
    out = []
    for p in poly:
        d = Vector(p) - c
        out.append(tuple(Vector(p) + Vector((math.copysign(m, d.x), math.copysign(m, d.y)))))
    return out


def side_surface(y, z, inset):
    n = Vector((1.0, 0.0, TUMBLE)).normalized()
    return Vector((side_x(y, z), y, z)) - n * inset, n


def build_glass_and_frames():
    part = nwcf.Part("glass_frames")
    nu, nv = 8, 5
    for name, poly in windows().items():
        big = expand(poly, 0.014)
        for sx in (1.0, -1.0):
            rows = []
            for j in range(nv + 1):
                row = []
                for i in range(nu + 1):
                    y, z = bilinear(big, i / nu, j / nv)
                    p, _ = side_surface(y, z, 0.011)
                    row.append((p.x * sx, p.y, p.z))
                rows.append(row if sx > 0 else list(reversed(row)))
            part.grid(rows, "glass")
            # Black window frame on the outer surface, around the opening.
            loop = _densify(expand(poly, 0.010) + [expand(poly, 0.010)[0]], 0.03)
            pts, nrm = [], []
            for y, z in loop:
                p, n = side_surface(y, z, -0.0)
                pts.append((p.x * sx, p.y, p.z))
                nrm.append((n.x * sx, n.y, n.z))
            nwcf.strip(part, pts, nrm, 0.022, "black_satin", lift=0.0016)
    # B-pillar, division bar and mirror sail: black plates on the side.
    for poly in (
        [(-0.135, None), (-0.257, None), (-0.257, WIN_TOP + 0.012), (-0.135, WIN_TOP + 0.012)],
        [(-0.800, None), (-0.825, None), (-0.825, WIN_TOP + 0.012), (-0.800, WIN_TOP + 0.012)],
        [(0.575, None), (0.845, None), (0.62, None), (0.4775, None)],
    ):
        if poly[2][1] is None:   # sail
            zb0 = belt_z(0.575) + 0.002
            quad = [(0.575, zb0), (0.845, zb0), (0.620, zb0 + 0.160), (0.4775, zb0 + 0.160)]
        else:
            quad = [(y, belt_z(y) + 0.002 if z is None else z) for y, z in poly]
        for sx in (1.0, -1.0):
            rows = []
            for j in range(4):
                row = []
                for i in range(4):
                    y, z = bilinear(quad, i / 3, j / 3)
                    p, _ = side_surface(y, z, -0.0017)
                    row.append((p.x * sx, p.y, p.z))
                rows.append(row)
            part.grid(rows, "black_satin", orient=lambda c, sx=sx: (sx, 0.0, 0.0))
    # Windshield and rear glass + rubber surrounds.
    for (y0, y1) in ((WS_Y0, WS_Y1), (RW_Y0, RW_Y1)):
        rows = []
        n_y, n_x = 10, 12
        for j in range(n_y + 1):
            y = (y0 + 0.014 * math.copysign(1, y0 - y1)) + ((y1 - 0.014 * math.copysign(1, y0 - y1))
                                                             - (y0 + 0.014 * math.copysign(1, y0 - y1))) * j / n_y
            hw = ws_half(y) + 0.014
            row = []
            for i in range(n_x + 1):
                x = -hw + 2 * hw * i / n_x
                row.append((x, y, g_top(y, x) - 0.011))
            rows.append(row)
        if y1 < y0:
            part.grid(rows, "glass")
        else:
            part.grid([list(reversed(r)) for r in rows], "glass")
        loop = [(x + math.copysign(0.010, x), y) for x, y in glass_outline(y0, y1, 0.0, 16)]
        loop.append(loop[0])
        loop = _densify(loop, 0.03)
        pts, nrm = [], []
        for x, y in loop:
            pts.append((x, y, g_top(y, x)))
            nrm.append((x * 0.15, 0.0, 1.0))
        nwcf.strip(part, pts, nrm, 0.022, "rubber", lift=0.0016)
    return part.to_object()


def _densify(loop, step):
    out = []
    for a, b in zip(loop, loop[1:]):
        a, b = Vector(a), Vector(b)
        n = max(1, int((b - a).length / step))
        for k in range(n):
            out.append(tuple(a.lerp(b, k / n)))
    out.append(tuple(loop[-1]))
    return out


# ------------------------------------------------------------- cutters

def arch_cutter(name, y_axle, radius, side):
    part = nwcf.Part(name)
    x_in, x_out = W - 0.45, W + 0.30
    m = nwcf.frame_from_axis((0, y_axle, ARCH_Z), (side, 0, 0))
    a0, a1 = (x_in, x_out)
    nwcf.lathe(part, m, [(a0, radius), (a1, radius)], "well", segments=72,
               cap_start="well", cap_end="well")
    return part.to_object(recalc=True)


def cabin_cutter():
    part = nwcf.Part("cabin_cavity")
    nwcf.box(part, (0.0, (0.862 + -1.395) * 0.5, (0.27 + 1.6) * 0.5),
             (1.40, 0.862 + 1.395, 1.6 - 0.27), "interior", bevel=0.04, segments=2)
    return part.to_object(recalc=True)


def arch_lips():
    part = nwcf.Part("arch_lips")
    for y_axle, radius in ((Y_FA, ARCH_R_F), (Y_RA, ARCH_R_R)):
        for sx in (1.0, -1.0):
            pts = []
            r = radius + 0.004
            a_end = math.acos(max(-1.0, min(1.0, (0.30 - ARCH_Z) / r)))
            for k in range(41):
                t = -a_end + 2 * a_end * k / 40
                y = y_axle + r * math.sin(t)
                z = ARCH_Z + r * math.cos(t)
                pts.append((sx * (half_width(y) + 0.001), y, z))
            nwcf.tube(part, pts, 0.009, "paint", sides=8)
    return part.to_object()


# -------------------------------------------------------- body details

def build_details():
    part = nwcf.Part("details")
    # Side rubbing strip between the arches (black, half-round).
    prof = [(0.0, -0.024), (0.008, -0.020), (0.012, -0.008), (0.012, 0.008), (0.008, 0.020), (0.0, 0.024)]
    for sx in (1.0, -1.0):
        rows = []
        y0, y1 = Y_FA - ARCH_R_F - 0.012, Y_RA + ARCH_R_R + 0.012
        for k in range(31):
            y = y0 + (y1 - y0) * k / 30
            row = [(sx * (half_width(y) + o), y, 0.430 + dz) for o, dz in prof]
            rows.append(row if sx > 0 else list(reversed(row)))
        V, faces = part.grid(rows, "black_satin")
        faces.append(part.face(list(reversed(V[0])), "black_satin"))
        faces.append(part.face(V[-1], "black_satin"))
        part.orient([f for f in faces if f is not None],
                    lambda c, sx=sx: Vector((sx, 0.0, (c.z - 0.430) * 40.0)))
    # Door handles (black, just above the crease line).
    for y in (0.020, -0.890):
        for sx in (1.0, -1.0):
            x = sx * (half_width(y) - 0.010)
            nwcf.box(part, (x, y, 0.738), (0.022, 0.105, 0.016), "black_satin", bevel=0.004)
    # Panel gaps: doors (vertical), rear door around the arch, bonnet and boot.
    for sx in (1.0, -1.0):
        for y in (0.840, -0.200):
            pts, nrm = side_curve(y, ZB + 0.03, top_z(y) - 0.012, 18)
            _gap(part, pts, nrm, sx)
        pts, nrm = side_curve(-1.070, 0.612, belt_z(-1.07) - 0.012, 8)
        r = 0.380
        arc_p, arc_n = [], []
        a0, a1 = math.asin(0.1025 / r), math.radians(106.0)
        for k in range(1, 17):
            t = a0 + (a1 - a0) * k / 16
            y = Y_RA + r * math.sin(t)
            z = ARCH_Z + r * math.cos(t)
            arc_p.append((half_width(y), y, z))
            arc_n.append((1.0, 0.0, 0.0))
        pts = list(reversed(pts)) + arc_p
        nrm = list(reversed(nrm)) + arc_n
        _gap(part, pts, nrm, sx)
        # Bonnet and boot shut lines on the top surface.
        for (ya, yb) in ((Y_BF - 0.030, 0.878), (-1.470, Y_BR + 0.024)):
            pts, nrm = [], []
            for k in range(25):
                y = ya + (yb - ya) * k / 24
                p, n = top_point(y, 0.690)
                pts.append(p)
                nrm.append(n)
            _gap(part, pts, nrm, sx)
    for (y, half) in ((0.878, 0.69), (-1.470, 0.69)):
        pts, nrm = [], []
        for k in range(25):
            p, n = top_point(y, abs(-half + 2 * half * k / 24))
            pts.append((-half + 2 * half * k / 24, p[1], p[2]))
            nrm.append(n)
        _gap(part, pts, nrm, 1.0)
    # Boot lid on the rear face, between the tail lights.
    yb = Y_BR - 0.0012
    for x in (-0.266, 0.266):
        nwcf.strip(part, [(x, yb, 0.545), (x, yb, 0.814)], [(0, -1, 0), (0, -1, 0)], 0.004, "gap", lift=0.0)
    nwcf.strip(part, [(-0.266, yb, 0.545), (0.266, yb, 0.545)], [(0, -1, 0), (0, -1, 0)], 0.004, "gap", lift=0.0)
    # Mirrors on the sail.
    for sx in (1.0, -1.0):
        m = Matrix.Translation((sx * 0.858, 0.705, 0.915))
        nwcf.box(part, (0, 0, 0), (0.075, 0.115, 0.085), "black_satin", matrix=m, bevel=0.025, segments=3)
        nwcf.box(part, (sx * -0.050, 0.020, -0.040), (0.070, 0.050, 0.030), "black_satin", matrix=m,
                 bevel=0.010)
        nwcf.box(part, (sx * 0.004, -0.058, 0.0), (0.060, 0.004, 0.064), "chrome", matrix=m, bevel=0.012)
    return part.to_object()


def _gap(part, pts, nrm, sx):
    if len(pts) < 2:
        return
    p = [(sx * x, y, z) for x, y, z in pts]
    n = [(sx * a, b, c) for a, b, c in nrm]
    nwcf.strip(part, p, n, 0.0045, "gap", lift=0.0009)


# -------------------------------------------------------------- front

def build_front():
    part = nwcf.Part("front")
    yf = Y_BF
    # Recessed black grille panel under the bonnet lip.
    nwcf.box(part, (0, yf - 0.012, 0.578), (1.484, 0.040, 0.182), "black_matte", bevel=0.006)
    # Horizontal slats between the kidneys and the lamps.
    for sx in (1.0, -1.0):
        for z in (0.512, 0.540, 0.568, 0.596, 0.624, 0.652):
            nwcf.box(part, (sx * 0.255, yf + 0.010, z), (0.235, 0.008, 0.010), "black_gloss", bevel=0.002)
    # Quad round lamps: chrome bezel + textured lens.
    for sx in (1.0, -1.0):
        for x, r in ((0.615, 0.074), (0.455, 0.068)):
            m = nwcf.frame_from_axis((sx * x, yf + 0.008, 0.578), (0, 1, 0))
            back = Vector((sx * x, yf - 0.06, 0.578))
            nwcf.lathe(part, m, [(0.000, r + 0.014), (0.010, r + 0.013), (0.015, r + 0.006),
                                 (0.012, r - 0.002)], "chrome", segments=36,
                       orient=lambda c, back=back: c - back)
            prof = [(0.008, r), (0.013, r * 0.78), (0.017, r * 0.45), (0.0185, 0.0)]

            def uv(ks, kp, prof=prof, r=r):
                rad = prof[kp][1] / r
                t = math.tau * ks / 36
                return (0.5 + 0.5 * rad * math.cos(t), 0.5 + 0.5 * rad * math.sin(t))

            nwcf.lathe(part, m, prof, "tex_headlight", segments=36, uv_fn=uv,
                       orient=lambda c: (0.0, 1.0, 0.0))
            nwcf.lathe(part, m, [(-0.030, r + 0.004), (0.004, r + 0.004)], "black_gloss", segments=24,
                       orient=lambda c, back=back: c - back)
    # Kidney grille: chrome surround, black backing, vertical slats.
    for sx in (1.0, -1.0):
        cx, cz, hw, hh, rc = sx * 0.075, 0.578, 0.056, 0.083, 0.026
        loop = _rounded_rect(cx, cz, hw, hh, rc, 5)
        nwcf.tube(part, [(x, yf + 0.024, z) for x, z in loop] + [(loop[0][0], yf + 0.024, loop[0][1])],
                  0.0075, "chrome", sides=6, cap=False)
        inner = _rounded_rect(cx, cz, hw - 0.004, hh - 0.004, rc - 0.004, 5)
        f = part.poly([(x, yf + 0.016, z) for x, z in reversed(inner)], "black_gloss")
        part.orient([f], lambda c: (0.0, 1.0, 0.0))
        for k in range(5):
            x = cx - hw + 0.019 + k * (2 * hw - 0.038) / 4
            nwcf.box(part, (x, yf + 0.020, cz), (0.007, 0.010, 2 * hh - 0.020), "black_gloss", bevel=0.002)
    # Front bumper (wraps to the arches) with indicators, plate and intakes.
    _bumper(part, front=True)
    for sx in (1.0, -1.0):
        nwcf.box(part, (sx * 0.640, HALF_L - 0.012, 0.455), (0.120, 0.012, 0.030), "amber_lens", bevel=0.004)
    _plate(part, (-0.170, HALF_L - 0.020, 0.335), front=True)
    nwcf.box(part, (0.0, HALF_L - 0.004, 0.215), (0.92, 0.012, 0.050), "black_gloss", bevel=0.006)
    return part.to_object()


def _rounded_rect(cx, cz, hw, hh, r, seg):
    pts = []
    corners = ((hw - r, hh - r, 0.0), (-(hw - r), hh - r, 90.0), (-(hw - r), -(hh - r), 180.0),
               (hw - r, -(hh - r), 270.0))
    for ox, oz, a0 in corners:
        for k in range(seg + 1):
            a = math.radians(a0 + 90.0 * k / seg)
            pts.append((cx + ox + r * math.cos(a), cz + oz + r * math.sin(a)))
    return pts


def _bumper(part, front):
    """Bumper lofted along a U-shaped plan path, thinner at the sides."""
    if front:
        y_face, y_end, z0, z1 = Y_BF + 0.006, Y_FA + ARCH_R_F + 0.055, 0.118, 0.492
    else:
        y_face, y_end, z0, z1 = Y_BR - 0.006, Y_RA - ARCH_R_R - 0.055, 0.255, 0.535
    sgn = 1.0 if front else -1.0
    rc = 0.11
    path = []
    # (x, y, outward normal x, outward normal y, reach scale)
    n_side = 6
    for k in range(n_side + 1):
        y = y_end + (y_face - sgn * rc - y_end) * k / n_side
        path.append((half_width(y) + 0.004, y, 1.0, 0.0, 0.04 + 0.06 * min(1.0, k / 2.0)))
    for k in range(1, 9):
        a = math.radians(90.0 * k / 8)
        x = W + 0.004 - rc + rc * math.cos(a)
        y = y_face - sgn * rc + sgn * rc * math.sin(a)
        path.append((x, y, math.cos(a), sgn * math.sin(a), 0.10 + 0.90 * (k / 8) ** 2))
    for k in range(1, 9):
        x = (W + 0.004 - rc) * (1.0 - k / 8)
        path.append((x, y_face, 0.0, sgn, 1.0))
    h = z1 - z0
    prof = [(-0.030, 1.000), (0.000, 1.005), (0.034, 0.990), (0.042, 0.945), (0.042, 0.885),
            (0.035, 0.872), (0.035, 0.832), (0.045, 0.818), (0.050, 0.520), (0.068, 0.140),
            (0.070, 0.070), (0.055, 0.0), (0.0, -0.005), (-0.030, 0.0)]
    rows = []
    full = path + [(-x, y, -nx, ny, s) for x, y, nx, ny, s in reversed(path[:-1])]
    for x, y, nx, ny, s in full:
        rows.append([(x + nx * o * s, y + ny * o * s, z0 + h * t) for o, t in prof])
    if not front:
        rows = [list(reversed(r)) for r in rows]
    V, faces = part.grid(rows, "black_matte", closed_u=True)
    c0 = part.cap(V[0], "black_matte")
    c1 = part.cap(list(reversed(V[-1])), "black_matte")
    nwcf.recalc(part, faces + list(c0.link_faces) + list(c1.link_faces))


def _plate(part, center, front):
    """Blank registration plate (no characters are reproduced)."""
    x, y, z = center
    hw, hh = 0.260, 0.057
    if front:
        pts = [(x - hw, y, z - hh), (x + hw, y, z - hh), (x + hw, y, z + hh), (x - hw, y, z + hh)]
        uvs = [(0, 0), (1, 0), (1, 1), (0, 1)]
    else:
        pts = [(x + hw, y, z - hh), (x - hw, y, z - hh), (x - hw, y, z + hh), (x + hw, y, z + hh)]
        uvs = [(0, 0), (1, 0), (1, 1), (0, 1)]
    f = part.poly(pts, "tex_plate", uvs=uvs, smooth=False)
    if f is not None:
        f.normal_update()


# -------------------------------------------------------------- rear

def build_rear():
    part = nwcf.Part("rear")
    yr = Y_BR
    for sx in (1.0, -1.0):
        x0, x1, z0, z1 = 0.272, 0.772, 0.557, 0.742
        # Lamp body (black) slightly proud of the rear face.
        nwcf.box(part, (sx * (x0 + x1) * 0.5, yr - 0.002, (z0 + z1) * 0.5),
                 (x1 - x0, 0.020, z1 - z0), "black_satin", bevel=0.004)
        nu = 6
        rows = []
        for j in range(2):
            row = []
            for i in range(nu + 1):
                x = x0 + (x1 - x0) * i / nu
                row.append((sx * x, yr - 0.0125, z0 + 0.006 + (z1 - z0 - 0.012) * j))
            rows.append(row if sx < 0 else list(reversed(row)))
        uvf = (lambda i, j: (i / nu, j)) if sx < 0 else (lambda i, j: (1.0 - i / nu, j))
        part.grid(rows, "tex_tail", uv_fn=uvf, smooth=False, orient=lambda c: (0.0, -1.0, 0.0))
    _bumper(part, front=False)
    _plate(part, (0.0, yr - 0.0035, 0.627), front=False)
    # Twin exhaust tips at the far left rear corner (rear photo, camera-matched).
    for x in (-0.700, -0.630):
        nwcf.tube(part, [(x, -1.95, 0.215), (x, HALF_L * -1 - 0.004, 0.215)], 0.030, "exhaust", sides=16,
                  cap=False)
        m = nwcf.frame_from_axis((x, -HALF_L + 0.012, 0.215), (0, 1, 0))
        nwcf.lathe(part, m, [(0.0, 0.0), (0.0, 0.026)], "soot", segments=16,
                   orient=lambda c: (0.0, -1.0, 0.0))
    return part.to_object()


# ----------------------------------------------------------- interior

def build_interior():
    part = nwcf.Part("interior")
    nwcf.box(part, (0, 0.735, 0.715), (1.36, 0.27, 0.17), "interior", bevel=0.03)
    nwcf.box(part, (0, 0.60, 0.585), (0.18, 0.30, 0.20), "interior", bevel=0.02)
    nwcf.tube(part, [(0, 0.40, 0.38), (0.0, 0.33, 0.52)], 0.010, "black_satin", sides=6)
    # Left-hand drive: wheel, column.
    c = Vector((-0.360, 0.470, 0.805))
    tilt = Matrix.Rotation(math.radians(-62.0), 4, 'X')
    ring = [c + (tilt @ Vector((0.175 * math.cos(a), 0.0, 0.175 * math.sin(a)))) for a in
            [math.tau * k / 20 for k in range(21)]]
    nwcf.tube(part, ring, 0.013, "black_satin", sides=6, cap=False)
    for a in (0.0, math.pi, math.pi * 1.5):
        tip = c + tilt @ Vector((0.17 * math.cos(a), 0.0, 0.17 * math.sin(a)))
        nwcf.tube(part, [c, tip], 0.009, "black_satin", sides=6)
    nwcf.tube(part, [c, c + Vector((0, 0.25, -0.10))], 0.020, "black_satin", sides=8)
    # Bucket seats.
    for sx in (-1.0, 1.0):
        x = sx * 0.355
        nwcf.box(part, (x, 0.08, 0.35), (0.46, 0.50, 0.10), "seat", bevel=0.035)
        back = Matrix.Translation((x, -0.20, 0.70)) @ Matrix.Rotation(math.radians(-12.0), 4, 'X')
        nwcf.box(part, (0, 0, 0), (0.48, 0.09, 0.74), "seat", matrix=back, bevel=0.035)
        for side in (-1.0, 1.0):
            nwcf.box(part, (side * 0.225, 0.07, 0.08), (0.07, 0.16, 0.50), "seat", matrix=back, bevel=0.03)
        nwcf.box(part, (0, 0.06, 0.30), (0.30, 0.10, 0.10), "seat", matrix=back, bevel=0.03)
    nwcf.box(part, (0, -0.80, 0.36), (1.26, 0.48, 0.12), "seat", bevel=0.04)
    back = Matrix.Translation((0, -1.16, 0.62)) @ Matrix.Rotation(math.radians(-18.0), 4, 'X')
    nwcf.box(part, (0, 0, 0), (1.26, 0.12, 0.48), "seat", matrix=back, bevel=0.04)
    # Roll cage: main hoop, A-pillar bars, roof bars, rear stays, diagonal, door bars.
    r = 0.020
    hoop_y = -0.360
    hoop = [(0.655, hoop_y, 0.29), (0.650, hoop_y, 0.95), (0.610, hoop_y, 1.14), (0.520, hoop_y, 1.215),
            (0.0, hoop_y, 1.235), (-0.520, hoop_y, 1.215), (-0.610, hoop_y, 1.14), (-0.650, hoop_y, 0.95),
            (-0.655, hoop_y, 0.29)]
    nwcf.tube(part, hoop, r, "cage", sides=8)
    for sx in (1.0, -1.0):
        nwcf.tube(part, [(sx * 0.520, hoop_y, 1.215), (sx * 0.535, 0.20, 1.205), (sx * 0.600, 0.55, 1.02),
                         (sx * 0.655, 0.80, 0.80), (sx * 0.665, 0.84, 0.30)], r, "cage", sides=8)
        nwcf.tube(part, [(sx * 0.520, hoop_y, 1.215), (sx * 0.560, -1.00, 0.86), (sx * 0.600, -1.32, 0.42)],
                  r, "cage", sides=8)
        nwcf.tube(part, [(sx * 0.660, 0.78, 0.36), (sx * 0.660, hoop_y, 0.70)], r * 0.9, "cage", sides=8)
        nwcf.tube(part, [(sx * 0.660, 0.78, 0.70), (sx * 0.660, hoop_y, 0.36)], r * 0.9, "cage", sides=8)
    nwcf.tube(part, [(0.640, hoop_y, 0.33), (-0.520, hoop_y, 1.205)], r * 0.9, "cage", sides=8)
    nwcf.tube(part, [(0.53, 0.18, 1.205), (-0.53, -0.34, 1.215)], r * 0.9, "cage", sides=8)
    return part.to_object()


# ---------------------------------------------------------- textures

def draw_regions(key, size):
    from PIL import Image, ImageDraw, ImageFilter

    w, h = size
    alb = Image.new("RGB", (w, h), (0, 0, 0))
    orm = Image.new("RGB", (w, h), (255, 60, 0))
    emi = Image.new("RGB", (w, h), (0, 0, 0))
    da, do, de = ImageDraw.Draw(alb), ImageDraw.Draw(orm), ImageDraw.Draw(emi)
    if key == "tex_headlight":
        cx, cy = w / 2, h / 2
        for k in range(60, 0, -1):
            r = cx * k / 60
            t = k / 60
            g = int(150 + 90 * (0.5 + 0.5 * math.cos(t * 22.0)))
            da.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(g, g, min(255, g + 6)))
            do.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(255, int(18 + 30 * t), 200))
        for k in range(-6, 7):
            y = cy + k * h / 14
            da.line((0, y, w, y), fill=(235, 238, 242), width=1)
        da.ellipse((cx - w * 0.16, cy - h * 0.16, cx + w * 0.16, cy + h * 0.16), fill=(250, 248, 236))
        de.ellipse((cx - w * 0.46, cy - h * 0.46, cx + w * 0.46, cy + h * 0.46), fill=(90, 86, 70))
        de.ellipse((cx - w * 0.20, cy - h * 0.20, cx + w * 0.20, cy + h * 0.20), fill=(255, 246, 214))
        emi = emi.filter(ImageFilter.GaussianBlur(w * 0.05))
        da.ellipse((0, 0, w - 1, h - 1), outline=(60, 62, 66), width=max(2, w // 64))
    elif key == "tex_tail":
        split = int(w * 0.22)
        da.rectangle((0, 0, split, h), fill=(205, 206, 210))
        da.rectangle((split, 0, w, h), fill=(150, 8, 12))
        for k in range(0, h, max(4, h // 12)):
            da.line((split, k, w, k), fill=(110, 4, 8), width=2)
            da.line((0, k, split, k), fill=(175, 176, 180), width=2)
        da.rectangle((split - 3, 0, split + 3, h), fill=(20, 18, 20))
        da.rectangle((0, 0, w - 1, h - 1), outline=(18, 16, 18), width=4)
        do.rectangle((0, 0, w, h), fill=(255, 30, 0))
        de.rectangle((split + 6, 8, w - 8, h - 8), fill=(120, 6, 8))
        emi = emi.filter(ImageFilter.GaussianBlur(4))
    elif key == "tex_plate":
        da.rectangle((0, 0, w, h), fill=(236, 236, 230))
        da.rectangle((0, 0, int(w * 0.09), h), fill=(24, 52, 150))
        da.rectangle((1, 1, w - 2, h - 2), outline=(30, 30, 34), width=3)
        do.rectangle((0, 0, w, h), fill=(255, 120, 0))
    elif key == "tex_sidewall":
        return None
    return alb, orm, emi


# --------------------------------------------------------------- main

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
REPORT = os.path.join(REPO, "tools", "car_factory", "reports", "e30_blessed_build_report.json")


def build(out_dir, report_path=REPORT):
    nwcf.reset()
    lower = build_lower_body()
    cutters = [cabin_cutter()]
    for y_axle, radius, tag in ((Y_FA, ARCH_R_F, "f"), (Y_RA, ARCH_R_R, "r")):
        for side in (1.0, -1.0):
            cutters.append(arch_cutter("arch_%s_%d" % (tag, side), y_axle, radius, side))
    nwcf.boolean(lower, cutters)
    _drop_cutter_leftovers(lower)
    _mark_underside(lower)
    gh = cut_greenhouse(build_greenhouse())
    parts = [lower, gh, build_glass_and_frames(), arch_lips(), build_details(), build_front(),
             build_rear(), build_interior()]
    body = nwcf.join(parts, "E30_Blessed_Body")
    os.makedirs(out_dir, exist_ok=True)
    tmp = tempfile.mkdtemp(prefix="nwcf_")   # atlas PNGs are embedded in the GLB
    atlas = nwcf.write_atlas_images(os.path.join(tmp, "e30_blessed_atlas.png"), draw_regions)
    mats = nwcf.make_runtime_materials(atlas, (0.98, 0.70, 0.02))
    stats = nwcf.finalize(body, mats)
    empties = [
        nwcf.empty("wheel_FL", (-TRACK_F, Y_FA, WHEEL_Z), {"axle": "front", "side": -1}),
        nwcf.empty("wheel_FR", (TRACK_F, Y_FA, WHEEL_Z), {"axle": "front", "side": 1}),
        nwcf.empty("wheel_RL", (-TRACK_R, Y_RA, WHEEL_Z), {"axle": "rear", "side": -1}),
        nwcf.empty("wheel_RR", (TRACK_R, Y_RA, WHEEL_Z), {"axle": "rear", "side": 1}),
    ]
    glb = nwcf.export_glb(os.path.join(out_dir, "e30_blessed.glb"), [body] + empties)
    report = nwcf.mesh_report(body)
    lo, hi = report["bounds_min"], report["bounds_max"]
    if lo[0] < -(W + 0.08) or hi[0] > W + 0.08 or lo[2] < 0.0 or hi[2] > STOCK_HEIGHT:
        raise SystemExit("VALIDATION FAILED: geometry outside the car outline %s %s" % (lo, hi))
    report["logical_faces"] = stats
    report["glb_bytes"] = os.path.getsize(glb)
    report["wheel_pivots"] = {e.name: list(e.location) for e in empties}
    report["dimensions"] = {
        "length_with_bumpers_m": report["bounds_max"][1] - report["bounds_min"][1],
        "width_body_without_mirrors_m": 2 * W,
        "height_m": report["bounds_max"][2],
        "wheelbase_m": WHEELBASE,
        "front_overhang_m": FRONT_OVERHANG,
        "factory_height_m": STOCK_HEIGHT,
    }
    nwcf.write_json(report_path, report)
    return report


def _drop_cutter_leftovers(obj):
    """The exact boolean can keep pieces of a wheel-arch cutter outside the
    body (below the floor / beyond the side). Delete them: a factory car
    must stay inside its own outline (checked again in validate)."""
    import bmesh
    me = obj.data
    keys = [m.name for m in me.materials]
    bm = bmesh.new()
    bm.from_mesh(me)
    bad = [f for f in bm.faces if keys[f.material_index] == "L_well"
           and (f.calc_center_median().z < ZB - 0.004 or abs(f.calc_center_median().x) > W + 0.004)]
    bmesh.ops.delete(bm, geom=bad, context='FACES')
    loose = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context='VERTS')
    bm.to_mesh(me)
    bm.free()
    return len(bad)


def _mark_underside(obj):
    me = obj.data
    idx = len(me.materials)
    me.materials.append(nwcf.logical_material("under"))
    for p in me.polygons:
        if p.normal.z < -0.7 and p.center.z < 0.28:
            p.material_index = idx


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(REPO, "game", "assets", "cars", "e30_blessed"))
    ap.add_argument("--report", default=REPORT)
    args, _ = ap.parse_known_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:])
    os.makedirs(os.path.dirname(args.report), exist_ok=True)
    rep = build(args.out, args.report)
    print("E30 BUILD OK tris=%d verts=%d glb=%d bytes" % (rep["triangles"], rep["vertices"], rep["glb_bytes"]))
    print("bounds", rep["bounds_min"], rep["bounds_max"])
