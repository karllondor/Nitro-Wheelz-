#!/usr/bin/env python3
"""Write truthful game build metadata before export."""
import argparse
import datetime
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def git(*args):
    p = subprocess.run(["git", *args], cwd=ROOT, text=True, capture_output=True)
    return p.stdout.strip() if p.returncode == 0 else "unknown"

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--allow-dirty", action="store_true")
    args = p.parse_args()
    status = git("status", "--porcelain")
    if status and not args.allow_dirty:
        p.error("Working tree has changes; commit before stamping (or --allow-dirty for local dev)")
    meta = json.loads((ROOT / "project.json").read_text(encoding="utf-8"))
    version = (ROOT / "VERSION").read_text(encoding="utf-8").strip()
    if version != meta.get("game_version"):
        p.error("version mismatch")
    info = {
        "name": meta["game_name"], "version": version,
        "git_sha": git("rev-parse", "--verify", "HEAD"),
        "built_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "dirty": bool(status), "platform_status": "not-tested"
    }
    (ROOT / "game/build_info.json").write_text(json.dumps(info, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(info, indent=2))

if __name__ == "__main__":
    main()

