#!/bin/bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Jetmoji is macOS only." >&2
  exit 1
fi

if ! xcode-select -p >/dev/null 2>&1; then
  echo "Xcode Command Line Tools are required. Run: xcode-select --install" >&2
  exit 1
fi

work=$(mktemp -d "${TMPDIR:-/tmp}/jetmoji.XXXXXX")
trap 'rm -rf "$work"' EXIT

echo "Downloading Jetmoji…"
curl -fsSL https://github.com/ChristopherChifor/jetmoji/archive/refs/heads/main.tar.gz \
  | tar -xz -C "$work"

cd "$work/jetmoji-main"
bash install.sh

if [[ "${JETMOJI_SKIP_RELAUNCH:-}" == "1" ]]; then
  exit 0
fi

osascript -e 'tell application "Jetmoji" to quit' >/dev/null 2>&1 || true
open /Applications/Jetmoji.app
