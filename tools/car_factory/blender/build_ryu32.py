"""Nitro Wheelz Car Factory: RYU-32 coupe (fictional 90s Japanese drift
coupe, aggressive aero kit, large fixed wing, deep-dish wheels, bonnet
removed with a Toyota 1UZ-FE-style V8 on individual throttle bodies),
built from numbers with bpy and exported as ONE GLB.

Run (bpy module or Blender):
  python tools/car_factory/blender/build_ryu32.py --out game/assets/cars/ryu32

CLEAN and LIVERY share this GLB: they differ only in the paint material
(the LIVERY look adds a texture in the paint's livery UV layout, made by
draw_livery() below and saved next to the GLB). No geometry variants.

Sources and confidence (docs/car_factory/RYU32_FACTORY.md):
  * GAMEPLAY dimensions kept: length 4.545 m, wheelbase 2.615 m, width
    1.90 m (catalog / collisions; the body stays inside it).
  * Owner's "3D MODELING REFERENCE SHEET - CLEAN BLUE VERSION (HOOD
    REMOVED / ENGINE VISIBLE)": height 1.29 m, overhangs, greenhouse,
    lamps, kit, wing and wheel proportions measured on its orthographic
    views (visual estimates). The sheet lists width 1.76 m; the kit here
    is 1.87 m so the gameplay 1.90 m footprint is filled.
  * ENGINE: the owner's car spec is a 4.0 V8 ITB (1UZ-FE style, 350 HP);
    the sheet draws an inline engine with six trumpets. The V8 with eight
    trumpets is kept (brief: never replace the V8 with an R6).
  * LIVERY: no LIVERY reference image was received; the yellow / red
    livery drawn here is PROVISIONAL and must be replaced by the owner's.
  * No logos, badges or registration numbers.
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
LENGTH = 4.545
WHEELBASE = 2.615
HALF_L = LENGTH * 0.5
FRONT_OVERHANG = 1.040    # sheet (scaled)
Y_FA = HALF_L - FRONT_OVERHANG            # +1.2325
Y_RA = Y_FA - WHEELBASE                    # -1.3825
BUMPER = 0.100                             # kit bumpers reach
Y_BF = HALF_L - BUMPER
Y_BR = -HALF_L + BUMPER
W = 0.855                                  # body shell half width
WIDE = 0.935                               # kit arches (1.87 m, inside 1.90)
ROOF = 1.290

WHEEL_R = 0.330
WHEEL_Z = WHEEL_R
TRACK = 0.795
ARCH_Z = 0.320
ARCH_R = 0.365

ZB = 0.110
Y_C = 0.640
Y_RF = 0.050
Y_RR = -0.980
Y_RW = -1.590
ROOF_RAIL = 1.255
ROOF_CROWN = 0.035
GLASS_CROWN = 0.040
X_BELT = 0.748
TUMBLE = 0.38
WIN_TOP = 1.215
CREASE_Z = 0.715
HOOD_Y0 = Y_C + 0.030
HOOD_Y1 = Y_BF - 0.050
HOOD_F = 0.925


def smoothstep(a, b, x):
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3 - 2 * t)


# --------------------------------------------------------- lower body

def belt_z(y):
    """Wedge belt line rising to the C-pillar (90s coupe)."""
    return 0.885 + 0.060 * smoothstep(Y_C, Y_RW, y)


def top_z(y):
    if y >= Y_C:
        s = (Y_BF - y) / (Y_BF - Y_C)
        hood = 0.660 + (0.860 - 0.660) * s ** 0.80
        return hood + (belt_z(Y_C) - 0.860) * smoothstep(Y_C + 0.06, Y_C, y)
    if y >= Y_RW:
        return belt_z(y)
    s = (Y_RW - y) / (Y_RW - Y_BR)
    return belt_z(Y_RW) - 0.015 * s


def crown(y):
    if y >= Y_C:
        return 0.026
    if y >= Y_RW:
        return 0.0
    return 0.018


def half_width(y):
    # Front wings curve in towards the nose (R-series coupe plan).
    w = W - 0.045 * smoothstep(1.55, Y_BF, y)
    rf, rr = 0.110, 0.085
    d = y - (Y_BF - rf)
    if d > 0:
        w -= rf - math.sqrt(max(rf * rf - d * d, 0.0))
    d = (Y_BR + rr) - y
    if d > 0:
        w -= rr - math.sqrt(max(rr * rr - d * d, 0.0))
    return w


def lip_drop(y):
    r = 0.040
    d = y - (Y_BF - r)
    drop = 0.0
    if d > 0:
        drop = r - math.sqrt(max(r * r - d * d, 0.0))
    d = (Y_BR + 0.035) - y
    if d > 0:
        drop = max(drop, 0.035 - math.sqrt(max(0.035 ** 2 - d * d, 0.0)))
    return drop


def bottom_z(y):
    tf = smoothstep(Y_FA + ARCH_R, Y_FA + ARCH_R + 0.20, y)
    tr = smoothstep(Y_RA - ARCH_R, Y_RA - ARCH_R - 0.20, y)
    return ZB + 0.150 * tf + 0.160 * tr


def deck_edge(y):
    return half_width(y) - 0.055


def hood_x(y):
    return HOOD_F * deck_edge(y)


TOP_FRACTIONS = (0.965, HOOD_F, 0.76, 0.56, 0.37, 0.18, 0.0)


def section(y):
    zb = bottom_z(y)
    w = half_width(y)
    zt = top_z(y) - lip_drop(y)
    zs = min(CREASE_Z, zt - 0.055)
    cr = crown(y)
    xe = deck_edge(y)

    def top(x):
        return zt + cr * (1.0 - (x / xe) ** 2)

    pts = [
        (0.0, zb), (w * 0.5, zb), (w - 0.09, zb), (w - 0.035, zb + 0.008),
        (w - 0.014, zb + 0.035), (w - 0.004, zb + 0.080), (w, zb + 0.140), (w, 0.40),
        (w, 0.56), (w, zs - 0.040), (w - 0.002, zs - 0.008), (w - 0.012, zs),
        (w - 0.024, zs + 0.45 * (zt - zs)), (w - 0.040, zt - 0.012), (xe, zt),
    ]
    for f in TOP_FRACTIONS:
        pts.append((xe * f, top(xe * f)))
    return pts


def stations():
    ys = [Y_BF - d for d in (0.0, 0.004, 0.012, 0.024, 0.040)]
    y = Y_BF - 0.090
    while y > HOOD_Y0 + 0.02:
        ys.append(y)
        y -= 0.080
    ys.append(HOOD_Y0)
    y = HOOD_Y0 - 0.075
    while y > Y_BR + 0.12:
        ys.append(y)
        y -= 0.080
    ys += [Y_BR + d for d in (0.080, 0.055, 0.035, 0.020, 0.010, 0.004, 0.0)]
    ys = sorted(set(round(v, 5) for v in ys), reverse=True)
    if HOOD_Y1 not in ys:
        ys = sorted(ys + [HOOD_Y1], reverse=True)
    return ys


def build_lower_body():
    part = nwcf.Part("lower_body")
    rows = []
    for y in stations():
        half = section(y)
        ring = [(x, y, z) for x, z in half]
        ring += [(-x, y, z) for x, z in reversed(half[1:-1])]
        rows.append(ring)
    V, _ = part.grid(rows, "paint", closed_u=True)
    part.cap(V[0], "paint")
    part.cap(list(reversed(V[-1])), "paint")
    return part.to_object(recalc=True)


def side_curve(y, z0, z1, samples=10):
    half = section(y)[4:15]
    pts, nrm = [], []
    for k in range(samples + 1):
        z = z0 + (z1 - z0) * k / samples
        for (xa, za), (xb, zb_) in zip(half, half[1:]):
            if min(za, zb_) <= z <= max(za, zb_) and abs(zb_ - za) > 1e-6:
                t = (z - za) / (zb_ - za)
                x = xa + (xb - xa) * t
                n = Vector((zb_ - za, 0.0, -(xb - xa))).normalized()
                if n.x < 0:
                    n = -n
                pts.append((x, y, z))
                nrm.append(tuple(n))
                break
    return pts, nrm


def top_point(y, x):
    zt = top_z(y) - lip_drop(y)
    xe = deck_edge(y)
    z = zt + crown(y) * (1.0 - (min(x, xe) / xe) ** 2)
    return (x, y, z), (x / xe * 0.25, 0.0, 1.0)


def _drop_cutter_leftovers(obj):
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


def _mark_underside(obj):
    me = obj.data
    idx = len(me.materials)
    me.materials.append(nwcf.logical_material("under"))
    for p in me.polygons:
        if p.normal.z < -0.7 and p.center.z < 0.30:
            p.material_index = idx


def open_bonnet(obj):
    """Bonnet removed (sheet: engine visible) - both looks."""
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    gone = []
    for f in bm.faces:
        c = f.calc_center_median()
        if HOOD_Y0 + 1e-4 < c.y < HOOD_Y1 - 1e-4 and c.z > 0.55 and abs(c.x) < hood_x(c.y) - 1e-4:
            f.normal_update()
            if f.normal.z > 0.3:
                gone.append(f)
    bmesh.ops.delete(bm, geom=gone, context='FACES')
    loose = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context='VERTS')
    bm.to_mesh(obj.data)
    bm.free()
    return len(gone)


# ------------------------------------------------------------ greenhouse

def rail_z(y):
    zb = belt_z(min(max(y, Y_RW), Y_C))
    if y >= Y_RF:
        s = (Y_C - y) / (Y_C - Y_RF)
        return zb + (ROOF_RAIL - zb) * s + 0.020 * math.sin(math.pi * s)
    if y <= Y_RR:
        s = (y - Y_RW) / (Y_RR - Y_RW)
        return zb + (ROOF_RAIL - zb) * s ** 0.85 + 0.022 * math.sin(math.pi * s)
    return ROOF_RAIL


def g_crown(y):
    if y > Y_RF + 0.05 or y < Y_RR - 0.05:
        return GLASS_CROWN
    return ROOF_CROWN


def side_x(y, z):
    return X_BELT - (z - belt_z(y)) * TUMBLE


def g_section(y):
    zb = belt_z(y)
    zr = rail_z(y)
    cr = g_crown(y)
    h = max(zr - zb, 0.0)
    rr = min(0.055, 0.5 * h + 0.004)
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
    n = 12
    for k in range(n + 1):
        ys.append(Y_C - (Y_C - Y_RF) * k / n)
    y = Y_RF - 0.10
    while y > Y_RR + 0.05:
        ys.append(y)
        y -= 0.10
    for k in range(n + 1):
        ys.append(Y_RR - (Y_RR - Y_RW) * k / n)
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
    me = obj.data
    roof = max(me.polygons, key=lambda p: p.center.z)
    if roof.normal.z < 0:
        me.flip_normals()
    nwcf.solidify(obj, 0.022, -1.0)
    me = obj.data
    idx = len(me.materials)
    me.materials.append(nwcf.logical_material("interior"))
    cabin = Vector((0.0, -0.40, 0.85))
    for p in me.polygons:
        if p.normal.dot(p.center - cabin) < 0.0 and p.center.z > 0.92:
            p.material_index = idx
    return obj


def windows():
    zb = lambda y: belt_z(y) + 0.012  # noqa: E731
    return {
        "door": [(0.540, zb(0.540)), (-0.585, zb(-0.585)), (-0.585, WIN_TOP), (0.060, WIN_TOP)],
        "quarter": [(-0.645, zb(-0.645)), (-1.115, zb(-1.115)), (-0.925, WIN_TOP - 0.020), (-0.645, WIN_TOP)],
    }


def ws_half(y):
    return side_x(y, rail_z(y)) - 0.075


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


def prism_xy(name, outline, z0, z1, key="paint"):
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


WS_Y0, WS_Y1 = Y_C - 0.035, Y_RF + 0.030
RW_Y0, RW_Y1 = Y_RR - 0.030, Y_RW + 0.045


def cut_greenhouse(gh):
    cutters = [prism_yz("win_" + name, poly) for name, poly in windows().items()]
    cutters.append(prism_xy("win_ws", glass_outline(WS_Y0, WS_Y1), 0.75, 1.60))
    cutters.append(prism_xy("win_rw", glass_outline(RW_Y0, RW_Y1), 0.80, 1.60))
    return nwcf.boolean(gh, cutters)


def bilinear(poly, u, v):
    a, b, c, d = [Vector(p) for p in poly]
    return a.lerp(b, u).lerp(d.lerp(c, u), v)


def expand(poly, m):
    c = Vector((0, 0))
    for p in poly:
        c += Vector(p)
    c /= len(poly)
    return [tuple(Vector(p) + Vector((math.copysign(m, Vector(p).x - c.x), math.copysign(m, Vector(p).y - c.y))))
            for p in poly]


def side_surface(y, z, inset):
    n = Vector((1.0, 0.0, TUMBLE)).normalized()
    return Vector((side_x(y, z), y, z)) - n * inset, n


def _densify(loop, step):
    out = []
    for a, b in zip(loop, loop[1:]):
        a, b = Vector(a), Vector(b)
        n = max(1, int((b - a).length / step))
        for k in range(n):
            out.append(tuple(a.lerp(b, k / n)))
    out.append(tuple(loop[-1]))
    return out


def build_glass_and_frames():
    part = nwcf.Part("glass")
    nu, nv = 6, 3
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
            loop = _densify(expand(poly, 0.009) + [expand(poly, 0.009)[0]], 0.03)
            pts, nrm = [], []
            for y, z in loop:
                p, n = side_surface(y, z, 0.0)
                pts.append((p.x * sx, p.y, p.z))
                nrm.append((n.x * sx, n.y, n.z))
            nwcf.strip(part, pts, nrm, 0.016, "black_satin", lift=0.0018)
    for (y0, y1) in ((WS_Y0, WS_Y1), (RW_Y0, RW_Y1)):
        rows = []
        n_y, n_x = 8, 10
        sg = math.copysign(1, y0 - y1)
        for j in range(n_y + 1):
            y = (y0 + 0.014 * sg) + ((y1 - 0.014 * sg) - (y0 + 0.014 * sg)) * j / n_y
            hw = ws_half(y) + 0.014
            rows.append([(-hw + 2 * hw * i / n_x, y, g_top(y, -hw + 2 * hw * i / n_x) - 0.011)
                         for i in range(n_x + 1)])
        part.grid(rows if y1 < y0 else [list(reversed(r)) for r in rows], "glass")
        loop = [(x + math.copysign(0.0075, x), y) for x, y in glass_outline(y0, y1, 0.0, 16)]
        loop.append(loop[0])
        loop = _densify(loop, 0.03)
        nwcf.strip(part, [(x, y, g_top(y, x)) for x, y in loop], [(x * 0.15, 0.0, 1.0) for x, y in loop],
                   0.015, "rubber", lift=0.0018)
    return part.to_object()


# ------------------------------------------------------------- cutters

def arch_cutter(name, y_axle, side):
    part = nwcf.Part(name)
    m = nwcf.frame_from_axis((0, y_axle, ARCH_Z), (side, 0, 0))
    nwcf.lathe(part, m, [(W - 0.45, ARCH_R), (W + 0.30, ARCH_R)], "well", segments=48,
               cap_start="well", cap_end="well")
    return part.to_object(recalc=True)


def cabin_cutter():
    part = nwcf.Part("cabin_cavity")
    y0, y1 = Y_C - 0.030, Y_RW + 0.045
    nwcf.box(part, (0.0, (y0 + y1) * 0.5, (0.25 + 1.6) * 0.5),
             (1.46, y0 - y1, 1.6 - 0.25), "interior", bevel=0.04, segments=2)
    return part.to_object(recalc=True)


# ------------------------------------------------------- aero kit

def build_flares():
    """Kit over-fenders: rolled, wide, the tyre tucked slightly at the top."""
    part = nwcf.Part("flares")
    seg = 28
    a_l, b_l, a_o, b_o = 0.372, 0.300, 0.470, 0.378
    prof = [(0.0, 0.0), (0.18, 0.28), (0.40, 0.60), (0.64, 0.85), (0.86, 0.98), (1.0, 1.0)]
    end = math.acos((0.135 - ARCH_Z) / b_o)
    for y_axle in (Y_FA, Y_RA):
        for sx in (1.0, -1.0):
            rows = []
            for k in range(seg + 1):
                t = -end + 2 * end * k / seg
                st, ct = math.sin(t), math.cos(t)
                row = []
                for s, g in prof:
                    a = a_o + (a_l - a_o) * s
                    b = b_o + (b_l - b_o) * s
                    y = y_axle + a * st
                    z = ARCH_Z + b * ct
                    x = half_width(y) - 0.002 + (WIDE - half_width(y) + 0.002) * g
                    row.append((sx * x, y, z))
                row.append((sx * (WIDE - 0.010), y_axle + (a_l - 0.008) * st, ARCH_Z + (b_l - 0.008) * ct))
                row.append((sx * (WIDE - 0.045), y_axle + (a_l - 0.006) * st, ARCH_Z + (b_l - 0.006) * ct))
                rows.append(row)
            V, faces = part.grid(rows, lambda i, j: "paint" if i < len(prof) else "well")
            for end_row in (V[0], V[-1]):
                c = Vector((0, 0, 0))
                for v in end_row:
                    c += v.co
                c /= len(end_row)
                cap = part.cap(end_row, "paint", center=c)
                faces += list(cap.link_faces)
            cen = Vector((sx * (W - 0.10), y_axle, ARCH_Z))
            part.orient(faces, lambda c, cen=cen, sx=sx: Vector((sx * 0.6, 0, 0)) + (c - cen).normalized())
    return part.to_object()


def build_skirts():
    part = nwcf.Part("skirts")
    a_o = 0.470
    for sx in (1.0, -1.0):
        y0, y1 = Y_FA - a_o + 0.02, Y_RA + a_o - 0.02
        rows = []
        prof = [(-0.004, 0.215), (0.012, 0.212), (0.026, 0.190), (0.034, 0.120), (0.034, 0.075),
                (0.026, 0.055), (-0.010, 0.052)]
        for k in range(17):
            y = y0 + (y1 - y0) * k / 16
            rows.append([(sx * (half_width(y) + o), y, z) for o, z in prof])
        part.grid(rows, "paint")
        V0 = [part.bm.verts.new(Vector(p)) for p in rows[0]]
        V1 = [part.bm.verts.new(Vector(p)) for p in rows[-1]]
        part.cap(V0, "paint")
        part.cap(V1, "paint")
        part.orient(part.bm.faces[:], lambda c, sx=sx: Vector((sx, 0.0, (c.z - 0.13) * 6.0)))
    return part.to_object()


def _bumper(part, front, z0, z1, prof, key, wrap_to, rc=0.14, n_side=6):
    y_face = (Y_BF + 0.004) if front else (Y_BR - 0.004)
    sgn = 1.0 if front else -1.0
    path = []
    for k in range(n_side + 1):
        y = wrap_to + (y_face - sgn * rc - wrap_to) * k / n_side
        path.append((half_width(y) + 0.004, y, 1.0, 0.0, 0.35 + 0.15 * k / n_side))
    xw = half_width(y_face - sgn * rc) + 0.004
    for k in range(1, 9):
        a = math.radians(90.0 * k / 8)
        x = xw - rc + rc * math.cos(a)
        y = y_face - sgn * rc + sgn * rc * math.sin(a)
        path.append((x, y, math.cos(a), sgn * math.sin(a), 0.5 + 0.5 * (k / 8) ** 2))
    for k in range(1, 9):
        x = (xw - rc) * (1.0 - k / 8)
        path.append((x, y_face, 0.0, sgn, 1.0))
    full = path + [(-x, y, -nx, ny, s) for x, y, nx, ny, s in reversed(path[:-1])]
    rows = []
    for x, y, nx, ny, s in full:
        rows.append([(x + nx * o * s, y + ny * o * s, z0 + (z1 - z0) * t) for o, t in prof])
    if not front:
        rows = [list(reversed(r)) for r in rows]
    V, faces = part.grid(rows, key, closed_u=True)
    c0 = part.cap(V[0], key)
    c1 = part.cap(list(reversed(V[-1])), key)
    nwcf.recalc(part, faces + list(c0.link_faces) + list(c1.link_faces))


# Kit bumpers (sheet): tall faces, a horizontal swage, deep lower lips.
KIT_FRONT = [(-0.030, 1.0), (0.000, 1.004), (0.034, 0.990), (0.056, 0.950), (0.068, 0.860), (0.072, 0.700),
             (0.066, 0.670), (0.072, 0.640), (0.076, 0.320), (0.084, 0.200), (0.096, 0.150), (0.096, 0.090),
             (0.080, 0.040), (0.040, 0.0), (0.0, -0.004), (-0.030, 0.0)]
KIT_REAR = [(-0.030, 1.0), (0.000, 1.004), (0.034, 0.990), (0.056, 0.950), (0.068, 0.860), (0.072, 0.700),
            (0.072, 0.420), (0.080, 0.330), (0.092, 0.260), (0.094, 0.120), (0.070, 0.030), (0.030, 0.0),
            (0.0, -0.004), (-0.030, 0.0)]


def build_front():
    part = nwcf.Part("front")
    yf = Y_BF
    # Lamps sit in the body-coloured nose (sheet), each in its own black
    # housing; the black grille slot runs between them.
    for sx in (1.0, -1.0):
        cx, cz, hw, hh = sx * 0.462, 0.565, 0.172, 0.060
        nwcf.box(part, (cx, yf + 0.004, cz), (2 * hw + 0.020, 0.024, 2 * hh + 0.018), "black_gloss", bevel=0.008)
        rows = []
        nu, nv = 6, 3
        for j in range(nv + 1):
            row = []
            for i in range(nu + 1):
                u, v = i / nu, j / nv
                bulge = 0.005 * (1 - (2 * u - 1) ** 2) * (1 - (2 * v - 1) ** 2)
                row.append((cx - hw + 2 * hw * u, yf + 0.016 + bulge, cz - hh + 2 * hh * v))
            rows.append(row)
        uvf = (lambda i, j: (i / nu, j / nv)) if sx > 0 else (lambda i, j: (1.0 - i / nu, j / nv))
        part.grid(rows, "tex_headlight_twin", uv_fn=uvf, orient=lambda c: (0.0, 1.0, 0.0))
        # Amber corner lamps wrapping round the wing.
        nwcf.box(part, (sx * 0.705, yf - 0.012, 0.565), (0.125, 0.040, 0.118), "amber_lens", bevel=0.020,
                 segments=2)
    # Grille slot with a body-coloured bar.
    nwcf.box(part, (0.0, yf + 0.004, 0.565), (0.560, 0.016, 0.080), "gap", bevel=0.004)
    nwcf.box(part, (0.0, yf + 0.012, 0.566), (0.560, 0.010, 0.010), "paint", bevel=0.003)
    # Kit bumper with three intakes and a lower lip.
    _bumper(part, True, 0.040, 0.520, KIT_FRONT, "paint", Y_FA + 0.470 + 0.02)
    yb = Y_BF + 0.004 + 0.076
    for cx, hw in ((0.0, 0.330), (0.585, 0.130), (-0.585, 0.130)):
        nwcf.box(part, (cx, yb + 0.002, 0.250), (2 * hw, 0.012, 0.150), "gap", bevel=0.012)
        for k in range(4):
            nwcf.box(part, (cx, yb + 0.007, 0.200 + 0.033 * k), (2 * hw - 0.02, 0.004, 0.006), "black_satin")
    # Front crash tube X behind the centre intake (sheet).
    for sx in (1.0, -1.0):
        nwcf.tube(part, [(sx * 0.30, Y_BF - 0.02, 0.18), (-sx * 0.30, Y_BF - 0.02, 0.32)], 0.014, "alu",
                  sides=8)
    return part.to_object()


def _round_lamp(part, x, z, r, y, back_dir, tex, bezel="chrome"):
    m = nwcf.frame_from_axis((x, y, z), back_dir)
    back = Vector((x, y, z)) - Vector(back_dir) * 0.06
    nwcf.lathe(part, m, [(-0.030, r + 0.010), (0.004, r + 0.010)], "black_gloss", segments=24,
               orient=lambda c, back=back: c - back)
    nwcf.lathe(part, m, [(0.003, r + 0.011), (0.008, r + 0.010), (0.010, r + 0.006), (0.009, r + 0.002),
                         (0.005, r + 0.0005)], bezel, segments=28, orient=lambda c, back=back: c - back)
    prof = [(0.0045, r + 0.0005), (0.0085, r * 0.80), (0.0110, r * 0.48), (0.0120, 0.0)]

    def uv(ks, kp, prof=prof, r=r):
        rad = min(prof[kp][1] / r, 1.0)
        t = math.tau * ks / 28
        return (0.5 + 0.5 * rad * math.cos(t), 0.5 + 0.5 * rad * math.sin(t))

    nwcf.lathe(part, m, prof, tex, segments=28, uv_fn=uv, orient=lambda c, d=back_dir: d)


def build_rear():
    part = nwcf.Part("rear")
    yr = Y_BR
    for sx in (1.0, -1.0):
        nwcf.box(part, (sx * 0.515, yr - 0.002, 0.665), (0.440, 0.012, 0.185), "black_gloss", bevel=0.012)
        for x in (0.405, 0.625):
            _round_lamp(part, sx * x, 0.665, 0.072, yr - 0.006, (0, -1, 0), "tex_tail_round")
        nwcf.box(part, (sx * 0.515, yr - 0.010, 0.665), (0.022, 0.010, 0.060), "amber_lens", bevel=0.004)
    # Boot lid shut lines on the rear face.
    yb = Y_BR - 0.0012
    nwcf.strip(part, [(-0.76, yb, 0.585), (0.76, yb, 0.585)], [(0, -1, 0), (0, -1, 0)], 0.0045, "gap", lift=0.0)
    _bumper(part, False, 0.065, 0.565, KIT_REAR, "paint", Y_RA - 0.470 - 0.02)
    yb = Y_BR - 0.004 - 0.072
    for (a, b) in (((-0.24, 0.24), (0.24, 0.24)), ((0.24, 0.24), (0.24, 0.42)),
                   ((0.24, 0.42), (-0.24, 0.42)), ((-0.24, 0.42), (-0.24, 0.24))):
        nwcf.strip(part, [(a[0], yb - 0.001, a[1]), (b[0], yb - 0.001, b[1])], [(0, -1, 0), (0, -1, 0)],
                   0.006, "gap", lift=0.0)
    # Diffuser strakes.
    for x in (-0.30, -0.10, 0.10, 0.30):
        nwcf.box(part, (x, Y_BR - 0.03, 0.095), (0.010, 0.10, 0.06), "black_satin", bevel=0.003)
    # One big exhaust on the left (sheet rear view).
    x, z, r = -0.460, 0.150, 0.068
    # Dark cut-out in the bumper face so the big tip reads (sheet).
    m0 = nwcf.frame_from_axis((x, Y_BR - 0.004 - 0.092, z), (0, -1, 0))
    nwcf.lathe(part, m0, [(0.0, r * 1.45), (0.002, r * 1.40), (0.003, 0.0)], "gap", segments=20,
               orient=lambda c: (0.0, -1.0, 0.0))
    y_end = -HALF_L + 0.032
    nwcf.tube(part, [(x, -1.95, z + 0.02), (x, y_end, z)], r * 0.85, "exhaust", sides=16, cap=False)
    m = nwcf.frame_from_axis((x, y_end, z), (0, -1, 0))
    nwcf.lathe(part, m, [(0.0, r * 0.88), (0.030, r), (0.038, r * 1.03), (0.040, r * 0.92), (0.036, r * 0.84)],
               "chrome", segments=20, orient=lambda c: Vector((c.x - x, 0.0, c.z - z)) * 4.0
               + Vector((0.0, -1.0, 0.0)))
    nwcf.lathe(part, m, [(0.036, r * 0.84), (0.010, r * 0.78), (0.010, 0.0)], "soot", segments=20,
               orient=lambda c: (0.0, -1.0, 0.0))
    return part.to_object()


def build_wing():
    """Large fixed wing on the boot: cambered blade, end plates, uprights."""
    part = nwcf.Part("wing")
    # Thick cambered blade with a kicked-up trailing edge (sheet rear view).
    chord = [(0.000, 0.000), (0.030, 0.026), (0.100, 0.040), (0.200, 0.040), (0.290, 0.050), (0.345, 0.080),
             (0.352, 0.068), (0.300, 0.020), (0.200, -0.006), (0.100, -0.012), (0.030, -0.010)]
    y_le, z_le = -1.860, 1.040
    rows = []
    for k in range(13):
        x = -0.720 + 1.44 * k / 12
        rows.append([(x, y_le - c, z_le + t + 0.020 * (c / 0.34)) for c, t in chord])
    V, faces = part.grid(rows, "paint", closed_u=True)
    c0 = part.cap(V[0], "paint")
    c1 = part.cap(list(reversed(V[-1])), "paint")
    nwcf.recalc(part, faces + list(c0.link_faces) + list(c1.link_faces))
    for sx in (1.0, -1.0):
        plate = [(-1.820, 0.960), (-2.225, 0.985), (-2.225, 1.150), (-1.860, 1.100)]
        prism = []
        for (y, z) in plate:
            prism.append((y, z))
        bm = part.bm
        a = [bm.verts.new((sx * 0.722, y, z)) for y, z in prism]
        b = [bm.verts.new((sx * 0.736, y, z)) for y, z in prism]
        fs = []
        for k in range(4):
            fs.append(part.face([a[k], a[(k + 1) % 4], b[(k + 1) % 4], b[k]], "paint"))
        fs.append(part.face(list(reversed(a)), "paint"))
        fs.append(part.face(b, "paint"))
        nwcf.recalc(part, fs)
        (_, _, zd), _ = top_point(-1.98, 0.45)
        nwcf.box(part, (sx * 0.45, -1.98, (zd + 1.04) * 0.5), (0.016, 0.110, 1.04 - zd + 0.01), "black_satin",
                 bevel=0.004)
    return part.to_object()


def build_side_details():
    part = nwcf.Part("side")
    for sx in (1.0, -1.0):
        for y in (0.580,):
            pts, nrm = side_curve(y, ZB + 0.05, top_z(y) - 0.012, 18)
            _gap(part, pts, nrm, sx)
        pts, nrm = side_curve(-0.665, 0.25, belt_z(-0.665) - 0.012, 14)
        _gap(part, pts, nrm, sx)
        # Door handle (body-coloured pull with a dark recess).
        y = -0.40
        nwcf.box(part, (sx * (half_width(y) + 0.003), y, 0.800), (0.012, 0.130, 0.028), "paint", bevel=0.006)
        nwcf.box(part, (sx * (half_width(y) + 0.0005), y, 0.794), (0.006, 0.110, 0.012), "black_satin", bevel=0.002)
        # Aero mirror on a slim stalk (sheet: large body-coloured mirrors).
        m = Matrix.Translation((sx * 0.892, 0.460, 1.000))
        nwcf.box(part, (0, 0, 0), (0.095, 0.075, 0.065), "paint", matrix=m, bevel=0.025, segments=3)
        nwcf.box(part, (0, -0.040, 0), (0.080, 0.006, 0.050), "black_gloss", matrix=m, bevel=0.012)
        nwcf.box(part, (sx * -0.075, 0.010, -0.040), (0.080, 0.030, 0.020), "black_satin", matrix=m, bevel=0.006)
    # Boot and fuel filler.
    pts, nrm = [], []
    for k in range(25):
        x = -0.72 + 1.44 * k / 24
        p, n = top_point(Y_RW - 0.040, abs(x))
        pts.append((x, p[1], p[2]))
        nrm.append(n)
    _gap(part, pts, nrm, 1.0)
    for sx in (1.0, -1.0):
        pts, nrm = [], []
        for k in range(13):
            y = Y_RW - 0.040 + (Y_BR + 0.03 - (Y_RW - 0.040)) * k / 12
            p, n = top_point(y, 0.72)
            pts.append(p)
            nrm.append(n)
        _gap(part, pts, nrm, sx)
    return part.to_object()


def _gap(part, pts, nrm, sx):
    if len(pts) < 2:
        return
    p = [(sx * x, y, z) for x, y, z in pts]
    n = [(sx * a, b, c) for a, b, c in nrm]
    nwcf.strip(part, p, n, 0.0045, "gap", lift=0.0009)


# --------------------------------------------------------- engine bay

def build_engine_bay():
    """Open bay with a 1UZ-style 4.0 V8 on eight individual throttle bodies
    (two rows of four polished trumpets in the valley), cam covers, headers,
    radiator, strut tops + brace, battery and catch can."""
    part = nwcf.Part("engine_bay")
    ys = [y for y in stations() if HOOD_Y0 - 1e-6 <= y <= HOOD_Y1 + 1e-6]
    floor_z = 0.40
    for sx in (1.0, -1.0):
        rows = []
        for y in ys:
            (x, _, z), _n = top_point(y, hood_x(y))
            rows.append([(sx * x, y, z), (sx * x, y, z - 0.10), (sx * (x - 0.06), y, floor_z)])
        V, faces = part.grid(rows, "paint")
        part.orient(faces, lambda c, sx=sx: (-sx, 0.0, 0.2))
    for y, d in ((HOOD_Y0, 1.0), (HOOD_Y1, -1.0)):
        xh = hood_x(y)
        top_row = []
        for k in range(17):
            x = -xh + 2 * xh * k / 16
            (_, _, z), _n = top_point(y, abs(x))
            top_row.append((x, y, z))
        low = [(x * (xh - 0.06) / xh, y, floor_z) for x, _, _ in top_row]
        V, faces = part.grid([top_row, low], "paint")
        part.orient(faces, lambda c, d=d: (0.0, d, 0.0))
    xf = hood_x(1.40) - 0.06
    f = part.poly([(-xf, HOOD_Y0, floor_z), (xf, HOOD_Y0, floor_z), (xf, HOOD_Y1, floor_z), (-xf, HOOD_Y1, floor_z)],
                  "well")
    part.orient([f], lambda c: (0.0, 0.0, 1.0))
    # Radiator + intercooler-style core behind the slam panel.
    nwcf.box(part, (0.0, HOOD_Y1 - 0.060, 0.560), (1.20, 0.050, 0.260), "radiator", bevel=0.006)
    nwcf.box(part, (0.0, HOOD_Y1 - 0.060, 0.705), (1.24, 0.070, 0.030), "alu_cast", bevel=0.008)
    ey, el = 1.430, 0.62
    # Block + heads (V): sump block, two angled heads with cam covers.
    nwcf.box(part, (0.0, ey, 0.500), (0.46, el, 0.200), "engine_black", bevel=0.020)
    for sx in (1.0, -1.0):
        tilt = Matrix.Translation((sx * 0.175, ey, 0.640)) @ Matrix.Rotation(math.radians(-sx * 32.0), 4, 'Y')
        nwcf.box(part, (0, 0, 0), (0.170, el - 0.04, 0.110), "engine_black", matrix=tilt, bevel=0.018)
        nwcf.box(part, (0, 0, 0.070), (0.150, el - 0.10, 0.050), "black_satin", matrix=tilt, bevel=0.020, segments=3)
        for k in range(4):
            nwcf.box(part, (0, -0.21 + 0.14 * k, 0.098), (0.11, 0.020, 0.008), "alu_cast", matrix=tilt, bevel=0.003)
        # Headers: four primaries per bank dropping outward.
        for k in range(4):
            yk = ey - 0.21 + 0.14 * k
            nwcf.tube(part, [(sx * 0.26, yk, 0.600), (sx * 0.36, yk, 0.570), (sx * 0.42, yk - 0.02, 0.48),
                             (sx * 0.44, ey - 0.15, 0.41)], 0.018, "header", sides=8, cap=False)
    # Valley: ITB carrier + eight polished trumpets (two rows of four).
    nwcf.box(part, (0.0, ey, 0.705), (0.200, el - 0.06, 0.050), "alu_cast", bevel=0.012)
    for sx in (1.0, -1.0):
        for k in range(4):
            at = Vector((sx * 0.058, ey - 0.225 + 0.15 * k, 0.725))
            axis = Vector((sx * 0.22, 0.0, 1.0)).normalized()
            m = nwcf.frame_from_axis(tuple(at), tuple(axis))
            bell = [(0.0, 0.030), (0.050, 0.030), (0.082, 0.036), (0.104, 0.048), (0.113, 0.059),
                    (0.116, 0.061), (0.115, 0.054), (0.108, 0.050)]
            nwcf.lathe(part, m, bell, "chrome", segments=18,
                       orient=lambda c, at=at, axis=axis: (c - at) - axis * (c - at).dot(axis) + axis * 0.2)
            nwcf.lathe(part, m, [(0.108, 0.050), (0.040, 0.026), (0.040, 0.0)], "soot", segments=10,
                       orient=lambda c, axis=axis: tuple(axis))
    # Fuel rail + throttle linkage.
    for sx in (1.0, -1.0):
        nwcf.tube(part, [(sx * 0.13, ey - 0.30, 0.735), (sx * 0.13, ey + 0.28, 0.735)], 0.010, "red_part", sides=6)
    # Strut tops, strut brace behind the engine, battery, catch can.
    for sx in (1.0, -1.0):
        m = nwcf.frame_from_axis((sx * 0.640, Y_FA, 0.640), (0, 0, 1))
        nwcf.lathe(part, m, [(0.0, 0.080), (0.10, 0.076), (0.12, 0.054), (0.125, 0.0)], "paint", segments=14,
                   orient=lambda c, sx=sx: Vector((c.x - sx * 0.64, c.y - Y_FA, 0.4)))
        m2 = nwcf.frame_from_axis((sx * 0.640, Y_FA, 0.765), (0, 0, 1))
        nwcf.lathe(part, m2, [(0.0, 0.034), (0.012, 0.030), (0.016, 0.0)], "gold_part", segments=10,
                   orient=lambda c: (0.0, 0.0, 1.0))
    nwcf.tube(part, [(0.64, Y_FA - 0.02, 0.775), (0.30, 1.03, 0.80), (-0.30, 1.03, 0.80), (-0.64, Y_FA - 0.02, 0.775)],
              0.016, "blue_part", sides=8)
    nwcf.box(part, (-0.52, 0.86, 0.540), (0.17, 0.25, 0.170), "black_satin", bevel=0.010)
    nwcf.box(part, (-0.52, 0.81, 0.630), (0.12, 0.06, 0.020), "red_part", bevel=0.005)
    m = nwcf.frame_from_axis((0.50, 0.88, 0.50), (0, 0, 1))
    nwcf.lathe(part, m, [(0.0, 0.045), (0.20, 0.045), (0.215, 0.034), (0.22, 0.0)], "alu", segments=14,
               cap_start="alu", orient=lambda c: Vector((c.x - 0.50, c.y - 0.88, 0.3)))
    for sx in (1.0, -1.0):
        nwcf.tube(part, [(sx * 0.10, ey + 0.32, 0.58), (sx * 0.20, ey + 0.45, 0.60), (sx * 0.30, HOOD_Y1 - 0.10, 0.60)],
                  0.022, "black_satin", sides=8, cap=False)
    return part.to_object()


# ----------------------------------------------------------- interior

def build_interior():
    part = nwcf.Part("interior")
    nwcf.box(part, (0, 0.47, 0.790), (1.42, 0.26, 0.16), "interior", bevel=0.03)
    nwcf.box(part, (0, 0.30, 0.600), (0.22, 0.36, 0.26), "interior", bevel=0.02)
    c = Vector((0.380, 0.200, 0.880))          # right-hand drive
    tilt = Matrix.Rotation(math.radians(-60.0), 4, 'X')
    ring = [c + (tilt @ Vector((0.180 * math.cos(a), 0.0, 0.180 * math.sin(a)))) for a in
            [math.tau * k / 20 for k in range(21)]]
    nwcf.tube(part, ring, 0.014, "black_satin", sides=6, cap=False)
    for a in (0.0, math.pi, math.pi * 1.5):
        tip = c + tilt @ Vector((0.17 * math.cos(a), 0.0, 0.17 * math.sin(a)))
        nwcf.tube(part, [c, tip], 0.010, "black_satin", sides=6)
    nwcf.tube(part, [c, c + Vector((0, 0.25, -0.10))], 0.022, "black_satin", sides=8)
    for sx in (-1.0, 1.0):
        x = sx * 0.370
        nwcf.box(part, (x, -0.20, 0.34), (0.48, 0.50, 0.10), "seat", bevel=0.035)
        back = Matrix.Translation((x, -0.48, 0.70)) @ Matrix.Rotation(math.radians(-14.0), 4, 'X')
        nwcf.box(part, (0, 0, 0), (0.48, 0.10, 0.72), "seat", matrix=back, bevel=0.035)
        for side in (-1.0, 1.0):
            nwcf.box(part, (side * 0.225, 0.07, 0.06), (0.07, 0.16, 0.48), "seat", matrix=back, bevel=0.03)
        nwcf.box(part, (sx * 0.745, -0.35, 0.62), (0.03, 2.00, 0.40), "interior", bevel=0.01)
    nwcf.box(part, (0, -1.10, 0.40), (1.20, 0.40, 0.12), "seat", bevel=0.04)
    # Roll cage: main hoop, A-pillar bars, rear stays and the X behind the seats.
    r = 0.020
    hy = -0.760
    hoop = [(0.66, hy, 0.30), (0.66, hy, 0.98), (0.60, hy, 1.15), (0.50, hy, 1.205), (0.0, hy, 1.225),
            (-0.50, hy, 1.205), (-0.60, hy, 1.15), (-0.66, hy, 0.98), (-0.66, hy, 0.30)]
    nwcf.tube(part, hoop, r, "cage", sides=8)
    for sx in (1.0, -1.0):
        nwcf.tube(part, [(sx * 0.50, hy, 1.205), (sx * 0.52, -0.10, 1.200), (sx * 0.60, 0.30, 1.03),
                         (sx * 0.66, 0.55, 0.85), (sx * 0.67, 0.60, 0.32)], r, "cage", sides=8)
        nwcf.tube(part, [(sx * 0.50, hy, 1.205), (sx * 0.55, -1.30, 0.92), (sx * 0.60, -1.55, 0.45)], r, "cage",
                  sides=8)
    nwcf.tube(part, [(0.64, hy, 0.34), (-0.50, hy, 1.200)], r * 0.9, "cage", sides=8)
    nwcf.tube(part, [(-0.64, hy, 0.34), (0.50, hy, 1.200)], r * 0.9, "cage", sides=8)
    return part.to_object()


# ---------------------------------------------------------- textures

def draw_regions(key, size):
    from PIL import Image, ImageDraw, ImageFilter

    w, h = size
    alb = Image.new("RGB", (w, h), (0, 0, 0))
    orm = Image.new("RGB", (w, h), (255, 60, 0))
    emi = Image.new("RGB", (w, h), (0, 0, 0))
    da, do, de = ImageDraw.Draw(alb), ImageDraw.Draw(orm), ImageDraw.Draw(emi)
    if key == "tex_headlight_twin":
        # Clear lens over a chrome reflector with two round projector units.
        for y in range(h):
            t = abs(y / h - 0.5) * 2.0
            g = int(200 - 70 * t)
            da.line((0, y, w, y), fill=(g, g, g + 4))
        for cx in (w * 0.33, w * 0.68):
            r = h * 0.36
            for k in range(20, 0, -1):
                rr = r * k / 20
                g = int(120 + 120 * (1 - k / 20))
                da.ellipse((cx - rr, h / 2 - rr, cx + rr, h / 2 + rr), fill=(g, g, g + 6))
            da.ellipse((cx - r, h / 2 - r, cx + r, h / 2 + r), outline=(70, 72, 78), width=3)
            da.ellipse((cx - r * 0.35, h / 2 - r * 0.35, cx + r * 0.35, h / 2 + r * 0.35), fill=(236, 238, 244))
            de.ellipse((cx - r * 0.8, h / 2 - r * 0.8, cx + r * 0.8, h / 2 + r * 0.8), fill=(36, 36, 34))
        do.rectangle((0, 0, w, h), fill=(255, 30, 170))
        emi = emi.filter(ImageFilter.GaussianBlur(h * 0.08))
        da.rectangle((0, 0, w - 1, h - 1), outline=(26, 26, 30), width=4)
    elif key == "tex_tail_round":
        cx, cy = w / 2, h / 2
        for k in range(48, 0, -1):
            t = k / 48
            r_ = int(120 + 80 * (1 - t))
            da.ellipse((cx - cx * t, cy - cy * t, cx + cx * t, cy + cy * t), fill=(r_, 8, 14))
        for k in range(1, 7):
            rr = cx * k / 7
            da.ellipse((cx - rr, cy - rr, cx + rr, cy + rr), outline=(90, 4, 8), width=2)
        da.ellipse((cx - cx * 0.22, cy - cy * 0.22, cx + cx * 0.22, cy + cy * 0.22), fill=(210, 40, 44))
        do.rectangle((0, 0, w, h), fill=(255, 26, 0))
        de.ellipse((cx - cx * 0.8, cy - cy * 0.8, cx + cx * 0.8, cy + cy * 0.8), fill=(80, 4, 6))
        emi = emi.filter(ImageFilter.GaussianBlur(w * 0.05))
    else:
        return None
    return alb, orm, emi


def draw_livery(path, bounds):
    """PROVISIONAL yellow / red livery in the paint's livery UV layout (see
    nwcf.livery_uv): a yellow sweep along the lower sides with a red
    pinstripe and a red-edged yellow stripe over roof and boot. No logos,
    no text, no numbers. Replace with the owner's LIVERY reference."""
    from PIL import Image, ImageDraw

    S = 1024
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    (x0, y0, z0), (x1, y1, z1) = bounds
    L, H, Wd = y1 - y0, z1 - z0, x1 - x0
    yellow, red = (255, 196, 0, 255), (214, 18, 30, 255)

    def side_pt(u_len, z, right):
        u = (u_len - y0) / L            # 0 rear .. 1 front
        v = (z - z0) / H
        if right:
            return (u * S, (1.0 - (0.02 + v * 0.30)) * S)
        return ((1.0 - u) * S, (1.0 - (0.34 + v * 0.30)) * S)

    for right in (True, False):
        # Sweep rising from the rear bumper to the front wing.
        top = [side_pt(y0 + L * k / 20, 0.215 + 0.13 * (k / 20) ** 1.6, right) for k in range(21)]
        bottom = [side_pt(y0 + L * k / 20, 0.085, right) for k in range(20, -1, -1)]
        d.polygon(top + bottom, fill=yellow)
        stripe = [side_pt(y0 + L * k / 20, 0.240 + 0.13 * (k / 20) ** 1.6, right) for k in range(21)]
        d.line(stripe, fill=red, width=12)
        stripe2 = [side_pt(y0 + L * k / 20, 0.272 + 0.13 * (k / 20) ** 1.6, right) for k in range(21)]
        d.line(stripe2, fill=yellow, width=5)

    def top_pt(y, x):
        return ((0.02 + (y - y0) / L * 0.66) * S, (1.0 - (0.66 + (x - x0) / Wd * 0.32)) * S)

    for xo, col, wd in ((0.0, red, 0.24), (0.0, yellow, 0.17)):
        poly = [top_pt(y0, xo - wd), top_pt(y1, xo - wd), top_pt(y1, xo + wd), top_pt(y0, xo + wd)]
        d.polygon(poly, fill=col)
    # Front and rear islands: a yellow lower band.
    d.rectangle((0.70 * S, (1.0 - 0.66 - 0.32 * 0.10) * S, 0.84 * S, (1.0 - 0.66) * S), fill=yellow)
    d.rectangle((0.85 * S, (1.0 - 0.66 - 0.32 * 0.10) * S, 0.99 * S, (1.0 - 0.66) * S), fill=yellow)
    img.save(path)
    return path


# --------------------------------------------------------------- main

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
REPORT = os.path.join(REPO, "tools", "car_factory", "reports", "ryu32_build_report.json")


def build(out_dir, report_path=REPORT):
    nwcf.reset()
    lower = build_lower_body()
    cutters = [cabin_cutter()]
    for y_axle, tag in ((Y_FA, "f"), (Y_RA, "r")):
        for side in (1.0, -1.0):
            cutters.append(arch_cutter("arch_%s_%d" % (tag, side), y_axle, side))
    nwcf.boolean(lower, cutters)
    _drop_cutter_leftovers(lower)
    _mark_underside(lower)
    opened = open_bonnet(lower)
    gh = cut_greenhouse(build_greenhouse())
    parts = [lower, gh, build_glass_and_frames(), build_flares(), build_skirts(), build_side_details(),
             build_front(), build_rear(), build_wing(), build_engine_bay(), build_interior()]
    for p in parts:
        nwcf.tag_variant(p, 0)
    body = nwcf.join(parts, "RYU32_Body")
    os.makedirs(out_dir, exist_ok=True)
    tmp = tempfile.mkdtemp(prefix="nwcf_")
    atlas = nwcf.write_atlas_images(os.path.join(tmp, "ryu32_atlas.png"), draw_regions)
    mats = nwcf.make_runtime_materials(atlas, (0.05, 0.20, 0.78))
    stats = nwcf.finalize(body, mats)
    empties = [
        nwcf.empty("wheel_FL", (-TRACK, Y_FA, WHEEL_Z), {"axle": "front", "side": -1}),
        nwcf.empty("wheel_FR", (TRACK, Y_FA, WHEEL_Z), {"axle": "front", "side": 1}),
        nwcf.empty("wheel_RL", (-TRACK, Y_RA, WHEEL_Z), {"axle": "rear", "side": -1}),
        nwcf.empty("wheel_RR", (TRACK, Y_RA, WHEEL_Z), {"axle": "rear", "side": 1}),
    ]
    glb = nwcf.export_glb(os.path.join(out_dir, "ryu32.glb"), [body] + empties)
    report = nwcf.mesh_report(body)
    lo, hi = report["bounds_min"], report["bounds_max"]
    livery = draw_livery(os.path.join(out_dir, "ryu32_livery_provisional.png"), (lo, hi))
    if lo[0] < -0.95 or hi[0] > 0.95 or lo[2] < 0.0 or hi[2] > ROOF + 0.02 \
            or hi[1] > HALF_L + 0.01 or lo[1] < -HALF_L - 0.01:
        raise SystemExit("VALIDATION FAILED: geometry outside the car outline %s %s" % (lo, hi))
    report["logical_faces"] = stats
    report["bonnet_faces_removed"] = opened
    report["glb_bytes"] = os.path.getsize(glb)
    report["livery_png"] = os.path.basename(livery)
    report["livery_png_bytes"] = os.path.getsize(livery)
    report["wheel_pivots"] = {e.name: list(e.location) for e in empties}
    report["dimensions"] = {
        "length_m": hi[1] - lo[1], "width_m": hi[0] - lo[0], "height_m": hi[2],
        "wheelbase_m": WHEELBASE, "front_overhang_m": FRONT_OVERHANG, "track_hub_m": 2 * TRACK,
        "wheel_radius_m": WHEEL_R,
    }
    nwcf.write_json(report_path, report)
    return report


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(REPO, "game", "assets", "cars", "ryu32"))
    ap.add_argument("--report", default=REPORT)
    args, _ = ap.parse_known_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:])
    os.makedirs(os.path.dirname(args.report), exist_ok=True)
    rep = build(args.out, args.report)
    print("RYU32 BUILD OK tris=%d verts=%d glb=%d bytes" % (rep["triangles"], rep["vertices"], rep["glb_bytes"]))
    print("bounds", rep["bounds_min"], rep["bounds_max"])
