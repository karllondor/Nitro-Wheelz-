# Nitro Wheelz Car Factory — standard (v0.1.31)

How every car in Nitro Wheelz is made, from references to the phone. Written from what was actually used for the
E30 Blessed (v0.1.24 – v0.3), the Lada 2106 RED / WHITE (stage 2) and the RYU-32 CLEAN / LIVERY (stage 3).
Companion documents: CAR_REFERENCE_PACKAGE_STANDARD.md, CAR_MATERIALS_AND_PAINT.md, CAR_WHEEL_LIBRARY.md,
CAR_QUALITY_CHECKLIST.md.

## 1. Rules

1. **One car = one model.** The same GLB, geometry and details in the garage and the race. No LOD variants, nothing
   hidden while driving. Paint, wheels and livery are swappable; geometry is not swapped per mode.
2. **Gameplay is data and is never touched by a model change.** Handling, engine sound, scoring, collisions (catalog
   length / width), controls and saves live in `game/cars/*.json` and `car_catalog.gd`; a model must fit inside the
   catalog footprint and keep the catalog wheelbase.
3. **Each car keeps its own silhouette.** Shared helpers are fine; a shared body is not (Lada, E30 and RYU-32 each
   have their own build script and proportions).
4. **Separate, revertable commits** per car / stage. `git revert <commit>` must restore the previous car.
5. **Not approved until the owner looks at it on the phone.** New models of cars that already have an approved model
   ship as TEST models behind DEVELOPER > CAR FACTORY TEST MODELS (default OFF). Automated tests and CI builds never
   count as visual acceptance.
6. **No logos, badges, plates or third-party art** in the repository (see docs/LICENSE_AND_SOURCES.md).

## 2. Pipeline

```
references (owner) -> measurements table -> tools/car_factory/blender/build_<car>.py (bpy, numbers only)
   -> GLB + build report (tris, bounds, pivots, variant triangles)
   -> godot --import -> NitroGlbCar (glb_car.gd) via car_catalog.gd + game/cars/models/<car>.json
   -> tests (budget, footprint, materials, variants, gameplay untouched)
   -> capture_car_views.gd (same cameras BEFORE / AFTER, close-ups, orthographic, garage, race)
   -> report docs/car_factory/<CAR>.md -> commit -> CI (Android, Web, desktop) -> owner review on the phone
```
Tools: Blender Python module `bpy` 5.3.0 (no Blender UI needed), Godot 4.7.2 GL Compatibility, Pillow for textures
and sheets, Xvfb + llvmpipe for renders in CI-like containers.

## 3. Coordinates and GLB conventions (nwcf.py)

| Item | Convention |
|---|---|
| units | metres |
| Blender axes | +Y = forward (nose), +Z = up, +X = right; exported Y-up: Godot forward = -Z, right = +X |
| origin | body centre in plan (catalog footprint centred), ground at z = 0 |
| body object | one mesh, three materials: `NW_Paint` (swappable colour, livery UV), `NW_Atlas` (every other opaque part, one atlas texture), `NW_Glass` |
| wheel hubs | empties `wheel_FL`, `wheel_FR`, `wheel_RL`, `wheel_RR` at the hub centres; wheels are separate GLBs |
| logical materials | parts are built with keys (`paint`, `glass`, `chrome`, `rubber`, `tex_headlight` ...); `nwcf.finalize()` maps them to the three runtime materials and atlas UVs, and sets sharp edges by angle (38°) |
| geometry variants | `nwcf.tag_variant(obj, slot)` writes TEXCOORD_1 (Godot UV2.x): 0 shared, n = only variant slot n; the car shaders collapse other slots (Lada RED = 1, WHITE = 2) |
| looks without geometry change | paint material only: colour / finish / per-variant shading / livery texture (RYU-32 CLEAN / LIVERY) |
| model data | `game/cars/models/<car>.json`: glb, wheel radius, camber (cosmetic), shadow size, per-variant slot, paint, wheels, paint_shader overrides, looks |

## 4. Budgets (per visible car, measured in Godot)

| | Budget | E30 v0.3 | Lada RED / WHITE | RYU-32 |
|---|---|---|---|---|
| triangles incl. 4 wheels + shadow | ≤ 42 000 | 41 502 | 37 510 / 31 444 | 38 550 |
| draw calls | ≤ 8 (paint, atlas, glass, 4 wheels, shadow) | 8 | 8 | 8 |
| body GLB | about 1–1.6 MB | 1.05 MB | 1.60 MB (both variants) | 1.18 MB |
Raise a budget only with the owner's consent. Pay for detail by trading invisible geometry (tube sides, planar glass
rows, lathe segments) for visible detail.

## 5. Building a body (what worked)

- **Lofted sections:** the lower body is one closed loft of `section(y)` polylines (same point count at every
  station, denser stations at the ends); special points (bonnet shut line) sit at fixed indices so openings follow
  the grid exactly.
- **Booleans with Blender's Manifold solver** on closed inputs: wheel-arch cylinders (their inner faces become the
  wheel wells, material transfer `well`), a cabin cavity box, window prisms through the solidified greenhouse.
  Delete cutter leftovers outside the outline afterwards.
- **Greenhouse:** an open loft from belt to belt, solidified 22 mm, window openings cut with prisms; glass is a
  separate inset grid; seals / frames are `strip()` ribbons on the surface.
- **Open bonnet:** delete the bonnet faces of the shell by their grid rectangle and add an engine bay (inner wings,
  firewall, slam panel, dark floor) + engine; a closed bonnet variant is a grid over the same rectangle.
- **Bumpers / kits as profile tables** `(reach, height fraction)` lofted along a U-shaped plan path; front and rear
  share the loft code.
- **Flares** as a lofted band between an outer ellipse on the body and a lip ellipse, with a rolled liner.
- **Validation in the script:** the build fails if any vertex leaves the car outline (catalog length / width,
  ground, roof).

## 6. Integration in the game

- `car_catalog.gd`: factory cars (`"factory": true`, e.g. E30) or test models of existing cars (`"factory_model"`
  path, shown only with the DEVELOPER switch). `CARS.make(variant)` builds the same node for the garage and the race.
- `glb_car.gd` (NitroGlbCar): converts the three materials to the Nitro shaders, sets `variant_slot`, mounts wheels
  (steer pivot -> camber -> rolling wheel), contact shadow, `set_motion()`.
- The garage fits its lens to the real silhouette of whatever car it shows (v0.3 framing); no per-car zoom constants.

## 7. Versioning and reports

Every test build gets a new version (`VERSION`, `project.json`, `project.godot`, export presets, workflow artefact
names). Each car stage has a report in docs/car_factory/ with: sources and confidence, decisions, measurements,
verification table (PASS / FAIL / NOT RUN), BEFORE / AFTER sheets, remaining differences and unconfirmed details,
rebuild commands.
