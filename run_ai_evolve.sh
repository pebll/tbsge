#!/usr/bin/env sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
cd "$ROOT_DIR"

if [ ! -x "./godot_exe" ]; then
  echo "ERROR: ./godot_exe not found or not executable" 1>&2
  echo "Hint: put your Godot binary at repo root as 'godot_exe' and chmod +x it." 1>&2
  exit 2
fi

./godot_exe \
  --path . \
  --headless \
  --display-driver headless \
  --audio-driver Dummy \
  --script res://tests/run_ai_evolve.gd \
  -- "$@"
