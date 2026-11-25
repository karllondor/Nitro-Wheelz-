"""Build a Park-only glTF reusing the production GLB vertex buffer and texture files."""
import base64
import copy
import json
import struct
from pathlib import Path

CARS = Path(__file__).resolve().parents[2] / "game/assets/cars"
source = CARS / "lada_2106/lada_2106.glb"
raw = source.read_bytes()
length = struct.unpack_from("<I", raw, 12)[0]
gltf = json.loads(raw[20:20 + length])
offset = 28 + length
binary = raw[offset:]


def read_accessor(index, fmt):
    accessor = gltf["accessors"][index]
    view = gltf["bufferViews"][accessor["bufferView"]]
    start = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
    stride = view.get("byteStride", struct.calcsize(fmt))
    return [struct.unpack_from(fmt, binary, start + i * stride) for i in range(accessor["count"])]


paint = next(p for p in gltf["meshes"][0]["primitives"]
             if gltf["materials"][p["material"]]["name"] == "NW_Paint")
xyz = read_accessor(paint["attributes"]["POSITION"], "<fff")
uv2 = read_accessor(paint["attributes"]["TEXCOORD_1"], "<ff")
assert gltf["accessors"][paint["indices"]]["componentType"] == 5123
indices = [v[0] for v in read_accessor(paint["indices"], "<H")]
# The authored white bumper lofts are disjoint paint components. Use the generating
# profile's exact vertical rings, side wraps and variant tag; exclude adjacent lamps/skirts.
parts = [[], [], []]
for i in range(0, len(indices), 3):
    tri = indices[i:i + 3]
    part = 0
    if all(uv2[k][0] == 2 for k in tri):
        if all(0.1188 <= xyz[k][1] <= 0.4062 and xyz[k][2] < -1.827 for k in tri):
            part = 1
        elif all(0.1590 <= xyz[k][1] <= 0.4010 and xyz[k][2] > 1.445 for k in tri):
            part = 2
    parts[part].extend(tri)
assert [len(group)//3 for group in parts[1:]] == [1260, 1080], "Review the new production topology"

# A glTF buffer can point at an arbitrary binary file. Address the BIN chunk within
# the original GLB so only the new triangle partition is stored in this asset.
gltf["buffers"][0] = {"uri": "../lada_2106/lada_2106.glb", "byteLength": len(raw)}
for view in gltf["bufferViews"]:
    view["byteOffset"] = view.get("byteOffset", 0) + offset
for image in gltf["images"]:
    image.pop("bufferView")
    image["uri"] = "../lada_2106/lada_2106_" + image["name"] + ".png"

extra = bytearray()
for i, group in enumerate(parts):
    extra.extend(bytes(-len(extra) % 4))
    view = {"buffer": 1, "byteOffset": len(extra), "byteLength": 2*len(group), "target": 34963}
    extra.extend(struct.pack(f"<{len(group)}H", *group))
    gltf["accessors"].append({"bufferView": len(gltf["bufferViews"]), "componentType": 5123,
                              "count": len(group), "type": "SCALAR", "min": [min(group)], "max": [max(group)]})
    gltf["bufferViews"].append(view)
    primitive = paint if i == 0 else copy.deepcopy(paint)
    primitive["indices"] = len(gltf["accessors"]) - 1
    if i:
        name = ["", "FrontBumper", "RearBumper"][i]
        gltf["scenes"][0]["nodes"].append(len(gltf["nodes"]))
        gltf["nodes"].append({"name": name, "mesh": len(gltf["meshes"])})
        gltf["meshes"].append({"name": name, "primitives": [primitive]})
gltf["buffers"].append({"byteLength": len(extra), "uri": "data:application/octet-stream;base64," +
                        base64.b64encode(extra).decode()})
(CARS/"park_damage/white_lada.gltf").write_text(json.dumps(gltf, separators=(",", ":"))+"\n")
