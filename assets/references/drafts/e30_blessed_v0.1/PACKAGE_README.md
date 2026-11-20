# Nitro Wheelz | NIGHTRIDE Yellow E30 Blessed | Car Factory research package v0.1 (DRAFT)

Date: 2026-11-20. **Research only — not an approved car asset or a build update.**

## Source of truth and visual references
`references/user_photos/photo_01_front_three_quarter.jpg`, `photo_02_front_drift.jpg`, and `photo_03_rear_three_quarter.jpg` are user-provided real photographic references. The fourth image, `reference_04_stylized_side_illustration.jpg`, is **stylized illustration**, NOT a technically accurate side blueprint. It may exaggerate stance, tire dimensions or rear exhaust features.

No standalone orthographic 3D projection can be honestly derived from these image files without building and validating a consistent 3D shape. Do not invent dimensions or technical modifications from low resolution photos.

## Verified build history
- NIGHTRIDE describes a swap to BMW **M52B28 2.8L inline six** for their E30, explicitly in the Feb 2022 video `https://www.youtube.com/watch?v=SK-YDJgQ2Rg`.
- DAYRIDE published `FULL STORY OF NIGHTRIDE BMW E30`, describing the crash, new engine and restoration: `https://www.youtube.com/watch?v=qPHvtorDaLM`.
- NIGHTRIDE video Apr 2024 thanks GARAGISTIC for a package; **exact parts are not confirmed** by the textual source: `https://www.youtube.com/watch?v=sgvzl-l29bQ`.
- BMW factory 328i M52B28 193 PS / 280 Nm is a **reference**, not dyno data for this car: `https://www.adac.de/rund-ums-fahrzeug/autokatalog/marken-modelle/bmw/3er-reihe/e36/983365/`.
- Stock E30 geometry 4325 x 1645 x 1380 mm, wheelbase 2570 mm from owner manual mirror: `https://www.billswebspace.com/BMW%20E30%20Owner%20Manual%20%28325i-325is%29.pdf`; modified car width/height/track/weight **unknown**.

## Plausible but NOT CONFIRMED
- A third-party caption names Colin Star Shark 4H wheels and BC Racing True Rear coilovers: `https://www.tumgik.com/tag/meister%20L1`. Treat this only as a lead and check against precisely the right car / build phase.
- Community comments speculate about M3-style/M-Tech II-style bumper parts; not verified: `https://www.reddit.com/r/E30/comments/1kuv5ti`.
- Steering angle kit, LSD/welded differential, manual gearing, exact camber, wheel sizes, tires, mass and dyno output are NOT known. Do not assert them as true.
- NIGHTRIDE's 400 HP turbo E30 video describes **Arek's different vehicle**, not this project: `https://www.youtube.com/watch?v=h8EaLcFNM1A`.

## User-approved rules
Approved look must remain identical in garage and on track. If the approved original has an exposed engine / removed hood, preserve it everywhere. Never auto-close or auto-open the hood in a separate mode. For these yellow E30 photos, the hood appears fitted.

## Proposed wheel library and paint options
Keep `Signature Original` paint and wheels immutable as the authentic showcase, and store player custom color/finish/wheel choices separately. All swaps use same wheel pivot conventions, require clearance and offset checks, and default to cosmetic effects only. Tire compound/size performance changes, if ever, must be a separate gameplay tuning system.

## Test plan
1. User approves exact E30 era and target style from supplied photos.
2. Implement a single Blender-Python proof of concept, using dimensions + one high-quality clean 3/4 style reference and a consistent mesh.
3. Export same car to both garage and track; do not create artificial appearance differences.
4. Test original wheels first; then test one NW Deep Dish cosmetic rim swap with offset/clearance check.
5. Test original yellow vs an alternate paint preset; preserve original as reset default.
6. Handle audio/physics in a separate profile, keep Lada baseline frozen and compare on the same course.
