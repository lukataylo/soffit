#!/usr/bin/env bash
# Build a proper Soffit.app bundle from the SPM executable.
# Usage: ./scripts/build-app.sh [debug|release]   (default: release)
#
# Output: ./build/Soffit.app
# Re-run any time after `swift build`.
set -euo pipefail

CONFIG="${1:-release}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${ROOT}/build"
APP="${BUILD_DIR}/Soffit.app"
BIN_SRC="${ROOT}/.build/${CONFIG}/Soffit"
ICON_SRC="${ROOT}/Sources/Soffit/Resources/AppIcon.icns"
RES_SRC="${ROOT}/Sources/Soffit/Resources"
BUNDLE_SRC="${ROOT}/.build/${CONFIG}/Soffit_Soffit.bundle"

VERSION="0.3.0"
BUILD_NUM="$(date +%Y%m%d%H%M)"

if [[ ! -x "${BIN_SRC}" ]]; then
  echo "Executable not found at ${BIN_SRC}." >&2
  echo "Run: DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build -c ${CONFIG}" >&2
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

# Add the standard embedded-framework rpath. SPM doesn't emit this for raw
# executables; without it, dyld can't find Contents/Frameworks/Sparkle.framework
# when the bundle is launched.
install_name_tool -add_rpath "@executable_path/../Frameworks" \
  "${APP}/Contents/MacOS/Soffit" 2>/dev/null || true

cp "${ICON_SRC}" "${APP}/Contents/Resources/AppIcon.icns"

# App Store requires PrivacyInfo.xcprivacy at Contents/Resources/ in the
# top-level bundle. Mirror it from the SPM resource directory.
PRIVACY_SRC="${ROOT}/Sources/Soffit/Resources/PrivacyInfo.xcprivacy"
if [[ -f "${PRIVACY_SRC}" ]]; then
  cp "${PRIVACY_SRC}" "${APP}/Contents/Resources/PrivacyInfo.xcprivacy"
fi

# Carry the SPM resource bundle so Bundle.module continues to find mermaid-shim,
# mermaid.min.js, etc. SPM places it next to the executable as Soffit_Soffit.bundle.
if [[ -d "${BUNDLE_SRC}" ]]; then
  cp -R "${BUNDLE_SRC}" "${APP}/Contents/Resources/"
fi

# Embed Sparkle.framework. Sparkle is a binary framework (XCFramework) and
# needs to live at Contents/Frameworks/ for the app to dlopen it at runtime.
SPARKLE_SRC=$(find "${ROOT}/.build" -path '*/release/Sparkle.framework' -type d | head -1)
if [[ -n "${SPARKLE_SRC}" && -d "${SPARKLE_SRC}" ]]; then
  mkdir -p "${APP}/Contents/Frameworks"
  cp -R "${SPARKLE_SRC}" "${APP}/Contents/Frameworks/"
fi

cat > "${APP}/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>            <string>Soffit</string>
  <key>CFBundleDisplayName</key>     <string>Soffit</string>
  <key>CFBundleIdentifier</key>      <string>com.soffit.app</string>
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
  <string>Soffit uses Apple events to open files in your default editor.</string>

  <!-- Sparkle auto-update. Appcast hosted on GitHub Pages; the SUPublicEDKey
       must match the private key used to sign each release DMG. Generate via
       scripts/sparkle-keygen.sh once. -->
  <key>SUFeedURL</key>
  <string>${SU_FEED_URL:-https://lukataylo.github.io/soffit/appcast.xml}</string>
  <key>SUEnableInstallerLauncherService</key>
  <true/>
  <key>SUPublicEDKey</key>
  <string>${SU_PUBLIC_ED_KEY:-REPLACE_WITH_KEYGEN_OUTPUT}</string>
</dict>
</plist>
EOF

# Ad-hoc sign with the App Sandbox entitlements so the app behaves the same
# locally as it will in production. NOT notarized — the user will still see
# the "downloaded from internet" warning if they distribute it; that step
# requires an Apple Developer ID and `notarytool submit`.
ENTITLEMENTS="${ROOT}/Resources/Soffit.entitlements"
if [[ -f "${ENTITLEMENTS}" ]]; then
  codesign --force \
           --sign - \
           --timestamp=none \
           --entitlements "${ENTITLEMENTS}" \
           --options runtime \
           "${APP}" 2>&1 | sed 's/^/  codesign: /' || true
else
  codesign --force --sign - --timestamp=none "${APP}" 2>&1 | sed 's/^/  codesign: /' || true
fi

echo
echo "✓ built ${APP}"
echo "  version ${VERSION} build ${BUILD_NUM}"
echo "  open ${APP}    # to launch"
