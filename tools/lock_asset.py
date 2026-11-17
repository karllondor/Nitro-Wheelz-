#!/usr/bin/env python3
"""Register immutable approved artwork with human-reviewed stable ID."""
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BASE = (ROOT / "assets/references/approved").resolve()
MANIFEST = ROOT / "assets/approved_assets.json"

def main():
    p = argparse.ArgumentParser(description="Register a NEW approved reference, never overwrite an old one.")
    p.add_argument("file", help="Path relative to project root, in assets/references/approved/")
    p.add_argument("--id", required=True, help="Unique owner-approved stable identifier")
    args = p.parse_args()
    src = (ROOT / args.file).resolve()
    if not src.is_file() or not src.is_relative_to(BASE) or src == BASE:
        p.error("Only real files under assets/references/approved can be locked")
    candidate = ROOT / args.file
    if candidate.is_symlink():
        p.error("Symlink not allowed")
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    relative = src.relative_to(ROOT).as_posix()
    if any(e["id"] == args.id or e["path"] == relative for e in data["assets"]):
        p.error("Already registered: create a new versioned file and unique ID")
    data["assets"].append({"id": args.id, "path": relative, "sha256": hashlib.sha256(src.read_bytes()).hexdigest()})
    MANIFEST.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print("APPROVED:", args.id, "->", relative)
    print("Commit asset + manifest via PR; automated hash alone does not prove owner approval.")

if __name__ == "__main__":
    main()

