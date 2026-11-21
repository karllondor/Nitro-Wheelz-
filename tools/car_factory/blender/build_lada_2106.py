"""Nitro Wheelz Car Factory: Lada 2106 Drift Spec, ONE model with two
geometry variants (RED = exposed ITB engine, quad round lamps, chrome
bumpers, bolt-on overfenders; WHITE = clean bonnet, rectangular lamps,
colour-keyed bumpers, rolled flares), built from numbers with bpy and
exported as ONE GLB.

Run (bpy module or Blender):
  python tools/car_factory/blender/build_lada_2106.py --out game/assets/cars/lada_2106

Sources and confidence (docs/car_factory/LADA_2106_FACTORY.md):
  * GAMEPLAY dimensions kept exactly: length 4.166 m (bumper to bumper),
    wheelbase 2.424 m, width over the arches 1.91 m (catalog / collisions).
    The stock VAZ-2106 shell is 1.611 m wide; the arches widen it.
  * VISUAL ESTIMATES measured on the two approved Nitro Wheelz concept
    sheets (red "LADA 2106 DRIFT SPEC" and the pearl-white sheet; side,
    front and rear views scaled to the 4.166 m length): roof 1.34 m, belt
    0.83 m, bonnet 0.70 -> 0.81 m, overhangs 0.68 / 1.06 m, tyre radius
    0.295 m, lamp / grille / bumper / tail-lamp positions.
  * No logos, badges or registration numbers are reproduced (the sheets'
    grille emblem becomes a blank chrome tab).

Variant mask: every part is tagged with nwcf.tag_variant(obj, slot):
0 = shared, 1 = RED only, 2 = WHITE only (TEXCOORD_1). The game collapses
the faces of the other variant in the vertex shader: one GLB, one mesh,
three materials, no LOD, the same object in the garage and the race.
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
LENGTH = 4.166            # gameplay length (bumper to bumper)
WHEELBASE = 2.424         # gameplay wheelbase
HALF_L = LENGTH * 0.5
FRONT_OVERHANG = 0.680    # sheet estimate (scaled)
Y_FA = HALF_L - FRONT_OVERHANG            # front axle  +1.403
Y_RA = Y_FA - WHEELBASE                    # rear axle   -1.021
BUMPER = 0.062                             # bumper reach beyond the body face
Y_BF = HALF_L - BUMPER                     # body front face
Y_BR = -HALF_L + BUMPER                    # body rear face
W = 0.806                                  # half of the stock 1.611 m shell
WIDE = {1: 0.955, 2: 0.938}                # half width over the arches per variant
ROOF = 1.340

WHEEL_R = 0.295           # sheet estimate (tyre outer radius)
WHEEL_Z = WHEEL_R
TRACK = 0.822             # hub x: tyre outer face ~0.94 m, inside the arches
ARCH_Z = WHEEL_Z          # wheel opening centred on the hub
ARCH_R = 0.330            # opening in the stock shell (tyre + clearance)

ZB = 0.145                # underside of the body (lowered)
Y_C = 0.955               # cowl / windscreen base
Y_RF = 0.505              # roof front / windscreen top
Y_RR = -0.965             # roof rear / rear window top
Y_RW = -1.395             # rear window base
ROOF_RAIL = 1.298
ROOF_CROWN = 0.034
GLASS_CROWN = 0.040
X_BELT = 0.752            # greenhouse side at the belt
TUMBLE = 0.21             # side glass lean dx per dz (upright 70s cabin)
WIN_TOP = 1.262
CREASE_Z = 0.648          # side character line (chrome strip on RED)
HOOD_Y0 = Y_C + 0.030     # bonnet rear edge (cowl)
HOOD_Y1 = Y_BF - 0.030    # bonnet front edge (before the nose radius)
HOOD_F = 0.925            # bonnet half width as a fraction of the deck

SHARED, RED, WHITE = 0, 1, 2


def smoothstep(a, b, x):
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3 - 2 * t)


# --------------------------------------------------------- lower body

def belt_z(y):
    """Window sill height (a whisker higher at the rear)."""
    return 0.828 + (Y_C - y) * (0.010 / (Y_C - Y_RW))


def top_z(y):
    """Top surface edge height: bonnet, belt deck, boot lid."""
    if y >= Y_C:
        s = (Y_BF - y) / (Y_BF - Y_C)
        hood = 0.700 + (0.808 - 0.700) * s ** 0.85
        return hood + (belt_z(Y_C) - 0.808) * smoothstep(Y_C + 0.06, Y_C, y)
    if y >= Y_RW:
        return belt_z(y)
    s = (Y_RW - y) / (Y_RW - Y_BR)
    return 0.840 - 0.020 * s


def crown(y):
    if y >= Y_C:
        return 0.020
    if y >= Y_RW:
        return 0.0
    return 0.014


def half_width(y):
    w = W - 0.010 * max(0.0, (y - 1.70) / (Y_BF - 1.70))
    rf, rr = 0.070, 0.060
    d = y - (Y_BF - rf)
    if d > 0:
        w -= rf - math.sqrt(max(rf * rf - d * d, 0.0))
    d = (Y_BR + rr) - y
    if d > 0:
        w -= rr - math.sqrt(max(rr * rr - d * d, 0.0))
    return w


def lip_drop(y):
    """Crisp 70s nose / tail edges (small radius)."""
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
    """Flat floor; the front / rear valances behind the bumpers sit higher."""
    tf = smoothstep(Y_FA + ARCH_R, Y_FA + ARCH_R + 0.20, y)
    tr = smoothstep(Y_RA - ARCH_R, Y_RA - ARCH_R - 0.25, y)
    return ZB + 0.050 * tf + 0.080 * tr


def deck_edge(y):
    """x where the top surface starts rolling into the side."""
    return half_width(y) - 0.048


def hood_x(y):
    return HOOD_F * deck_edge(y)


TOP_FRACTIONS = (0.965, HOOD_F, 0.76, 0.56, 0.37, 0.18, 0.0)
K_HOOD = 16               # index of the bonnet edge point in section()


def section(y):
    """Right half of the lower-body section, bottom centre -> top centre.
    Same point count everywhere (lofted). Point K_HOOD lies exactly on the
    bonnet shut line, so the bonnet opening follows the grid."""
    zb = bottom_z(y)
    w = half_width(y)
    zs = min(CREASE_Z, top_z(y) - lip_drop(y) - 0.050)
    zt = top_z(y) - lip_drop(y)
    cr = crown(y)
    xe = deck_edge(y)

    def top(x):
        return zt + cr * (1.0 - (x / xe) ** 2)

    pts = [
        (0.0, zb), (w * 0.5, zb), (w - 0.08, zb), (w - 0.030, zb + 0.006),
        (w - 0.010, zb + 0.030), (w - 0.002, zb + 0.070), (w, zb + 0.130), (w, 0.36),
        (w, 0.52), (w, zs - 0.040), (w - 0.0015, zs - 0.008), (w - 0.006, zs),
        (w - 0.014, zs + 0.45 * (zt - zs)), (w - 0.032, zt - 0.010), (xe, zt),
    ]
    assert len(pts) == 15
    for f in TOP_FRACTIONS:
        pts.append((xe * f, top(xe * f)))
    return pts


def stations():
    ys = [Y_BF - d for d in (0.0, 0.003, 0.009, 0.018, 0.030)]
    y = Y_BF - 0.075
    while y > HOOD_Y0 + 0.02:
        ys.append(y)
        y -= 0.075
    ys.append(HOOD_Y0)
    y = HOOD_Y0 - 0.07
    while y > Y_BR + 0.10:
        ys.append(y)
        y -= 0.075
    ys += [Y_BR + d for d in (0.065, 0.045, 0.030, 0.018, 0.009, 0.003, 0.0)]
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
    """Points and outward normals on the body side at station y."""
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
    half = section(y)
    zt = top_z(y) - lip_drop(y)
    xe = deck_edge(y)
    z = zt + crown(y) * (1.0 - (min(x, xe) / xe) ** 2)
    _ = half
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
    """Remove the bonnet panel from the shared shell: RED shows its engine
    bay there, WHITE adds a closed bonnet with the same edges."""
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    gone = []
    for f in bm.faces:
        c = f.calc_center_median()
        if HOOD_Y0 + 1e-4 < c.y < HOOD_Y1 - 1e-4 and c.z > 0.60 and abs(c.x) < hood_x(c.y) - 1e-4:
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
        return zb + (ROOF_RAIL - zb) * s + 0.018 * math.sin(math.pi * s)
    if y <= Y_RR:
        s = (y - Y_RW) / (Y_RR - Y_RW)
        return zb + (ROOF_RAIL - zb) * s + 0.014 * math.sin(math.pi * s)
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
    rr = min(0.040, 0.5 * h + 0.004)
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
    cabin = Vector((0.0, -0.25, 0.80))
    for p in me.polygons:
        if p.normal.dot(p.center - cabin) < 0.0 and p.center.z > 0.86:
            p.material_index = idx
    return obj


def windows():
    """Side windows in (y, z): front door (with the vent pane in front of
    the divider), rear door (with the fixed quarter pane behind it)."""
    zb = lambda y: belt_z(y) + 0.012  # noqa: E731
    return {
        "front": [(0.792, zb(0.792)), (-0.060, zb(-0.060)), (-0.060, WIN_TOP), (0.468, WIN_TOP)],
        "rear": [(-0.118, zb(-0.118)), (-1.000, zb(-1.000)), (-0.872, WIN_TOP), (-0.118, WIN_TOP)],
    }


VENT_Y = {"front": 0.474, "rear": -0.735}      # window divider bars


def ws_half(y):
    return side_x(y, rail_z(y)) - 0.070


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
RW_Y0, RW_Y1 = Y_RR - 0.030, Y_RW + 0.040


def cut_greenhouse(gh):
    cutters = [prism_yz("win_" + name, poly) for name, poly in windows().items()]
    cutters.append(prism_xy("win_ws", glass_outline(WS_Y0, WS_Y1), 0.70, 1.60))
    cutters.append(prism_xy("win_rw", glass_outline(RW_Y0, RW_Y1), 0.70, 1.60))
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


def build_glass():
    """Shared glass (both sheets: dark tinted)."""
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
    return part.to_object()


def build_frames(key, slot):
    """Window frames + divider bars: chrome on RED, black rubber on WHITE."""
    part = nwcf.Part("frames_%d" % slot)
    width = 0.016 if slot == RED else 0.014
    for name, poly in windows().items():
        for sx in (1.0, -1.0):
            loop = _densify(expand(poly, 0.009) + [expand(poly, 0.009)[0]], 0.03)
            pts, nrm = [], []
            for y, z in loop:
                p, n = side_surface(y, z, 0.0)
                pts.append((p.x * sx, p.y, p.z))
                nrm.append((n.x * sx, n.y, n.z))
            nwcf.strip(part, pts, nrm, width, key, lift=0.0018)
            if slot == RED or name == "front":
                yv = VENT_Y[name]
                if slot == WHITE:
                    continue
                pa, na = side_surface(yv, belt_z(yv) + 0.012, -0.004)
                pb, _ = side_surface(yv, WIN_TOP, -0.004)
                nwcf.strip(part, [(pa.x * sx, pa.y, pa.z), (pb.x * sx, pb.y, pb.z)],
                           [(na.x * sx, 0, na.z)] * 2, 0.012, key, lift=0.0)
    for (y0, y1) in ((WS_Y0, WS_Y1), (RW_Y0, RW_Y1)):
        loop = [(x + math.copysign(0.0075, x), y) for x, y in glass_outline(y0, y1, 0.0, 16)]
        loop.append(loop[0])
        loop = _densify(loop, 0.03)
        pts = [(x, y, g_top(y, x)) for x, y in loop]
        nrm = [(x * 0.15, 0.0, 1.0) for x, y in loop]
        nwcf.strip(part, pts, nrm, width, key, lift=0.0018)
    return nwcf.tag_variant(part.to_object(), slot)


# ------------------------------------------------------------- cutters

def arch_cutter(name, y_axle, side):
    part = nwcf.Part(name)
    m = nwcf.frame_from_axis((0, y_axle, ARCH_Z), (side, 0, 0))
    nwcf.lathe(part, m, [(W - 0.42, ARCH_R), (W + 0.30, ARCH_R)], "well", segments=48,
               cap_start="well", cap_end="well")
    return part.to_object(recalc=True)


def cabin_cutter():
    part = nwcf.Part("cabin_cavity")
    y0, y1 = Y_C - 0.030, Y_RW + 0.040
    nwcf.box(part, (0.0, (y0 + y1) * 0.5, (0.27 + 1.6) * 0.5),
             (1.42, y0 - y1, 1.6 - 0.27), "interior", bevel=0.04, segments=2)
    return part.to_object(recalc=True)


# ------------------------------------------------------- wheel arches

def build_flares(slot):
    """RED: bolt-on overfenders (polygonal, 14 facets, blunt ends).
    WHITE: rolled, smooth flares blending into the body.
    The lip ellipse sits lower than the tyre top (tucked stance, sheets)."""
    part = nwcf.Part("flares_%d" % slot)
    wide = WIDE[slot]
    seg = 14 if slot == RED else 28
    if slot == RED:
        a_l, b_l, a_o, b_o = 0.318, 0.252, 0.400, 0.338
        prof = [(0.0, 0.0), (0.30, 0.48), (0.62, 0.86), (0.90, 1.00), (1.0, 1.0)]
    else:
        a_l, b_l, a_o, b_o = 0.330, 0.270, 0.405, 0.338
        prof = [(0.0, 0.0), (0.20, 0.30), (0.42, 0.62), (0.66, 0.86), (0.86, 0.98), (1.0, 1.0)]
    end = math.acos((0.165 - WHEEL_Z) / b_o)
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
                    z = WHEEL_Z + b * ct
                    x = half_width(y) - 0.002 + (wide - half_width(y) + 0.002) * g
                    row.append((sx * x, y, z))
                # lip return (rolled under) and a short liner
                y = y_axle + a_l * st
                z = WHEEL_Z + b_l * ct
                row.append((sx * (wide - 0.010), y_axle + (a_l - 0.008) * st, WHEEL_Z + (b_l - 0.008) * ct))
                row.append((sx * (wide - 0.040), y_axle + (a_l - 0.006) * st, WHEEL_Z + (b_l - 0.006) * ct))
                rows.append(row)
            V, faces = part.grid(rows, lambda i, j: "paint" if i < len(prof) else "well")
            # Blunt ends (bolt-on look) closed with flat caps.
            for end_row in (V[0], V[-1]):
                c = Vector((0, 0, 0))
                for v in end_row:
                    c += v.co
                c /= len(end_row)
                cap = part.cap(end_row, "paint", center=c)
                faces += list(cap.link_faces)
            cen = Vector((sx * (W - 0.10), y_axle, WHEEL_Z))
            part.orient(faces, lambda c, cen=cen, sx=sx: Vector((sx * 0.6, 0, 0)) + (c - cen).normalized())
            if slot == RED:
                # Bolt heads along the overfender (sheet: riveted look).
                for k in range(1, 8):
                    t = -end * 0.86 + 2 * end * 0.86 * k / 8
                    a = a_o + (a_l - a_o) * 0.55
                    b = b_o + (b_l - b_o) * 0.55
                    y = y_axle + a * math.sin(t)
                    z = WHEEL_Z + b * math.cos(t)
                    x = half_width(y) + (wide - half_width(y)) * 0.80
                    nrm = Vector((sx * 0.75, math.sin(t) * 0.45, math.cos(t) * 0.45)).normalized()
                    m = nwcf.frame_from_axis((sx * x, y, z), tuple(nrm))
                    nwcf.lathe(part, m, [(0.0, 0.0085), (0.004, 0.007), (0.0055, 0.0)], "chrome", segments=6,
                               orient=lambda c, o=Vector((sx * x, y, z)): c - o)
    return nwcf.tag_variant(part.to_object(), slot)


# -------------------------------------------------------- side details

def _gap(part, pts, nrm, sx):
    if len(pts) < 2:
        return
    p = [(sx * x, y, z) for x, y, z in pts]
    n = [(sx * a, b, c) for a, b, c in nrm]
    nwcf.strip(part, p, n, 0.0045, "gap", lift=0.0009)


def build_shared_details():
    part = nwcf.Part("details")
    for sx in (1.0, -1.0):
        # Door shut lines: front edge, B-pillar line, rear door around the arch.
        for y in (0.792, -0.090):
            pts, nrm = side_curve(y, ZB + 0.03, top_z(y) - 0.012, 18)
            _gap(part, pts, nrm, sx)
        pts, nrm = side_curve(-1.035, 0.60, belt_z(-1.035) - 0.012, 8)
        _gap(part, pts, nrm, sx)
        # Boot shut lines on the deck.
        pts, nrm = [], []
        for k in range(17):
            y = Y_RW - 0.035 + (Y_BR + 0.028 - (Y_RW - 0.035)) * k / 16
            p, n = top_point(y, 0.700)
            pts.append(p)
            nrm.append(n)
        _gap(part, pts, nrm, sx)
    pts, nrm = [], []
    for k in range(25):
        x = -0.70 + 1.40 * k / 24
        p, n = top_point(Y_RW - 0.035, abs(x))
        pts.append((x, p[1], p[2]))
        nrm.append(n)
    _gap(part, pts, nrm, 1.0)
    # Boot lid shut line on the rear face (above the lamps).
    yb = Y_BR - 0.0012
    nwcf.strip(part, [(-0.70, yb, 0.715), (0.70, yb, 0.715)], [(0, -1, 0), (0, -1, 0)], 0.0045, "gap", lift=0.0)
    for x in (-0.70, 0.70):
        nwcf.strip(part, [(x, yb, 0.715), (x, yb, 0.818)], [(0, -1, 0), (0, -1, 0)], 0.0045, "gap", lift=0.0)
    # Boot lock (chrome) and the rubber end of the drip rails.
    m = nwcf.frame_from_axis((0.0, Y_BR - 0.002, 0.665), (0, -1, 0))
    nwcf.lathe(part, m, [(0.0, 0.020), (0.004, 0.019), (0.007, 0.012), (0.008, 0.0)], "chrome", segments=14,
               orient=lambda c: (0.0, -1.0, 0.0))
    # Fuel filler flap (right rear wing).
    p, n = side_curve(-1.62, 0.70, 0.70, 1)
    if p:
        x, y, z = p[0]
        loop = [(x + 0.001, y + 0.06 * math.cos(a), z + 0.06 * math.sin(a)) for a in
                [math.tau * k / 16 for k in range(17)]]
        nwcf.strip(part, loop, [(1, 0, 0)] * len(loop), 0.004, "gap", lift=0.0009)
    return nwcf.tag_variant(part.to_object(), SHARED)


def build_bonnet():
    """WHITE: closed bonnet filling the shell opening exactly (same grid),
    with a raised centre panel (sheet) and shut lines."""
    part = nwcf.Part("bonnet")
    ys = [y for y in stations() if HOOD_Y0 - 1e-6 <= y <= HOOD_Y1 + 1e-6]
    rows = []
    for y in ys:
        xh = hood_x(y)
        fade = smoothstep(HOOD_Y0, HOOD_Y0 + 0.10, y) * smoothstep(HOOD_Y1, HOOD_Y1 - 0.06, y)
        row = []
        for k in range(29):
            x = -xh + 2 * xh * k / 28
            (_, _, z), _n = top_point(y, abs(x))
            z += 0.020 * smoothstep(0.42, 0.34, abs(x)) * fade
            row.append((x, y, z + 0.0005))
        rows.append(row)
    V, faces = part.grid(rows, "paint")
    part.orient(faces, lambda c: (0.0, 0.0, 1.0))
    for sx in (1.0, -1.0):
        pts, nrm = [], []
        for y in ys:
            p, n = top_point(y, hood_x(y) - 0.001)
            pts.append(p)
            nrm.append(n)
        _gap(part, pts, nrm, sx)
    for y in (HOOD_Y0, HOOD_Y1):
        pts, nrm = [], []
        for k in range(25):
            x = -hood_x(y) + 2 * hood_x(y) * k / 24
            p, n = top_point(y, abs(x))
            pts.append((x, p[1], p[2] + 0.0006))
            nrm.append(n)
        _gap(part, pts, nrm, 1.0)
    return nwcf.tag_variant(part.to_object(), WHITE)


def build_engine_bay():
    """RED: open bay (body-colour inner wings, firewall, slam panel, dark
    floor), the VAZ inline four with four polished ITB trumpets, radiator,
    headers, battery and a red reservoir (concept sheet)."""
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
    y0, y1 = HOOD_Y0, HOOD_Y1
    xf = hood_x(1.4) - 0.06
    f = part.poly([(-xf, y0, floor_z), (xf, y0, floor_z), (xf, y1, floor_z), (-xf, y1, floor_z)], "well")
    part.orient([f], lambda c: (0.0, 0.0, 1.0))
    # Radiator behind the slam panel.
    nwcf.box(part, (0.0, y1 - 0.055, 0.565), (1.10, 0.050, 0.250), "radiator", bevel=0.006)
    nwcf.box(part, (0.0, y1 - 0.055, 0.700), (1.14, 0.070, 0.030), "alu_cast", bevel=0.008)
    # Engine: block, cam cover, intake plenum with four trumpets (2 x 2).
    ey = 1.40
    nwcf.box(part, (0.02, ey, 0.510), (0.34, 0.56, 0.230), "engine_black", bevel=0.020)
    nwcf.box(part, (0.02, ey, 0.660), (0.25, 0.50, 0.075), "alu_cast", bevel=0.022, segments=3)
    for k in range(5):
        nwcf.box(part, (0.02, ey - 0.18 + 0.09 * k, 0.699), (0.21, 0.012, 0.010), "alu_cast", bevel=0.003)
    nwcf.box(part, (-0.17, ey, 0.640), (0.16, 0.48, 0.080), "alu_cast", bevel=0.015)
    for i in range(2):
        for j in range(2):
            at = Vector((-0.12 - 0.13 * i + 0.065, ey - 0.095 + 0.19 * j, 0.690))
            m = nwcf.frame_from_axis(tuple(at), (0, 0, 1))
            bell = [(0.0, 0.034), (0.050, 0.034), (0.085, 0.040), (0.108, 0.054), (0.118, 0.066),
                    (0.121, 0.068), (0.120, 0.060), (0.112, 0.056)]
            nwcf.lathe(part, m, bell, "chrome", segments=20,
                       orient=lambda c, at=at: Vector((c.x - at.x, c.y - at.y, 0.25)))
            nwcf.lathe(part, m, [(0.112, 0.056), (0.050, 0.030), (0.050, 0.0)], "soot", segments=12,
                       orient=lambda c: (0.0, 0.0, 1.0))
    # Headers on the right side, dropping into the bay.
    for k in range(4):
        yk = ey - 0.19 + 0.127 * k
        nwcf.tube(part, [(0.19, yk, 0.560), (0.30, yk, 0.545), (0.36, yk - 0.03, 0.47),
                         (0.38, ey - 0.10, 0.41)], 0.019, "header", sides=8, cap=False)
    # Battery + red reservoir, hoses.
    nwcf.box(part, (0.50, 1.09, 0.500), (0.17, 0.25, 0.170), "black_satin", bevel=0.010)
    nwcf.box(part, (0.50, 1.04, 0.590), (0.12, 0.06, 0.020), "red_part", bevel=0.005)
    m = nwcf.frame_from_axis((-0.48, 1.08, 0.48), (0, 0, 1))
    nwcf.lathe(part, m, [(0.0, 0.050), (0.13, 0.050), (0.145, 0.040), (0.15, 0.0)], "red_part", segments=14,
               cap_start="red_part", orient=lambda c: Vector((c.x + 0.48, c.y - 1.08, 0.3)))
    nwcf.tube(part, [(0.10, ey + 0.27, 0.60), (0.18, ey + 0.38, 0.62), (0.25, y1 - 0.09, 0.62)], 0.020,
              "black_satin", sides=8, cap=False)
    # Strut tops (body colour) with chrome caps.
    for sx in (1.0, -1.0):
        m = nwcf.frame_from_axis((sx * 0.60, Y_FA, 0.60), (0, 0, 1))
        nwcf.lathe(part, m, [(0.0, 0.075), (0.10, 0.072), (0.12, 0.050), (0.125, 0.0)], "paint", segments=14,
                   orient=lambda c, sx=sx: Vector((c.x - sx * 0.60, c.y - Y_FA, 0.4)))
        m2 = nwcf.frame_from_axis((sx * 0.60, Y_FA, 0.725), (0, 0, 1))
        nwcf.lathe(part, m2, [(0.0, 0.030), (0.012, 0.026), (0.016, 0.0)], "chrome", segments=10,
                   orient=lambda c: (0.0, 0.0, 1.0))
    return nwcf.tag_variant(part.to_object(), RED)


def build_red_side():
    part = nwcf.Part("red_side")
    for sx in (1.0, -1.0):
        # Chrome belt moulding along the whole side on the crease line.
        rows = []
        prof = [(0.0, -0.011), (0.004, -0.009), (0.006, 0.0), (0.004, 0.009), (0.0, 0.011)]
        y0, y1 = Y_BF - 0.060, Y_BR + 0.060
        for k in range(41):
            y = y0 + (y1 - y0) * k / 40
            f = min(1.0, 0.3 + 0.7 * min(k, 40 - k) / 1.5)
            xw = half_width(y) - 0.004
            row = [(sx * (xw + o * f), y, CREASE_Z + 0.004 + dz) for o, dz in prof]
            rows.append(row if sx > 0 else list(reversed(row)))
        V, faces = part.grid(rows, "chrome")
        part.orient(faces, lambda c, sx=sx: Vector((sx, 0.0, (c.z - CREASE_Z - 0.004) * 60.0)))
        # Chrome door handles.
        for y in (0.070, -0.810):
            x = sx * (half_width(y) + 0.004)
            nwcf.box(part, (x, y, 0.718), (0.016, 0.150, 0.030), "chrome", bevel=0.006, segments=2)
            nwcf.box(part, (sx * (half_width(y) + 0.0005), y - 0.04, 0.718), (0.006, 0.050, 0.036),
                     "black_satin", bevel=0.002)
        # Chrome mirror on the door corner.
        m = Matrix.Translation((sx * 0.875, 0.690, 0.905))
        nwcf.box(part, (0, 0, 0), (0.085, 0.060, 0.075), "chrome", matrix=m, bevel=0.018, segments=2)
        nwcf.box(part, (0, -0.033, 0), (0.072, 0.006, 0.060), "black_gloss", matrix=m, bevel=0.010)
        nwcf.box(part, (sx * -0.065, 0.010, -0.050), (0.070, 0.035, 0.030), "black_satin", matrix=m, bevel=0.008)
        # C-pillar vent grille (2106).
        for k in range(4):
            y = -0.955 - 0.050 * k
            pa, na = side_surface(y, belt_z(y) + 0.045, -0.002)
            pb, _ = side_surface(y - 0.040, belt_z(y) + 0.045, -0.002)
            nwcf.strip(part, [(pa.x * sx, pa.y, pa.z), (pb.x * sx, pb.y, pb.z)],
                       [(na.x * sx, 0, na.z)] * 2, 0.040, "black_satin", lift=0.002)
    return nwcf.tag_variant(part.to_object(), RED)


def build_white_side():
    part = nwcf.Part("white_side")
    for sx in (1.0, -1.0):
        # Colour-keyed side skirt between the flares.
        y0, y1 = Y_FA - 0.400, Y_RA + 0.405
        rows = []
        prof = [(-0.004, 0.300), (0.010, 0.296), (0.020, 0.270), (0.026, 0.200), (0.026, 0.160),
                (0.018, 0.140), (-0.010, 0.138)]
        for k in range(17):
            y = y0 + (y1 - y0) * k / 16
            rows.append([(sx * (half_width(y) + o), y, z) for o, z in prof])
        V, faces = part.grid(rows, "paint")
        for end in (V[0], V[-1]):
            part.cap(end, "paint")
        part.orient(part.bm.faces[:], lambda c, sx=sx: Vector((sx, 0.0, (c.z - 0.22) * 6.0)))
    return nwcf.tag_variant(part.to_object(), WHITE)


# -------------------------------------------------------------- front

def _rounded_rect(cx, cz, hw, hh, r, seg):
    pts = []
    corners = ((hw - r, hh - r, 0.0), (-(hw - r), hh - r, 90.0), (-(hw - r), -(hh - r), 180.0),
               (hw - r, -(hh - r), 270.0))
    for ox, oz, a0 in corners:
        for k in range(seg + 1):
            a = math.radians(a0 + 90.0 * k / seg)
            pts.append((cx + ox + r * math.cos(a), cz + oz + r * math.sin(a)))
    return pts


def _round_lamp(part, x, z, r, tex):
    yf = Y_BF
    m = nwcf.frame_from_axis((x, yf + 0.006, z), (0, 1, 0))
    back = Vector((x, yf - 0.06, z))
    nwcf.lathe(part, m, [(-0.035, r + 0.012), (0.006, r + 0.012)], "black_gloss", segments=28,
               orient=lambda c, back=back: c - back)
    nwcf.lathe(part, m, [(0.004, r + 0.014), (0.010, r + 0.013), (0.013, r + 0.008), (0.012, r + 0.002),
                         (0.007, r + 0.0005)], "chrome", segments=32, orient=lambda c, back=back: c - back)
    prof = [(0.0055, r + 0.0005), (0.0090, r * 0.80), (0.0110, r * 0.48), (0.0118, 0.0)]

    def uv(ks, kp, prof=prof, r=r):
        rad = min(prof[kp][1] / r, 1.0)
        t = math.tau * ks / 32
        return (0.5 + 0.5 * rad * math.cos(t), 0.5 + 0.5 * rad * math.sin(t))

    nwcf.lathe(part, m, prof, tex, segments=32, uv_fn=uv, orient=lambda c: (0.0, 1.0, 0.0))


def _bumper(part, front, z0, z1, prof, key, wrap_to, rc=0.10, n_side=4):
    """Bumper lofted along a U-shaped plan path (face + rounded corners +
    short side wraps)."""
    y_face = (Y_BF + 0.004) if front else (Y_BR - 0.004)
    sgn = 1.0 if front else -1.0
    path = []
    for k in range(n_side + 1):
        y = wrap_to + (y_face - sgn * rc - wrap_to) * k / n_side
        path.append((half_width(y) + 0.004, y, 1.0, 0.0, 0.35 + 0.15 * k / n_side))
    for k in range(1, 9):
        a = math.radians(90.0 * k / 8)
        x = W + 0.004 - rc + rc * math.cos(a)
        y = y_face - sgn * rc + sgn * rc * math.sin(a)
        path.append((x, y, math.cos(a), sgn * math.sin(a), 0.5 + 0.5 * (k / 8) ** 2))
    for k in range(1, 9):
        x = (W + 0.004 - rc) * (1.0 - k / 8)
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


# Chrome bar (RED sheet): a rounded rectangle section, 5.8 cm reach.
CHROME_BAR = [(-0.020, 1.0), (0.000, 1.004), (0.032, 0.985), (0.050, 0.900), (0.057, 0.700), (0.058, 0.450),
              (0.056, 0.180), (0.046, 0.040), (0.026, 0.0), (0.0, -0.004), (-0.020, 0.0)]
# Colour-keyed bumper (WHITE sheet): plain face, slight crease, lower lip.
WHITE_FRONT = [(-0.030, 1.0), (0.000, 1.004), (0.030, 0.985), (0.046, 0.930), (0.051, 0.800), (0.051, 0.620),
               (0.045, 0.585), (0.051, 0.550), (0.054, 0.300), (0.060, 0.110), (0.062, 0.040), (0.052, 0.0),
               (0.0, -0.004), (-0.030, 0.0)]
WHITE_REAR = [(-0.030, 1.0), (0.000, 1.004), (0.030, 0.985), (0.046, 0.930), (0.051, 0.780), (0.051, 0.600),
              (0.045, 0.565), (0.051, 0.530), (0.052, 0.120), (0.040, 0.020), (0.0, -0.004), (-0.030, 0.0)]


def build_red_front():
    part = nwcf.Part("red_front")
    yf = Y_BF
    # Black fascia panel carrying the lamps and the grille.
    nwcf.box(part, (0.0, yf - 0.008, 0.540), (1.52, 0.030, 0.262), "black_matte", bevel=0.008)
    for sx in (1.0, -1.0):
        _round_lamp(part, sx * 0.665, 0.540, 0.080, "tex_headlight")
        _round_lamp(part, sx * 0.470, 0.540, 0.076, "tex_headlight_hi")
        # Amber indicators under the outer lamps.
        nwcf.box(part, (sx * 0.590, yf + 0.004, 0.368), (0.175, 0.014, 0.052), "amber_lens", bevel=0.005)
        nwcf.box(part, (sx * 0.590, yf + 0.0, 0.368), (0.187, 0.010, 0.064), "black_satin", bevel=0.004)
    # Chrome grille: rounded frame, black backing, horizontal + vertical bars.
    loop = _rounded_rect(0.0, 0.540, 0.355, 0.118, 0.018, 3)
    nwcf.tube(part, [(x, yf + 0.016, z) for x, z in loop] + [(loop[0][0], yf + 0.016, loop[0][1])],
              0.009, "chrome", sides=6, cap=False)
    f = part.poly([(x, yf + 0.006, z) for x, z in reversed(_rounded_rect(0.0, 0.540, 0.350, 0.113, 0.015, 3))],
                  "black_gloss")
    part.orient([f], lambda c: (0.0, 1.0, 0.0))
    for k in range(6):
        z = 0.448 + k * 0.0368
        nwcf.box(part, (0.0, yf + 0.014, z), (0.690, 0.010, 0.010), "chrome", bevel=0.002)
    for k in range(9):
        x = -0.300 + k * 0.075
        nwcf.box(part, (x, yf + 0.011, 0.540), (0.008, 0.010, 0.215), "chrome", bevel=0.002)
    # Blank centre badge (no logo).
    nwcf.box(part, (0.0, yf + 0.022, 0.540), (0.052, 0.008, 0.080), "chrome", bevel=0.006)
    nwcf.box(part, (0.0, yf + 0.025, 0.540), (0.036, 0.004, 0.062), "black_gloss", bevel=0.004)
    # Chrome bumper with black rubber end caps, air dam and splitter.
    _bumper(part, True, 0.215, 0.330, CHROME_BAR, "chrome", Y_BF - 0.150)
    for sx in (1.0, -1.0):
        nwcf.box(part, (sx * 0.30, HALF_L - 0.005, 0.272), (0.040, 0.010, 0.060), "black_satin", bevel=0.006)
    nwcf.box(part, (0.0, Y_BF - 0.010, 0.155), (1.48, 0.060, 0.120), "black_matte", bevel=0.010)
    # Splitter blade: ends flush with the bumper face (gameplay length).
    blade = [(-0.80, Y_BF - 0.30), (0.80, Y_BF - 0.30), (0.82, Y_BF - 0.02), (0.74, HALF_L - 0.002),
             (-0.74, HALF_L - 0.002), (-0.82, Y_BF - 0.02)]
    sp = prism_like(part, blade, 0.072, 0.092, "black_satin")
    _ = sp
    for sx in (1.0, -1.0):
        nwcf.box(part, (sx * 0.81, Y_BF - 0.05, 0.135), (0.012, 0.22, 0.10), "black_satin", bevel=0.004)
    return nwcf.tag_variant(part.to_object(), RED)


def prism_like(part, outline, z0, z1, key):
    """Flat plate with the given outline (x, y), z0..z1, inside a Part."""
    bm = part.bm
    a = [bm.verts.new((x, y, z0)) for x, y in outline]
    b = [bm.verts.new((x, y, z1)) for x, y in outline]
    n = len(outline)
    faces = []
    for k in range(n):
        faces.append(part.face([a[k], a[(k + 1) % n], b[(k + 1) % n], b[k]], key))
    faces.append(part.face(list(reversed(a)), key))
    faces.append(part.face(b, key))
    nwcf.recalc(part, faces)
    return faces


def build_white_front():
    part = nwcf.Part("white_front")
    yf = Y_BF
    nwcf.box(part, (0.0, yf - 0.008, 0.523), (1.50, 0.030, 0.205), "black_matte", bevel=0.008)
    for sx in (1.0, -1.0):
        cx, cz, hw, hh = sx * 0.595, 0.523, 0.178, 0.090
        nwcf.box(part, (cx, yf + 0.004, cz), (2 * hw + 0.016, 0.018, 2 * hh + 0.016), "black_gloss", bevel=0.006)
        rows = []
        nu, nv = 6, 3
        for j in range(nv + 1):
            row = []
            for i in range(nu + 1):
                u, v = i / nu, j / nv
                bulge = 0.004 * (1 - (2 * u - 1) ** 2) * (1 - (2 * v - 1) ** 2)
                row.append((cx - hw + 2 * hw * u, yf + 0.014 + bulge, cz - hh + 2 * hh * v))
            rows.append(row)
        uvf = (lambda i, j: (i / nu, j / nv)) if sx > 0 else (lambda i, j: (1.0 - i / nu, j / nv))
        part.grid(rows, "tex_headlight_rect", uv_fn=uvf, orient=lambda c: (0.0, 1.0, 0.0))
    # Black slatted grille with a centre divider (sheet).
    nwcf.box(part, (0.0, yf + 0.002, 0.523), (0.800, 0.014, 0.185), "black_gloss", bevel=0.004)
    for k in range(7):
        nwcf.box(part, (0.0, yf + 0.010, 0.448 + 0.025 * k), (0.780, 0.008, 0.008), "black_satin", bevel=0.002)
    nwcf.box(part, (0.0, yf + 0.012, 0.523), (0.014, 0.010, 0.180), "black_satin", bevel=0.003)
    # Raised centre "nose" continuing the bonnet panel down to the grille.
    nwcf.box(part, (0.0, yf + 0.006, 0.660), (0.80, 0.024, 0.090), "paint", bevel=0.010, segments=2)
    _bumper(part, True, 0.120, 0.405, WHITE_FRONT, "paint", Y_FA + 0.405 + 0.02, rc=0.12, n_side=6)
    nwcf.box(part, (0.0, HALF_L - 0.004, 0.235), (0.90, 0.012, 0.050), "black_gloss", bevel=0.010)
    return nwcf.tag_variant(part.to_object(), WHITE)


# -------------------------------------------------------------- rear

def _tail_lamp(part, sx, x0, x1, z0, z1, tex):
    yr = Y_BR
    nwcf.box(part, (sx * (x0 + x1) * 0.5, yr - 0.001, (z0 + z1) * 0.5), (x1 - x0, 0.006, z1 - z0), "black_satin")
    fw = 0.010
    for bx, bz, bw, bh in (((x0 + x1) * 0.5, z1 + 0.003, x1 - x0 + 2 * fw, fw),
                           ((x0 + x1) * 0.5, z0 - 0.003, x1 - x0 + 2 * fw, fw),
                           (x0 - 0.003, (z0 + z1) * 0.5, fw, z1 - z0),
                           (x1 + 0.003, (z0 + z1) * 0.5, fw, z1 - z0)):
        nwcf.box(part, (sx * bx, yr - 0.010, bz), (bw, 0.020, bh), "black_satin")
    nu, nv = 8, 4
    rows = []
    for j in range(nv + 1):
        row = []
        v = j / nv
        for i in range(nu + 1):
            u = i / nu
            bulge = 0.004 * (1.0 - (2 * u - 1) ** 2) * (1.0 - (2 * v - 1) ** 2)
            row.append((sx * (x0 + 0.004 + (x1 - x0 - 0.008) * u), yr - 0.0075 - bulge,
                        z0 + 0.005 + (z1 - z0 - 0.010) * v))
        rows.append(row if sx < 0 else list(reversed(row)))
    uvf = (lambda i, j: (i / nu, j / nv)) if sx < 0 else (lambda i, j: (1.0 - i / nu, j / nv))
    part.grid(rows, tex, uv_fn=uvf, smooth=True, orient=lambda c: (0.0, -1.0, 0.0))


def _exhaust(part, x, z, r):
    y_end = -HALF_L + 0.044          # tip ends inside the gameplay length
    nwcf.tube(part, [(x, -1.80, z + 0.02), (x, y_end, z)], r * 0.85, "exhaust", sides=14, cap=False)
    m = nwcf.frame_from_axis((x, y_end, z), (0, -1, 0))
    nwcf.lathe(part, m, [(0.0, r * 0.88), (0.030, r), (0.038, r * 1.03), (0.040, r * 0.92), (0.036, r * 0.84)],
               "chrome", segments=18, orient=lambda c, x=x: Vector((c.x - x, 0.0, c.z - z)) * 4.0
               + Vector((0.0, -1.0, 0.0)))
    nwcf.lathe(part, m, [(0.036, r * 0.84), (0.010, r * 0.78), (0.010, 0.0)], "soot", segments=18,
               orient=lambda c: (0.0, -1.0, 0.0))


def _plate_recess(part):
    """Recessed plate area between the lamps (no plate reproduced)."""
    yr = Y_BR - 0.0012
    for (a, b) in (((-0.33, 0.395), (0.33, 0.395)), ((0.33, 0.395), (0.33, 0.600)),
                   ((0.33, 0.600), (-0.33, 0.600)), ((-0.33, 0.600), (-0.33, 0.395))):
        nwcf.strip(part, [(a[0], yr, a[1]), (b[0], yr, b[1])], [(0, -1, 0), (0, -1, 0)], 0.006, "gap", lift=0.0)


def _ducktail(part, rise, reach, y_start):
    """Spoiler lip on the boot edge, lofted across the car."""
    rows = []
    for k in range(17):
        x = -0.74 + 1.48 * k / 16
        f = 1.0 - (abs(x) / 0.74) ** 6 * 0.35
        (_, _, z0), _ = top_point(y_start, abs(x))
        (_, _, ze), _ = top_point(Y_BR + 0.01, abs(x))
        tip_y = Y_BR - reach
        prof = [(y_start, z0 + 0.0008), (y_start - 0.10, z0 + rise * 0.20 * f),
                (tip_y + 0.03, ze + rise * f), (tip_y, ze + rise * f + 0.004),
                (tip_y + 0.004, ze + rise * f - 0.016), (Y_BR + 0.012, ze - 0.012)]
        rows.append([(x, y, z) for y, z in prof])
    V, faces = part.grid(rows, "paint")
    part.orient(faces, lambda c: (0.0, -0.4, 1.0) if c.z > 0.83 else (0.0, -1.0, -0.6))
    for end in (V[0], V[-1]):
        f = part.poly([v.co[:] for v in end], "paint")
        if f is not None:
            part.orient([f], lambda c: (math.copysign(1.0, c.x), 0.0, 0.0))


def build_red_rear():
    part = nwcf.Part("red_rear")
    for sx in (1.0, -1.0):
        _tail_lamp(part, sx, 0.360, 0.752, 0.400, 0.585, "tex_tail")
    _plate_recess(part)
    _bumper(part, False, 0.190, 0.300, CHROME_BAR, "chrome", Y_BR + 0.150)
    for sx in (1.0, -1.0):
        nwcf.box(part, (sx * 0.30, -HALF_L + 0.005, 0.247), (0.040, 0.010, 0.056), "black_satin", bevel=0.006)
    _exhaust(part, 0.490, 0.118, 0.045)
    _ducktail(part, 0.070, 0.040, Y_RW - 0.28)
    return nwcf.tag_variant(part.to_object(), RED)


def build_white_rear():
    part = nwcf.Part("white_rear")
    for sx in (1.0, -1.0):
        _tail_lamp(part, sx, 0.420, 0.735, 0.465, 0.600, "tex_tail_b")
    _plate_recess(part)
    _bumper(part, False, 0.160, 0.400, WHITE_REAR, "paint", Y_RA - 0.405 - 0.02, rc=0.12, n_side=6)
    _exhaust(part, 0.420, 0.130, 0.038)
    _ducktail(part, 0.035, 0.020, Y_RW - 0.20)
    return nwcf.tag_variant(part.to_object(), WHITE)


# ----------------------------------------------------------- interior

def build_interior():
    part = nwcf.Part("interior")
    nwcf.box(part, (0, 0.80, 0.735), (1.38, 0.26, 0.16), "interior", bevel=0.03)
    nwcf.box(part, (0, 0.62, 0.560), (0.20, 0.34, 0.24), "interior", bevel=0.02)
    c = Vector((-0.370, 0.520, 0.830))
    tilt = Matrix.Rotation(math.radians(-60.0), 4, 'X')
    ring = [c + (tilt @ Vector((0.180 * math.cos(a), 0.0, 0.180 * math.sin(a)))) for a in
            [math.tau * k / 20 for k in range(21)]]
    nwcf.tube(part, ring, 0.014, "black_satin", sides=6, cap=False)
    for a in (0.0, math.pi, math.pi * 1.5):
        tip = c + tilt @ Vector((0.17 * math.cos(a), 0.0, 0.17 * math.sin(a)))
        nwcf.tube(part, [c, tip], 0.010, "black_satin", sides=6)
    nwcf.tube(part, [c, c + Vector((0, 0.25, -0.10))], 0.022, "black_satin", sides=8)
    for sx in (-1.0, 1.0):
        x = sx * 0.360
        nwcf.box(part, (x, 0.10, 0.36), (0.48, 0.50, 0.10), "seat", bevel=0.035)
        back = Matrix.Translation((x, -0.18, 0.72)) @ Matrix.Rotation(math.radians(-12.0), 4, 'X')
        nwcf.box(part, (0, 0, 0), (0.48, 0.10, 0.72), "seat", matrix=back, bevel=0.035)
        for side in (-1.0, 1.0):
            nwcf.box(part, (side * 0.225, 0.07, 0.06), (0.07, 0.16, 0.48), "seat", matrix=back, bevel=0.03)
        # Door cards (inner side walls) so the far side never shows through.
        nwcf.box(part, (sx * 0.735, -0.25, 0.60), (0.03, 2.10, 0.40), "interior", bevel=0.01)
    nwcf.box(part, (0, -0.78, 0.38), (1.30, 0.50, 0.12), "seat", bevel=0.04)
    back = Matrix.Translation((0, -1.12, 0.64)) @ Matrix.Rotation(math.radians(-18.0), 4, 'X')
    nwcf.box(part, (0, 0, 0), (1.30, 0.12, 0.50), "seat", matrix=back, bevel=0.04)
    nwcf.box(part, (0, -1.30, 0.83), (1.36, 0.22, 0.03), "interior", bevel=0.01)
    return nwcf.tag_variant(part.to_object(), SHARED)


# ---------------------------------------------------------- textures

def draw_regions(key, size):
    from PIL import Image, ImageDraw, ImageFilter

    w, h = size
    alb = Image.new("RGB", (w, h), (0, 0, 0))
    orm = Image.new("RGB", (w, h), (255, 60, 0))
    emi = Image.new("RGB", (w, h), (0, 0, 0))
    da, do, de = ImageDraw.Draw(alb), ImageDraw.Draw(orm), ImageDraw.Draw(emi)
    if key in ("tex_headlight", "tex_headlight_hi"):
        cx, cy = w / 2, h / 2
        for k in range(64, 0, -1):
            t = k / 64
            g = int(150 + 74 * (1.0 - t) + 18 * math.cos(t * 9.0))
            da.ellipse((cx - cx * t, cy - cy * t, cx + cx * t, cy + cy * t), fill=(g, g, min(255, g + 4)))
            do.ellipse((cx - cx * t, cy - cy * t, cx + cx * t, cy + cy * t), fill=(255, int(30 + 40 * t), 210))
        if key == "tex_headlight":
            step = max(3, w // 24)
            for x in range(0, w, step):
                da.line((x, 0, x, h), fill=(210, 210, 214), width=1)
                da.line((x + step // 2, 0, x + step // 2, h), fill=(104, 104, 108), width=1)
        else:
            for k in range(1, 11):
                r = cx * k / 11
                da.ellipse((cx - r, cy - r, cx + r, cy + r), outline=(212, 212, 216), width=1)
        da.ellipse((cx - w * 0.11, cy - h * 0.11, cx + w * 0.11, cy + h * 0.11), fill=(50, 48, 46))
        # Warm halogen glow (the concept sheet shows the lamps lit).
        de.ellipse((cx - w * 0.44, cy - h * 0.44, cx + w * 0.44, cy + h * 0.44), fill=(120, 104, 70))
        de.ellipse((cx - w * 0.22, cy - h * 0.22, cx + w * 0.22, cy + h * 0.22), fill=(190, 170, 120))
        emi = emi.filter(ImageFilter.GaussianBlur(w * 0.05))
        da.ellipse((0, 0, w - 1, h - 1), outline=(40, 42, 46), width=max(2, w // 48))
    elif key == "tex_headlight_rect":
        for y in range(h):
            t = abs(y / h - 0.5) * 2.0
            g = int(214 - 60 * t)
            da.line((0, y, w, y), fill=(g, g, g - 6))
        step = max(4, w // 30)
        for x in range(0, w, step):
            da.line((x, 0, x, h), fill=(236, 234, 226), width=1)
        for k in range(1, 5):
            y = int(h * k / 5)
            da.line((0, y, w, y), fill=(160, 160, 158), width=1)
        for cx in (w * 0.28, w * 0.72):
            da.ellipse((cx - h * 0.28, h * 0.22, cx + h * 0.28, h * 0.78), outline=(250, 246, 230), width=2)
        do.rectangle((0, 0, w, h), fill=(255, 30, 160))
        de.rectangle((int(w * 0.06), int(h * 0.12), int(w * 0.94), int(h * 0.88)), fill=(150, 134, 92))
        emi = emi.filter(ImageFilter.GaussianBlur(h * 0.10))
        da.rectangle((0, 0, w - 1, h - 1), outline=(36, 36, 40), width=3)
    elif key == "tex_tail":
        # 2106 tail lamp (RED sheet): 2 x 2 segments. Top row tail / brake
        # red, bottom: outer amber-red indicator, inner clear reverse.
        sx, sy = int(w * 0.50), int(h * 0.52)
        # u = 0 is the INNER edge on both sides: inner = clear reverse lamp.
        da.rectangle((0, 0, w, h), fill=(170, 12, 18))
        da.rectangle((0, sy, sx, h), fill=(214, 216, 220))
        da.rectangle((sx, sy, w, h), fill=(205, 70, 16))
        rib = max(4, h // 12)
        for k in range(0, h, rib):
            da.line((0, k, w, k), fill=(132, 8, 12), width=1)
        da.line((0, sy, w, sy), fill=(40, 4, 6), width=4)
        da.line((sx, 0, sx, h), fill=(40, 4, 6), width=4)
        da.line((0, sy - 6, w, sy - 6), fill=(230, 120, 20), width=2)
        do.rectangle((0, 0, w, h), fill=(255, 26, 0))
        de.rectangle((6, 6, w - 6, sy - 8), fill=(70, 4, 6))
        emi = emi.filter(ImageFilter.GaussianBlur(4))
    elif key == "tex_tail_b":
        # WHITE sheet: red lamp with an amber lower outer segment.
        sx, sy = int(w * 0.45), int(h * 0.55)
        da.rectangle((0, 0, w, h), fill=(176, 14, 20))
        da.rectangle((sx, sy, w, h), fill=(228, 110, 18))
        rib = max(4, h // 12)
        for k in range(0, h, rib):
            da.line((0, k, w, k), fill=(136, 8, 12), width=1)
        da.line((0, sy, w, sy), fill=(40, 4, 6), width=3)
        do.rectangle((0, 0, w, h), fill=(255, 26, 0))
        de.rectangle((6, 6, w - 6, sy - 6), fill=(70, 4, 6))
        emi = emi.filter(ImageFilter.GaussianBlur(4))
    else:
        return None
    return alb, orm, emi


# --------------------------------------------------------------- main

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
REPORT = os.path.join(REPO, "tools", "car_factory", "reports", "lada_2106_build_report.json")


def _variant_tris(obj):
    me = obj.data
    me.calc_loop_triangles()
    layer = me.uv_layers.get(nwcf.VARIANT_LAYER)
    out = {SHARED: 0, RED: 0, WHITE: 0}
    for t in me.loop_triangles:
        slot = int(round(layer.data[t.loops[0]].uv[0])) if layer else 0
        out[slot] = out.get(slot, 0) + 1
    return out


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
    nwcf.tag_variant(lower, SHARED)
    gh = nwcf.tag_variant(cut_greenhouse(build_greenhouse()), SHARED)
    parts = [lower, gh, nwcf.tag_variant(build_glass(), SHARED), build_shared_details(), build_interior(),
             build_frames("chrome", RED), build_frames("rubber", WHITE),
             build_flares(RED), build_flares(WHITE),
             build_engine_bay(), build_bonnet(),
             build_red_side(), build_white_side(),
             build_red_front(), build_white_front(),
             build_red_rear(), build_white_rear()]
    body = nwcf.join(parts, "Lada_2106_Body")
    os.makedirs(out_dir, exist_ok=True)
    tmp = tempfile.mkdtemp(prefix="nwcf_")
    atlas = nwcf.write_atlas_images(os.path.join(tmp, "lada_2106_atlas.png"), draw_regions)
    mats = nwcf.make_runtime_materials(atlas, (0.55, 0.02, 0.04))
    stats = nwcf.finalize(body, mats)
    empties = [
        nwcf.empty("wheel_FL", (-TRACK, Y_FA, WHEEL_Z), {"axle": "front", "side": -1}),
        nwcf.empty("wheel_FR", (TRACK, Y_FA, WHEEL_Z), {"axle": "front", "side": 1}),
        nwcf.empty("wheel_RL", (-TRACK, Y_RA, WHEEL_Z), {"axle": "rear", "side": -1}),
        nwcf.empty("wheel_RR", (TRACK, Y_RA, WHEEL_Z), {"axle": "rear", "side": 1}),
    ]
    glb = nwcf.export_glb(os.path.join(out_dir, "lada_2106.glb"), [body] + empties)
    report = nwcf.mesh_report(body)
    lo, hi = report["bounds_min"], report["bounds_max"]
    if lo[0] < -(WIDE[RED] + 0.01) or hi[0] > WIDE[RED] + 0.01 or lo[2] < 0.0 or hi[2] > ROOF + 0.02 \
            or hi[1] > HALF_L + 0.04 or lo[1] < -HALF_L - 0.04:
        raise SystemExit("VALIDATION FAILED: geometry outside the car outline %s %s" % (lo, hi))
    vt = _variant_tris(body)
    report["logical_faces"] = stats
    report["bonnet_faces_removed"] = opened
    report["glb_bytes"] = os.path.getsize(glb)
    report["wheel_pivots"] = {e.name: list(e.location) for e in empties}
    report["variant_triangles"] = {"shared": vt[SHARED], "red_only": vt[RED], "white_only": vt[WHITE],
                                   "red_visible": vt[SHARED] + vt[RED], "white_visible": vt[SHARED] + vt[WHITE]}
    report["dimensions"] = {
        "length_with_bumpers_m": hi[1] - lo[1],
        "width_over_arches_m": hi[0] - lo[0],
        "height_m": hi[2],
        "wheelbase_m": WHEELBASE,
        "front_overhang_m": FRONT_OVERHANG,
        "track_hub_m": 2 * TRACK,
        "wheel_radius_m": WHEEL_R,
    }
    nwcf.write_json(report_path, report)
    return report


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(REPO, "game", "assets", "cars", "lada_2106"))
    ap.add_argument("--report", default=REPORT)
    args, _ = ap.parse_known_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:])
    os.makedirs(os.path.dirname(args.report), exist_ok=True)
    rep = build(args.out, args.report)
    print("LADA BUILD OK tris=%d verts=%d glb=%d bytes" % (rep["triangles"], rep["vertices"], rep["glb_bytes"]))
    print("variants", rep["variant_triangles"])
    print("bounds", rep["bounds_min"], rep["bounds_max"])
