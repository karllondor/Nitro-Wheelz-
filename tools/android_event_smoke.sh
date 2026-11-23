#!/usr/bin/env bash
set -euo pipefail
apk=$(find builds/android -name '*.apk' -print -quit)
pkg=com.karllondor.nitrowheelz.workshop
adb install -r "$apk"
adb shell settings put secure immersive_mode_confirmations confirmed
adb shell input keyevent KEYCODE_WAKEUP
adb shell wm dismiss-keyguard
adb shell wm size 720x1280
adb shell wm density 240
adb shell run-as "$pkg" mkdir -p files
adb shell run-as "$pkg" touch files/qa-workshop.once
adb shell monkey -p "$pkg" 1
mkdir -p builds/event-android
trap 'adb logcat -d -s godot > builds/event-android/godot.log || true' EXIT
await_file() {
  for attempt in {1..150}; do
    if adb shell run-as "$pkg" test -s "files/$1"; then return 0; fi
    sleep 2
  done
  echo "Timed out waiting for $1" >&2
  return 1
}
for view in straight corner s-bend circuit practice pro club drive; do
  await_file "ready-$view"
  adb exec-out screencap -p > "builds/event-android/$view.png"
  adb shell run-as "$pkg" touch "files/captured-$view"
done
await_file workshop-verdict.txt
adb exec-out run-as "$pkg" cat files/workshop-verdict.txt | tee builds/event-android/verdict.txt
grep -q '^PASS' builds/event-android/verdict.txt
/usr/bin/python3 - <<'CHECK'
from pathlib import Path
from PIL import Image
for path in Path("builds/event-android").glob("*.png"):
    with Image.open(path) as image:
        w,h=image.size
        scene=image.crop((w//5,h//4,4*w//5,2*h//3)).convert("RGB").resize((128,128))
        assert len(set(scene.getdata()))>180, f"Missing rendered scene in {path}"
CHECK
