# Nitro Wheelz — visual references for procedural track worlds

**Status:** concept reference library complete and verified on 2026-11-20. **49 unique original PNG files.** These are *concept images / asset boards*, not native 3D meshes, models, textures for commercial redistribution, or proof of Godot implementation.

## Google Drive hosting (do not import >30 MB archives into Claude chat)

**Source:** [Nitro Wheelz Drive project folder](https://drive.google.com/drive/folders/1H7X-yXy61SczcEWz9ESTj5nYTSjmfwoo), **owned by `karllondor@gmail.com`**, with [Visual References](https://drive.google.com/drive/folders/1Rsah31rODprQKNlUzaC9RSe2GHX3SmVt) sorted by country/location and [12 Claude ZIP packs](https://drive.google.com/drive/folders/1Dtrh0Rm59azqvKqwoeJ41gsKkPGBrFBc). Google Drive hosts original image bytes; GitHub tracks this index and research.

**Access note:** The file-transfer connector cannot enable anonymous \"Anyone with the link\" access on a personal Google Drive. These are now on the correct owning account; until the owner selects Google Drive **Share → General access → Anyone with the link → Viewer** on the project folder, Claude CLI may still encounter login barriers. Do not claim public access has been verified.\n\n### Claude-safe ZIP archives (all <19 MB)

| Region / group | Archive link | Files in archive |
| --- | --- | --- |
| Overview / global concept boards / index / manifest | [Overview](https://drive.google.com/file/d/1s6VWcun-o0twqfpUv2WlXZSyLYq2bnWE/view?usp=drivesdk) | 13 |
| Ireland — Coastal Cliffs | [Irish Coast](https://drive.google.com/file/d/1E_qArS7Gecflf5mKsosvY628Fd1iygw9/view?usp=drivesdk) | 5 |
| Japan — City Track | [Japan City](https://drive.google.com/file/d/1ZhyvgkGxnlZUoJT3G_TTXPGc4d-YTetH/view?usp=drivesdk) | 4 |
| Japan — Sakura Circuit | [Sakura part 1](https://drive.google.com/file/d/1tXqNMQ-BR6JW-8Pt9RtDouZTjj8lwROk/view?usp=drivesdk), [part 2](https://drive.google.com/file/d/1E-yMycO4GRONYDpGbT_wc1jFFssKADTF/view?usp=drivesdk) | 11 |
| Japan — Touge Mountain | [Touge part 1](https://drive.google.com/file/d/1u_mrAKmeNeaWboVGZtNCewepn57gOApr/view?usp=drivesdk), [part 2](https://drive.google.com/file/d/19SJXLHHSZqTBNLmHkq67MVfEzAHANX63/view?usp=drivesdk) | 11 |
| Japan — General architecture | [Japan overview](https://drive.google.com/file/d/1nOm5qcrsL0JZliv6hd1ysPhQaJlZmKRf/view?usp=drivesdk) | 2 |
| Poland — Ojców Canyon / Golden Autumn | [Ojców part 1](https://drive.google.com/file/d/1eiKLNCVUgIAUjWq98zzVI62whDhZ3oxJ/view?usp=drivesdk), [part 2](https://drive.google.com/file/d/1H78o3psQMqdl0zDtbO7fVBI5evvuJfHD/view?usp=drivesdk) | 6 |
| Poland — Tatry Mountain | [Tatry](https://drive.google.com/file/d/1osMIWUkKZMuGzzDomLawYAynXekKYivY/view?usp=drivesdk) | 4 |
| Wales — Welsh Highlands (future reference only) | [Wales](https://drive.google.com/file/d/1JtAkWt9KilMszUofZIYoYbB1cBiXRUqZ/view?usp=drivesdk) | 1 |

[Drive pack manifest JSON](https://drive.google.com/file/d/1qfP80SblR5-H21Jbk0rFaVJf3Gef6a7B/view?usp=drivesdk) — full ZIP membership. [49-image SHA-256 manifest](MANIFEST.csv) — versioned in GitHub; original also stored in the new Drive `Visual References` folder.

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
