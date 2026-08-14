#!/bin/bash
#
# Regenerates Resources/AppIcon.icns from Tools/make-icon.swift.
# Both the .iconset and the .icns are gitignored — the source of truth is the
# drawing code, so the binary artefacts stay out of the repo.

set -euo pipefail

ICONSET="Resources/AppIcon.iconset"

echo "==> Rendering icon images"
rm -rf "$ICONSET"
swift Tools/make-icon.swift "$ICONSET"

echo "==> Packing AppIcon.icns"
iconutil --convert icns "$ICONSET" --output Resources/AppIcon.icns

echo "Wrote Resources/AppIcon.icns"
