#!/usr/bin/env python3
"""Optional Godot export wrapper. Refuses to claim a build without presets and templates."""
import argparse
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PRESETS = {"Windows":"Windows Desktop","Linux":"Linux","Web":"Web","Android":"Android"}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--platform", choices=PRESETS, required=True)
    parser.add_argument("--release", action="store_true", help="Request release rather than debug export")
    args = parser.parse_args()
    godot = os.getenv("GODOT_BIN","godot")
    presets = ROOT / "game/export_presets.cfg"
    if not presets.is_file():
        parser.error("No game/export_presets.cfg. Configure export templates, package names and signing locally first.")
    staging = ROOT / "builds/_staging" / args.platform
    staging.mkdir(parents=True,exist_ok=True)
    extension = {"Android":".apk","Windows":".exe","Linux":".x86_64","Web":".html"}[args.platform]
    output = staging / ("game" + extension)
    cmd = [godot,"--headless","--path",str(ROOT/"game"),
           "--export-release" if args.release else "--export-debug",
           PRESETS[args.platform],str(output)]
    print("EXPORT:", " ".join(cmd))
    result = subprocess.run(cmd)
    if result.returncode or not output.exists():
        print("FAIL: export failed or output absent; no artifact marked built",file=sys.stderr)
        raise SystemExit(result.returncode or 1)
    print("Exported, NOT installed/tested:",output)
    print("Next: python3 tools/package_release.py --platform",args.platform,"--input",staging)

if __name__ == "__main__":
    main()

