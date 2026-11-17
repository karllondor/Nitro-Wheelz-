# Technical baseline

Godot 4.7.2-stable is the pinned initial adapter. .godot-version and game/project.godot must agree. Non-Godot projects reuse the shared agent, art, version, QA and release policies and replace game/ with the appropriate engine adapter.

Renderer default: GL Compatibility for widest low-end/mobile reach; choose Vulkan deliberately after benchmarking. Base render 1280x720 landscape; per-game settings can differ. 60 Hz physics baseline; profile changes require tests.

Repository profile from project.json is descriptive, not an implemented engine. Pick quick-2d, cinematic-2.5d, or 3d-production. Mechanics depend on the game rather than on template.

