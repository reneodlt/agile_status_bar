#!/bin/bash
#
# Renders the App Store screenshots into docs/app-store/ at 2880×1800.
#
# Tools/make-screenshots.swift needs the app's own view code, so this compiles
# the sources alongside it — everything bar main.swift and AppDelegate.swift,
# which carry the real entry point and would collide with the tool's.
#
# Prices are fetched live from the Octopus public API, so this needs a network
# connection and the output changes with the market.

set -euo pipefail

OUT="${1:-docs/app-store}"
BIN="$(mktemp -d)/make-screenshots"

echo "==> Compiling"
# The settings footer reads CFBundleShortVersionString from Bundle.main, which
# a bare executable does not have — without this it photographs as "Agile Bar
# dev". Embedding the real Info.plist in __TEXT,__info_plist gives the tool the
# same version the app will ship with.
xcrun swiftc -O \
  Sources/OctoStatusBar/Models/*.swift \
  Sources/OctoStatusBar/Services/*.swift \
  Sources/OctoStatusBar/Util/*.swift \
  Sources/OctoStatusBar/Views/*.swift \
  Tools/make-screenshots.swift \
  -Xlinker -sectcreate -Xlinker __TEXT -Xlinker __info_plist -Xlinker Resources/Info.plist \
  -o "$BIN"

echo "==> Fetching prices and rendering"
"$BIN" "$OUT"
