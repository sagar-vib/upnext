#!/bin/bash
# Builds Upnext.app from the Swift package.
#   ./build.sh               build and launch from ./build
#   ./build.sh --install     build, copy to /Applications and launch
#   ./build.sh --build-only  build without launching (used by CI)
# Signs with your Apple Development certificate when there is one, or the identity in
# CODESIGN_IDENTITY. macOS 26 and later only show desktop widgets signed by a team, and
# a certificate also keeps the calendar permission between rebuilds. Without one it signs
# ad hoc: the app works, but the widget won't appear in the gallery.
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Upnext"
APP_DIR="build/${APP_NAME}.app"
WIDGET_NAME="UpnextWidget"
APPEX_DIR="$APP_DIR/Contents/PlugIns/${WIDGET_NAME}.appex"

IDENTITY="${CODESIGN_IDENTITY:-}"
if [[ -z "$IDENTITY" ]]; then
  IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null | sed -nE 's/.*"(Apple Development: [^"]+)".*/\1/p' | head -1)"
fi
if [[ -z "$IDENTITY" ]]; then
  IDENTITY="-"
  echo "warning: no Apple Development certificate found, so signing ad hoc. The desktop widget won't appear in the widget gallery; see Signing in the README." >&2
elif [[ "$IDENTITY" != "-" ]] && ! security find-identity -v -p codesigning | grep -qF -- "$IDENTITY"; then
  echo "error: no signing identity matches \"$IDENTITY\". The identities on this Mac:" >&2
  security find-identity -v -p codesigning >&2
  exit 1
fi
echo "Signing with: $IDENTITY"

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

# The desktop widget. It's signed first, sandboxed as WidgetKit requires, so the app's
# signature can seal it.
mkdir -p "$APPEX_DIR/Contents/MacOS"
cp "$BIN_DIR/$WIDGET_NAME" "$APPEX_DIR/Contents/MacOS/$WIDGET_NAME"
cp Resources/UpnextWidget-Info.plist "$APPEX_DIR/Contents/Info.plist"
# macOS caches a widget's description per build number, so each build gets a new one.
BUILD_NUMBER="$(date +1.%y%m%d.%H%M%S)"
plutil -replace CFBundleVersion -string "$BUILD_NUMBER" "$APP_DIR/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$BUILD_NUMBER" "$APPEX_DIR/Contents/Info.plist"
codesign --force --sign "$IDENTITY" --entitlements Resources/UpnextWidget.entitlements "$APPEX_DIR"
codesign --force --sign "$IDENTITY" "$APP_DIR"

MODE="${1:-}"
if [[ "$MODE" == "--build-only" ]]; then
  echo "Built $APP_DIR"
  exit 0
fi

pkill -x "$APP_NAME" 2>/dev/null || true
# A widget process from the previous build keeps drawing its old version until it exits.
pkill -x "$WIDGET_NAME" 2>/dev/null || true

if [[ "$MODE" == "--install" ]]; then
  rm -rf "/Applications/${APP_NAME}.app"
  cp -R "$APP_DIR" /Applications/
  # Only one copy of the widget may be registered, or the two take turns in the gallery.
  pluginkit -r "$PWD/$APPEX_DIR" 2>/dev/null || true
  pluginkit -a "/Applications/${APP_NAME}.app/Contents/PlugIns/${WIDGET_NAME}.appex" 2>/dev/null || true
  open "/Applications/${APP_NAME}.app"
  echo "Installed /Applications/${APP_NAME}.app"
else
  open "$APP_DIR"
  echo "Built $APP_DIR"
fi
