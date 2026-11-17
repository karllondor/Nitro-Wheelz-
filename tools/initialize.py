#!/usr/bin/env python3
"""One-time safe template initialization; no game asset overwrites."""
import argparse
import json
import re
import subprocess
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PLACEHOLDER = "NEW_GAME_NAME"

def safe_name(name):
    name = name.strip()
    if not 1 <= len(name) <= 72 or any(ord(x) < 32 or x in '"\\/<>{}' for x in name):
        raise ValueError("Invalid name: 1..72 chars, no control chars, quotes, slash, backslash or markup")
    return name

def slugify(name):
    normalized = unicodedata.normalize("NFKD", name)
    ascii_name = normalized.encode("ascii", "ignore").decode()
    slug = re.sub(r"[^a-z0-9]+", "-", ascii_name.lower()).strip("-")
    if not slug:
        raise ValueError("Name must include transliterable letters or digits for file names")
    return slug

def check_clean():
    proc = subprocess.run(["git", "status", "--porcelain"], cwd=ROOT, text=True, capture_output=True)
    if proc.returncode != 0 or proc.stdout.strip():
        raise ValueError("Git tree is dirty/unavailable; commit or stash before initialization")

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--name", required=True)
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args()
    try:
        name = safe_name(args.name)
        slug = slugify(name)
        check_clean()
        paths = [
            "README.md", "PROJECT_BRIEF.md",
            "game/project.godot", "game/scripts/boot.gd",
        ]
        changes = {}
        for item in paths:
            path = ROOT / item
            old = path.read_text(encoding="utf-8")
            if PLACEHOLDER not in old:
                raise ValueError("Template is already initialized or edited: " + item)
            changes[path] = old.replace(PLACEHOLDER, name)
        meta_path = ROOT / "project.json"
        meta = json.loads(meta_path.read_text(encoding="utf-8"))
        if meta.get("game_name") != PLACEHOLDER:
            raise ValueError("Project metadata already initialized")
        meta["game_name"], meta["game_slug"] = name, slug
        changes[meta_path] = json.dumps(meta, ensure_ascii=False, indent=2) + "\n"
        stamp_path = ROOT / "game/build_info.json"
        stamp = json.loads(stamp_path.read_text(encoding="utf-8"))
        stamp["name"] = name
        changes[stamp_path] = json.dumps(stamp, ensure_ascii=False, indent=2) + "\n"
    except (ValueError, OSError, json.JSONDecodeError) as e:
        p.error(str(e))
    print(("DRY RUN" if args.dry_run else "INITIALIZE") + ":", name, "slug:", slug)
    for path in changes:
        print(" ->", path.relative_to(ROOT))
    if not args.dry_run:
        for path, content in changes.items():
            path.write_text(content, encoding="utf-8")

if __name__ == "__main__":
    main()

