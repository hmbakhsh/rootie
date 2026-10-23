#!/bin/zsh
# Installs Rootie, or updates it from any older version (including Browser Router).
#   curl -fsSL https://raw.githubusercontent.com/hmbakhsh/rootie/main/scripts/install-release.sh | zsh
# VERSION=0.5.0 installs that release instead of the latest.
# ROOTIE_ARCHIVE=path/Rootie.zip installs a local build; ROOTIE_APP_DIR picks the folder;
# ROOTIE_NO_OPEN=1 skips launching it.
set -euo pipefail

REPOSITORY="${ROOTIE_REPOSITORY:-hmbakhsh/rootie}"
VERSION="${${VERSION:-}#v}"

if [[ -z "${ROOTIE_ARCHIVE:-}" ]]; then
  for CASKROOM in /opt/homebrew/Caskroom /usr/local/Caskroom; do
    [[ -d "$CASKROOM/rootie" || -d "$CASKROOM/browser-router" ]] || continue
    if [[ -n "$VERSION" ]]; then
      echo "Rootie is installed with Homebrew, which only installs the latest release." >&2
      exit 1
    fi
    echo "Updating Rootie with Homebrew…"
    brew update --quiet
    brew upgrade --cask rootie
    exit
  done
fi

if [[ -n "${ROOTIE_APP_DIR:-}" ]]; then
  APP_DIR="$ROOTIE_APP_DIR"
elif [[ -d /Applications/Rootie.app ]]; then
  APP_DIR=/Applications
else
  APP_DIR="$HOME/Applications"
fi
DESTINATION="$APP_DIR/Rootie.app"
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

if [[ -n "${ROOTIE_ARCHIVE:-}" ]]; then
  cp "$ROOTIE_ARCHIVE" "$TEMP_DIR/Rootie.zip"
else
  if [[ -n "$VERSION" ]]; then
    URL="https://github.com/$REPOSITORY/releases/download/v$VERSION/Rootie.zip"
  else
    URL="https://github.com/$REPOSITORY/releases/latest/download/Rootie.zip"
  fi
  echo "Downloading Rootie…"
  curl -fL "$URL" -o "$TEMP_DIR/Rootie.zip"
fi
ditto -x -k "$TEMP_DIR/Rootie.zip" "$TEMP_DIR"

for DIR in "$APP_DIR" "$HOME/Applications"; do
  for NAME in Rootie "Browser Router"; do
    pkill -f "^$DIR/$NAME.app/Contents/MacOS/" 2>/dev/null || true
  done
  rm -rf "$DIR/Browser Router.app"
done
mkdir -p "$APP_DIR"
rm -rf "$DESTINATION"
ditto "$TEMP_DIR/Rootie.app" "$DESTINATION"
if [[ "${ROOTIE_NO_OPEN:-}" != 1 ]]; then
  open -Ra "$DESTINATION"
  open "$DESTINATION"
fi

echo "Installed $DESTINATION"
