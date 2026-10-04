#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Builds a Developer ID-signed, notarized and stapled Crunchpad.dmg.
#
#   macos/release.sh 1.0.0             # build/Crunchpad-1.0.0.dmg
#   macos/release.sh 1.0.0 --publish   # also tag v1.0.0 and create a GitHub release
#
# One-time setup:
#   1. A "Developer ID Application" certificate in the login keychain
#      (Xcode > Settings > Accounts > Manage Certificates > +).
#   2. Notary credentials stored under the profile name "crunchpad":
#        xcrun notarytool store-credentials crunchpad \
#          --apple-id <you@example.com> --team-id <TEAMID> --password <app-specific password>
# Override with SIGN_IDENTITY / NOTARY_PROFILE if needed.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
VERSION="${1:?usage: release.sh <version> [--publish]}"
VERSION="${VERSION#v}"
PUBLISH="${2:-}"
REPO="jimpayne1/crunchpad"   # explicit: gh would otherwise target the fork's parent
PROFILE="${NOTARY_PROFILE:-crunchpad}"

IDENTITY="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning \
    | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' | head -1)}"
if [[ -z "$IDENTITY" ]]; then
    echo "No Developer ID Application certificate found (see setup notes in $0)." >&2
    exit 1
fi
if ! xcrun notarytool history --keychain-profile "$PROFILE" >/dev/null 2>&1; then
    echo "No notary credentials for profile '$PROFILE' (see setup notes in $0)." >&2
    exit 1
fi
if [[ -n "$(git -C "$ROOT" status --porcelain)" ]]; then
    echo "Working tree has uncommitted changes; commit before releasing." >&2
    exit 1
fi

BUILD="$ROOT/build"
APP="$BUILD/Crunchpad.app"
DMG="$BUILD/Crunchpad-$VERSION.dmg"

SIGN_IDENTITY="$IDENTITY" CRUNCHPAD_VERSION="$VERSION" "$HERE/build.sh"

notarize() {
    echo "==> Notarize $(basename "$1")"
    xcrun notarytool submit "$1" --keychain-profile "$PROFILE" --wait
}

# Notarize and staple the app itself so it passes Gatekeeper offline once
# copied out of the disk image.
ZIP="$BUILD/Crunchpad-$VERSION.zip"
ditto -c -k --keepParent "$APP" "$ZIP"
notarize "$ZIP"
xcrun stapler staple "$APP"
rm -f "$ZIP"

echo "==> Disk image"
STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -volname "Crunchpad $VERSION" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null
rm -rf "$STAGE"
codesign --force --sign "$IDENTITY" --timestamp "$DMG"
notarize "$DMG"
xcrun stapler staple "$DMG"

echo "==> Gatekeeper check"
spctl --assess --type execute --verbose "$APP"
spctl --assess --type open --context context:primary-signature --verbose "$DMG"
shasum -a 256 "$DMG"

if [[ "$PUBLISH" == "--publish" ]]; then
    echo "==> Publish v$VERSION"
    git -C "$ROOT" tag -a "v$VERSION" -m "Crunchpad $VERSION"
    git -C "$ROOT" push origin "v$VERSION"
    gh release create "v$VERSION" "$DMG" --repo "$REPO" --title "Crunchpad $VERSION" \
        --notes "Notarized build for macOS 15 and later (Apple silicon). Drag Crunchpad to Applications."
fi
echo "Done: $DMG"
