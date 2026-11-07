#!/usr/bin/env sh
# Fetch the official Godot editor binary (checksum-verified) and link it as ./godot_exe,
# which run_tests.sh / run_ai_duel.sh / run_balance.sh expect.
#
# Usage: tools/get_godot.sh [CACHE_DIR]     (default: ~/.cache/godot)
# Env:   GODOT_VERSION (default 4.6-stable — keep in sync with project.godot features)
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
VERSION="${GODOT_VERSION:-4.6-stable}"
CACHE_DIR="${1:-${HOME}/.cache/godot}/${VERSION}"
ZIP="Godot_v${VERSION}_linux.x86_64.zip"
BIN="Godot_v${VERSION}_linux.x86_64"
BASE="https://github.com/godotengine/godot/releases/download/${VERSION}"

mkdir -p "$CACHE_DIR"
cd "$CACHE_DIR"
if [ ! -x "$BIN" ]; then
  echo "Downloading Godot ${VERSION}..."
  curl -sSLo "$ZIP" "$BASE/$ZIP"
  curl -sSLo SHA512-SUMS.txt "$BASE/SHA512-SUMS.txt"
  grep " ${ZIP}\$" SHA512-SUMS.txt | sha512sum -c -
  unzip -oq "$ZIP"
  chmod +x "$BIN"
  rm -f "$ZIP"
fi

ln -sf "$CACHE_DIR/$BIN" "$ROOT_DIR/godot_exe"
echo "Linked $ROOT_DIR/godot_exe -> $CACHE_DIR/$BIN"

# First run needs an import pass so class_name globals resolve headless.
if [ ! -d "$ROOT_DIR/.godot" ]; then
  echo "Importing project (first run)..."
  timeout 600 "$ROOT_DIR/godot_exe" --headless --path "$ROOT_DIR" --import >/dev/null 2>&1 || true
fi
