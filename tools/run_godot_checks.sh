#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT_BIN="$(printenv GODOT_BIN || true)"
if [ -z "$GODOT_BIN" ]; then GODOT_BIN=godot; fi
if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
    echo "BLOCKED: Godot missing; set GODOT_BIN=/path/to/Godot" >&2
    exit 2
fi
EXPECTED="$(cat .godot-version)"
EXPECTED_BASE="$(printf '%s' "$EXPECTED" | sed 's/-stable/.stable/')"
ACTUAL="$("$GODOT_BIN" --version)"
case "$ACTUAL" in
    "$EXPECTED_BASE"*) echo "PINNED: $ACTUAL";;
    *) echo "FAIL: need $EXPECTED but found $ACTUAL" >&2; exit 3;;
esac
python3 tools/check_project.py
LOG_DIR="$(mktemp -d)"
trap 'rm -rf "$LOG_DIR"' EXIT
# A test prints exactly one final "PASS:" line and then quits. The headless
# engine sometimes never finishes shutting down after that: the Dummy audio
# driver thread spins while the main thread joins it (gdb, v0.1.29: main in
# pthread_join, the audio thread at 100 % CPU). The checks themselves have
# completed by then, so a process still alive 20 s after its PASS line is
# killed and reported as a WARNING (never silently). A hang before PASS, an
# error line or a non-zero exit is still a failure.
run_spec() {
    local spec="$1" limit="$2" log="$LOG_DIR/$1.log"
    "$GODOT_BIN" --headless --audio-driver Dummy --path game --script "res://tests/$spec.gd" > "$log" 2>&1 &
    local pid=$! start=$SECONDS passed_at=-1 code=0
    while kill -0 "$pid" 2>/dev/null; do
        if [ "$passed_at" -lt 0 ] && grep -q '^PASS:' "$log"; then passed_at=$SECONDS; fi
        if [ "$passed_at" -ge 0 ] && [ $((SECONDS - passed_at)) -ge 20 ]; then
            kill -9 "$pid" 2>/dev/null || true
            wait "$pid" 2>/dev/null || true
            cat "$log"
            echo "WARNING: $spec printed PASS but the engine did not exit within 20 s (headless audio-thread shutdown hang); process killed after its checks had completed"
            return 0
        fi
        if [ $((SECONDS - start)) -ge "$limit" ]; then
            kill -9 "$pid" 2>/dev/null || true
            wait "$pid" 2>/dev/null || true
            cat "$log"
            echo "FAIL: $spec did not finish within ${limit}s" >&2
            return 5
        fi
        sleep 1
    done
    if wait "$pid"; then code=0; else code=$?; fi
    cat "$log"
    if [ "$code" -ne 0 ]; then
        echo "FAIL: $spec exited with code $code" >&2
        return 6
    fi
}

for spec in import smoke_test input_test driving_test mobile_visual_test track_dna_test benchmark_track_test generated_track_test editor_results_test brand_pause_surface_test garage_audio_test dynamic_camera_test visual_identity_test track_builder_test drift_scoring_test engine_audio_test wall_body_test results_screen_test main_menu_test car_profiles_test audio_regression_test editor_geometry_test hud_layout_test procedural_world_test e30_factory_car_test factory_models_test builder_touch_test wheel_visual_test track_records_test terrain_world_test terrain_scenery_test terrain_builder_test terrain_physics_test terrain_route_minimap_test wheel_smoke_test terrain_water_road_test terrain_water_footprint_test vegetation_stability_test loading_screen_test car_factory_default_test driver_profile_test player_profile_test gas_pedal_shape_test track_details_test car_performance_test park_layout_test park_site_test park_stunt_test production_lighting_test desktop_hud_layout_test park_damage_test park_tutorial_test physics_modes_test white_lada_test android_start_test park_navigation_test event_workshop_test net_session_test net_race_test net_remote_view_test multiplayer_lobby_test node_editor_open_test terrain_integration_matrix_test integration_boundary_test three_circuits_test; do
    echo "START TEST: $spec"
    LIMIT=45
    case "$spec" in terrain_*) LIMIT=150;; esac
    if [ "$spec" = import ]; then
        timeout 45s "$GODOT_BIN" --headless --path game --editor --import 2>&1 | tee "$LOG_DIR/$spec.log"
    else
        run_spec "$spec" "$LIMIT"
    fi
    if grep -Eq 'SCRIPT ERROR|ERROR:|FAIL:' "$LOG_DIR/$spec.log"; then
        echo "FAIL: Godot reported runtime/parse errors in $spec" >&2
        exit 4
    fi
done
GODOT_BIN="$GODOT_BIN" python3 tools/test_net_rounds.py
GODOT_BIN="$GODOT_BIN" python3 tools/test_net_rounds.py --park
GODOT_BIN="$GODOT_BIN" python3 tools/test_net_rounds.py --damage
echo "PASS: Godot import, real scenes, input and driving regressions"
echo "NOT RUN: Xbox real controller, Android, Windows export and physical device performance"

