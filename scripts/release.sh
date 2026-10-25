#!/bin/zsh
# Publishes a release end to end:  ./scripts/release.sh 0.5.0
# Tags it, waits for CI to build, sign and publish the release, then bumps the
# Homebrew cask. Installed copies pick it up through the Sparkle appcast.
set -euo pipefail

VERSION="${1:?usage: ./scripts/release.sh MAJOR.MINOR.PATCH}"
APP_REPOSITORY="hmbakhsh/rootie"
TAP_REPOSITORY="hmbakhsh/homebrew-tap"
CASK="Casks/rootie.rb"

[[ "$VERSION" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]] || {
  echo "Version must use MAJOR.MINOR.PATCH." >&2
  exit 1
}

git tag "v$VERSION"
git push origin "v$VERSION"

echo "Waiting for the release build…"
RUN=""
until [[ -n "$RUN" ]]; do
  sleep 5
  RUN=$(gh run list -R "$APP_REPOSITORY" --workflow release.yml --branch "v$VERSION" -L 1 \
    --json databaseId -q '.[0].databaseId')
done
gh run watch "$RUN" -R "$APP_REPOSITORY" --exit-status

TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT
gh release download "v$VERSION" -R "$APP_REPOSITORY" -p Rootie.zip -D "$TEMP_DIR"
SHA=$(shasum -a 256 "$TEMP_DIR/Rootie.zip" | cut -d' ' -f1)

FILE=$(gh api "repos/$TAP_REPOSITORY/contents/$CASK")
CONTENT=$(jq -r .content <<<"$FILE" | base64 -d |
  sed -E "s/^  version \".*\"/  version \"$VERSION\"/; s/^  sha256 \".*\"/  sha256 \"$SHA\"/")
gh api -X PUT "repos/$TAP_REPOSITORY/contents/$CASK" \
  -f message="chore: update Rootie to $VERSION" \
  -f content="$(print -r -- "$CONTENT" | base64)" \
  -f sha="$(jq -r .sha <<<"$FILE")" >/dev/null

echo "Released $VERSION. Installed copies update themselves within 6 hours."
