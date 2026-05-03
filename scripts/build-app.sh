#!/usr/bin/env bash
# Build a proper Soffit.app bundle from the SPM executable.
# Usage: ./scripts/build-app.sh [debug|release]   (default: release)
#
# Output: ./build/Soffit.app
# Re-run any time after `swift build`.
#
# Environment knobs:
#   SOFFIT_VARIANT  appstore | pro    (default: appstore)
#   SIGN_IDENTITY   codesign identity (default: -, i.e. ad-hoc).
#                   Use "Apple Distribution: …" for App Store uploads,
#                   or "Developer ID Application: …" for the Pro DMG.
#   SU_PUBLIC_ED_KEY / SU_FEED_URL   only consumed by the Pro variant.
set -euo pipefail

CONFIG="${1:-release}"
VARIANT="${SOFFIT_VARIANT:-appstore}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${ROOT}/build"
APP="${BUILD_DIR}/Soffit.app"
BIN_SRC="${ROOT}/.build/${CONFIG}/Soffit"
ICON_SRC="${ROOT}/Sources/Soffit/Resources/AppIcon.icns"
RES_SRC="${ROOT}/Sources/Soffit/Resources"
BUNDLE_SRC="${ROOT}/.build/${CONFIG}/Soffit_Soffit.bundle"

VERSION="0.3.0"
BUILD_NUM="$(date +%Y%m%d%H%M)"

if [[ "${VARIANT}" == "pro" ]]; then
  BUNDLE_ID="com.soffit.app.pro"
else
  BUNDLE_ID="com.soffit.app"
fi

echo "→ building Soffit (variant=${VARIANT}, config=${CONFIG}, sign=${SIGN_IDENTITY})"

# Compile with the right SOFFIT_PRO define for the variant. Also export
# SOFFIT_PRO=1 so Package.swift conditionally pulls in Sparkle/SwiftTerm
# only for the Pro build — App Store builds resolve neither dependency.
# Wipe .build between variants to avoid SPM caching the wrong dependency
# graph from a previous run.
rm -rf "${ROOT}/.build/${CONFIG}/Soffit" \
       "${ROOT}/.build/${CONFIG}/Soffit_Soffit.bundle" \
       "${ROOT}/.build/${CONFIG}/Sparkle.framework" 2>/dev/null || true

if [[ "${VARIANT}" == "pro" ]]; then
  SOFFIT_PRO=1 \
  DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}" \
    swift build -c "${CONFIG}" -Xswiftc -DSOFFIT_PRO >/dev/null
else
  DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}" \
    swift build -c "${CONFIG}" >/dev/null
fi

if [[ ! -x "${BIN_SRC}" ]]; then
  echo "Executable not found at ${BIN_SRC} after build." >&2
  exit 1
fi

if [[ ! -f "${ICON_SRC}" ]]; then
  echo "AppIcon.icns missing — run: swift scripts/generate-icon.swift" >&2
  exit 1
fi

rm -rf "${APP}"
mkdir -p "${APP}/Contents/MacOS" "${APP}/Contents/Resources"

cp "${BIN_SRC}" "${APP}/Contents/MacOS/Soffit"
chmod +x "${APP}/Contents/MacOS/Soffit"

# Pro embeds Sparkle.framework, so the executable needs an rpath to
# Contents/Frameworks/. App Store doesn't ship any frameworks so skip the
# rpath edit there — keeps the binary unmodified after `swift build`.
if [[ "${VARIANT}" == "pro" ]]; then
  install_name_tool -add_rpath "@executable_path/../Frameworks" \
    "${APP}/Contents/MacOS/Soffit" 2>/dev/null || true
fi

cp "${ICON_SRC}" "${APP}/Contents/Resources/AppIcon.icns"

# App Store requires PrivacyInfo.xcprivacy at Contents/Resources/ in the
# top-level bundle. Mirror it from the SPM resource directory.
PRIVACY_SRC="${ROOT}/Sources/Soffit/Resources/PrivacyInfo.xcprivacy"
if [[ -f "${PRIVACY_SRC}" ]]; then
  cp "${PRIVACY_SRC}" "${APP}/Contents/Resources/PrivacyInfo.xcprivacy"
fi

# Flatten the SPM resource bundle directly into Contents/Resources/. SPM
# generates a `Soffit_Soffit.bundle` next to the executable, but its
# auto-generated `Bundle.module` accessor only looks for that bundle at
# `Bundle.main.bundleURL/Soffit_Soffit.bundle` — which is `Soffit.app/`,
# not `Soffit.app/Contents/Resources/`. To keep the conventional macOS
# layout *and* let `Bundle.main.url(forResource:)` (via SoffitBundle.module)
# find resources, copy the inner `Resources/` contents flat into the
# .app's Contents/Resources/. `ditto --noextattr --noqtn` strips xattrs.
if [[ -d "${BUNDLE_SRC}/Resources" ]]; then
  ditto --noextattr --noqtn "${BUNDLE_SRC}/Resources/" "${APP}/Contents/Resources/"
fi

# Embed Sparkle.framework — Pro variant only. App Store apps must not
# bundle third-party update mechanisms (Apple guideline 2.4.5) and the
# framework requires `cs.disable-library-validation` to load under
# hardened runtime, which is incompatible with the App Sandbox.
if [[ "${VARIANT}" == "pro" ]]; then
  SPARKLE_SRC=$(find "${ROOT}/.build" -path '*/release/Sparkle.framework' -type d | head -1)
  if [[ -n "${SPARKLE_SRC}" && -d "${SPARKLE_SRC}" ]]; then
    mkdir -p "${APP}/Contents/Frameworks"
    ditto --noextattr --noqtn "${SPARKLE_SRC}" "${APP}/Contents/Frameworks/Sparkle.framework"
  fi
fi

# Strip macOS xattrs that codesign rejects.
xattr -cr "${APP}" 2>/dev/null || true

# Info.plist — Sparkle keys only included for Pro. App Store rejects
# SUFeedURL / SUPublicEDKey because they imply a non-MAS update channel.
if [[ "${VARIANT}" == "pro" ]]; then
  SPARKLE_KEYS="
  <key>SUFeedURL</key>
  <string>${SU_FEED_URL:-https://lukataylo.github.io/soffit/appcast.xml}</string>
  <key>SUEnableInstallerLauncherService</key>
  <true/>
  <key>SUPublicEDKey</key>
  <string>${SU_PUBLIC_ED_KEY:-REPLACE_WITH_KEYGEN_OUTPUT}</string>"
else
  SPARKLE_KEYS=""
fi

cat > "${APP}/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>            <string>Soffit</string>
  <key>CFBundleDisplayName</key>     <string>Soffit</string>
  <key>CFBundleIdentifier</key>      <string>${BUNDLE_ID}</string>
  <key>CFBundleVersion</key>         <string>${BUILD_NUM}</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundlePackageType</key>     <string>APPL</string>
  <key>CFBundleExecutable</key>      <string>Soffit</string>
  <key>CFBundleIconFile</key>        <string>AppIcon</string>
  <key>LSMinimumSystemVersion</key>  <string>14.0</string>
  <key>NSHighResolutionCapable</key> <true/>
  <key>NSSupportsAutomaticTermination</key> <true/>
  <key>NSSupportsSuddenTermination</key>    <true/>
  <key>NSPrincipalClass</key>        <string>NSApplication</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
  <key>NSAppleEventsUsageDescription</key>
  <string>Soffit uses Apple events to open files in your default editor.</string>${SPARKLE_KEYS}
</dict>
</plist>
EOF

# Pick entitlements per variant. Pro: hardened runtime + JIT/library
# exceptions, no sandbox (terminal subprocess needs full access). App
# Store: full sandbox + the four required-reason entitlements.
if [[ "${VARIANT}" == "pro" ]]; then
  ENTITLEMENTS="${ROOT}/Resources/Soffit-Pro.entitlements"
else
  ENTITLEMENTS="${ROOT}/Resources/Soffit.entitlements"
fi

# Final xattr cleanup. macOS auto-stamps bundle dirs (.framework / .bundle /
# .app / .xpc / .nib) with FinderInfo and fileprovider attrs which codesign
# rejects ("resource fork, Finder information, or similar detritus not
# allowed"). `xattr -cr` walks files but skips bundle-dir xattrs; clear
# each bundle dir explicitly.
find "${APP}" -name '._*' -delete 2>/dev/null || true
find "${APP}" -name '.DS_Store' -delete 2>/dev/null || true
xattr -cr "${APP}" 2>/dev/null || true
while IFS= read -r d; do
  xattr -c "$d" 2>/dev/null || true
done < <(find "${APP}" -type d \( -name "*.framework" -o -name "*.bundle" -o -name "*.app" -o -name "*.xpc" -o -name "*.nib" \))

# Sign nested bundles first (leaf → root). Apple's recommended signing
# order; also forces codesign to clear FinderInfo as a side effect on
# each bundle as it signs. Without this, the outer codesign aborts on
# the first nested dir that the kernel re-stamped with FinderInfo
# between our strip and the recursive walk.
if [[ "${VARIANT}" == "pro" ]]; then
  while IFS= read -r b; do
    xattr -c "$b" 2>/dev/null || true
    codesign --force --sign "${SIGN_IDENTITY}" --options runtime \
             --timestamp=none "$b" >/dev/null 2>&1 || true
  done < <(find "${APP}" -type d \( -name "*.xpc" -o -name "*.app" -o -name "*.framework" -o -name "*.bundle" \) -depth)
fi

if [[ -f "${ENTITLEMENTS}" ]]; then
  xattr -c "${APP}" 2>/dev/null
  codesign --force --options runtime \
           --sign "${SIGN_IDENTITY}" \
           --timestamp=none \
           --entitlements "${ENTITLEMENTS}" \
           "${APP}" 2>&1 | sed 's/^/  codesign: /' || true
else
  xattr -c "${APP}" 2>/dev/null
  codesign --force --options runtime \
           --sign "${SIGN_IDENTITY}" \
           --timestamp=none \
           "${APP}" 2>&1 | sed 's/^/  codesign: /' || true
fi

echo
echo "✓ built ${APP}"
echo "  variant ${VARIANT}   bundle ${BUNDLE_ID}"
echo "  version ${VERSION} build ${BUILD_NUM}"
echo "  open ${APP}    # to launch"
