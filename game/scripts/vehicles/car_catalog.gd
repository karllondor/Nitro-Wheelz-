extends RefCounted
class_name NitroCarCatalog
## The selectable cars. A "variant" id is what the garage stores
## (user://nitro_garage.cfg) and passes to the race (nitro/car_variant).
## All cars share the same drive model for now (owner audit: keep physics);
## only looks, dimensions and the wall footprint differ.
const LADA = preload("res://scripts/vehicles/lada_lowpoly.gd")
const COUPE = preload("res://scripts/vehicles/coupe_lowpoly.gd")

const ORDER: Array[String] = ["red","white","blue"]
const CARS: Dictionary = {
    "red":{"name":"LADA 2106 DRIFT SPEC","paint":"RACING RED","short":"LADA • RED",
        "length":4.166,"wheelbase":2.424,"width":1.91,"note":"EXPOSED ENGINE"},
    "white":{"name":"LADA 2106 DRIFT SPEC","paint":"PEARL WHITE","short":"LADA • WHITE",
        "length":4.166,"wheelbase":2.424,"width":1.91,"note":"CLEAN HOOD"},
    "blue":{"name":"RYU-32 COUPE","paint":"DEEP BLUE","short":"RYU-32 • BLUE",
        "length":4.545,"wheelbase":2.615,"width":1.90,"note":"INLINE-SIX ITB • WING"},
}

static func valid(variant: String) -> String:
    return variant if CARS.has(variant) else "red"

static func info(variant: String) -> Dictionary:
    return CARS[valid(variant)]

## New car node for a variant (Lada red/white or the RYU-32 coupe).
static func make(variant: String) -> Node3D:
    var v: String = valid(variant)
    if v == "blue":
        return COUPE.new()
    var lada: NitroLadaLowPoly = LADA.new()
    lada.paint_variant = v
    return lada
