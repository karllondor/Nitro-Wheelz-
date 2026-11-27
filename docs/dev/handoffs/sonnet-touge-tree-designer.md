# SONNET — TOUGE-FIRST TREE DESIGNER + FOREST ASSET POLISH

**Owner directive (27 Nov 2026):** "Zlećmy to Sonnetowi na trasie Touge, niech je na razie przygotuje i poprawi." This supersedes the wider biome rollout in the earlier Forest Lab handoff. **First deliverable must work on the existing Touge map only.** Other regions continue using CLASSIC vegetation until separately approved.

**Status:** OWNER APPROVED FOR IMPLEMENTATION, NOT IMPLEMENTED. Do not present the concept image as existing in-game geometry. This is an execution brief for Claude Sonnet and requires a real Sonnet coding session; filing it here does NOT launch Sonnet.

## Source and visual design target

Use the owner-approved illustrated species reference in the conversation and source archive **`NITRO_WHEELZ_COMPLETE_FOREST_LAB_8_SPECIES.zip`** as the starting reference. The archive exists in ChatGPT, **not** GitHub. Ask the owner to attach it to Sonnet's coding session, or reproduce its procedural implementation in the repository. Inside are `nitro_tree_factory.gd`, `nitro_species_gallery.gd`, `nitro_forest_demo.gd`, `nitro_fly_camera.gd`, showroom scenes, smoke tests and reference art. The standalone code **has not passed Godot compilation or Android performance tests**; validate and improve instead of copying blindly.

Approved species (all 8): layered **pine**, narrow **fir**, white-bark **birch**, broad **oak**, pink-flowering **sakura**, red/orange **Japanese maple**, berry-bearing **rowan**, **shrubs**; visual spring/summer/autumn gold/orange/red palettes and NEAR/FAR geometries. Preserve distinct silhouettes, irregular branch structure, faceted opaque crown lobes, careful leaf/flower cluster detailing, but optimize for the game's stylized toy-diecast aesthetic. User explicitly wants better actual 3D meshes, as close to approved image as reasonable on mobile — NOT a painted flat billboard or a copy of the whole promotional scene.

## New core requirement: editable Tree Designer in Godot

Provide an **interactive runtime/in-editor debug Tree Designer** for *one currently selected species or preview instance* so owner can inspect and tune without repeatedly editing GDScript. An Inspector-driven `@tool` preview with immediate rebuild is acceptable for phase 1 if robust; a small debug panel inside the Forest Lab scene is preferable because owner uses a phone often. Required controls:
- Species select across all 8; NEAR/FAR view; orbit + zoom + inspect trunk/crown at close distance. Reuse fly camera in gallery.
- Height, trunk thickness, crown spread/height, canopy volume or cluster density, primary branch count (capped safely), tilt/variation seed, tint/saturation, season palette.
- Separate blossom density/color for sakura, berry density for rowan, white bark markings for birch, layered tier count for pine/fir where supported.
- Reset single tree to default, compare **ORIGINAL / EDITED** side by side, SAVE / LOAD named preset JSON under `user://` (no silent overwrite), select the preset to preview on Touge, and a safe revert to stock geometry.
- Edits should regenerate only the selected preview mesh/chunk, NOT re-instance entire forest every slider tick. Use finite ranges and avoid breaking LOD geometry.
- If time constrained, prioritize a useful MVP (species, height, crown spread/density, palette, seed, save/revert, fly/orbit) and log remaining controls as follow-up; don't ship decorative inert controls.

## Touge integration: experimental switch only

- New `CLASSIC / FOREST LAB` visual toggle for **Touge** only, optionally add low/medium/high density. Defaults to CLASSIC; preserve existing generated seeds, saved route identity, PB, scoring and physics. Don't change other biomes.
- Procedurally place species in sensible patches on Touge slopes: pine/fir backbone, mixed deciduous clusters, smaller maple/sakura accents, limited birch/oak/rowan and low shrubs/rocks. Season/palette can be designer-controlled without affecting the terrain seed or physics.
- Dense forest in midground and opposite hillside, but **preserve chase camera sightlines and scenic multi-level road/bridge views**, tight hairpin entrance visibility, track boundaries and camera collision.
- Precisely sample terrain heights/slope; exclude road surface, walls, start, bridges, over/under passes, water and future tunnel portals. No floating branches/roots, no forest growing inside track.
- Shared procedural mesh/resources by species/preset/LOD, opaque vertex-colour material; **chunked MultiMeshInstance3D** for culling. NEAR/FAR and mobile-safe shadow rules, no excessive alpha overdraw. Stronger density is conditional on benchmark, not assumed free.
- Do not touch already approved GAS hitbox, results panel, vehicle physics, scoring (#62), track management (#61) or CIRCUIT judged zones (#29).

## Mandatory quality gates

1. Compile/run Godot 4 with GL Compatibility; run factory tests for all 8 species, LODs, seasons; fix source errors.
2. Produce **actual Godot screenshots**: close-up of every species against a neutral background, seasonal variants, plus BEFORE/AFTER on the same seeded Touge with Top-down and Chase, both day and night. Distinguish in-engine captures from concept artwork.
3. Run same-device Android **CLASSIC versus FOREST LAB** tests with FPS median, p95 frame time, draw calls, memory, load time and short thermal/stutter test. Existing owner captures have isolated 23–26 FPS points; cannot assume spare GPU headroom.
4. Tune at least one dense Touge forest scene until owner sees meaningful improvement without material FPS regression and no visible plant pop-in / vegetation wind flicker (#20).
5. Verify presets load/revert, toggle is off by default, old saves still load identically, no generated bridge/road overlap, PC/Web safe.
6. Deliver a **draft PR**, exact commit SHA, Android review APK, before/after set, benchmark table, concise handoff, and 5-minute owner test steps. Do not merge to `main`.

**Branch:** continue work solely on `feat/sonnet-forest-lab`, created from verified PR #58 baseline. Check current HEAD, prior handoff `docs/dev/handoffs/sonnet-forest-lab-task.md` and current main/integration changes before implementation. If #62 scoring session is active, keep this forest work in a separate Sonnet session. Scope is **Touge pilot first**, no rollout elsewhere until owner QA.
