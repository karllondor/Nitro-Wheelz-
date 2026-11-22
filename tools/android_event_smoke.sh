#!/usr/bin/env bash
set -euo pipefail
apk=$(find builds/android -name '*.apk' -print -quit)
pkg=com.karllondor.nitrowheelz
adb install -r "$apk"
adb shell wm size 720x1280
adb shell wm density 240
adb shell run-as "$pkg" mkdir -p files
adb shell run-as "$pkg" touch files/qa-workshop.once
adb shell monkey -p "$pkg" 1
mkdir -p builds/event-android
for attempt in {1..120}; do
  if adb shell run-as "$pkg" test -s files/workshop-verdict.txt; then break; fi
  sleep 3
done
adb logcat -d -s godot > builds/event-android/godot.log
adb exec-out run-as "$pkg" cat files/workshop-verdict.txt | tee builds/event-android/verdict.txt
grep -q '^PASS' builds/event-android/verdict.txt
for view in practice club pro drive; do
  adb exec-out run-as "$pkg" cat "files/workshop-$view.png" > "builds/event-android/$view.png"
  file "builds/event-android/$view.png" | grep PNG
done
