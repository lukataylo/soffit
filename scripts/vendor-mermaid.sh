#!/usr/bin/env bash
# Vendor a copy of mermaid.min.js into the app bundle so the mermaid:// provider works offline.
# Usage: ./scripts/vendor-mermaid.sh [VERSION]   (default: 10.9.1)
set -euo pipefail
VERSION="${1:-10.9.1}"
DEST="Sources/Workbench/Resources/mermaid.min.js"
URL="https://unpkg.com/mermaid@${VERSION}/dist/mermaid.min.js"

echo "Fetching mermaid@${VERSION} from ${URL}"
if command -v curl >/dev/null 2>&1; then
  curl -fsSL "${URL}" -o "${DEST}"
elif command -v wget >/dev/null 2>&1; then
  wget -q "${URL}" -O "${DEST}"
else
  echo "Neither curl nor wget available — download manually and place at ${DEST}" >&2
  exit 1
fi
echo "Wrote $(wc -c < "${DEST}") bytes to ${DEST}"
