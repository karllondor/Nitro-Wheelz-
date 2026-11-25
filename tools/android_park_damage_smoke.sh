#!/usr/bin/env bash
# APK installed on an emulator or a USB-connected Android phone. Uses app-private files.
set -euo pipefail
pkg=${NITRO_PKG:?Set NITRO_PKG to the installed review package}
out=builds/damage-android
mkdir -p "$out"
adb shell am force-stop "$pkg"
adb shell run-as "$pkg" mkdir -p files/park-damage-qa
adb shell run-as "$pkg" rm -f files/park-damage-qa/frames.json
adb shell run-as "$pkg" touch files/qa-damage.once
adb shell monkey -p "$pkg" 1
for attempt in {1..150}; do
    if adb shell run-as "$pkg" test -s files/park-damage-qa/frames.json; then break; fi
    sleep 2
done
for file in frames.json 01-intact.png 02-front-dangling.png 03-rear-dangling.png 04-detached.png 05-repaired.png; do
    adb exec-out run-as "$pkg" cat "files/park-damage-qa/$file" > "$out/$file"
done
adb shell getprop ro.product.model > "$out/device-model.txt"
adb shell getprop ro.boot.qemu > "$out/qemu.txt"
python3 - "$out" <<'CHECK'
import json, struct, sys
from pathlib import Path
root = Path(sys.argv[1])
report = json.loads((root / 'frames.json').read_text())
print(json.dumps(report, indent=2))
assert report['ok'] and len(report['samples'])==3
for image in root.glob('*.png'):
    data = image.read_bytes()
    assert data.startswith(b'\x89PNG') and min(struct.unpack('>II',data[16:24]))>=320
CHECK
