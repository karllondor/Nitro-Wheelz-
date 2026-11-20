"""Nitro Wheelz Car Factory: wheel library (separate GLB per design).

Conventions shared by every wheel asset (and read by the game):
  * origin = hub centre, rolling axis = Blender +X (Godot +X),
    OUTER face towards +X; the game turns left-side wheels by 180 deg;
  * one material NW_Atlas (flat swatches) -> one draw call per wheel;
  * size in metres, recorded in game/assets/cars/wheels/wheels.json.

Run: python tools/car_factory/blender/build_wheels.py --out game/assets/cars/wheels
"""
import argparse
import math
import os
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import nwcf  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

TYRE_R = 0.290
TYRE_W = 0.205
RIM_R = 0.2032          # 16 in bead seat
FLANGE_R = 0.2212
HALF = 0.1075           # half rim width (8.5 in)


def _outward(center_r):
    def want(c):
        radial = Vector((0.0, c.y, c.z))
        if radial.length < 1e-6:
            return Vector((math.copysign(1.0, c.x), 0, 0))
        return c - radial.normalized() * center_r
    return want


def tyre(part, seg=40):
    m = nwcf.frame_from_axis((0, 0, 0), (1, 0, 0))
    w = TYRE_W * 0.5
    prof = [(-HALF - 0.001, FLANGE_R - 0.002), (-w - 0.005, 0.240), (-w - 0.003, 0.262),
            (-w + 0.004, 0.278), (-w + 0.016, 0.2875), (-w + 0.04, TYRE_R),
            (w - 0.04, TYRE_R), (w - 0.016, 0.2875), (w - 0.004, 0.278), (w + 0.003, 0.262),
            (w + 0.005, 0.240), (HALF + 0.001, FLANGE_R - 0.002)]
    keys = ["tyre_side"] * 4 + ["tyre"] * 3 + ["tyre_side"] * 4
    rows = []
    for a, r in prof:
        rows.append([m @ Vector((a, r * math.cos(math.tau * s / seg), r * math.sin(math.tau * s / seg)))
                     for s in range(seg)])
    part.grid(rows, lambda i, j: keys[j], closed_u=True, orient=_outward(0.250))
    # Tread grooves: shallow dark rings so rotation reads at speed.
    for a in (-0.045, 0.0, 0.045):
        nwcf.lathe(part, m, [(a - 0.004, TYRE_R + 0.0006), (a + 0.004, TYRE_R + 0.0006)], "soot",
                   segments=seg, orient=_outward(0.0))


def rim_signature(part):
    """v0.2 Signature: wide polished STEP LIP that dives into a deep dish,
    a concave silver face set ~7 cm back, eight vent pockets with real depth
    (dark tunnels, not painted dots), raised webbing between them, a domed
    centre and 4 nuts (4x100). Same size, hub pivot and outer offset."""
    m = nwcf.frame_from_axis((0, 0, 0), (1, 0, 0))
    seg = 36
    lip_depth = 0.080               # v0.3: deeper dish (was 0.070)
    face_a = HALF - lip_depth
    r_step = RIM_R - 0.023          # v0.3: wider polished step lip (was -0.015)
    # Rolled outer flange -> flat polished lip -> step down into the dish.
    nwcf.lathe(part, m, [(HALF - 0.006, FLANGE_R + 0.001), (HALF + 0.002, FLANGE_R - 0.001),
                         (HALF + 0.004, FLANGE_R - 0.006), (HALF + 0.004, r_step + 0.004),
                         (HALF + 0.001, r_step)], "rim_lip", segments=seg,
               orient=lambda c: Vector((1.0, 0, 0)) + Vector((0, c.y, c.z)) * 1.5)
    # Polished dish wall: slightly conical, so it catches the light.
    nwcf.lathe(part, m, [(HALF + 0.001, r_step), (HALF - 0.020, r_step - 0.003),
                         (face_a + 0.010, r_step - 0.010), (face_a + 0.004, r_step - 0.013)], "rim_lip",
               segments=seg, orient=lambda c: -Vector((0, c.y, c.z)) + Vector((0.6, 0, 0)))
    # v0.3: dark contact-shadow ring where the polished dish wall meets the
    # face, then a more concave face (outer edge forward, centre deeper).
    r_f = r_step - 0.013
    nwcf.lathe(part, m, [(face_a + 0.004, r_step - 0.013), (face_a + 0.002, r_f - 0.003)], "rim_dark",
               segments=seg, orient=lambda c: (1.0, 0, 0))
    face = [(face_a + 0.002, r_f - 0.003), (face_a - 0.001, r_f - 0.010), (face_a - 0.007, 0.140),
            (face_a - 0.011, 0.106), (face_a - 0.008, 0.078), (face_a + 0.004, 0.064)]
    nwcf.lathe(part, m, face, "rim_silver", segments=seg, orient=lambda c: (1.0, 0, 0))
    # Vent pockets: dark tunnels sunk 25 mm into the face.
    for k in range(8):
        a = math.tau * k / 8 + math.tau / 16
        cen = Vector((face_a - 0.0085, 0.124 * math.cos(a), 0.124 * math.sin(a)))
        mm = nwcf.frame_from_axis(cen, (1, 0, 0))
        nwcf.lathe(part, mm, [(0.0015, 0.0255), (-0.022, 0.0235)], "rim_dark", segments=10,
                   orient=lambda c, cen=cen: -(c - cen) + Vector((0, 0, 0)))
        nwcf.lathe(part, mm, [(-0.022, 0.0235), (-0.022, 0.0)], "brake", segments=10,
                   orient=lambda c: (1.0, 0, 0))
        nwcf.lathe(part, mm, [(0.0012, 0.0285), (0.0022, 0.0262)], "rim_lip", segments=10,
                   orient=lambda c: (1.0, 0, 0))
    # Domed centre with 4 nuts and a polished cap.
    nwcf.lathe(part, m, [(face_a + 0.004, 0.064), (face_a + 0.016, 0.058), (face_a + 0.022, 0.044),
                         (face_a + 0.024, 0.028)], "rim_silver", segments=24, orient=lambda c: (1.0, 0, 0))
    for k in range(4):
        a = math.tau * k / 4
        cen = Vector((face_a + 0.022, 0.044 * math.cos(a), 0.044 * math.sin(a)))
        mm = nwcf.frame_from_axis(cen, (1, 0, 0))
        nwcf.lathe(part, mm, [(-0.004, 0.0095), (0.007, 0.0095), (0.009, 0.0065), (0.0095, 0.0)], "nut",
                   segments=6, orient=lambda c, cen=cen: c - cen + Vector((0.002, 0, 0)))
    nwcf.lathe(part, m, [(face_a + 0.024, 0.028), (face_a + 0.030, 0.024), (face_a + 0.034, 0.012),
                         (face_a + 0.035, 0.0)], "rim_lip", segments=20, orient=lambda c: (1.0, 0, 0))
    _barrel(part, m, face_a - 0.006, seg)


def rim_nw_deep_dish(part):
    """NW Deep Dish: deeper polished lip, dark face, 8 straight spokes."""
    m = nwcf.frame_from_axis((0, 0, 0), (1, 0, 0))
    seg = 40
    lip_depth = 0.088
    face_a = HALF - lip_depth
    nwcf.lathe(part, m, [(HALF - 0.004, FLANGE_R + 0.001), (HALF + 0.003, FLANGE_R - 0.003),
                         (HALF + 0.004, RIM_R + 0.004), (HALF, RIM_R - 0.002)], "rim_lip", segments=seg,
               orient=lambda c: Vector((1.0, 0, 0)) + Vector((0, c.y, c.z)) * 2.0)
    nwcf.lathe(part, m, [(HALF, RIM_R - 0.002), (face_a + 0.006, RIM_R - 0.006)], "rim_lip", segments=seg,
               orient=lambda c: -Vector((0, c.y, c.z)))
    nwcf.lathe(part, m, [(face_a + 0.006, RIM_R - 0.006), (face_a, RIM_R - 0.014), (face_a, 0.0)],
               "rim_dark", segments=seg, orient=lambda c: (1.0, 0, 0))
    for k in range(8):
        a = math.tau * k / 8
        rot = Matrix.Rotation(a, 4, 'X')
        nwcf.box(part, (face_a + 0.012, 0.0, 0.120), (0.020, 0.024, 0.160), "rim_silver", matrix=rot,
                 bevel=0.006, segments=2)
    nwcf.lathe(part, m, [(face_a, 0.058), (face_a + 0.020, 0.054), (face_a + 0.030, 0.040),
                         (face_a + 0.034, 0.0)], "rim_silver", segments=24, orient=lambda c: (1.0, 0, 0))
    for k in range(4):
        a = math.tau * k / 4 + math.tau / 8
        cen = Vector((face_a + 0.030, 0.042 * math.cos(a), 0.042 * math.sin(a)))
        mm = nwcf.frame_from_axis(cen, (1, 0, 0))
        nwcf.lathe(part, mm, [(0.0, 0.009), (0.009, 0.009), (0.011, 0.006), (0.0115, 0.0)], "nut",
                   segments=6, orient=lambda c, cen=cen: c - cen + Vector((0.002, 0, 0)))
    _barrel(part, m, face_a, seg)


def _barrel(part, m, face_a, seg):
    """Inner barrel, inner flange and a brake disc seen through the face."""
    nwcf.lathe(part, m, [(face_a - 0.002, RIM_R - 0.006), (-HALF + 0.004, RIM_R - 0.006),
                         (-HALF - 0.003, FLANGE_R - 0.004)], "rim_dark", segments=seg,
               orient=lambda c: -Vector((0, c.y, c.z)))
    nwcf.lathe(part, m, [(face_a - 0.030, 0.150), (face_a - 0.030, 0.050)], "brake", segments=28,
               orient=lambda c: (1.0, 0, 0))
    cal = Matrix.Translation((face_a - 0.040, 0.0, 0.125))
    nwcf.box(part, (0, 0, 0), (0.040, 0.090, 0.045), "caliper", matrix=cal, bevel=0.010)


DESIGNS = {
    "wheel_signature_e30": {"name": "SIGNATURE", "builder": rim_signature, "tyre_seg": 36,
                            "note": "Source-matched approximation (v0.3): wide polished step lip, deep polished dish "
                                    "with a contact-shadow ring and a concave silver face are visible in the photos; "
                                    "the exact face design, vent count and size are NOT confirmed."},
    "wheel_nw_deep_dish": {"name": "NW DEEP DISH", "builder": rim_nw_deep_dish,
                           "note": "Nitro Wheelz original design (cosmetic only)."},
}


def build(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    catalog = {}
    for wid, d in DESIGNS.items():
        nwcf.reset()
        part = nwcf.Part(wid)
        tyre(part, d.get("tyre_seg", 40))
        d["builder"](part)
        obj = part.to_object()
        atlas = nwcf.write_atlas_images(os.path.join(tempfile.mkdtemp(prefix="nwcf_"), wid + "_atlas.png"))
        mats = nwcf.make_runtime_materials(atlas, (0.5, 0.5, 0.5))
        nwcf.finalize(obj, mats, sharp_angle_deg=40.0)
        # Drop unused paint / glass slots: one material per wheel.
        me = obj.data
        me.materials.pop(index=2)   # glass (unused)
        me.materials.pop(index=0)   # paint (unused): atlas becomes slot 0
        for p in me.polygons:
            p.material_index = 0
        glb = nwcf.export_glb(os.path.join(out_dir, wid + ".glb"), [obj])
        rep = nwcf.mesh_report(obj)
        catalog[wid] = {
            "name": d["name"], "file": wid + ".glb", "tyre_radius_m": TYRE_R, "tyre_width_m": TYRE_W,
            "rim_radius_m": RIM_R, "rim_half_width_m": HALF, "outer_face_offset_m": HALF + 0.004,
            "triangles": rep["triangles"], "glb_bytes": os.path.getsize(glb), "note": d["note"],
        }
        for png in (atlas, atlas[:-4] + "_orm.png", atlas[:-4] + "_emission.png"):
            os.remove(png)
    return catalog


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    repo = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
    ap.add_argument("--out", default=os.path.join(repo, "game", "assets", "cars", "wheels"))
    ap.add_argument("--report", default=os.path.join(repo, "tools", "car_factory", "reports",
                                                     "wheels_build_report.json"))
    args, _ = ap.parse_known_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:])
    cat = build(args.out)
    os.makedirs(os.path.dirname(args.report), exist_ok=True)
    nwcf.write_json(args.report, cat)
    # Runtime catalog read by the game (car_cosmetics.gd): sizes + names.
    runtime = {k: {f: v[f] for f in ("name", "file", "tyre_radius_m", "tyre_width_m", "rim_radius_m",
                                      "rim_half_width_m", "outer_face_offset_m", "note")}
               for k, v in cat.items()}
    nwcf.write_json(os.path.join(args.out, "wheels.json"), {"schema": 1, "wheels": runtime})
    for k, v in cat.items():
        print("WHEEL", k, "tris", v["triangles"], "bytes", v["glb_bytes"])
