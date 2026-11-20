#!/bin/bash
# Builds Upnext.app from the Swift package.
#   ./build.sh               build and launch from ./build
#   ./build.sh --install     build, copy to /Applications and launch
#   ./build.sh --build-only  build without launching (used by CI)
# Set CODESIGN_IDENTITY="Apple Development: you@example.com" to sign with your
# own certificate so macOS keeps the calendar permission between rebuilds.
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Upnext"
APP_DIR="build/${APP_NAME}.app"
IDENTITY="${CODESIGN_IDENTITY:--}"

SWIFT_FLAGS=(-c release)
# The default Swift Build system fails with "Unknown error parsing property list" when only
# the Command Line Tools are installed (swiftlang/swift-package-manager#10561).
if [[ "$(xcode-select -p)" == */CommandLineTools ]]; then
  SWIFT_FLAGS+=(--build-system native)
fi
swift build "${SWIFT_FLAGS[@]}"
BIN_DIR="$(swift build "${SWIFT_FLAGS[@]}" --show-bin-path)"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN_DIR/$APP_NAME" "$APP_DIR/Contents/MacOS/$APP_NAME"
cp Resources/Info.plist "$APP_DIR/Contents/Info.plist"
codesign --force --sign "$IDENTITY" "$APP_DIR"

MODE="${1:-}"
if [[ "$MODE" == "--build-only" ]]; then
  echo "Built $APP_DIR"
  exit 0
fi

pkill -x "$APP_NAME" 2>/dev/null || true

if [[ "$MODE" == "--install" ]]; then
  rm -rf "/Applications/${APP_NAME}.app"
  cp -R "$APP_DIR" /Applications/
  open "/Applications/${APP_NAME}.app"
  echo "Installed /Applications/${APP_NAME}.app"
else
  open "$APP_DIR"
  echo "Built $APP_DIR"
fi
