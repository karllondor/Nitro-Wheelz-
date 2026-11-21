# Car wheel library — standard (v0.1.31)

Wheels are separate GLBs shared by any factory car: `tools/car_factory/blender/build_wheels.py` builds them into
`game/assets/cars/wheels/`, and `wheels.json` is the runtime catalogue read by `car_cosmetics.gd` / `glb_car.gd`.

## 1. Conventions

| Item | Convention |
|---|---|
| origin | hub centre |
| rolling axis | Blender +X = Godot +X, **outer face towards +X**; the game turns left-side wheels by 180° |
| material | one `NW_Atlas` material (flat swatches) = one draw call per wheel |
| size | per design (`size` dict: TYRE_R, TYRE_W, RIM_R, FLANGE_R, HALF); recorded in wheels.json |
| scaling | the game scales a wheel by `model.wheel_radius_m / tyre_radius_m`, so a design can be fitted to another car |
| mounting | hub empty -> steer pivot (front) -> camber (cosmetic, from the model file) -> rolling wheel |
| tyre | shared lathe profile; sidewall heights scale between flange and tread (any rim size); shallow tread rings so rotation reads at speed |
| building one design | `build_wheels.py --only <id>[,<id>]` rebuilds only those files and merges wheels.json / the report, so existing wheels stay byte-identical |

## 2. Designs

| id | Name | Tyre r / width | Rim r | Tris | Used by | Confidence |
|---|---|---|---|---|---|---|
| `wheel_signature_e30` | SIGNATURE | 0.290 / 0.205 | 0.2032 (16 in) | 3 016 | E30 default | approximation: lip, dish and concave face from photos; face design, vent count NOT confirmed |
| `wheel_nw_deep_dish` | NW DEEP DISH | 0.290 / 0.205 | 0.2032 | 2 988 | E30 option | Nitro Wheelz original |
| `wheel_lada_5spoke` | LADA 5-SPOKE DISH | 0.295 / 0.235 | 0.2286 (18 in) | 2 522 | Lada RED | from the red sheet; spoke shape approximated |
| `wheel_lada_mesh` | LADA MESH | 0.295 / 0.235 | 0.2286 | 2 710 | Lada WHITE | from the white sheet; 16 x 2 spokes approximated |
| `wheel_ryu_5spoke` | RYU DEEP 5-SPOKE | 0.330 / 0.255 | 0.2540 (20 in look) | 2 522 | RYU-32 | from the CLEAN sheet; die-cast proportions |

## 3. Building blocks (what worked)

- **Step lip -> dish wall -> contact-shadow ring -> concave face**: a polished `rim_lip` step lip and conical dish wall
  catch the horizon reflection; a dark `rim_dark` ring where dish meets face gives depth without geometry.
- **Spokes with real depth**: spokes are prisms standing proud of a dark barrel face, so openings read as holes.
- **Vents as dark tunnels** (lathe into the face), not painted dots.
- **Centre**: domed cap + 4 or 5 nut lathes (6 segments).
- `_barrel()` adds the inner barrel, inner flange and a brake disc + caliper seen through the openings.
- Polished vs machined surfaces must differ in roughness: the atlas shader's horizon reflection sharpness follows
  roughness (mirror lip vs soft face).

## 4. Checks

`e30_factory_car_test` and `factory_models_test`: every wheel asset loads, the tyre's outer face stays inside the
catalog half width (with the model's scale), the tyre radius fits the arches.
