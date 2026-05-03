#!/usr/bin/env bash
# Sign a release DMG with the Sparkle private key and emit an appcast.xml
# entry to stdout. Pipe the entry into your hosted appcast.xml so Soffit's
# auto-updater picks up the new version.
#
# Usage:
#   ./scripts/sparkle-sign-and-publish.sh build/Soffit-0.4.0.dmg 0.4.0
#
# Output: an XML <item> block on stdout suitable for inserting into appcast.xml.
set -euo pipefail
DMG="${1:?Usage: $0 <dmg> <version>}"
VERSION="${2:?Usage: $0 <dmg> <version>}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [[ ! -f "${DMG}" ]]; then
  echo "DMG not found: ${DMG}" >&2
  exit 1
fi

# Resolve the sign_update tool from the SwiftPM Sparkle checkout.
SIGN=$(find "${ROOT}/.build" -name "sign_update" -type f 2>/dev/null | head -1)
if [[ -z "${SIGN}" ]]; then
  echo "sign_update not found. Run swift build first." >&2
  exit 1
fi

SIGNATURE=$("${SIGN}" "${DMG}")
SIZE=$(stat -f%z "${DMG}")
PUBDATE=$(LC_ALL=en_US.UTF-8 date "+%a, %d %b %Y %H:%M:%S %z")
DMG_NAME=$(basename "${DMG}")

cat <<EOF
<item>
  <title>Soffit ${VERSION}</title>
  <pubDate>${PUBDATE}</pubDate>
  <sparkle:version>${VERSION}</sparkle:version>
  <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
  <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
  <enclosure
      url="https://github.com/lukataylo/soffit/releases/download/v${VERSION}/${DMG_NAME}"
      length="${SIZE}"
      type="application/octet-stream"
      ${SIGNATURE} />
</item>
EOF
