extends RefCounted
class_name NitroTerrainCatalog
## Countries and terrain archetypes of the terrain-first Track Builder
## (owner master brief 2026-11-20). Country, archetype, terrain seed,
## scenery seed, light/weather and event mode are independent settings.
##
## Every archetype is data: relief recipe, max road grade (a generator
## target, not a universal law), ground palette, rock type, vegetation mix,
## water, venue rules and light. The generator code reads only this table.

const COUNTRIES: Array[String] = ["japan","poland","ireland"]
const COUNTRY_NAMES: Dictionary = {"japan":"JAPAN","poland":"POLAND","ireland":"IRELAND"}
const EVENT_MODES: Array[String] = ["practice","club","pro"]

# Ground palette keys: low grass, high grass, dirt / forest floor, rock,
# snow, seasonal tint (petals / leaves), shore.
const ARCHETYPES: Dictionary = {
    "jp_sakura":{"country":"japan","name":"SAKURA CIRCUIT","short":"SAKURA",
        "grade":0.03,"grade_hint":"0–3 %","relief":"rolling","sea":false,
        "ground":{"low":Color(0.42,0.60,0.27),"high":Color(0.33,0.50,0.24),"dirt":Color(0.42,0.34,0.25),
            "rock":Color(0.47,0.46,0.43),"snow":Color(0.95,0.95,0.97),"tint":Color(0.96,0.70,0.80),
            "shore":Color(0.66,0.62,0.50)},
        "rock_kind":"mossy","tint_mask":"petals",
        "trees":{"sakura":0.46,"pine_jp":0.22,"cedar":0.32},"forest":0.55,
        "landmarks":["village_jp"],"venue":"paddock_jp",
        "sky":{"top":Color(0.36,0.58,0.88),"horizon":Color(0.86,0.84,0.86),"sun":Color(1.0,0.93,0.82),
            "energy":1.25,"sun_angle":Vector2(-48.0,40.0),"fog":Color(0.86,0.82,0.86),"fog_density":0.0009,"ambient":0.62},
        "desc":"Spring hills, sakura and Japanese pine, distant village, small paddock."},
    "jp_forest":{"country":"japan","name":"FOREST DRIFT PARK","short":"FOREST",
        "grade":0.04,"grade_hint":"0–4 %","relief":"terraced","sea":false,
        "ground":{"low":Color(0.36,0.50,0.22),"high":Color(0.30,0.43,0.20),"dirt":Color(0.48,0.36,0.24),
            "rock":Color(0.45,0.42,0.38),"snow":Color(0.95,0.95,0.97),"tint":Color(0.55,0.45,0.25),
            "shore":Color(0.60,0.55,0.45)},
        "rock_kind":"earth_cut","tint_mask":"none",
        "trees":{"cedar":0.52,"broadleaf_green":0.33,"pine_jp":0.15},"forest":0.78,
        "landmarks":[],"venue":"paddock_jp",
        "sky":{"top":Color(0.40,0.60,0.86),"horizon":Color(0.82,0.84,0.82),"sun":Color(1.0,0.90,0.74),
            "energy":1.2,"sun_angle":Vector2(-38.0,-60.0),"fog":Color(0.78,0.82,0.80),"fog_density":0.0012,"ambient":0.58},
        "desc":"Ebisu-type forested ridges, cut slopes, service roads, compact paddock."},
    "jp_touge":{"country":"japan","name":"TOUGE MOUNTAIN","short":"TOUGE",
        "grade":0.07,"grade_hint":"3–7 %","relief":"mountainside","sea":false,
        "ground":{"low":Color(0.34,0.47,0.22),"high":Color(0.29,0.39,0.20),"dirt":Color(0.45,0.36,0.27),
            "rock":Color(0.46,0.45,0.43),"snow":Color(0.95,0.95,0.97),"tint":Color(0.90,0.55,0.25),
            "shore":Color(0.55,0.52,0.45)},
        "rock_kind":"mossy","tint_mask":"none",
        "trees":{"cedar":0.55,"pine_jp":0.30,"broadleaf_green":0.15},"forest":0.82,
        "landmarks":["village_jp_small"],"venue":"touge_start",
        "sky":{"top":Color(0.42,0.56,0.84),"horizon":Color(0.96,0.80,0.62),"sun":Color(1.0,0.82,0.60),
            "energy":1.15,"sun_angle":Vector2(-22.0,80.0),"fog":Color(0.88,0.80,0.72),"fog_density":0.0011,"ambient":0.55},
        "desc":"Mountainside switchbacks, cedar forest, retaining walls, mirrors."},
    "jp_city":{"country":"japan","name":"CITY TRACK","short":"CITY",
        "grade":0.03,"grade_hint":"0–3 %","relief":"urban","sea":true,
        "ground":{"low":Color(0.40,0.40,0.42),"high":Color(0.36,0.36,0.38),"dirt":Color(0.30,0.30,0.32),
            "rock":Color(0.45,0.45,0.47),"snow":Color(0.95,0.95,0.97),"tint":Color(0.36,0.52,0.30),
            "shore":Color(0.50,0.50,0.52)},
        "rock_kind":"none","tint_mask":"parks",
        "trees":{"street_tree":0.70,"sakura":0.30},"forest":0.10,
        "landmarks":["expressway","skyline"],"venue":"city_pits",
        "sky":{"top":Color(0.26,0.38,0.66),"horizon":Color(0.92,0.78,0.66),"sun":Color(1.0,0.86,0.70),
            "energy":1.05,"sun_angle":Vector2(-26.0,-120.0),"fog":Color(0.78,0.72,0.70),"fog_density":0.0008,"ambient":0.58},
        "desc":"Closed street course between towers, shops and an elevated expressway."},
    "pl_ojcow":{"country":"poland","name":"OJCÓW CANYON","short":"OJCÓW",
        "grade":0.04,"grade_hint":"0–4 %","relief":"canyon","sea":false,
        "ground":{"low":Color(0.42,0.52,0.24),"high":Color(0.46,0.47,0.24),"dirt":Color(0.48,0.36,0.22),
            "rock":Color(0.86,0.84,0.78),"snow":Color(0.95,0.95,0.97),"tint":Color(0.86,0.56,0.16),
            "shore":Color(0.55,0.52,0.42)},
        "rock_kind":"limestone","tint_mask":"leaves",
        "trees":{"autumn_gold":0.40,"autumn_red":0.25,"autumn_orange":0.20,"pine_eu":0.15},"forest":0.66,
        "landmarks":["castle_rock"],"venue":"paddock_eu",
        "sky":{"top":Color(0.40,0.58,0.86),"horizon":Color(0.92,0.84,0.70),"sun":Color(1.0,0.86,0.62),
            "energy":1.2,"sun_angle":Vector2(-30.0,-50.0),"fog":Color(0.88,0.82,0.70),"fog_density":0.0010,"ambient":0.6},
        "desc":"Golden autumn valley, limestone outcrops, stream, castle on a rock in the distance."},
    "pl_tatry":{"country":"poland","name":"TATRY MOUNTAIN","short":"TATRY",
        "grade":0.06,"grade_hint":"2–6 %","relief":"alpine","sea":false,
        "ground":{"low":Color(0.36,0.52,0.27),"high":Color(0.44,0.50,0.32),"dirt":Color(0.44,0.38,0.30),
            "rock":Color(0.55,0.53,0.52),"snow":Color(0.94,0.95,0.98),"tint":Color(0.30,0.40,0.24),
            "shore":Color(0.50,0.50,0.48)},
        "rock_kind":"granite","tint_mask":"none",
        "trees":{"spruce":0.62,"dwarf_pine":0.38},"forest":0.50,
        "landmarks":["mountain_hut"],"venue":"paddock_eu",
        "sky":{"top":Color(0.34,0.50,0.80),"horizon":Color(0.80,0.84,0.88),"sun":Color(1.0,0.95,0.86),
            "energy":1.2,"sun_angle":Vector2(-34.0,30.0),"fog":Color(0.80,0.84,0.88),"fog_density":0.0014,"ambient":0.62},
        "desc":"High alpine slopes, granite peaks with snow, spruce and dwarf pine belts."},
    "ie_coast":{"country":"ireland","name":"COASTAL CLIFFS","short":"COAST",
        "grade":0.03,"grade_hint":"0–3 %","relief":"coast","sea":true,
        "ground":{"low":Color(0.36,0.56,0.26),"high":Color(0.40,0.54,0.30),"dirt":Color(0.42,0.36,0.28),
            "rock":Color(0.36,0.36,0.38),"snow":Color(0.95,0.95,0.97),"tint":Color(0.55,0.40,0.55),
            "shore":Color(0.42,0.42,0.40)},
        "rock_kind":"basalt","tint_mask":"heather",
        "trees":{"gorse":0.55,"windswept":0.45},"forest":0.12,
        "landmarks":["lighthouse","castle_ruin"],"venue":"paddock_ie",
        "sky":{"top":Color(0.46,0.56,0.70),"horizon":Color(0.80,0.84,0.86),"sun":Color(0.96,0.94,0.90),
            "energy":1.05,"sun_angle":Vector2(-28.0,-140.0),"fog":Color(0.78,0.82,0.86),"fog_density":0.0016,"ambient":0.7},
        "desc":"Atlantic cliffs and sea, heather, stone walls, lighthouse and ruins far away."},
    "ie_hills":{"country":"ireland","name":"GREEN HILLS","short":"HILLS",
        "grade":0.04,"grade_hint":"0–4 %","relief":"hills","sea":true,
        "ground":{"low":Color(0.34,0.60,0.26),"high":Color(0.30,0.52,0.24),"dirt":Color(0.42,0.36,0.28),
            "rock":Color(0.48,0.48,0.46),"snow":Color(0.95,0.95,0.97),"tint":Color(0.60,0.58,0.22),
            "shore":Color(0.60,0.58,0.50)},
        "rock_kind":"basalt","tint_mask":"fields",
        "trees":{"oak":0.55,"hawthorn":0.45},"forest":0.18,
        "landmarks":["castle_ruin"],"venue":"paddock_ie",
        "sky":{"top":Color(0.38,0.52,0.78),"horizon":Color(0.86,0.88,0.90),"sun":Color(1.0,0.94,0.84),
            "energy":1.25,"sun_angle":Vector2(-40.0,-30.0),"fog":Color(0.82,0.86,0.88),"fog_density":0.0011,"ambient":0.62},
        "desc":"Rolling pasture, hedgerows and stone walls, rocky cuttings, distant coast."},
}

const ORDER: Array[String] = ["jp_sakura","jp_forest","jp_touge","jp_city","pl_ojcow","pl_tatry","ie_coast","ie_hills"]

static func of_country(country: String) -> Array[String]:
    var out: Array[String] = []
    for key in ORDER:
        if str(ARCHETYPES[key]["country"]) == country:
            out.append(key)
    return out

static func info(archetype: String) -> Dictionary:
    return ARCHETYPES.get(archetype,ARCHETYPES["jp_sakura"])

static func valid(archetype: String) -> String:
    return archetype if ARCHETYPES.has(archetype) else "jp_sakura"

static func descriptor(archetype: String, terrain_seed: int, scenery_seed: int = -1,
        event_mode: String = "club") -> Dictionary:
    var a: String = valid(archetype)
    return {"kind":"terrain","version":1,"country":str(ARCHETYPES[a]["country"]),"archetype":a,
        "terrain_seed":terrain_seed,"scenery_seed":terrain_seed if scenery_seed < 0 else scenery_seed,
        "event_mode":event_mode if EVENT_MODES.has(event_mode) else "club","light_weather":"default"}
