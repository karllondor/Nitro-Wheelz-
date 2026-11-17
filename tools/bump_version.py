#!/usr/bin/env python3
"""Atomic-ish SemVer bump for VERSION, project.json, Godot config/version."""
import argparse
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REGEX = re.compile(r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$")

def new_version(current, kind):
    match = REGEX.fullmatch(current)
    if not match:
        raise ValueError("VERSION is not MAJOR.MINOR.PATCH")
    major, minor, patch = map(int, match.groups())
    if kind == "major":
        return str(major+1) + ".0.0"
    if kind == "minor":
        return str(major) + "." + str(minor+1) + ".0"
    return str(major) + "." + str(minor) + "." + str(patch+1)

def main():
    p = argparse.ArgumentParser()
    p.add_argument("kind", choices=("patch", "minor", "major"))
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args()
    status = subprocess.run(["git", "status", "--porcelain"], cwd=ROOT, text=True, capture_output=True)
    if status.returncode or status.stdout.strip():
        p.error("Dirty/unavailable git working tree; abort")
    current = (ROOT / "VERSION").read_text(encoding="utf-8").strip()
    target = new_version(current, args.kind)
    metadata = ROOT / "project.json"
    data = json.loads(metadata.read_text(encoding="utf-8"))
    if data.get("game_version") != current:
        p.error("project.json and VERSION do not agree")
    conf = ROOT / "game/project.godot"
    src = conf.read_text(encoding="utf-8")
    old = 'config/version="' + current + '"'
    if src.count(old) != 1:
        p.error("Godot config/version missing or conflicting")
    print(current, "->", target, "(dry run)" if args.dry_run else "")
    if args.dry_run:
        return
    data["game_version"] = target
    (ROOT / "VERSION").write_text(target + "\n", encoding="utf-8")
    metadata.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    conf.write_text(src.replace(old, 'config/version="' + target + '"'), encoding="utf-8")
    print("Next: record the reason in CHANGELOG.md and commit the version bump.")

if __name__ == "__main__":
    main()

