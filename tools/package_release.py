#!/usr/bin/env python3
"""Immutable release artifact + SHA256 + manifest, no claimed hardware testing."""
import argparse
import hashlib
import json
import re
import shutil
import subprocess
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EXCLUDES = {".git", ".godot", "__pycache__", "builds", "dist", "captures", ".venv"}
SEMVER = re.compile(r"^\d+\.\d+\.\d+$")

def sha(path):
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

def git_sha():
    p = subprocess.run(["git", "rev-parse", "--verify", "HEAD"], cwd=ROOT, capture_output=True, text=True)
    return p.stdout.strip() if p.returncode == 0 else "unknown"

def zip_directory(target, directory, source=False):
    with zipfile.ZipFile(target, "x", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for path in sorted(directory.rglob("*")):
            if not path.is_file() or any(part in EXCLUDES for part in path.relative_to(directory).parts):
                continue
            if source and path.suffix.lower() in {".apk", ".aab", ".exe"}:
                continue
            archive.write(path, path.relative_to(directory).as_posix())

def package(root, dest, platform, source_input=None):
    config = json.loads((root / "project.json").read_text(encoding="utf-8"))
    version = (root / "VERSION").read_text(encoding="utf-8").strip()
    if not SEMVER.fullmatch(version) or version != config.get("game_version"):
        raise ValueError("Version mismatch")
    slug = config["game_slug"]
    if not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", slug):
        raise ValueError("Unsafe game_slug")
    extension = ".apk" if platform == "Android" else ".zip"
    name = slug + "_v" + version + "_" + platform + extension
    dest.mkdir(parents=True, exist_ok=True)
    target = dest / name
    manifest = dest / (name + ".manifest.json")
    digest_file = dest / (name + ".sha256")
    if any(x.exists() for x in (target, manifest, digest_file)):
        raise FileExistsError("Immutable release artifact already exists: " + name)
    if platform != "Source" and source_input is None:
        raise ValueError("Non-source release needs --input actual exported file or folder")
    if platform == "Android" and (not source_input.is_file() or source_input.suffix.lower() != ".apk"):
        raise ValueError("Android input must be an existing APK")
    if platform != "Source" and not source_input.exists():
        raise FileNotFoundError(source_input)
    if platform == "Source":
        zip_directory(target, root, source=True)
    elif source_input.is_dir():
        zip_directory(target, source_input)
    else:
        shutil.copyfile(source_input, target)
    digest = sha(target)
    manifest.write_text(json.dumps({"artifact":name, "game":config["game_name"], "version":version,
        "platform":platform, "git_sha":git_sha(), "sha256":digest,
        "status":"BUILT_NOT_TESTED", "source":str(source_input) if source_input else "repository"}, indent=2) + "\n", encoding="utf-8")
    digest_file.write_text(digest + "  " + name + "\n", encoding="utf-8")
    return target

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--platform", required=True, choices=["Source","Windows","Linux","Web","Android"])
    p.add_argument("--input", help="Exported app file/folder (required except Source)")
    p.add_argument("--output", default=str(ROOT / "builds"))
    args = p.parse_args()
    try:
        result = package(ROOT, Path(args.output).resolve(), args.platform, Path(args.input).resolve() if args.input else None)
    except (ValueError, OSError, FileExistsError) as exc:
        p.error(str(exc))
    print("PACKAGED:", result)
    print("NOT TESTED ON DEVICE; see docs/QA_MATRIX.md.")

if __name__ == "__main__":
    main()

