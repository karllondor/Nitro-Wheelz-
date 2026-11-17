#!/usr/bin/env python3
"""Append a hardware/execution QA evidence record (no invented PASS)."""
import argparse
import datetime
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def main():
    p = argparse.ArgumentParser()
    for key in ("test", "platform", "device", "status"):
        p.add_argument("--" + key, required=True)
    p.add_argument("--evidence", default="")
    p.add_argument("--notes", default="")
    p.add_argument("--output", default=str(ROOT / "captures/qa_records.jsonl"))
    args = p.parse_args()
    if args.status not in ("PASS","FAIL","BLOCKED","NOT_RUN"):
        p.error("status must be PASS/FAIL/BLOCKED/NOT_RUN")
    if args.status == "PASS" and not args.evidence.strip():
        p.error("PASS requires an evidence path or link")
    if args.evidence and not args.evidence.startswith(("https://","http://")) and not Path(args.evidence).exists():
        p.error("Local evidence path does not exist")
    pth = Path(args.output)
    pth.parent.mkdir(parents=True, exist_ok=True)
    proc = subprocess.run(["git","rev-parse","HEAD"],cwd=ROOT,text=True,capture_output=True)
    data = {key:getattr(args,key) for key in ("test","platform","device","status","evidence","notes")}
    data.update({"game_version":(ROOT/"VERSION").read_text().strip(),
                 "git_sha":proc.stdout.strip() if proc.returncode == 0 else "unknown",
                 "timestamp_utc":datetime.datetime.now(datetime.timezone.utc).isoformat()})
    with pth.open("a",encoding="utf-8") as f:
        f.write(json.dumps(data,ensure_ascii=False)+"\n")
    print("RECORDED:", args.status, args.test)

if __name__ == "__main__":
    main()

