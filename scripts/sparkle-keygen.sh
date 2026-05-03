#!/usr/bin/env bash
# One-time: generate the EdDSA key pair Sparkle uses to sign app updates.
#
# The PRIVATE key is stored in your macOS Keychain (Sparkle uses it via
# `sign_update`). The PUBLIC key is printed here — paste it into the
# SU_PUBLIC_ED_KEY environment variable when running build-app.sh, or hard-code
# it into the Info.plist generation in build-app.sh.
#
# Usage:
#   ./scripts/sparkle-keygen.sh
#
# After this:
#   SU_PUBLIC_ED_KEY="<the-printed-key>" ./scripts/build-app.sh release
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# generate_keys ships inside the Sparkle SwiftPM checkout under a host-arch
# subfolder. Resolve it.
GEN=$(find "${ROOT}/.build" -name "generate_keys" -type f 2>/dev/null | head -1)
if [[ -z "${GEN}" ]]; then
  echo "generate_keys not found. Run a build first:" >&2
  echo "  swift build -c release" >&2
  exit 1
fi

echo "Generating Sparkle EdDSA key pair…"
"${GEN}"
echo
echo "The PRIVATE key is now in your macOS Keychain (item: Sparkle private key)."
echo "Copy the public key above into Info.plist's SUPublicEDKey, or pass it via:"
echo "  SU_PUBLIC_ED_KEY=\"<key>\" ./scripts/build-app.sh release"
