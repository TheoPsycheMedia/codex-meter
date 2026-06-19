#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="CodexMeter"
DISPLAY_NAME="Codex Meter"
BUNDLE_ID="dev.opensource.codexmeter"
MIN_SYSTEM_VERSION="13.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"

cd "$ROOT_DIR"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true
pkill -f "/Applications/$DISPLAY_NAME.app/Contents/MacOS/$APP_NAME" >/dev/null 2>&1 || true
pkill -f "$ROOT_DIR/dist/$APP_NAME.app/Contents/MacOS/$APP_NAME" >/dev/null 2>&1 || true

swift build
BUILD_BINARY="$(swift build --show-bin-path)/$APP_NAME"

if [[ -d "$APP_BUNDLE" ]]; then
  case "$APP_BUNDLE" in
    "$ROOT_DIR"/dist/*.app) /bin/rm -rf "$APP_BUNDLE" ;;
    *) echo "Refusing to remove unexpected bundle path: $APP_BUNDLE" >&2; exit 1 ;;
  esac
fi

mkdir -p "$APP_MACOS" "$APP_RESOURCES"
# Use ditto --noextattr --norsrc rather than cp: the swift-built binary carries
# resource-fork/Finder-info metadata that makes `codesign --deep` fail with
# "resource fork, Finder information, or similar detritus not allowed". ditto
# rewrites the files clean.
/usr/bin/ditto --noextattr --norsrc "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

if [[ -f "$ROOT_DIR/Resources/AppIcon.icns" ]]; then
  /usr/bin/ditto --noextattr --norsrc "$ROOT_DIR/Resources/AppIcon.icns" "$APP_RESOURCES/AppIcon.icns"
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
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$DISPLAY_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

if command -v /usr/bin/codesign >/dev/null 2>&1; then
  # Strip extended attributes (e.g. com.apple.provenance) first: `codesign
  # --deep` intermittently fails with "resource fork, Finder information, or
  # similar detritus not allowed" when they're present on bundle files.
  /usr/bin/xattr -cr "$APP_BUNDLE" 2>/dev/null || true
  /usr/bin/codesign --force --deep --sign - "$APP_BUNDLE" >/dev/null
fi

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
