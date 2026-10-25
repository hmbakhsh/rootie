#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
APP_NAME="Rootie.app"
APP="$ROOT/dist/$APP_NAME"
RELEASE_BUILD="${ROOTIE_RELEASE_BUILD:-0}"

cd "$ROOT"
BIN_DIR=$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)
swift build -c release --arch arm64 --arch x86_64

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp "$BIN_DIR/Rootie" "$APP/Contents/MacOS/Rootie"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
ditto "$BIN_DIR/Frameworks/Sparkle.framework" "$APP/Contents/Frameworks/Sparkle.framework"
cp "$ROOT/.build/checkouts/Sparkle/LICENSE" "$APP/Contents/Resources/Sparkle-LICENSE.txt"

if [[ -n "${ROOTIE_VERSION:-}" ]]; then
  plutil -replace CFBundleShortVersionString -string "$ROOTIE_VERSION" "$APP/Contents/Info.plist"
fi
if [[ -n "${ROOTIE_BUILD_NUMBER:-}" ]]; then
  plutil -replace CFBundleVersion -string "$ROOTIE_BUILD_NUMBER" "$APP/Contents/Info.plist"
fi

if [[ "$RELEASE_BUILD" == "1" ]]; then
  if [[ -z "${ROOTIE_VERSION:-}" || -z "${ROOTIE_BUILD_NUMBER:-}" ]]; then
    echo "Release builds require ROOTIE_VERSION and ROOTIE_BUILD_NUMBER." >&2
    exit 1
  fi
fi

ICONSET=$(mktemp -d)/AppIcon.iconset
mkdir -p "$ICONSET"
swift "$ROOT/scripts/generate-icon.swift" "$ICONSET/icon_512x512@2x.png"
for spec in "16:16x16" "32:16x16@2x" "32:32x32" "64:32x32@2x" "128:128x128" "256:128x128@2x" "256:256x256" "512:256x256@2x" "512:512x512"; do
  pixels=${spec%%:*}
  name=${spec#*:}
  sips -z "$pixels" "$pixels" "$ICONSET/icon_512x512@2x.png" --out "$ICONSET/icon_$name.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

SPARKLE="$APP/Contents/Frameworks/Sparkle.framework"
rm -rf "$SPARKLE/Versions/B/XPCServices" "$SPARKLE/XPCServices"

# Ad-hoc signed, so no hardened runtime: its library validation rejects the
# embedded Sparkle.framework and the app fails to launch.
SIGN_ARGS=(--force --sign -)

codesign "${SIGN_ARGS[@]}" "$SPARKLE/Versions/B/Autoupdate"
codesign "${SIGN_ARGS[@]}" "$SPARKLE/Versions/B/Updater.app"
codesign "${SIGN_ARGS[@]}" "$SPARKLE"
codesign "${SIGN_ARGS[@]}" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

echo "$APP"
