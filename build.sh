#!/bin/bash
#
# Builds OctoStatusBar.app for local use.
#
# This is the development path — it produces an ad-hoc signed bundle that runs
# on this machine. For Mac App Store submission use the Xcode project instead
# (see README § Distribution); Apple requires a Team ID signature and an
# uploaded archive, neither of which this script attempts.

set -euo pipefail

CONFIG="${1:-release}"
APP_NAME="OctoStatusBar"
BUILD_DIR="$(swift build -c "$CONFIG" --show-bin-path)"
APP="build/${APP_NAME}.app"

echo "==> Compiling ($CONFIG)"
swift build -c "$CONFIG"

echo "==> Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
cp Resources/Info.plist "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

if [ -f Resources/AppIcon.icns ]; then
  cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
else
  echo "    (no AppIcon.icns — run ./Tools/make-icon.sh first for a bundle icon)"
fi

echo "==> Signing (ad-hoc)"
codesign --force --deep \
  --sign - \
  --entitlements Resources/OctoStatusBar.entitlements \
  --options runtime \
  "$APP"

echo
echo "Built $APP"
echo "Run it with:  open $APP"
