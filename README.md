# Karll Game Starter

**Version 0.1.0 — reusable AI-assisted game production foundation**

Game-agnostic production rules + **Godot 4.7.2** playable starter shell for Claude, Codex, Blender, REA, PC, Android and Xbox Wireless Controller.

## Game generated from this template
NEW_GAME_NAME

## Create a game
1. On GitHub choose **Use this template** and create the new game's repo.
2. Clone it, run python3 tools/initialize.py --name "Your Game" --dry-run, then repeat without --dry-run.
3. Edit PROJECT_BRIEF.md and project.json; game/project.godot remains authoritative for engine settings.
4. Run python3 tools/doctor.py; python3 tools/check_project.py; python3 -m unittest discover -s tests.
5. Open game/project.godot in Godot 4.7.2, then run the sample menu and input monitor.
6. Run bash tools/run_godot_checks.sh when the pinned Godot binary is available.
7. Complete hardware QA before claiming Xbox USB/Bluetooth, Android or desktop exports work.
8. Use agent/* branches/worktrees and keep HANDOFF.md current.

## Implemented foundation
- Godot menu + moveable test object + prototype touchscreen controls + Xbox/keyboard raw-input monitor.
- InputMap with left stick/WASD, A/Space, X/E, Start/Escape, built-in ui_* menu actions.
- Python tools: structural validator, approved-art registry with trusted-base comparison, safe setup, version bump, environment doctor, build stamp, immutable release packaging, evidence logger.
- CI: Python structural/negative-control tests, pinned Godot import and scene/input smoke checks; manual source artifact workflow.
- Production contracts: approved assets, Blender/sprites, REA, QA evidence, rollback, versions, agent isolation, device testing, performance and licensing.

## Explicit limitations
The source is not a finished game. No physical Xbox pad, Windows computer, Android phone or signed app build has yet been tested in this authoring environment. GitHub CI may validate Godot import/smoke, but that is not hardware QA. Runtime export presets and platform signing credentials must be configured for each new game. Optional modules are not forced onto every genre.

## Architecture
The shared policies in AGENTS.md, docs/ and tools/ are engine-neutral. The game/ folder is a minimal Godot adapter. Production profile in project.json is a workflow choice, not a full genre engine.

## Version and assets
Starter version and new game's version are tracked separately in project.json. Immutable packages are named Game-Slug_vMAJOR.MINOR.PATCH_Platform. Locked art is in assets/approved_assets.json; PR CI compares its entries to origin/main. Never reuse a released artifact name.

## Source license
No general redistribution license assigned; public repository visibility is not a reuse license. Choose a code license and a separate art license before distributing.

