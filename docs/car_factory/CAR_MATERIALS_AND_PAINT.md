# Car materials and paint — standard (v0.1.31)

Every factory car body uses exactly three runtime materials (three draw calls) plus one per wheel. The game converts
the GLB materials to Nitro shaders in `glb_car.gd`.

## 1. Runtime materials

| GLB material | Godot shader | Holds | Notes |
|---|---|---|---|
| `NW_Paint` | `nitro_car_paint.gdshader` | painted panels | colour / finish from the cosmetic choice or the model file; livery UV layout in UV |
| `NW_Atlas` | `nitro_car_atlas.gdshader` | every other opaque part | 1024² atlas: albedo, ORM (G roughness, B metallic), emission; double-sided |
| `NW_Glass` | `nitro_car_glass.gdshader` | glass | tinted, see-through (interior / cage visible), double-sided; glass is never darkened to hide a simple interior |
All three read UV2.x as the geometry-variant mask (`variant_slot` uniform, see CAR_FACTORY_STANDARD §3).

## 2. Atlas swatches and regions (nwcf.py)

- Flat swatches live in an 8 x 8 grid (lower-left quarter of the atlas): albedo, roughness, metallic, emission.
  The first 29 keys are sorted (E30 layout); **new keys are APPEND-ONLY** in `SWATCH_EXT`
  (`rim_white`, `rim_mesh`, `engine_black`, `alu_cast`, `red_part`, `radiator`, `header`, `blue_part`, `gold_part`,
  `white_lens`), so rebuilding an older car never moves its colours.
- Textured regions (`REGION`, append-only): headlights (round low / high beam), E30 tail lamp, plate, sidewall,
  Lada rectangular headlight, Lada WHITE tail lamp, RYU twin-projector headlight, RYU round tail lamp. Each car's
  `draw_regions(key, size)` paints the regions it uses (Pillow) and returns None for the others.
- Dark details that must read as openings (intakes, grille slots, exhaust cut-outs) use `gap` / `well` (near-black,
  rough), not `radiator` grey: the atlas shader's horizon reflection makes mid-rough dark greys look light grey.

## 3. Paint shader (Premium Die-Cast)

| Parameter | Default | Meaning |
|---|---|---|
| `paint`, `roughness`, `metallic`, `gloss`, `rim` | from the finish | `car_cosmetics.gd` FINISHES: solid, metallic, pearl |
| `body_shade` | 0.27 | how much darker vertical / lower panels get (shading from the car's own geometry) |
| `shade_tint` | warm (1.0, 0.94, 0.84) | tone of the shaded side (keeps yellow golden); **white paint needs a neutral tint** |
| `depth` | 0.24 | richer, darker colour at grazing angles |
| `coat`, `horizon`, `horizon_sharp` | 1.4 / 1.0 / 0.07 | clear coat: studio soft boxes + a world-space horizon reflection that follows the body's curvature |
| `livery_tex`, `livery_on` | none / 0 | RGBA livery texture over the paint (CLEAN = off) |
| `variant_slot` | 0 | geometry variant to show |

Rules learned:
- **Reflections, not brightness, sell the material.** Never brighten the scene or the albedo to fix a flat-looking
  car; sharpen / add reflections (v0.3 horizon reflection).
- **Measure colour before changing it** (HSV of reference vs render); the E30 "ochre" was a reflection problem, not a
  hue problem.
- **Per-variant shading overrides** go into the model file (`paint_shader`), e.g. Lada WHITE
  `{"body_shade": 0.15, "shade_tint": "#EEF0F7", "depth": 0.10}` — the default warm shade turned pearl white beige.

## 4. Livery UV layout

`nwcf.livery_uv()` box-projects every paint face by its dominant normal: right side (u along length rear -> front,
v 0.02–0.32), left side (u mirrored, v 0.34–0.64), top (u 0.02–0.68 along length, v 0.66–0.98 across), front island
(u 0.70–0.84), rear island (u 0.85–0.99). A livery is a 1024² RGBA PNG drawn in this layout (see
`build_ryu32.py draw_livery()`); transparent = paint colour. Keep liveries free of logos, text and numbers unless the
owner supplies licensed artwork.

## 5. Paints in use

| Car / look | Colour | Finish | Source |
|---|---|---|---|
| E30 Blessed | #EFBA0D Blessed Yellow (+ palette) | solid | sampled from photos, deepened in v0.2 |
| Lada RED | #B20C22 | solid | sampled from the red sheet |
| Lada WHITE | #EEEDF1 | pearl + neutral shading override | white sheet (lavender = studio light) |
| RYU-32 CLEAN | #1240C8 | metallic | sampled from the CLEAN sheet |
| RYU-32 LIVERY | same + provisional yellow / red livery | metallic | PROVISIONAL (no reference) |
