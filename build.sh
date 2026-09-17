#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

app="$PWD/build/Jetmoji.app"
mkdir -p "$PWD/build" "$PWD/Assets"

if [[ ! -f "$PWD/Assets/AppIcon.icns" ]]; then
  echo "Generating app icon…"
  swift "$PWD/scripts/make-icon.swift"
fi

staging=$(mktemp -d "$PWD/build/.jetmoji.XXXXXX")
trap 'rm -rf "$staging"' EXIT
candidate="$staging/Jetmoji.app"

mkdir -p "$candidate/Contents/MacOS" "$candidate/Contents/Resources"

sdk="$(xcrun --show-sdk-path)"
min_os="${JETMOJI_MIN_OS:-14.0}"
arch="$(uname -m)"
target="${arch}-apple-macos${min_os}"

echo "Compiling Jetmoji ($target)…"
# shellcheck disable=SC2046
swiftc -O -parse-as-library \
  -target "$target" \
  -sdk "$sdk" \
  -strict-concurrency=complete \
  -framework AppKit \
  -framework Carbon \
  -framework SwiftUI \
  -framework ServiceManagement \
  -framework ApplicationServices \
  -framework CoreGraphics \
  $(find Sources Tests -name '*.swift' | sort) \
  -o "$candidate/Contents/MacOS/Jetmoji"

cp Info.plist "$candidate/Contents/Info.plist"
cp Assets/AppIcon.icns "$candidate/Contents/Resources/AppIcon.icns"
cp Assets/StatusItem.png "$candidate/Contents/Resources/StatusItem.png"
cp Assets/StatusItem@2x.png "$candidate/Contents/Resources/StatusItem@2x.png"

identity="${JETMOJI_SIGN_IDENTITY-}"
if [[ -z "${identity}" ]]; then
  identity="$(security find-identity -v -p codesigning 2>/dev/null | awk -F '"' '/Apple Development/ { print $2; exit }' || true)"
fi
if [[ -z "${identity}" ]]; then
  identity="$(security find-identity -v -p codesigning 2>/dev/null | awk -F '"' '/Developer ID Application/ { print $2; exit }' || true)"
fi

if [[ -n "${identity}" ]]; then
  echo "Signing with ${identity}"
  codesign --force --sign "${identity}" --entitlements Jetmoji.entitlements "$candidate"
  codesign --verify --verbose=2 "$candidate"
else
  echo "Ad-hoc signing (no Apple Development identity found)"
  codesign --force --sign - --entitlements Jetmoji.entitlements "$candidate" >/dev/null
fi

"$candidate/Contents/MacOS/Jetmoji" --self-test

if [[ -e "$app" ]]; then mv "$app" "$staging/previous.app"; fi
if ! mv "$candidate" "$app"; then
  if [[ -e "$staging/previous.app" ]]; then mv "$staging/previous.app" "$app"; fi
  exit 1
fi

printf '\nBuilt %s\nRun: open "%s"\n' "$app" "$app"
