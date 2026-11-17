#!/usr/bin/env python3
"""Preflight large git-tracked files: redirect large sources to Git LFS."""
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LIMIT = 25 * 1024 * 1024
proc = subprocess.run(["git","ls-files","-z"],cwd=ROOT,capture_output=True)
if proc.returncode:
    sys.exit("Git unavailable")
large=[]
for raw in proc.stdout.split(b"\x00"):
    if not raw:
        continue
    path = ROOT / raw.decode(errors="surrogateescape")
    if path.is_file() and path.stat().st_size > LIMIT:
        # LFS pointer files are tiny in Git working trees; large checked-out LFS assets
        # are expected and must be recognized by git check-attr filter.
        attr = subprocess.run(["git","check-attr","filter","--",str(path.relative_to(ROOT))],cwd=ROOT,text=True,capture_output=True)
        if "filter: lfs" not in attr.stdout:
            large.append(str(path.relative_to(ROOT)))
if large:
    for path in large:
        print("FAIL: large non-LFS file",path)
    raise SystemExit(1)
print("PASS: no tracked non-LFS files above 25 MiB")

