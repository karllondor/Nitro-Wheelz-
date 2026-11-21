# Lada 2106 Drift Spec — Car Factory migration (stage 2, test build v0.1.30)

Owner brief, section 11, stage 2: move the RED and WHITE Lada to the Blender -> GLB pipeline, keep the proportions,
lamps, grille, bumpers, arches, lowered stance and wheels, Premium Die-Cast materials, handling and engine sound
unchanged; one model with variants if both share the body.
**Status: TEST MODEL, NOT APPROVED.** The approved procedural Lada (`lada_lowpoly.gd`) stays the default. The new model
is shown only with **DEVELOPER > CAR FACTORY TEST MODELS: ON** (main menu > DEVELOPER); switching it off restores the
old model at once. Looks only: handling, sound, collisions, scoring and saves never change.

## Decision: one GLB, two geometry variants

RED and WHITE share the same sedan body (shell, greenhouse, doors, glass, interior). They differ in parts: bonnet
(open bay with the engine vs closed bonnet), front (quad round lamps + chrome grille vs rectangular lamps + black
grille), bumpers (chrome vs colour-keyed), arches (bolt-on overfenders vs rolled flares), trim (chrome window frames,
belt moulding, handles, mirrors vs black seals and clean sides + skirts), tail lamps, exhaust and ducktail.

So the factory builds **one** GLB (`game/assets/cars/lada_2106/lada_2106.glb`) and tags every part with a
**variant mask** (`nwcf.tag_variant`): TEXCOORD_1 / Godot UV2.x = 0 shared, 1 RED only, 2 WHITE only. The three car
shaders (paint / atlas / glass) collapse the faces of the other variant in `vertex()`. Result: one GLB, one mesh,
three body materials, the same draw calls as the E30, no LOD and nothing hidden while driving. The same mechanism is
ready for the RYU-32 CLEAN / LIVERY variants.

## Sources

Only the two approved Nitro Wheelz concept sheets from the owner (red "LADA 2106 DRIFT SPEC" and the pearl-white sheet;
side, front and rear views scaled to the gameplay length). They are kept out of the repository; the sheet-vs-render
comparison was reviewed in the session. No logos, badges or plates (the red grille emblem is a blank chrome tab).

| Value | Source | Value used |
|---|---|---|
| length, wheelbase, width over the arches | gameplay catalog (collisions) | 4.166 / 2.424 / 1.91 m (exact) |
| stock shell width | VAZ-2106 reference | 1.611 m |
| roof / belt / bonnet front -> cowl | red sheet side + front views | 1.34 / 0.83 / 0.70 -> 0.81 m |
| overhangs | red sheet side view, scaled to 4.166 / 2.424 | front 0.68, rear 1.06 m (the old model had 0.87 / 0.87) |
| tyre radius | both sheets (about 0.29-0.30 m) | 0.295 m (the old model used an exaggerated 0.39 m) |
| quad lamps | red front view | centres +/-0.47 / +/-0.665 m, z 0.54, r 0.076-0.080 |
| grille, indicators, chrome bumper | red front view | grille 0.71 x 0.24 m; indicators z 0.37; bumper z 0.215-0.33 |
| tail lamps (2 x 2, inner = reverse) | red rear view | x 0.36-0.75, z 0.40-0.585 |
| rectangular lamps, black grille, raised bonnet centre | white front view | lamps x 0.42-0.77, z 0.43-0.61 |
| colours | sampled from the sheets | RED #B20C22 solid (sheet #AE0E23 / #BF0A21); WHITE #EEEDF1 pearl (the sheet's lavender is studio light) |

## Measurements (Godot, per variant = what the player sees)

| | old procedural RED / WHITE | factory RED | factory WHITE |
|---|---|---|---|
| visible triangles incl. 4 wheels + shadow | (procedural, see audit) | 37 510 | 31 444 |
| triangles in the shared GLB mesh (both variants) | — | 36 068 body | 36 068 body |
| draw calls | many surfaces per car | 8 (paint, atlas, glass + 4 wheels + shadow) | 8 |
| body GLB | — | 1.60 MB (one file for both) | same file |
| wheels | procedural | `wheel_lada_5spoke` 2 522 tris, 98 KB | `wheel_lada_mesh` 2 710 tris, 118 KB |
| visible bounds (L x W x H) | 4.166 x 1.91 x 1.45 | 4.166 x 1.91 x 1.334 | 4.166 x 1.90 x 1.334 |
| handling / sound / collisions | lada_baseline | identical (test) | identical (test) |

Budget: 42 000 triangles and 8 draw calls (the E30 standard) held for both variants.

## Verification

| Check | Result |
|---|---|
| `tests/factory_models_test.gd`: switch OFF = procedural Lada; ON = one GLB with slots 1 / 2, own paint + wheels, 3 body materials with `variant_slot`, faces of the other variant masked, budget per variant, length / width / wheelbase vs catalog, tyres inside the arches, handling identical on / off, garage shows and labels the test model, no PAINT / WHEELS menu for the Lada | PASS (local) |
| `car_profiles_test` (Lada baseline physics bit-identical), full suite | see QA_MATRIX v0.1.30 |
| BEFORE / AFTER from identical garage cameras: front 3/4, rear 3/4, left, right, front, rear, top | `lada_2106/lada_{red,white}_views_before_after.jpg` |
| garage screen, race top-down, race chase, BEFORE / AFTER | `lada_2106/lada_{red,white}_garage_race_before_after.jpg` |
| close-ups: bonnet, A-pillar, grille + lamps, wheel, rear bumper, tail lamp | `lada_2106/lada_{red,white}_closeups.jpg` |
| phone look, frame time | NOT RUN — owner |

## Still different from the sheets / unconfirmed

- The sheets are concept renders, not measurements: every position above is a scaled estimate (+/- 2-3 cm).
- RED overfenders: the sheet shows a bulkier, more faceted flare; ours is a 14-facet smooth overfender limited by the
  1.91 m gameplay width and the chrome line above it.
- The engine is a stylised VAZ inline four with 4 ITB trumpets (as on the sheet); intake, wiring and hoses simplified.
- Wheel spoke shapes / mesh spoke count and offsets are approximations of the sheet images.
- Glass is the shared dark tint (both sheets show dark glass); the cabin is simple (seats, dash, wheel, door cards).
- The old model's proportions (taller body, 0.39 m wheels, symmetric overhangs) are intentionally NOT kept: the brief
  asks for the approved sheets' proportions, and the gameplay footprint is unchanged.

## Rebuild

```
python tools/car_factory/blender/build_lada_2106.py --out game/assets/cars/lada_2106
python tools/car_factory/blender/build_wheels.py --only wheel_lada_5spoke,wheel_lada_mesh
godot --headless --path game --editor --import
xvfb-run ... --script res://tests/capture_car_views.gd -- <out> red race factory
```
Model data (paint, wheels, slot, per-variant paint shading): `game/cars/models/lada_2106.json`.
