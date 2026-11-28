#!/usr/bin/env bash
set -euo pipefail

apk=$(find builds/android -name '*.apk' -print -quit)
pkg="${NITRO_PKG:?Set NITRO_PKG to the debug review package}"
case "${NITRO_SMOKE:-circuits}" in
    hotfix)
        case_name=hotfix
        shots=(paint-0 chase-paint-0 paint-1 chase-paint-1 paint-2 chase-paint-2 paint-3 chase-paint-3
            results-pro retry-five retry-paint results-club results-practice results-ordinary)
        ;;
    tracks)
        case_name=tracks
        shots=()
        ;;
    uxrescue)
        # issue #65 / #59: real adb swipe + Android BACK on the menus, cards and garage (android_ux_checks.gd)
        case_name=uxrescue
        shots=(ux-dev-top ux-dev-scrolled ux-delete ux-rename ux-garage)
        ;;
    circuits)
        case_name=circuits
        shots=()
        for circuit in driftwood_circuit testandori_raceway fuji_speedway_short; do
            shots+=("$circuit-editor" "$circuit-race")
        done
        ;;
    *)
        echo "Unknown Android review smoke case" >&2
        exit 2
        ;;
esac
out="builds/$case_name-android"
verdict="$case_name-verdict.txt"
mkdir -p "$out"
# The preceding signed review may age out of Actions retention. When present,
# exercise a real Android upgrade and verify that app-private data survives.
previous=""
upgrade_track="$out/upgrade-track.json"
upgrade_runs="$out/upgrade-runs.json"
if [[ "$case_name" == hotfix || "$case_name" == tracks || "$case_name" == uxrescue ]]; then
    previous_dir=builds/android-pr45
    previous_version=v0.1.49
    previous_sha=6fc57b954555c048c5f909a43cf2c7e53c29b7ea993bd2209dfe708b50e3b761
    target_version=v0.1.50
    if [[ "$case_name" == tracks ]]; then
        previous_dir=builds/android-pr58
        previous_version=v0.1.50
        previous_sha=02073a39db1d86c44d0ae382d0a35a0580b3b132134dee1a1eee269dc8278515
        target_version=v0.1.51
    fi
    if [[ "$case_name" == uxrescue ]]; then
        previous_dir=builds/android-pr63
        previous_version=v0.1.51
        previous_sha=b5cea4df5d84095f312504d0a0352f8adb34ea9e64a4c1751f38a5c1a1e68003
        target_version=v0.1.52
    fi
    if [[ -d "$previous_dir" ]]; then
        previous=$(find "$previous_dir" -name '*.apk' -print -quit)
    fi
    if [[ -n "$previous" ]]; then
        printf '%s  %s\n' "$previous_sha" "$previous" | sha256sum -c -
        adb install -r "$previous"
        adb shell run-as "$pkg" mkdir -p files
        cp game/tracks/fuji_speedway_short.json "$upgrade_track"
        printf '%s\n' '[{"track_id":"driftwood_circuit","seconds":183.24,"score":9900,"stars":1,"driver":"QA","car":"e30"}]' > "$upgrade_runs"
        adb shell "run-as $pkg sh -c 'cat > files/nitro_track_qa_upgrade.json'" < "$upgrade_track"
        adb shell "run-as $pkg sh -c 'cat > files/nitro_local_runs.json'" < "$upgrade_runs"
    else
        echo "SKIP: the signed $previous_version artifact is unavailable" | tee "$out/upgrade-verdict.txt"
    fi
fi
adb install -r "$apk"
adb shell am force-stop "$pkg"
adb shell settings put secure immersive_mode_confirmations confirmed
adb shell input keyevent KEYCODE_WAKEUP
adb shell wm dismiss-keyguard
adb shell wm size 720x1536
adb shell wm density 240
adb shell run-as "$pkg" mkdir -p files
adb shell run-as "$pkg" rm -f "files/$verdict"
for shot in "${shots[@]}"; do
    adb shell run-as "$pkg" rm -f "files/ready-$shot" "files/captured-$shot"
done
adb shell run-as "$pkg" touch "files/qa-$case_name.once"
adb shell monkey -p "$pkg" 1
trap 'adb logcat -d -s godot > "$out/godot.log" || true' EXIT

await_file() {
    for attempt in {1..75}; do
        if adb shell run-as "$pkg" test -s "files/$1"; then return; fi
        if [[ "$1" != "$verdict" ]] && adb shell run-as "$pkg" test -s "files/$verdict"; then
            adb exec-out run-as "$pkg" cat "files/$verdict" >&2
            return 1
        fi
        sleep 2
    done
    echo "Timed out waiting for $1" >&2
    return 1
}

# Real OS input after a screenshot (uxrescue): a swipe that starts on a DEVELOPER button, then Android BACK.
after_shot() {
    case "$1" in
        ux-dev-top) adb shell input swipe 360 1150 360 450 400 ;;
        ux-dev-scrolled|ux-delete|ux-rename) adb shell input keyevent KEYCODE_BACK ;;
    esac
}

for shot in "${shots[@]}"; do
    await_file "ready-$shot"
    adb exec-out screencap -p > "$out/$shot.png"
    after_shot "$shot"
    adb shell run-as "$pkg" touch "files/captured-$shot"
done
await_file "$verdict"
adb exec-out run-as "$pkg" cat "files/$verdict" | tee "$out/verdict.txt"
grep -q '^PASS:' "$out/verdict.txt"
if [[ -n "$previous" ]]; then
    adb exec-out run-as "$pkg" cat files/nitro_track_qa_upgrade.json | cmp "$upgrade_track" -
    adb exec-out run-as "$pkg" cat files/nitro_local_runs.json | cmp "$upgrade_runs" -
    echo "PASS: signed $previous_version to $target_version upgrade, custom track and records byte-identical" | tee "$out/upgrade-verdict.txt"
fi
/usr/bin/python3 - "$out" "${#shots[@]}" <<'PYCODE'
from pathlib import Path
import sys
from PIL import Image
shots = list(Path(sys.argv[1]).glob("*.png"))
assert len(shots) == int(sys.argv[2])
for path in shots:
    with Image.open(path) as image:
        w, h = image.size
        scene = image.crop((w//12, h//7, w*11//12, h*3//4)).convert("RGB")
        assert len(set(scene.resize((256, 256)).getdata())) > 100, f"Missing rendered scene in {path}"
PYCODE
