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
for spec in import smoke_test input_test; do
    if [ "$spec" = import ]; then
        "$GODOT_BIN" --headless --path game --editor --import 2>&1 | tee "$LOG_DIR/$spec.log"
    else
        "$GODOT_BIN" --headless --path game --script "res://tests/$spec.gd" 2>&1 | tee "$LOG_DIR/$spec.log"
    fi
    if grep -Eq 'SCRIPT ERROR|ERROR:' "$LOG_DIR/$spec.log"; then
        echo "FAIL: Godot reported runtime/parse errors in $spec" >&2
        exit 4
    fi
done
echo "PASS: Godot import, smoke and input script complete"
echo "NOT RUN: Xbox physical pad, Android, export, gameplay feel"

