#!/usr/bin/env bash
# Build a proper Soffit.app bundle from the SPM executable.
# Usage: ./scripts/build-app.sh [debug|release]   (default: release)
#
# Output: ./build/Soffit.app
# Re-run any time after `swift build`.
set -euo pipefail

CONFIG="${1:-release}"
# SOFFIT_VARIANT controls which build to produce:
#   appstore (default) → sandboxed, no terminal, App Store-ready.
#   pro                → embedded terminal, Sparkle auto-update, sold via DMG.
VARIANT="${SOFFIT_VARIANT:-appstore}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${ROOT}/build"
APP="${BUILD_DIR}/Soffit.app"
BIN_SRC="${ROOT}/.build/${CONFIG}/Soffit"
ICON_SRC="${ROOT}/Sources/Soffit/Resources/AppIcon.icns"
RES_SRC="${ROOT}/Sources/Soffit/Resources"
BUNDLE_SRC="${ROOT}/.build/${CONFIG}/Soffit_Soffit.bundle"

VERSION="0.3.0"
BUILD_NUM="$(date +%Y%m%d%H%M)"

echo "→ building Soffit (variant=${VARIANT}, config=${CONFIG})"

# Compile with the right SOFFIT_PRO define for the variant.
if [[ "${VARIANT}" == "pro" ]]; then
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
# `ditto --noextattr --noqtn` so we don't carry FinderInfo/quarantine xattrs
# across — codesign rejects bundles that have them.
if [[ -d "${BUNDLE_SRC}" ]]; then
  ditto --noextattr --noqtn "${BUNDLE_SRC}" "${APP}/Contents/Resources/$(basename "${BUNDLE_SRC}")"
fi

# Embed Sparkle.framework. Sparkle is a binary framework (XCFramework) and
# needs to live at Contents/Frameworks/ for the app to dlopen it at runtime.
SPARKLE_SRC=$(find "${ROOT}/.build" -path '*/release/Sparkle.framework' -type d | head -1)
if [[ -n "${SPARKLE_SRC}" && -d "${SPARKLE_SRC}" ]]; then
  mkdir -p "${APP}/Contents/Frameworks"
  ditto --noextattr --noqtn "${SPARKLE_SRC}" "${APP}/Contents/Frameworks/Sparkle.framework"
fi

# Strip macOS xattrs that codesign rejects ("resource fork, Finder information,
# or similar detritus not allowed"). Vendored binaries sometimes carry these.
xattr -cr "${APP}" 2>/dev/null || true

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

# Pick entitlements per variant. The Pro build doesn't apply the App Sandbox
# (we need to exec /bin/bash for the terminal), so we use a minimal set with
# hardened runtime + JIT/library exceptions. The App Store build uses the
# full sandbox.
if [[ "${VARIANT}" == "pro" ]]; then
  ENTITLEMENTS="${ROOT}/Resources/Soffit-Pro.entitlements"
else
  ENTITLEMENTS="${ROOT}/Resources/Soffit.entitlements"
fi

# Final xattr cleanup. macOS auto-stamps bundle dirs with FinderInfo and
# fileprovider attrs which codesign rejects ("resource fork, Finder
# information, or similar detritus not allowed"). The kernel will
# *re-add* these the moment we touch the bundle, so we have to clear and
# codesign back-to-back in the same shell pipeline.
find "${APP}" -name '._*' -delete 2>/dev/null || true
find "${APP}" -name '.DS_Store' -delete 2>/dev/null || true
xattr -cr "${APP}" 2>/dev/null || true

# `--deep` walks nested bundles (Sparkle.framework, Soffit_Soffit.bundle)
# bottom-up so the outer signature seals them. Without it, a sandboxed
# bundle ends up linker-signed and `Sealed Resources=none`, which fails
# App Store submission. The `xattr -c "${APP}" &&` chain strips FinderInfo
# off the outer .app immediately before codesign reads it.
if [[ -f "${ENTITLEMENTS}" ]]; then
  xattr -c "${APP}" 2>/dev/null
  codesign --force --deep \
           --sign - \
           --timestamp=none \
           --entitlements "${ENTITLEMENTS}" \
           --options runtime \
           "${APP}" 2>&1 | sed 's/^/  codesign: /' || true
else
  xattr -c "${APP}" 2>/dev/null
  codesign --force --deep --sign - --timestamp=none "${APP}" 2>&1 | sed 's/^/  codesign: /' || true
fi

echo
echo "✓ built ${APP}"
echo "  version ${VERSION} build ${BUILD_NUM}"
echo "  open ${APP}    # to launch"
