"""Nitro Wheelz Car Factory: AI-generated body mesh -> game-ready factory GLB
(PROTOTYPE, v0.1.33). The body comes from an image-to-3D service (Tripo "Sky
R32" test); this script fits it to the car's catalog footprint, cuts the four
wheels out and exports a GLB the game loads like any factory car (wheels from
the wheel library on the wheel_* empties, the body's own textures in one
NW_Atlas material).

Run:  python tools/car_factory/blender/import_ai_car.py -- --in body.glb \
          --out game/assets/cars/ryu32_ai/ryu32_ai.glb --length 4.545 --width 1.90 --height 1.29

Steps: import -> turn the nose to +Y (glTF +Z = nose in this model) -> scale
non-uniformly to the catalog length / width / height -> weld (glTF splits
vertices at UV seams; UVs are per loop in Blender, so welding is lossless) ->
find the axles from the ground-contact patches -> boolean-cut the tyres with
cylinders (their walls become the dark wheel wells, UV on a black texel
patch written into the textures) -> smooth shading -> hubs -> export.
Licence note: the mesh and textures are the owner's generation on the
service's PAID plan; nothing is committed to the repository without that.
"""
import argparse
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy  # noqa: E402  (bpy must load before bmesh)
import bmesh  # noqa: E402
import nwcf  # noqa: E402
from mathutils import Vector  # noqa: E402

TRACK = 0.795          # hub x (same as the RYU wheel asset)


def parse():
    ap = argparse.ArgumentParser()
    ap.add_argument("--in", dest="src", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--length", type=float, default=4.545)
    ap.add_argument("--width", type=float, default=1.90)
    ap.add_argument("--height", type=float, default=1.29)
    ap.add_argument("--wheelbase", type=float, default=2.615)
    ap.add_argument("--wheel-r", type=float, default=0.33)
    ap.add_argument("--cut-r", type=float, default=0.362)
    ap.add_argument("--nose", default="-y", help="axis the nose points to after import (blender space)")
    args, _ = ap.parse_known_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:])
    return args


def main():
    a = parse()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=a.src)
    obj = next(o for o in bpy.context.scene.objects if o.type == 'MESH')
    for o in list(bpy.context.scene.objects):
        if o is not obj:
            o.select_set(False)
    obj.parent = None
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    def end_heights():
        ys_ = [v.co.y for v in obj.data.vertices]
        y0, y1 = min(ys_), max(ys_)
        span = y1 - y0
        return (max(v.co.z for v in obj.data.vertices if v.co.y < y0 + span * 0.2),
                max(v.co.z for v in obj.data.vertices if v.co.y > y1 - span * 0.2))
    print("roof/wing height at the -y / +y end before the turn: %.3f / %.3f" % end_heights())
    try:
        bpy.ops.mesh.customdata_custom_splitnormals_clear()   # the importer's normals: recomputed below
    except RuntimeError:
        pass
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if a.nose == "-y":
        # 180 degrees about Z, done on the vertices (the glTF importer leaves the object
        # in quaternion mode, where rotation_euler is silently ignored)
        for v in obj.data.vertices:
            v.co = Vector((-v.co.x, -v.co.y, v.co.z))
    h0, h1 = end_heights()
    print("after the turn: %.3f / %.3f  (the nose end is the LOWER one and must be +y)" % (h0, h1))
    me = obj.data
    lo = Vector((min(v.co.x for v in me.vertices), min(v.co.y for v in me.vertices), min(v.co.z for v in me.vertices)))
    hi = Vector((max(v.co.x for v in me.vertices), max(v.co.y for v in me.vertices), max(v.co.z for v in me.vertices)))
    # centre in plan, ground at z = 0, catalog length / width / height
    sx = a.width / (hi.x - lo.x)
    sy = a.length / (hi.y - lo.y)
    sz = a.height / (hi.z - lo.z)
    for v in me.vertices:
        v.co = Vector(((v.co.x - (lo.x + hi.x) * 0.5) * sx, (v.co.y - (lo.y + hi.y) * 0.5) * sy, (v.co.z - lo.z) * sz))
    print("scale x %.3f y %.3f z %.3f (non-uniform: x %.0f %%, z %.0f %% of the length scale)" % (
        sx, sy, sz, 100 * sx / sy, 100 * sz / sy))
    # weld by position (UV seams stay seams: UVs are per loop)
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=2e-5)
    # drop the tiny floating pieces
    bm.faces.ensure_lookup_table()
    seen, comps = set(), []
    for f in bm.faces:
        if f.index in seen:
            continue
        stack, comp = [f], []
        seen.add(f.index)
        while stack:
            c = stack.pop()
            comp.append(c)
            for e in c.edges:
                for nf in e.link_faces:
                    if nf.index not in seen:
                        seen.add(nf.index)
                        stack.append(nf)
        comps.append(comp)
    comps.sort(key=len, reverse=True)
    drop = [f for c in comps[1:] if len(c) < 400 for f in c]
    bmesh.ops.delete(bm, geom=drop, context='FACES')
    vol = bm.calc_volume(signed=True)
    print("signed volume of the welded body: %.4f m3 (negative = faces point inward)" % vol)
    if vol < 0:
        bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
        print("faces reversed")
    nonman = sum(1 for e in bm.edges if len(e.link_faces) != 2)
    print("non-manifold edges after the weld: %d" % nonman)
    bm.to_mesh(me)
    bm.free()
    print("floaters removed: %d faces; body faces %d" % (len(drop), len(me.polygons)))
    # axles from the ground-contact patches
    # tyre bottoms: lowest vertices in the outer x band (excludes the floor and the bumper lips)
    low = sorted((v.co for v in me.vertices if abs(v.co.x) > a.width * 0.30 and v.co.z < 0.03), key=lambda c: c.y)
    clusters, cur = [], [low[0]]
    for c in low[1:]:
        if c.y - cur[-1].y > 0.5:
            clusters.append(cur)
            cur = [c]
        else:
            cur.append(c)
    clusters.append(cur)
    print("tyre-bottom clusters (y range, n):", [(round(c[0].y, 3), round(c[-1].y, 3), len(c)) for c in clusters])
    clusters = sorted(clusters, key=len, reverse=True)[:2]
    # centre of the 25 lowest vertices of each patch
    axle_y = sorted(sum(v.y for v in sorted(c, key=lambda q: q.z)[:25]) / min(25, len(c)) for c in clusters)  # rear, front
    mid = (axle_y[0] + axle_y[1]) * 0.5
    y_rear, y_front = mid - a.wheelbase * 0.5, mid + a.wheelbase * 0.5
    print("axles found: rear %.3f front %.3f (wheelbase %.3f) -> used %.3f / %.3f" % (
        axle_y[0], axle_y[1], axle_y[1] - axle_y[0], y_rear, y_front))
    # Cut the tyres out. The AI mesh is a closed solid, but Blender's exact boolean left whole
    # cutter shells behind on it, so the cut is done by hand: delete every face whose centre
    # lies inside the tyre cylinder, then close the hole with a dark liner (tube + inner disc).
    bm = bmesh.new()
    bm.from_mesh(me)
    hubs = [(side, y) for y in (y_rear, y_front) for side in (1.0, -1.0)]
    gone = []
    for f in bm.faces:
        c = f.calc_center_median()
        for side, y in hubs:
            if 0.48 < c.x * side < 1.05 and math.hypot(c.y - y, c.z - a.wheel_r) < a.cut_r:
                gone.append(f)
                break
    bmesh.ops.delete(bm, geom=gone, context='FACES')
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
    bm.to_mesh(me)
    bm.free()
    print("tyre faces removed: %d; body faces left %d" % (len(gone), len(me.polygons)))
    liners = []
    for side, y in hubs:
        part = nwcf.Part("liner")
        axis = Vector((0.0, y, a.wheel_r))
        m = nwcf.frame_from_axis((0, y, a.wheel_r), (side, 0, 0))
        r = a.cut_r + 0.004
        # tube (normals towards the axis) and the inner disc (normal towards the wheel)
        nwcf.lathe(part, m, [(0.54, r), (0.90, r)], "well", segments=48,
                   orient=lambda c, axis=axis: -(c - Vector((c.x, axis.y, axis.z))))
        nwcf.lathe(part, m, [(0.54, r), (0.54, 0.0)], "well", segments=48,
                   orient=lambda c, side=side: (side, 0.0, 0.0))
        liners.append(part.to_object())
    obj = nwcf.join([obj] + liners, "AI_Body")
    bpy.context.view_layer.objects.active = obj
    # materials: slot 0 = the body texture; the cut faces (L_well) go onto a
    # black texel patch of the same textures
    me = obj.data
    body_idx = next(i for i, m in enumerate(me.materials) if m is not None and not m.name.startswith("L_"))
    well_idx = next((i for i, m in enumerate(me.materials) if m is not None and m.name.startswith("L_")), None)
    mat = me.materials[body_idx]
    mat.name = "NW_Atlas"
    uv = me.uv_layers.active
    black = (3.0 / 2048.0, 3.0 / 2048.0)
    n_well = 0
    for p in me.polygons:
        if well_idx is not None and p.material_index == well_idx:
            n_well += 1
            for li in p.loop_indices:
                uv.data[li].uv = black
        p.material_index = 0
    while len(me.materials) > 1:
        me.materials.pop(index=len(me.materials) - 1)
    print("wheel-well faces: %d" % n_well)
    import tempfile
    paint_black_patch(mat, a.src, tempfile.mkdtemp(prefix="nwai_"))
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(52))
    me.calc_loop_triangles()
    tris = len(me.loop_triangles)
    pts = [v.co for v in me.vertices]
    bb = ([min(p[i] for p in pts) for i in range(3)], [max(p[i] for p in pts) for i in range(3)])
    print("RESULT tris %d  bounds %s .. %s" % (tris, [round(x, 3) for x in bb[0]], [round(x, 3) for x in bb[1]]))
    empties = [
        nwcf.empty("wheel_FL", (-TRACK, y_front, a.wheel_r), {"axle": "front", "side": -1}),
        nwcf.empty("wheel_FR", (TRACK, y_front, a.wheel_r), {"axle": "front", "side": 1}),
        nwcf.empty("wheel_RL", (-TRACK, y_rear, a.wheel_r), {"axle": "rear", "side": -1}),
        nwcf.empty("wheel_RR", (TRACK, y_rear, a.wheel_r), {"axle": "rear", "side": 1}),
    ]
    obj.name = "AI_Body"
    me.name = "AI_Body"
    os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
    for o in bpy.context.scene.objects:
        o.select_set(o is obj or o in empties)
    bpy.ops.export_scene.gltf(filepath=a.out, export_format='GLB', use_selection=True, export_apply=True,
                              export_yup=True, export_texcoords=True, export_normals=True,
                              export_materials='EXPORT', export_cameras=False, export_lights=False,
                              export_animations=False, export_image_format='AUTO')
    print("EXPORTED", a.out, os.path.getsize(a.out), "bytes")


def paint_black_patch(mat, src_glb, tmpdir):
    """Black, fully rough, non-metal 8 x 8 texel patch in the bottom-left corner of the base
    colour and metallic-roughness textures (the wheel-well UVs point there). Done on the
    textures embedded in the source GLB with PIL and written as baseline JPEGs: Blender's
    own JPEG export produced files Godot refused to decode. The normal map is dropped (the
    game's car shader does not use it)."""
    import io
    import json
    import struct
    from PIL import Image

    raw = open(src_glb, "rb").read()
    jl = struct.unpack("<I", raw[12:16])[0]
    j = json.loads(raw[20:20 + jl])
    base = 20 + jl + 8
    os.makedirs(tmpdir, exist_ok=True)
    out = {}
    for im in j["images"]:
        bv = j["bufferViews"][im["bufferView"]]
        data = raw[base + bv.get("byteOffset", 0): base + bv.get("byteOffset", 0) + bv["byteLength"]]
        name = im["name"].lower()
        img = Image.open(io.BytesIO(data)).convert("RGB")
        w, h = img.size
        if "basecolor" in name:
            img.paste((1, 1, 1), (0, h - 8, 8, h))
            path = os.path.join(tmpdir, "ryu_basecolor.jpg")
            key = "basecolor"
        elif name.replace(".jpg", "").replace(".png", "").endswith("rm"):
            img.paste((0, 255, 0), (0, h - 8, 8, h))       # G = roughness 1, B = metallic 0
            path = os.path.join(tmpdir, "ryu_rm.jpg")
            key = "rm"
        else:
            continue
        img.save(path, "JPEG", quality=92, subsampling=0)
        out[key] = path
    nt = mat.node_tree
    for node in list(nt.nodes):
        if node.type != 'TEX_IMAGE' or node.image is None:
            continue
        nm = node.image.name.lower()
        if "basecolor" in nm:
            node.image = bpy.data.images.load(out["basecolor"])
        elif "rm" in nm.replace(".jpg", "").replace(".png", "").split("_")[-1] or "rm" in nm.split(".")[0].split("_")[-1]:
            node.image = bpy.data.images.load(out["rm"])
            node.image.colorspace_settings.name = 'Non-Color'
        else:
            for lk in list(nt.links):
                if lk.from_node is node or (lk.from_node.type == 'NORMAL_MAP' and lk.from_node.inputs['Color'].links
                                            and lk.from_node.inputs['Color'].links[0].from_node is node):
                    nt.links.remove(lk)
    for node in list(nt.nodes):
        if node.type == 'NORMAL_MAP':
            nt.nodes.remove(node)
    for node in list(nt.nodes):
        if node.type == 'TEX_IMAGE' and not node.outputs[0].links and not node.outputs[1].links:
            nt.nodes.remove(node)


if __name__ == "__main__":
    main()
