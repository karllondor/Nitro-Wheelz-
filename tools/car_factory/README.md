# Nitro Wheelz Car Factory

Cars are built by **Blender Python scripts** from numbers (reviewable as text,
reproducible), exported as **GLB** and assembled in Godot by
`game/scripts/vehicles/glb_car.gd`. Decision and reasoning:
`docs/car_factory/CAR_FACTORY_AUDIT.md`. First car: `docs/car_factory/E30_BLESSED_PROTOTYPE.md`.

## Tools (tested versions)

| Tool | Version used | Install |
|---|---|---|
| Blender as a Python module | `bpy 5.3.0` (Python 3.13) | `python3 -m venv .venv && .venv/bin/pip install bpy==5.3.0 numpy pillow` |
| Comparison | `opencv-python-headless`, `numpy`, `pillow` | `.venv/bin/pip install opencv-python-headless` |
| Godot | 4.7.2 (pinned, `.godot-version`) | as for the game |

A full Blender 5.3 install works too: `blender -b -P tools/car_factory/blender/build_e30_blessed.py -- --out ...`.

## Build

```
.venv/bin/python tools/car_factory/blender/build_wheels.py        # -> game/assets/cars/wheels/*.glb + wheels.json
.venv/bin/python tools/car_factory/blender/build_e30_blessed.py   # -> game/assets/cars/e30_blessed/e30_blessed.glb
godot --headless --path game --editor --import                    # import / extract textures
godot --headless --path game --script res://tests/e30_factory_car_test.gd
```

Build reports (triangles per material, bounds, pivots, sizes) land in
`tools/car_factory/reports/`. A build fails (`VALIDATION FAILED`) when geometry
leaves the car outline.

## Conventions (all cars)

- Blender axes: X = car right, Y = forward, Z = up, metres, ground z = 0, origin
  at the body centre (glTF export turns this into Godot -Z forward, +Y up).
- **Three body materials** = three draw calls: `NW_Paint` (swappable colour /
  finish, livery UV island layout: right side, left side, top, front, rear),
  `NW_Atlas` (every other opaque part on a 1024 px atlas: flat swatches +
  textured lamp / plate regions; albedo, ORM and emission images),
  `NW_Glass` (tinted, transparent). Godot swaps them for
  `diecast_paint`, `nitro_car_atlas` and `nitro_car_glass` shaders.
- Empties `wheel_FL`, `wheel_FR`, `wheel_RL`, `wheel_RR` at the hubs.
- Wheels are separate GLBs: origin at the hub, axle along +X, outer face +X,
  one atlas material (one draw call). Sizes in `game/assets/cars/wheels/wheels.json`.
- No logos, badges, creator names or registration numbers; plates are blank.
- While building, parts use logical material keys (`paint`, `chrome`,
  `black_satin`, `tex_headlight`, ...); `nwcf.finalize()` turns them into atlas
  UVs and the three runtime materials, and marks sharp edges by angle.
- Booleans use Blender's Manifold solver (the Exact solver left wheel-arch
  cutter pieces outside the body on one side in Blender 5.3).

## Compare with references

```
.venv/bin/python tools/car_factory/compare/camera_match.py tools/car_factory/compare/e30_keypoints.json out/cams.json
xvfb-run -s "-screen 0 1536x860x24" godot --path game --rendering-driver opengl3 --resolution 1536x860 \
    --script res://tests/car_camera_match_render.gd -- out/cams.json photo_02_front_drift out/render_photo_02_front_drift.png
(same with "grey" as 4th argument -> out/grey_photo_02_front_drift.png)
cd out && python ../tools/car_factory/compare/overlay.py /path/to/photos/
```

The camera of each photo is solved from hand-picked keypoints (lamps, grille,
hubs, windscreen corners, mirrors, tail lamps) by PnP over a focal-length sweep;
the RMS reprojection error says how well the model's proportions fit the photo.
Overlay sheets contain the reference photos: keep them out of this public repo.

Performance probe (relative numbers on a software renderer):
`xvfb-run ... --script res://tests/car_perf_probe.gd -- red blue e30`.
