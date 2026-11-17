"""Run inside Blender: blender --background file.blend --python tools/blender_validate.py"""
try:
    import bpy
except ImportError:
    raise SystemExit("BLOCKED: run from Blender's Python environment")
from pathlib import Path

objects=[o for o in bpy.data.objects if o.type=="MESH"]
print("BLENDER FILE:",bpy.data.filepath or "(unsaved)")
print("Scene units:",bpy.context.scene.unit_settings.system)
print("Mesh objects:",len(objects))
for o in objects:
    print("MESH",o.name,"verts",len(o.data.vertices),"scale",tuple(round(s,4) for s in o.scale))
    if any(abs(s)<0.0001 for s in o.scale):
        print("WARNING: near-zero transform scale",o.name)
print("NOTE: visual/UV/rig/collision/export approval still requires manual review")

