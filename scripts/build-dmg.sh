#!/usr/bin/env bash
# Build a distributable Soffit.dmg from build/Soffit.app.
# Usage: ./scripts/build-dmg.sh
#
# Output: ./build/Soffit-<version>.dmg
#
# The .app inside is ad-hoc signed but NOT notarized. First-run on a fresh
# Mac will require: right-click → Open → Open in the Gatekeeper dialog.
# Notarized distribution requires an Apple Developer cert; out of scope here.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${ROOT}/build/Soffit.app"
BUILD_DIR="${ROOT}/build"

if [[ ! -d "${APP}" ]]; then
  echo "Soffit.app missing — run ./scripts/build-app.sh first." >&2
  exit 1
fi

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "${APP}/Contents/Info.plist")
DMG_NAME="Soffit-${VERSION}.dmg"
DMG="${BUILD_DIR}/${DMG_NAME}"

# Stage in a clean folder so the DMG only contains what we want to ship.
STAGE="${BUILD_DIR}/dmg-stage"
rm -rf "${STAGE}" "${DMG}"
mkdir -p "${STAGE}"
cp -R "${APP}" "${STAGE}/Soffit.app"
ln -s /Applications "${STAGE}/Applications"

hdiutil create \
  -volname "Soffit ${VERSION}" \
  -srcfolder "${STAGE}" \
  -ov \
  -format UDZO \
  "${DMG}" >/dev/null

# Ad-hoc sign the DMG too so users see consistent (unsigned-but-not-tampered)
# attribution rather than two different warnings.
codesign --force --sign - --timestamp=none "${DMG}" 2>/dev/null || true

rm -rf "${STAGE}"

SIZE=$(du -h "${DMG}" | awk '{print $1}')
echo
echo "✓ built ${DMG} (${SIZE})"
echo "  open ${DMG}    # to mount and verify"
