#!/usr/bin/env python3
"""Show installed tools and engine mismatch without pretending missing tools exist."""
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EXPECTED = (ROOT / ".godot-version").read_text(encoding="utf-8").strip()
TOOLS = [("python3", "required"), ("git", "required"),
         ("godot", "Godot project only"), ("blender", "3D profile"),
         ("adb", "Android hardware"), ("java", "Android export"),
         ("tmux", "optional agent session"), ("ffmpeg", "optional recordings")]
print("Pinned Godot:", EXPECTED)
for name, usage in TOOLS:
    path = shutil.which(name)
    print(("%-9s" % name), ("FOUND " + path if path else "MISSING"), "["+usage+"]")
    if name == "godot" and path:
        try:
            version = subprocess.run([path, "--version"], capture_output=True, text=True, timeout=10).stdout.strip()
            print("          version:", version)
            if not version.startswith(EXPECTED.replace("-stable", ".stable")):
                print("          WARNING: different engine version from pin")
        except (OSError, subprocess.TimeoutExpired) as exc:
            print("          ERROR:", exc)
print("Check Bluetooth pad mapping on actual target device; this check never tests hardware.")

