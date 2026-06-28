#!/usr/bin/env bash
set -euo pipefail

APP_NAME="CodexMeter"
DISPLAY_NAME="Codex Meter"
BUNDLE_ID="dev.opensource.codexmeter"
MIN_SYSTEM_VERSION="13.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
PACKAGE_ROOT="${PACKAGE_WORK_DIR:-/private/tmp/codexmeter-package-$$}"
RELEASE_DIR="$PACKAGE_ROOT/release"
STAGE_DIR="$PACKAGE_ROOT/dmg-stage"
APP_BUNDLE="$RELEASE_DIR/$DISPLAY_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
RESOURCE_BUNDLE_NAME="CodexMeter_CodexMeter.bundle"

VERSION="${VERSION:-}"
if [[ -z "$VERSION" ]]; then
  VERSION="$(git -C "$ROOT_DIR" describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || true)"
fi
VERSION="${VERSION:-0.1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-$(date +%Y%m%d%H%M)}"
VOLUME_NAME="${VOLUME_NAME:-Codex Meter}"
OUTPUT_DIR="${OUTPUT_DIR:-$DIST_DIR}"
DMG_NAME="${DMG_NAME:-CodexMeter-$VERSION.dmg}"
DMG_PATH="$OUTPUT_DIR/$DMG_NAME"
CHECKSUM_PATH="$DMG_PATH.sha256"
SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}"

cd "$ROOT_DIR"

safe_remove() {
  local target="$1"
  case "$target" in
    "$PACKAGE_ROOT" | "$DMG_PATH" | "$CHECKSUM_PATH")
      /bin/rm -rf "$target"
      ;;
    *)
      echo "Refusing to remove unexpected path: $target" >&2
      exit 1
      ;;
  esac
}

cleanup() {
  if [[ "${KEEP_PACKAGE_WORKDIR:-0}" != "1" ]]; then
    safe_remove "$PACKAGE_ROOT"
  fi
}
trap cleanup EXIT

verify_dmg() {
  local attempt
  for attempt in 1 2 3 4 5; do
    if /usr/bin/hdiutil verify "$DMG_PATH"; then
      return 0
    fi

    if [[ "$attempt" == "5" ]]; then
      return 1
    fi

    sleep 2
  done
}

mkdir -p "$DIST_DIR" "$OUTPUT_DIR"
safe_remove "$PACKAGE_ROOT"
if [[ -f "$DMG_PATH" ]]; then
  safe_remove "$DMG_PATH"
fi
if [[ -f "$CHECKSUM_PATH" ]]; then
  safe_remove "$CHECKSUM_PATH"
fi

swift build -c release
BUILD_DIR="$(swift build -c release --show-bin-path)"
BUILD_BINARY="$BUILD_DIR/$APP_NAME"

mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

if [[ -f "$ROOT_DIR/Resources/AppIcon.icns" ]]; then
  cp "$ROOT_DIR/Resources/AppIcon.icns" "$APP_RESOURCES/AppIcon.icns"
fi

if [[ -d "$BUILD_DIR/$RESOURCE_BUNDLE_NAME" ]]; then
  /usr/bin/ditto "$BUILD_DIR/$RESOURCE_BUNDLE_NAME" "$APP_RESOURCES/$RESOURCE_BUNDLE_NAME"
fi

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$DISPLAY_NAME</string>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$DISPLAY_NAME</string>
  <key>CFBundleLocalizations</key>
  <array>
    <string>en</string>
    <string>zh-Hans</string>
    <string>ja</string>
    <string>ko</string>
  </array>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHumanReadableCopyright</key>
  <string>MIT License</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

/usr/bin/xattr -cr "$APP_BUNDLE" 2>/dev/null || true

codesign_args=(--force --deep --sign "$SIGN_IDENTITY")
if [[ "$SIGN_IDENTITY" != "-" ]]; then
  codesign_args+=(--options runtime --timestamp)
fi

/usr/bin/codesign "${codesign_args[@]}" "$APP_BUNDLE"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

mkdir -p "$STAGE_DIR"
/usr/bin/ditto "$APP_BUNDLE" "$STAGE_DIR/$DISPLAY_NAME.app"
/usr/bin/xattr -cr "$STAGE_DIR/$DISPLAY_NAME.app" 2>/dev/null || true
/usr/bin/codesign --verify --deep --strict --verbose=2 "$STAGE_DIR/$DISPLAY_NAME.app"
ln -s /Applications "$STAGE_DIR/Applications"

cat >"$STAGE_DIR/README.txt" <<README
Codex Meter

Drag "Codex Meter.app" into Applications, then open it from there.

This local build is signed ad-hoc by default and is not notarized unless you
set CODE_SIGN_IDENTITY to a Developer ID Application certificate before
running script/package_dmg.sh.
README

/usr/bin/hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGE_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

verify_dmg
/usr/bin/shasum -a 256 "$DMG_PATH" > "$CHECKSUM_PATH"

echo "$DMG_PATH"
echo "$CHECKSUM_PATH"
