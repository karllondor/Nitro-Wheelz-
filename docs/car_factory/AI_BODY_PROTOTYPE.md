# AI-generated body prototype — "RYU-32 FLAME (AI TEST)" (v0.1.33)

Owner request: try a body generated with an image-to-3D service ("Sky R32", flame livery) in the game, as a separate
car, with the black bonnet vent removed. **TEST ONLY — NOT FOR RELEASE.**

## Licence status (read first)
- The mesh and textures were generated on the service's **free plan** (non-commercial). The owner accepted using them in
  this private test project and will buy the paid plan only if the approach proves worthwhile.
- The texture contains an invented sponsor text and a fake plate. Before any release: regenerate under a paid plan,
  remove all text / plates / marks, and clear the real-car likeness question (see the car notes in
  docs/LICENSE_AND_SOURCES.md).

## What the pipeline does (`tools/car_factory/blender/import_ai_car.py`)
1. Import the GLB (one closed solid, 39 984 triangles, 3 textures of 2048²), turn the nose to +Y.
2. Fit to the catalog footprint with a non-uniform scale (length 4.545 / width 1.90 / height 1.29 m; x 85 %, z 94 % of
   the length scale). The generated proportions already matched the reference sheet (wheelbase 2.604 vs 2.615 m).
3. Weld by position (UVs are per loop, so seams stay), drop three floating fragments, check it is a manifold solid.
4. Find the axles from the tyre bottoms; wheelbase set to the catalog 2.615 m.
5. Delete the fused tyres (face centres inside the tyre cylinders) and close the holes with dark liners (tube + disc),
   UV on a black texel patch written into the textures. Blender's exact boolean left whole cutter shells behind on this
   mesh, so the cut is done by hand.
6. `--hood-box`: the dark vent was painted into the texture. The faces inside the box have their UV triangles filled with
   the bonnet paint colour (median of the saturated texels in front of the box) and the same for the metallic-roughness
   map; the lumpy geometry under the vent is relaxed.
7. Metallic-roughness texture: roughness floor 0.30 and metal ceiling 0.25 (the service wrote mirror paint, which the car
   shader turned into a washed-out sky reflection).
8. `--decimate 0.95` to meet the budget. Textures are re-encoded with PIL as baseline JPEG (Blender's own JPEG export
   produced files Godot refused to decode); the normal map is dropped (the car shader does not use it).
9. Export with wheel_FL/FR/RL/RR hubs; the game mounts `wheel_ryu_5spoke` on them. One body material `NW_Atlas`.

## In the game
- Garage: fifth car **R32 • FLAME**. Always the GLB (no DEVELOPER switch). Drives exactly like the RYU-32: same
  handling profile, same 4.0 V8 ITB engine sound, same footprint (4.545 x 1.90 m, wheelbase 2.615 m).
- Paint and livery are baked into the texture: no PAINT / WHEELS choice.
- 41 371 triangles with wheels (budget 42 000), 6 draw calls. `factory_models_test` covers it.
- If the GLB is absent from a build the car falls back to the procedural RYU-32 coupe.

## Known flaws of the generated body (not fixed here)
- **Open roof:** the cabin interior and a roll cage are visible from above; the rear deck carries an invented black / white
  graphic. Fix: replace the roof with a modelled panel.
- Invented text ("Nike Wheelz"-like) on the sides and a fake plate.
- Closed bonnet (no V8 shown); the body is baked livery only (no CLEAN version from this mesh).
- A dark crescent above each tyre (wheel-well liner radius), a few grey specks left on the bonnet.
- Textures are chaotic UV islands; paint cannot be recoloured.

## Rebuild
```
python tools/car_factory/blender/import_ai_car.py -- --in Sky_r32.glb \
    --out game/assets/cars/ryu32_ai/ryu32_ai.glb --hood-box=-0.72,0.72,0.58,1.56 --decimate 0.95
godot --headless --path game --editor --import
```
The source GLB from the service is not stored in the repository.
