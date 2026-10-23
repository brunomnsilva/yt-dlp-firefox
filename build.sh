#!/usr/bin/env bash
# Builds the loadable extension zip. Does not require Omarchy or yt-dlp.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
VERSION=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
  "$SCRIPT_DIR/manifest.json" | head -n1)
VERSION=${VERSION:-0.0}
OUT="$SCRIPT_DIR/dist/yt-dlp-firefox-$VERSION.zip"

mkdir -p "$SCRIPT_DIR/dist"
rm -f "$OUT"

(cd "$SCRIPT_DIR" && zip -q -r "$OUT" \
  manifest.json background.js icon-16.png icon-48.png icon-128.png)

printf 'Built %s\n' "$OUT"
