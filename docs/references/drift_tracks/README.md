# Nitro Wheelz — visual references for procedural track worlds

**Status:** concept reference library complete and verified on 2026-11-20. **49 unique original PNG files.** These are *concept images / asset boards*, not native 3D meshes, models, textures for commercial redistribution, or proof of Godot implementation.

## Google Drive hosting (do not import >30 MB archives into Claude chat)

**Source:** [Nitro Wheelz Drive project folder](https://drive.google.com/drive/folders/1pvMDmAA1eh5SzHmvF9wCy1dKILA-Cjyb) under `colabcreatorstudio@gmail.com`; organized in `Visual References/<country>/<location>/{Visualizations,Assets}`. Google Drive is the byte host; GitHub tracks this index, the research and requirements. The files below were shared read-only with `karllondor@gmail.com`; if the folder itself is not browsable under that account, open these directly from **Shared with me**. Do not claim that the target account owns the folder.

### Claude-safe ZIP archives (all <19 MB)

| Region / group | Archive link | Files in archive |
| --- | --- | --- |
| Overview / global concept boards / index / manifest | [Overview](https://drive.google.com/file/d/1NPbubmIlljOsj3Fhi8O3qI5jgckwScrX/view?usp=drivesdk) | 13 |
| Ireland — Coastal Cliffs | [Irish Coast](https://drive.google.com/file/d/1IC5JpvU73kuhNicOGtinYuUPzhPOvE66/view?usp=drivesdk) | 5 |
| Japan — City Track | [Japan City](https://drive.google.com/file/d/1vNR07V0jHawuatYUgGP7hFr_nqxkxYRm/view?usp=drivesdk) | 4 |
| Japan — Sakura Circuit | [Sakura part 1](https://drive.google.com/file/d/1oJKDsl4AqHIBhpSiLUEW4_zmRYc9tXAc/view?usp=drivesdk), [part 2](https://drive.google.com/file/d/1vDtYkyvAUgm7K3RY69-ZZvL5x2Z3YvPm/view?usp=drivesdk) | 11 |
| Japan — Touge Mountain | [Touge part 1](https://drive.google.com/file/d/16NBQTMZwzvAT0w7B7F71RhhSA6kA3RfP/view?usp=drivesdk), [part 2](https://drive.google.com/file/d/1Qg3YD2ptZwodoN_Up0FQ0aEPFMb7Dx3T/view?usp=drivesdk) | 11 |
| Japan — General architecture | [Japan overview](https://drive.google.com/file/d/1yyBPAXGW4Dr7o537fkhMeze5FlbveMor/view?usp=drivesdk) | 2 |
| Poland — Ojców Canyon / Golden Autumn | [Ojców part 1](https://drive.google.com/file/d/1Ve_vHNcKkM75_TNFfWdB8DBX0P8jxpdO/view?usp=drivesdk), [part 2](https://drive.google.com/file/d/1XMCYGmGs9vzdV_lKZZ159Zng93jJoQHu/view?usp=drivesdk) | 6 |
| Poland — Tatry Mountain | [Tatry](https://drive.google.com/file/d/16SZdrX5QvLVdl7KVEDjRwOlDhVC8mB1e/view?usp=drivesdk) | 4 |
| Wales — Welsh Highlands (future reference only) | [Wales](https://drive.google.com/file/d/1Zsn3o0S4crD5oUpXzUG-NUVju6CpA--N/view?usp=drivesdk) | 1 |

[Drive pack manifest JSON](https://drive.google.com/file/d/1b1vi25Zi4qhAOTNejn_CFNCEEQ05s1aw/view?usp=drivesdk) — full ZIP membership. [49-image SHA-256 manifest](https://drive.google.com/file/d/10fosN0gMV5Eir-xENkh7HmpRNZp0-9Wf/view?usp=drivesdk) — verifies every PNG.

### Library inventory

- `japan`: **28 PNG** across `Sakura Circuit`, `Touge Mountain`, `City Track`, `Overview`.
- `poland`: **10 PNG** across `Ojcow Canyon` and `Tatry mountain`.
- `ireland`: **5 PNG** under `Coastal Cliffs`.
- `wales`: **1 PNG**, future reference only.
- `Overview`: **5 PNG** general/mixed world concepts and assets.
- Total: **49 unique PNG**, plus **6 JPG indexes**, `MANIFEST.csv`, `READ_ME_FIRST.txt`.

## How to use these in Claude Code

1. Read `docs/research/procedural_world/CLAUDE_MASTER_BUILD_BRIEF_2026-11-20.md` and `TERRAIN_FIRST_TOWNSCAPER_TRACK_BUILDER_SPEC.md` first.
2. Open the relevant 1–2 region ZIP files (<19 MB each), **not** all 152 MB in one chat attachment. Use the unpacked paths and SHA manifest to map references to regions.
3. Prefer exact region-specific `Visualizations` and `Assets` over global mixed boards. Some AI-generated board labels are stylized and potentially inaccurate; use written brief for correct regional geology, structures and safety.
4. Use images as visual art direction, create original, optimized in-engine assets and materials; do not present image cutouts as functional 3D assets.
5. Phase A adjacency/code was technically accepted, but roadside rows of generic houses were **artistically rejected**. Draw placement from terrain + functional venue zoning, not `road tile -> house`.
6. Track Builder must generate region terrain FIRST, then player draws on it, with appropriate full-width cliffside corridor availability, grade-aware 3D road geometry, closed loops and open courses, and 0/25/50/75/100% longitudinal-grade force tests in Developer Mode.

## Repository vs Drive

The 49 full-resolution PNG files are stored in Google Drive, **not in the Git repository**. This is deliberate: their combined ~153 MB size need not bloat the game's source tree. This file and the region indexes are the source-controlled pointers. The actual Godot procedural terrain generator has not been implemented by the image-library transfer; consult the master build spec for engineering acceptance criteria.
