# Asset production pipeline

Reference → draft → human approval → stable asset ID → source file → runtime derivative → inspect in engine.
Use Blender for modeling and keep .blend source separate from .glb/.gltf generated assets. Specify metres, forward-axis, origin/pivot, scale, textures, LOD and collision; export one reproducible variant before bulk work.

Sprite sheets: fixed cell size, alpha, consistent pivot, documented frame events and durations; check first/middle/last and full in-game motion, not just individual stills. Never silently regenerate unrelated approved characters. Check that light/shadow isn't baked into sprites when it belongs in game lighting.

Approved references are versioned, source-attributed, checksum protected. No license = no assumption of rights.

