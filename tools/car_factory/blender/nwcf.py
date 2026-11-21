"""Nitro Wheelz Car Factory: shared Blender helpers.

Runs inside Blender (or the `bpy` Python module, tested with bpy 5.3.0).
Every car is built by a script from numbers, so a model is reproducible
and reviewable as text. Conventions shared by all cars:

  * metres, Blender axes X = car right, Y = forward, Z = up, ground z = 0;
    glTF export turns this into Godot's -Z forward / +Y up;
  * three runtime materials per car: NW_Paint (swappable body colour,
    livery UV), NW_Atlas (every other opaque part, one atlas texture:
    albedo + ORM + emission) and NW_Glass (tinted, transparent);
  * while building, parts use LOGICAL material keys ("paint", "chrome",
    "tex_headlight" ...). `finalize()` turns keys into atlas UVs and the
    three runtime materials, so a car costs 3 draw calls for the body.
"""
from __future__ import annotations

import json
import math
import os

import bpy  # noqa: I001  (bpy must load before bmesh)
import bmesh
from mathutils import Matrix, Vector

TAU = math.tau

# ----------------------------------------------------------------- atlas
# 1024 x 1024 atlas. Flat-colour "swatches" live in an 8 x 8 grid in the
# lower-left quarter (Blender UV space, origin bottom-left); textured parts
# get their own rectangles. Each swatch: albedo, roughness, metallic,
# emission (rgb, linear-ish 0..1).
ATLAS_SIZE = 1024
SWATCH = {
    # key            albedo                  rough  metal  emission
    "black_matte":  ((0.030, 0.030, 0.034), 0.72, 0.0, (0, 0, 0)),
    "black_satin":  ((0.022, 0.022, 0.026), 0.42, 0.0, (0, 0, 0)),
    "black_gloss":  ((0.012, 0.012, 0.014), 0.18, 0.0, (0, 0, 0)),
    "rubber":       ((0.018, 0.018, 0.020), 0.88, 0.0, (0, 0, 0)),
    "chrome":       ((0.86, 0.86, 0.88), 0.10, 1.0, (0, 0, 0)),
    "alu":          ((0.70, 0.71, 0.73), 0.34, 1.0, (0, 0, 0)),
    "interior":     ((0.040, 0.040, 0.045), 0.92, 0.0, (0, 0, 0)),
    "seat":         ((0.060, 0.058, 0.062), 0.85, 0.0, (0, 0, 0)),
    "cage":         ((0.11, 0.11, 0.12), 0.48, 0.35, (0, 0, 0)),
    "gap":          ((0.006, 0.006, 0.007), 0.95, 0.0, (0, 0, 0)),
    "well":         ((0.010, 0.010, 0.011), 1.00, 0.0, (0, 0, 0)),
    "under":        ((0.035, 0.034, 0.036), 0.90, 0.0, (0, 0, 0)),
    "amber_lens":   ((0.95, 0.42, 0.04), 0.12, 0.0, (0.30, 0.12, 0.0)),
    "clear_lens":   ((0.80, 0.82, 0.84), 0.08, 0.1, (0.05, 0.05, 0.05)),
    "red_lens":     ((0.60, 0.02, 0.03), 0.10, 0.0, (0.35, 0.0, 0.01)),
    "exhaust":      ((0.20, 0.19, 0.18), 0.40, 0.8, (0, 0, 0)),
    "soot":         ((0.004, 0.004, 0.004), 1.00, 0.0, (0, 0, 0)),
    "tyre":         ((0.030, 0.030, 0.032), 0.86, 0.0, (0, 0, 0)),
    "tyre_side":    ((0.045, 0.045, 0.048), 0.80, 0.0, (0, 0, 0)),
    "rim_silver":   ((0.74, 0.75, 0.77), 0.28, 0.9, (0, 0, 0)),
    "rim_lip":      ((0.92, 0.92, 0.93), 0.06, 1.0, (0, 0, 0)),
    "rim_dark":     ((0.10, 0.10, 0.11), 0.40, 0.6, (0, 0, 0)),
    "rim_gold":     ((0.62, 0.45, 0.16), 0.24, 1.0, (0, 0, 0)),
    "nut":          ((0.55, 0.56, 0.58), 0.30, 1.0, (0, 0, 0)),
    "brake":        ((0.22, 0.21, 0.20), 0.55, 0.8, (0, 0, 0)),
    "caliper":      ((0.05, 0.05, 0.055), 0.50, 0.2, (0, 0, 0)),
}
# v0.1.30 (Lada / RYU-32 migration): APPEND-ONLY extension. The first 29
# swatches keep their atlas cells (sorted order, as built for the E30), new
# keys take the next free cells in the order listed here, so rebuilding an
# older car never moves its colours. Never insert into the middle.
SWATCH_EXT = {
    "rim_white":    ((0.80, 0.80, 0.82), 0.30, 0.05, (0, 0, 0)),
    "rim_mesh":     ((0.50, 0.50, 0.62), 0.28, 0.70, (0, 0, 0)),
    "engine_black": ((0.026, 0.026, 0.028), 0.62, 0.15, (0, 0, 0)),
    "alu_cast":     ((0.56, 0.57, 0.59), 0.46, 0.90, (0, 0, 0)),
    "red_part":     ((0.50, 0.02, 0.03), 0.34, 0.10, (0, 0, 0)),
    "radiator":     ((0.06, 0.06, 0.065), 0.70, 0.30, (0, 0, 0)),
    "header":       ((0.30, 0.24, 0.20), 0.42, 0.85, (0, 0, 0)),
    "blue_part":    ((0.04, 0.10, 0.42), 0.30, 0.20, (0, 0, 0)),
    "gold_part":    ((0.70, 0.52, 0.18), 0.28, 0.95, (0, 0, 0)),
    "white_lens":   ((0.92, 0.92, 0.90), 0.10, 0.0, (0.06, 0.06, 0.05)),
}
SWATCH_ORDER = sorted(SWATCH) + list(SWATCH_EXT)
SWATCH.update(SWATCH_EXT)
# Textured rectangles: (u0, v0, u1, v1) in Blender UV space.
REGION = {
    "tex_headlight": (0.50, 0.00, 0.75, 0.25),
    "tex_tail": (0.50, 0.50, 1.00, 0.625),
    "tex_plate": (0.75, 0.00, 1.00, 0.0625),
    "tex_sidewall": (0.75, 0.125, 1.00, 0.375),
    "tex_headlight_hi": (0.50, 0.25, 0.75, 0.50),
    # v0.1.30 (append-only, unused cells of the E30 layout)
    "tex_headlight_rect": (0.00, 0.625, 0.25, 0.6875),
    "tex_tail_b": (0.25, 0.625, 0.75, 0.75),
}


def swatch_uv(key):
    i = SWATCH_ORDER.index(key)
    col, row = i % 8, i // 8
    return ((col + 0.5) / 16.0, (row + 0.5) / 16.0)


def region_uv(key, u, v):
    u0, v0, u1, v1 = REGION[key]
    return (u0 + (u1 - u0) * min(max(u, 0.0), 1.0), v0 + (v1 - v0) * min(max(v, 0.0), 1.0))


# ----------------------------------------------------------------- scene

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.images):
        for item in list(coll):
            coll.remove(item)


def logical_material(key):
    """A placeholder material per logical key (renamed away in finalize)."""
    name = "L_" + key
    mat = bpy.data.materials.get(name)
    if mat is None:
        mat = bpy.data.materials.new(name)
    return mat


class Part:
    """A bmesh with logical material keys and one UV layer."""

    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.keys = []

    def slot(self, key):
        if key not in self.keys:
            self.keys.append(key)
        return self.keys.index(key)

    def face(self, verts, key, uvs=None, smooth=True):
        try:
            f = self.bm.faces.new(verts)
        except ValueError:
            return None
        f.material_index = self.slot(key)
        f.smooth = smooth
        if uvs is not None:
            for loop, uv in zip(f.loops, uvs):
                loop[self.uv].uv = uv
        return f

    def poly(self, pts, key, uvs=None, smooth=True):
        return self.face([self.bm.verts.new(Vector(p)) for p in pts], key, uvs, smooth)

    def grid(self, rows, key_fn, closed_u=False, closed_v=False, uv_fn=None, smooth=True, orient=None):
        """Quads between `rows` (list over v of lists over u of points).
        key_fn(i, j) -> logical key or None (hole). uv_fn(i, j) -> (u, v)
        per vertex (optional, for textured keys)."""
        V = [[self.bm.verts.new(Vector(p)) for p in row] for row in rows]
        nv, nu = len(rows), len(rows[0])
        faces = []
        for j in range(nv - 1 + (1 if closed_v else 0)):
            j2 = (j + 1) % nv
            for i in range(nu - 1 + (1 if closed_u else 0)):
                i2 = (i + 1) % nu
                key = key_fn(i, j) if callable(key_fn) else key_fn
                if key is None:
                    continue
                quad = [V[j][i], V[j][i2], V[j2][i2], V[j2][i]]
                uvs = None
                if uv_fn is not None:
                    uvs = [uv_fn(i, j), uv_fn(i2, j), uv_fn(i2, j2), uv_fn(i, j2)]
                f = self.face(quad, key, uvs, smooth)
                if f is not None:
                    faces.append(f)
        if orient is not None:
            self.orient(faces, orient)
        return V, faces

    def orient(self, faces, fn):
        """Flip faces whose normal disagrees with fn(center) (a direction)."""
        for f in faces:
            want = fn(f.calc_center_median())
            if want is None:
                continue
            f.normal_update()
            if f.normal.dot(Vector(want)) < 0.0:
                f.normal_flip()

    def cap(self, ring, key, center=None, smooth=False):
        """Fan-fill a closed ring of BMVerts (n-gon split into triangles)."""
        if center is None:
            c = Vector((0, 0, 0))
            for v in ring:
                c += v.co
            c /= len(ring)
        else:
            c = Vector(center)
        cv = self.bm.verts.new(c)
        for k in range(len(ring)):
            self.face([cv, ring[k], ring[(k + 1) % len(ring)]], key, smooth=smooth)
        return cv

    def to_object(self, recalc=False):
        bm = self.bm
        bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-6)
        if recalc:
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        me = bpy.data.meshes.new(self.name)
        bm.to_mesh(me)
        bm.free()
        for key in self.keys:
            me.materials.append(logical_material(key))
        obj = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(obj)
        return obj


# --------------------------------------------------------- primitives

def frame_from_axis(origin, axis, up_hint=(0, 0, 1)):
    """Matrix whose local +X is `axis` (lathe axis), placed at origin."""
    ax = Vector(axis).normalized()
    up = Vector(up_hint)
    if abs(ax.dot(up)) > 0.95:
        up = Vector((0, 1, 0))
    y = up.cross(ax).normalized()
    z = ax.cross(y).normalized()
    m = Matrix((ax, y, z)).transposed().to_4x4()
    m.translation = Vector(origin)
    return m


def lathe(part, matrix, profile, key, segments=24, uv_fn=None, cap_start=None, cap_end=None,
          sweep=TAU, start=0.0, smooth=True, orient=None):
    """Revolve profile [(axial, radius), ...] around local +X.
    The profile runs so that its outward side is to the right of the
    direction of travel when looking from +radius; use reverse order to flip.
    uv_fn(k_segment, k_profile) -> (u, v) for textured keys."""
    # Textured lathes keep a duplicated seam column so UVs do not wrap.
    closed = abs(sweep - TAU) < 1e-6 and uv_fn is None
    n = segments if closed else segments + 1
    rows = []
    for a, r in profile:
        row = []
        for s in range(n):
            t = start + sweep * s / segments
            row.append(matrix @ Vector((a, r * math.cos(t), r * math.sin(t))))
        rows.append(row)
    V, faces = part.grid(rows, key, closed_u=closed, uv_fn=uv_fn, smooth=smooth, orient=orient)
    if cap_start is not None and closed and profile[0][1] > 1e-6:
        part.cap(list(reversed(V[0])), cap_start, center=matrix @ Vector((profile[0][0], 0, 0)))
    if cap_end is not None and closed and profile[-1][1] > 1e-6:
        part.cap(V[-1], cap_end, center=matrix @ Vector((profile[-1][0], 0, 0)))
    return V, faces


def box(part, center, size, key, matrix=None, bevel=0.0, segments=2):
    """Axis-aligned box (optionally bevelled) in local space, then matrix."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
    if bevel > 0.0:
        bmesh.ops.bevel(bm, geom=bm.edges[:] + bm.verts[:], offset=bevel, segments=segments,
                        profile=0.5, affect='EDGES', clamp_overlap=True)
    m = (matrix if matrix is not None else Matrix.Identity(4)) @ Matrix.Translation(Vector(center))
    _append(part, bm, m, key)


def _append(part, bm, matrix, key, smooth=True):
    """Copy a temporary bmesh into a Part with one key."""
    remap = {}
    for v in bm.verts:
        remap[v] = part.bm.verts.new(matrix @ v.co)
    for f in bm.faces:
        part.face([remap[v] for v in f.verts], key, smooth=smooth)
    bm.free()


def tube(part, points, radius, key, sides=8, cap=True, smooth=True):
    """Tube along a polyline with parallel-transport frames."""
    pts = [Vector(p) for p in points]
    rows = []
    prev_n = None
    for k, p in enumerate(pts):
        if k == 0:
            d = (pts[1] - pts[0]).normalized()
        elif k == len(pts) - 1:
            d = (pts[-1] - pts[-2]).normalized()
        else:
            d = ((pts[k + 1] - pts[k]).normalized() + (pts[k] - pts[k - 1]).normalized()).normalized()
        if prev_n is None:
            ref = Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))
            n = (ref - d * ref.dot(d)).normalized()
        else:
            n = (prev_n - d * prev_n.dot(d)).normalized()
        b = d.cross(n)
        prev_n = n
        rows.append([p + (n * math.cos(TAU * s / sides) + b * math.sin(TAU * s / sides)) * radius
                     for s in range(sides)])
    V, faces = part.grid(rows, key, closed_u=True, smooth=smooth)
    if cap:
        c0 = part.cap(list(reversed(V[0])), key)
        c1 = part.cap(V[-1], key)
        faces = faces + list(c0.link_faces) + list(c1.link_faces)
        bmesh.ops.recalc_face_normals(part.bm, faces=faces)
    else:
        def away(c):
            k = min(range(len(pts)), key=lambda i: (pts[i] - c).length_squared)
            return c - pts[k]
        part.orient(faces, away)


def strip(part, points, normals, width, key, lift=0.0008, smooth=True, side_dirs=None):
    """Thin ribbon along a surface curve (panel gaps, seals). `normals`
    are surface normals at the points; the ribbon is offset by `lift`."""
    rows = [[], []]
    for k, p in enumerate(points):
        p = Vector(p)
        nrm = Vector(normals[k]).normalized()
        if side_dirs is not None:
            s = Vector(side_dirs[k]).normalized()
        else:
            if k == 0:
                d = Vector(points[1]) - p
            elif k == len(points) - 1:
                d = p - Vector(points[-2])
            else:
                d = Vector(points[k + 1]) - Vector(points[k - 1])
            s = d.normalized().cross(nrm).normalized()
        base = p + nrm * lift
        rows[0].append(base + s * width * 0.5)
        rows[1].append(base - s * width * 0.5)
    nrms = [Vector(n).normalized() for n in normals]
    centers = [Vector(p) for p in points]

    def want(c):
        k = min(range(len(centers)), key=lambda i: (centers[i] - c).length_squared)
        return nrms[k]

    part.grid(rows, key, smooth=smooth, orient=want)


# -------------------------------------------------------- modifiers

def apply_modifiers(obj):
    dg = bpy.context.evaluated_depsgraph_get()
    ev = obj.evaluated_get(dg)
    me = bpy.data.meshes.new_from_object(ev, preserve_all_data_layers=True, depsgraph=dg)
    old = obj.data
    obj.modifiers.clear()
    obj.data = me
    if old.users == 0:
        bpy.data.meshes.remove(old)
    return obj


def boolean(obj, cutters, operation='DIFFERENCE', solver='MANIFOLD'):
    """Boolean with Blender's Manifold solver (clean on closed inputs; the
    Exact solver left wheel-arch cutter pieces outside the body on one side
    in Blender 5.3). Falls back to Exact where Manifold is unavailable."""
    for c in cutters:
        mod = obj.modifiers.new("cut_" + c.name, 'BOOLEAN')
        mod.operation = operation
        try:
            mod.solver = solver
        except TypeError:
            mod.solver = 'EXACT'
        try:
            mod.material_mode = 'TRANSFER'
        except (AttributeError, TypeError):
            pass
        mod.object = c
        c.hide_render = True
    apply_modifiers(obj)
    for c in cutters:
        bpy.data.objects.remove(c, do_unlink=True)
    return obj


def solidify(obj, thickness, offset=-1.0):
    mod = obj.modifiers.new("solid", 'SOLIDIFY')
    mod.thickness = thickness
    mod.offset = offset
    mod.use_rim = True
    mod.use_even_offset = True
    apply_modifiers(obj)
    return obj


def join(objects, name):
    target = objects[0]
    with bpy.context.temp_override(active_object=target, object=target,
                                   selected_objects=objects, selected_editable_objects=objects):
        bpy.ops.object.join()
    target.name = name
    target.data.name = name
    return target


# ---------------------------------------------------------- finalize

def make_runtime_materials(atlas_png, paint_rgb):
    mats = {}
    paint = bpy.data.materials.new("NW_Paint")
    _principled(paint, base=paint_rgb + (1.0,), rough=0.22, metal=0.15)
    mats["paint"] = paint
    atlas = bpy.data.materials.new("NW_Atlas")
    _principled_textured(atlas, atlas_png)
    mats["atlas"] = atlas
    glass = bpy.data.materials.new("NW_Glass")
    _principled(glass, base=(0.03, 0.035, 0.045, 0.42), rough=0.04, metal=0.0, alpha=0.42)
    glass.blend_method = 'BLEND' if hasattr(glass, "blend_method") else None
    mats["glass"] = glass
    return mats


def _tree(mat):
    if mat.node_tree is None:
        try:
            mat.use_nodes = True
        except AttributeError:
            pass
    nt = mat.node_tree
    bsdf = next((n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED'), None)
    out = next((n for n in nt.nodes if n.type == 'OUTPUT_MATERIAL'), None)
    if bsdf is None:
        bsdf = nt.nodes.new('ShaderNodeBsdfPrincipled')
    if out is None:
        out = nt.nodes.new('ShaderNodeOutputMaterial')
    if not out.inputs['Surface'].is_linked:
        nt.links.new(bsdf.outputs['BSDF'], out.inputs['Surface'])
    return nt, bsdf


def _principled(mat, base, rough, metal, alpha=1.0):
    nt, bsdf = _tree(mat)
    bsdf.inputs['Base Color'].default_value = base
    bsdf.inputs['Roughness'].default_value = rough
    bsdf.inputs['Metallic'].default_value = metal
    bsdf.inputs['Alpha'].default_value = alpha
    if alpha < 1.0:
        for attr, val in (("surface_render_method", 'BLENDED'), ("blend_method", 'BLEND')):
            if hasattr(mat, attr):
                try:
                    setattr(mat, attr, val)
                except TypeError:
                    pass


def _principled_textured(mat, atlas_png):
    """Albedo, metallic-roughness (G,B) and emission images for glTF."""
    nt, bsdf = _tree(mat)
    base_dir = os.path.dirname(atlas_png)
    stem = os.path.splitext(os.path.basename(atlas_png))[0]

    def img_node(path, non_color):
        img = bpy.data.images.load(path)
        if non_color:
            img.colorspace_settings.name = 'Non-Color'
        node = nt.nodes.new('ShaderNodeTexImage')
        node.image = img
        return node

    alb = img_node(atlas_png, False)
    nt.links.new(alb.outputs['Color'], bsdf.inputs['Base Color'])
    orm = img_node(os.path.join(base_dir, stem + "_orm.png"), True)
    sep = nt.nodes.new('ShaderNodeSeparateColor')
    nt.links.new(orm.outputs['Color'], sep.inputs['Color'])
    nt.links.new(sep.outputs['Green'], bsdf.inputs['Roughness'])
    nt.links.new(sep.outputs['Blue'], bsdf.inputs['Metallic'])
    emi = img_node(os.path.join(base_dir, stem + "_emission.png"), False)
    emit_in = bsdf.inputs.get('Emission Color') or bsdf.inputs.get('Emission')
    nt.links.new(emi.outputs['Color'], emit_in)
    if 'Emission Strength' in bsdf.inputs:
        bsdf.inputs['Emission Strength'].default_value = 1.0


def livery_uv(co, nrm, bounds):
    """Box projection into the livery layout: right side, left side, top,
    front, rear. A side view of the car maps to a side view in the UV."""
    (x0, y0, z0), (x1, y1, z1) = bounds
    L, Wd, H = y1 - y0, x1 - x0, z1 - z0
    ax = max(range(3), key=lambda k: abs(nrm[k]))
    if ax == 0:      # sides: u along length, v along height
        u = (co.y - y0) / L
        v = (co.z - z0) / H
        if nrm.x > 0:
            return (u, 0.02 + v * 0.30)
        return (1.0 - u, 0.34 + v * 0.30)
    if ax == 2:      # top (and bottom, shares the island)
        return (0.02 + (co.y - y0) / L * 0.66, 0.66 + (co.x - x0) / Wd * 0.32)
    if nrm.y > 0:    # front
        return (0.70 + (co.x - x0) / Wd * 0.14, 0.66 + (co.z - z0) / H * 0.32)
    return (0.85 + (x1 - co.x) / Wd * 0.14, 0.66 + (co.z - z0) / H * 0.32)


def finalize(obj, mats, sharp_angle_deg=38.0):
    """Logical keys -> runtime materials + UVs, sharp edges by angle."""
    me = obj.data
    keys = [m.name[2:] if m.name.startswith("L_") else m.name for m in me.materials]
    bm = bmesh.new()
    bm.from_mesh(me)
    uv = bm.loops.layers.uv.get("UVMap") or bm.loops.layers.uv.new("UVMap")
    xs = [v.co for v in bm.verts]
    bounds = ((min(c.x for c in xs), min(c.y for c in xs), min(c.z for c in xs)),
              (max(c.x for c in xs), max(c.y for c in xs), max(c.z for c in xs)))
    order = ["paint", "atlas", "glass"]
    stats = {}
    for f in bm.faces:
        key = keys[f.material_index] if f.material_index < len(keys) else "black_matte"
        stats[key] = stats.get(key, 0) + 1
        if key == "paint":
            nrm = f.normal
            for loop in f.loops:
                loop[uv].uv = livery_uv(loop.vert.co, nrm, bounds)
            f.material_index = 0
        elif key == "glass":
            for loop in f.loops:
                loop[uv].uv = (0.5, 0.5)
            f.material_index = 2
        elif key in REGION:
            for loop in f.loops:
                u, v = loop[uv].uv
                loop[uv].uv = region_uv(key, u, v)
            f.material_index = 1
        else:
            if key not in SWATCH:
                raise ValueError("Unknown logical material key: " + key)
            s = swatch_uv(key)
            for loop in f.loops:
                loop[uv].uv = s
            f.material_index = 1
    for e in bm.edges:
        if len(e.link_faces) == 2:
            e.smooth = e.calc_face_angle(0.0) < math.radians(sharp_angle_deg)
        else:
            e.smooth = False
    for f in bm.faces:
        f.smooth = True
    # Set the final slots first: clearing slots after writing would drop
    # the per-face material indices.
    me.materials.clear()
    for k in order:
        me.materials.append(mats[k])
    bm.to_mesh(me)
    bm.free()
    return stats


def write_atlas_images(out_png, regions_draw=None):
    """Atlas albedo / ORM / emission PNGs (PIL). regions_draw(key, size)
    returns RGBA/ORM/emission PIL images for each textured region."""
    from PIL import Image

    S = ATLAS_SIZE
    alb = Image.new("RGB", (S, S), (20, 20, 22))
    orm = Image.new("RGB", (S, S), (255, 200, 0))
    emi = Image.new("RGB", (S, S), (0, 0, 0))
    cell = S // 16
    for key in SWATCH_ORDER:
        col, rough, metal, em = SWATCH[key]
        i = SWATCH_ORDER.index(key)
        cx, cy = i % 8, i // 8
        x0 = cx * cell
        y0 = S - (cy + 1) * cell   # PIL origin top-left
        box_ = (x0, y0, x0 + cell, y0 + cell)
        alb.paste(tuple(int(_srgb(c) * 255) for c in col), box_)
        orm.paste((255, int(rough * 255), int(metal * 255)), box_)
        emi.paste(tuple(int(_srgb(min(c, 1.0)) * 255) for c in em), box_)
    if regions_draw is not None:
        for key, (u0, v0, u1, v1) in REGION.items():
            w, h = int((u1 - u0) * S), int((v1 - v0) * S)
            got = regions_draw(key, (w, h))
            if got is None:
                continue
            a, o, e = got
            pos = (int(u0 * S), int(S - v1 * S))
            alb.paste(a.convert("RGB"), pos)
            orm.paste(o.convert("RGB"), pos)
            emi.paste(e.convert("RGB"), pos)
    stem = os.path.splitext(out_png)[0]
    alb.save(out_png)
    orm.save(stem + "_orm.png")
    emi.save(stem + "_emission.png")
    return out_png


def _srgb(c):
    c = max(0.0, min(1.0, c))
    return 12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055


def empty(name, location, props=None):
    e = bpy.data.objects.new(name, None)
    e.empty_display_type = 'PLAIN_AXES'
    e.location = Vector(location)
    for k, v in (props or {}).items():
        e[k] = v
    bpy.context.scene.collection.objects.link(e)
    return e


VARIANT_LAYER = "VariantMask"


def tag_variant(obj, slot):
    """Geometry-variant mask (exported as TEXCOORD_1 = Godot UV2): 0 = shared
    by every variant, n = only in variant slot n. The game collapses faces of
    the other slots in the vertex shader, so RED / WHITE (or CLEAN / LIVERY)
    share one GLB, one mesh and the same draw calls."""
    me = obj.data
    layer = me.uv_layers.get(VARIANT_LAYER) or me.uv_layers.new(name=VARIANT_LAYER)
    for loop_uv in layer.data:
        loop_uv.uv = (float(slot), 0.0)
    return obj


def export_glb(path, objects):
    for o in bpy.context.scene.objects:
        o.select_set(o in objects)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True,
                              export_apply=True, export_yup=True, export_texcoords=True,
                              export_normals=True, export_materials='EXPORT', export_extras=True,
                              export_cameras=False, export_lights=False, export_animations=False,
                              export_image_format='AUTO')
    return path


def mesh_report(obj):
    me = obj.data
    me.calc_loop_triangles()
    per_mat = {}
    for t in me.loop_triangles:
        name = me.materials[t.material_index].name if me.materials else "-"
        per_mat[name] = per_mat.get(name, 0) + 1
    xs = [obj.matrix_world @ v.co for v in me.vertices]
    bb = [[min(c[k] for c in xs) for k in range(3)], [max(c[k] for c in xs) for k in range(3)]]
    return {"triangles": len(me.loop_triangles), "vertices": len(me.vertices),
            "materials": [m.name for m in me.materials], "triangles_per_material": per_mat,
            "uv_layers": [l.name for l in me.uv_layers], "bounds_min": bb[0], "bounds_max": bb[1]}


def write_json(path, data):
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=2, sort_keys=True)
        fh.write("\n")


def recalc(part, faces):
    """Consistent outward winding for a closed (or nearly closed) region."""
    faces = [f for f in faces if f is not None and f.is_valid]
    if faces:
        bmesh.ops.recalc_face_normals(part.bm, faces=faces)
