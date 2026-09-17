#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

if ! xcode-select -p >/dev/null 2>&1; then
  echo "Xcode Command Line Tools are required. Run: xcode-select --install" >&2
  exit 1
fi

bash build.sh

destination=/Applications/Jetmoji.app
staging=$(mktemp -d /Applications/.jetmoji.XXXXXX)
trap 'rm -rf "$staging"' EXIT
ditto build/Jetmoji.app "$staging/Jetmoji.app"
if [[ -e "$destination" ]]; then mv "$destination" "$staging/previous.app"; fi
if ! mv "$staging/Jetmoji.app" "$destination"; then
  if [[ -e "$staging/previous.app" ]]; then mv "$staging/previous.app" "$destination"; fi
  exit 1
fi
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$destination"
mdimport "$destination" >/dev/null 2>&1 || true

cli_dir="$HOME/.local/bin"
mkdir -p "$cli_dir"
ln -sfn "$destination/Contents/MacOS/Jetmoji" "$cli_dir/jetmoji"

printf '\nInstalled %s\nCLI: %s/jetmoji\nQuit any running copy, then run: open "%s"\n' \
  "$destination" "$cli_dir" "$destination"
