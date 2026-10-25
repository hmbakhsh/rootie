#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
APP="${1:?app path is required}"
ARCHIVE="${2:?archive path is required}"
APPCAST="${3:?appcast path is required}"
SPARKLE_BIN="$ROOT/.build/artifacts/sparkle/Sparkle/bin"

codesign --verify --deep --strict --verbose=2 "$APP"
lipo "$APP/Contents/MacOS/Rootie" -verify_arch arm64 x86_64
# Proves the binary loads its frameworks.
"$APP/Contents/MacOS/Rootie" version >/dev/null

VERSION=$(plutil -extract CFBundleShortVersionString raw "$APP/Contents/Info.plist")
BUILD_NUMBER=$(plutil -extract CFBundleVersion raw "$APP/Contents/Info.plist")
[[ "$VERSION" == "${ROOTIE_VERSION:?ROOTIE_VERSION is required}" ]]
[[ "$BUILD_NUMBER" == "${ROOTIE_BUILD_NUMBER:?ROOTIE_BUILD_NUMBER is required}" ]]

ARCHIVE_CONTENTS=$(mktemp -d)
trap 'rm -rf "$ARCHIVE_CONTENTS"' EXIT
ditto -x -k "$ARCHIVE" "$ARCHIVE_CONTENTS"
codesign --verify --deep --strict "$ARCHIVE_CONTENTS/Rootie.app"

grep -q "sparkle-signatures:" "$APPCAST"
grep -q "sparkle:edSignature=" "$APPCAST"
grep -q "sparkle:version=\"$BUILD_NUMBER\"\|<sparkle:version>$BUILD_NUMBER</sparkle:version>" "$APPCAST"
grep -q "sparkle:shortVersionString=\"$VERSION\"\|<sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>" "$APPCAST"
grep -q "https://github.com/hmbakhsh/rootie/releases/download/v$VERSION/Rootie.zip" "$APPCAST"

SIGNATURE=$(xmllint --xpath 'string(//*[local-name()="enclosure"]/@*[local-name()="edSignature"])' "$APPCAST")
APPCAST_LENGTH=$(xmllint --xpath 'string(//*[local-name()="enclosure"]/@length)' "$APPCAST")
[[ "$APPCAST_LENGTH" == "$(stat -f%z "$ARCHIVE")" ]]

if [[ -n "${SPARKLE_PRIVATE_KEY:-}" ]]; then
  print -rn -- "$SPARKLE_PRIVATE_KEY" | "$SPARKLE_BIN/sign_update" \
    --ed-key-file - --verify "$APPCAST"
  print -rn -- "$SPARKLE_PRIVATE_KEY" | "$SPARKLE_BIN/sign_update" \
    --ed-key-file - --verify "$ARCHIVE" "$SIGNATURE"
else
  "$SPARKLE_BIN/sign_update" --account io.github.hmbakhsh.rootie --verify "$APPCAST"
  "$SPARKLE_BIN/sign_update" --account io.github.hmbakhsh.rootie \
    --verify "$ARCHIVE" "$SIGNATURE"
fi
