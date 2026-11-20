"""Car Factory comparison step: solve each reference photo's camera from
hand-picked keypoints (OpenCV PnP over a focal-length sweep) and report the
reprojection error of the model. Output cams.json is read by
game/tests/car_camera_match_render.gd to render the car from the same
camera, and by overlay.py to build photo / render / overlay sheets.

  python tools/car_factory/compare/camera_match.py tools/car_factory/compare/e30_keypoints.json out/cams.json
Needs numpy + opencv-python-headless.
"""
import json
import math
import sys

import cv2
import numpy as np


def solve(name, size, picked, model):
    W, H = size
    keys = list(picked.keys())
    obj = np.array([model[k] for k in keys], dtype=np.float64)
    img = np.array([picked[k] for k in keys], dtype=np.float64)
    best = None
    for f in np.geomspace(0.4 * W, 6.0 * W, 160):
        K = np.array([[f, 0, W / 2], [0, f, H / 2], [0, 0, 1]], dtype=np.float64)
        for flag in (cv2.SOLVEPNP_SQPNP, cv2.SOLVEPNP_ITERATIVE):
            try:
                ok, rv, tv = cv2.solvePnP(obj, img, K, None, flags=flag)
            except cv2.error:
                continue
            if not ok:
                continue
            rv, tv = cv2.solvePnPRefineLM(obj, img, K, None, rv, tv)
            proj, _ = cv2.projectPoints(obj, rv, tv, K, None)
            err = np.linalg.norm(proj.reshape(-1, 2) - img, axis=1)
            R, _ = cv2.Rodrigues(rv)
            if ((R @ obj.T + tv).T[:, 2] <= 0).any():
                continue
            rms = float(np.sqrt((err ** 2).mean()))
            if best is None or rms < best["rms"]:
                best = {"rms": rms, "f": float(f), "R": R, "t": tv.reshape(3), "err": err,
                        "proj": proj.reshape(-1, 2)}
    R, t = best["R"], best["t"]
    C = -R.T @ t
    g = lambda v: [float(v[0]), float(v[2]), float(-v[1])]   # Blender -> Godot axes
    span = float(max(img.max(0) - img.min(0)))
    return {"photo": name, "size": [W, H], "rms_px": best["rms"], "rms_pct_of_keypoint_span": 100 * best["rms"] / span,
            "focal_px": best["f"], "fov_v_deg": 2 * math.degrees(math.atan(H / 2 / best["f"])),
            "cam_pos": g(C), "basis_x": g(R.T[:, 0]), "basis_y": g(-R.T[:, 1]), "basis_z": g(-R.T[:, 2]),
            "per_point_px": {k: float(e) for k, e in zip(keys, best["err"])},
            "projected": {k: [float(p[0]), float(p[1])] for k, p in zip(keys, best["proj"])},
            "picked": picked}


if __name__ == "__main__":
    data = json.load(open(sys.argv[1]))
    out = [solve(n, d["size"], d["picked_px"], data["model_keypoints"]) for n, d in data["photos"].items()]
    json.dump(out, open(sys.argv[2], "w"), indent=1)
    for o in out:
        print("%s: RMS %.1f px (%.1f%% of keypoint span), vertical fov %.1f deg" %
              (o["photo"], o["rms_px"], o["rms_pct_of_keypoint_span"], o["fov_v_deg"]))
