#!/usr/bin/env bash
set -euo pipefail

apk=$(find builds/android -name '*.apk' -print -quit)
pkg="${NITRO_PKG:?Set NITRO_PKG to the debug review package}"
out=builds/circuits-android
mkdir -p "$out"
adb install -r "$apk"
adb shell am force-stop "$pkg"
adb shell settings put secure immersive_mode_confirmations confirmed
adb shell input keyevent KEYCODE_WAKEUP
adb shell wm dismiss-keyguard
adb shell wm size 720x1536
adb shell wm density 240
adb shell run-as "$pkg" mkdir -p files
adb shell run-as "$pkg" rm -f files/circuits-verdict.txt 'files/ready-*' 'files/captured-*'
adb shell run-as "$pkg" touch files/qa-circuits.once
adb shell monkey -p "$pkg" 1
trap 'adb logcat -d -s godot > "$out/godot.log" || true' EXIT

await_file() {
    for attempt in {1..75}; do
        if adb shell run-as "$pkg" test -s "files/$1"; then return; fi
        if [[ "$1" != circuits-verdict.txt ]] && adb shell run-as "$pkg" test -s files/circuits-verdict.txt; then
            adb exec-out run-as "$pkg" cat files/circuits-verdict.txt >&2
            return 1
        fi
        sleep 2
    done
    echo "Timed out waiting for $1" >&2
    return 1
}

for circuit in driftwood_circuit testandori_raceway fuji_speedway_short; do
    for scene in editor race; do
        shot="$circuit-$scene"
        await_file "ready-$shot"
        adb exec-out screencap -p > "$out/$shot.png"
        adb shell run-as "$pkg" touch "files/captured-$shot"
    done
done
await_file circuits-verdict.txt
adb exec-out run-as "$pkg" cat files/circuits-verdict.txt | tee "$out/verdict.txt"
grep -q '^PASS:' "$out/verdict.txt"
/usr/bin/python3 - "$out" <<'PY'
from pathlib import Path
import sys
from PIL import Image
shots = list(Path(sys.argv[1]).glob("*.png"))
assert len(shots) == 6
for path in shots:
    with Image.open(path) as image:
        w, h = image.size
        scene = image.crop((w//12, h//7, w*11//12, h*3//4)).convert("RGB")
        assert len(set(scene.resize((256, 256)).getdata())) > 100, f"Missing rendered scene in {path}"
PY
