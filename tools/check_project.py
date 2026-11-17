#!/usr/bin/env python3
"""Structure, SemVer and protected-art integrity validation."""
import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APPROVED = Path("assets/references/approved")
MANIFEST = Path("assets/approved_assets.json")
REQUIRED = (
    "README.md", "AGENTS.md", "CLAUDE.md", "PROJECT_BRIEF.md",
    "VERSION", ".godot-version", "project.json", "HANDOFF.md",
    "CHANGELOG.md", "docs/ART_LOCK.md", "docs/QA_MATRIX.md",
    "docs/RELEASE_POLICY.md", "game/project.godot",
    "game/scenes/boot.tscn", "game/scenes/prototype.tscn",
    "game/scenes/dev/input_monitor.tscn", "game/scripts/boot.gd",
    "game/scripts/prototype.gd", "game/scripts/dev/input_monitor.gd",
    "game/tests/smoke_test.gd", "game/tests/input_test.gd", str(MANIFEST),
)
SEMVER = re.compile(r"^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$")
SHA256 = re.compile(r"^[0-9a-f]{64}$")

def read_manifest(path):
    raw = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(raw, dict) or raw.get("schema_version") != 1 or not isinstance(raw.get("assets"), list):
        raise ValueError("Manifest must be object with schema_version=1 and assets array")
    return raw["assets"]

def validate_assets(root, baseline=None):
    root = Path(root).resolve()
    errors, ids, paths = [], set(), set()
    directory = root / APPROVED
    try:
        entries = read_manifest(root / MANIFEST)
    except (ValueError, OSError, json.JSONDecodeError) as exc:
        return ["Manifest unreadable: " + str(exc)]
    for entry in entries:
        if not isinstance(entry, dict):
            errors.append("Manifest asset must be an object")
            continue
        if set(entry) != {"id", "path", "sha256"} or not all(isinstance(entry.get(k), str) for k in ("id", "path", "sha256")):
            errors.append("Manifest asset fields must be exactly id/path/sha256")
            continue
        ident, name, digest = entry["id"], entry["path"], entry["sha256"]
        rel = Path(name)
        if not ident.strip() or ident in ids:
            errors.append("Duplicate/empty approved asset ID: " + ident)
        ids.add(ident)
        if name in paths:
            errors.append("Duplicate approved asset path: " + name)
        paths.add(name)
        if rel.is_absolute() or ".." in rel.parts or not name.startswith(APPROVED.as_posix() + "/"):
            errors.append("Invalid approved path: " + name)
            continue
        location = root / rel
        if location.is_symlink() or any(p.is_symlink() for p in location.parents if p != root):
            errors.append("Symlink forbidden in approved asset path: " + name)
            continue
        if not location.is_file() or not location.resolve().is_relative_to(directory.resolve()):
            errors.append("Approved asset missing or outside directory: " + name)
            continue
        if not SHA256.fullmatch(digest):
            errors.append("Invalid SHA256: " + name)
            continue
        actual = hashlib.sha256(location.read_bytes()).hexdigest()
        if actual != digest:
            errors.append("Approved asset hash mismatch: " + name)
    if directory.exists():
        for path in directory.rglob("*"):
            if path.is_symlink():
                errors.append("Unapproved symlink forbidden: " + str(path.relative_to(root)))
            elif path.is_file():
                key = path.relative_to(root).as_posix()
                if path.name == ".gitkeep":
                    continue
                if key not in paths:
                    errors.append("Unregistered file in approved/: " + key)
    if baseline is not None:
        before = {(e["id"], e["path"]): e for e in baseline}
        now = {(e["id"], e["path"]): e for e in entries if isinstance(e, dict) and "id" in e and "path" in e}
        for key, entry in before.items():
            if key not in now:
                errors.append("Protected baseline asset removed: " + str(key))
            elif now[key] != entry:
                errors.append("Protected baseline asset modified: " + str(key))
    return errors

def baseline_from_git(root, ref):
    location = ref + ":" + MANIFEST.as_posix()
    exists = subprocess.run(["git","-C",str(root),"cat-file","-e",location],capture_output=True,text=True)
    if exists.returncode:
        valid = subprocess.run(["git","-C",str(root),"rev-parse","--verify",ref],capture_output=True,text=True)
        if valid.returncode:
            raise ValueError("Trusted git ref does not exist: " + ref)
        # Initial bootstrap: main contains no manifest yet; all new files must still be registered.
        return []
    result = subprocess.run(["git","-C",str(root),"show",location],capture_output=True,text=True)
    if result.returncode:
        raise ValueError("Cannot load baseline: " + result.stderr.strip())
    obj = json.loads(result.stdout)
    if obj.get("schema_version") != 1 or not isinstance(obj.get("assets"),list):
        raise ValueError("Invalid baseline manifest")
    return obj["assets"]

def validate_structure(root):
    root = Path(root)
    errors = ["Missing file: "+p for p in REQUIRED if not (root/p).is_file()]
    try:
        ver = (root/"VERSION").read_text(encoding="utf-8").strip()
        conf = json.loads((root/"project.json").read_text(encoding="utf-8"))
        engine = (root/".godot-version").read_text(encoding="utf-8").strip()
        gd = (root/"game/project.godot").read_text(encoding="utf-8")
        if not SEMVER.fullmatch(ver):
            errors.append("VERSION is not MAJOR.MINOR.PATCH")
        if conf.get("game_version") != ver:
            errors.append("project.json game_version mismatch")
        if 'config/version="'+ver+'"' not in gd:
            errors.append("Godot version mismatches VERSION")
        if not re.fullmatch(r"\d+\.\d+\.\d+-stable",engine):
            errors.append("Engine pin invalid")
        if "config/features" not in gd:
            errors.append("Godot feature pin missing")
    except (OSError, ValueError, KeyError) as exc:
        errors.append("Project configuration unreadable: "+str(exc))
    return errors

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-ref",help="Trusted git baseline e.g. origin/main or HEAD^")
    args = parser.parse_args()
    errors = validate_structure(ROOT)
    baseline = None
    if args.base_ref:
        try:
            baseline = baseline_from_git(ROOT,args.base_ref)
        except (ValueError,OSError,json.JSONDecodeError) as exc:
            errors.append(str(exc))
    errors += validate_assets(ROOT,baseline)
    for error in errors:
        print("FAIL:",error)
    if errors:
        raise SystemExit(1)
    print("PASS: structure, SemVer agreement, asset hashes and optional trusted-base policy")
    print("NOT RUN: Godot, Xbox hardware and Android; use dedicated checks")

if __name__=="__main__":
    main()

