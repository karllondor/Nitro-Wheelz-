#!/usr/bin/env bash
## #33: on-device integration check of the combined APK (multiplayer over the device ENet stack + node editor on a
## terrain circuit + drive). Runs after tools/android_event_smoke.sh in the same emulator session.
set -euo pipefail
pkg=${NITRO_PKG:-com.karllondor.nitrowheelz.dev}
out=builds/integration-android
mkdir -p "$out"
adb shell am force-stop "$pkg" || true
adb shell run-as "$pkg" touch files/qa-integration.once
adb shell monkey -p "$pkg" 1
trap 'adb logcat -d -s godot > "$out/godot.log" || true' EXIT
await_file() {
  for attempt in {1..150}; do
    if adb shell run-as "$pkg" test -s "files/$1"; then return 0; fi
    sleep 2
  done
  echo "Timed out waiting for $1" >&2
  return 1
}
for view in mp_race editor_set_start editor_drive; do
  await_file "ready-$view"
  adb exec-out screencap -p > "$out/$view.png"
  adb shell run-as "$pkg" touch "files/captured-$view"
done
await_file integration-verdict.txt
adb exec-out run-as "$pkg" cat files/integration-verdict.txt | tee "$out/verdict.txt"
grep -q '^PASS' "$out/verdict.txt"
/usr/bin/python3 - <<'CHECK'
from pathlib import Path
from PIL import Image
for path in Path("builds/integration-android").glob("*.png"):
    with Image.open(path) as image:
        w,h=image.size
        scene=image.crop((w//5,h//4,4*w//5,2*h//3)).convert("RGB").resize((128,128))
        assert len(set(scene.getdata()))>120, f"Missing rendered scene in {path}"
CHECK
