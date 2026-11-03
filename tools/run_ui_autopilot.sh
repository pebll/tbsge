#!/usr/bin/env sh
# Click-through UI smoke test: plays menu -> setup -> draft -> battle -> game over (or
# abandon) with real mouse/keyboard events, saves screenshots, checks key behaviours.
# Uses the current display if set, otherwise a virtual one (Xvfb + software OpenGL).
#
# Usage: tools/run_ui_autopilot.sh [OUT_DIR]   (default: ./autopilot_shots)
set -eu
ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$ROOT_DIR"
OUT_DIR="$(realpath -m "${1:-autopilot_shots}")"
mkdir -p "$OUT_DIR"
[ -x ./godot_exe ] || tools/get_godot.sh

set -- ./godot_exe --path . --rendering-driver opengl3 --audio-driver Dummy \
  --resolution 1920x1080 res://tools/ui_autopilot.tscn -- "$OUT_DIR"

if [ -n "${DISPLAY:-}" ]; then
  exec "$@"
fi
exec xvfb-run -a -s "-screen 0 1920x1080x24" "$@"
