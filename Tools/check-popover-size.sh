#!/bin/bash
#
# Checks the popover is sized from its content and fits a small display.
# See Tools/check-popover-size.swift for what it guards and why.
set -euo pipefail
BIN="$(mktemp -d)/check-popover-size"
xcrun swiftc -O \
  Sources/OctoStatusBar/Models/*.swift \
  Sources/OctoStatusBar/Services/*.swift \
  Sources/OctoStatusBar/Util/*.swift \
  Sources/OctoStatusBar/Views/*.swift \
  Tools/check-popover-size.swift \
  -Xlinker -sectcreate -Xlinker __TEXT -Xlinker __info_plist -Xlinker Resources/Info.plist \
  -o "$BIN"
"$BIN"
