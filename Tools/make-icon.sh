#!/bin/bash
#
# Regenerates the app icon from Tools/make-icon.swift, in both the forms macOS
# wants: a .icns for ./build.sh, and an asset catalog for the App Store.
#
# The .iconset, the .icns and Assets.xcassets are all gitignored — the source of
# truth is the drawing code, so the binary artefacts stay out of the repo.

set -euo pipefail

ICONSET="Resources/AppIcon.iconset"
CATALOG="Resources/Assets.xcassets"
APPICONSET="$CATALOG/AppIcon.appiconset"

echo "==> Rendering icon images"
rm -rf "$ICONSET"
swift Tools/make-icon.swift "$ICONSET"

echo "==> Packing AppIcon.icns"
iconutil --convert icns "$ICONSET" --output Resources/AppIcon.icns

# App Store validation rejects a bundle whose icon is only a loose .icns
# ("does not have an icon in ICNS format containing a 512pt x 512pt @2x image",
# which is misleading — the .icns is fine and does contain it). Uploads need the
# icon compiled into Assets.car and named by CFBundleIconName, so build the
# catalog from the same PNGs.
echo "==> Building $CATALOG"
rm -rf "$CATALOG"
mkdir -p "$APPICONSET"
cp "$ICONSET"/*.png "$APPICONSET/"

printf '{\n  "info" : {\n    "author" : "xcode",\n    "version" : 1\n  }\n}\n' > "$CATALOG/Contents.json"

{
  printf '{\n  "images" : [\n'
  first=1
  for size in 16 32 128 256 512; do
    for scale in 1 2; do
      [ "$scale" = 1 ] && file="icon_${size}x${size}.png" || file="icon_${size}x${size}@2x.png"
      [ "$first" = 1 ] && first=0 || printf ',\n'
      printf '    {\n      "filename" : "%s",\n      "idiom" : "mac",\n      "scale" : "%dx",\n      "size" : "%dx%d"\n    }' \
        "$file" "$scale" "$size" "$size"
    done
  done
  printf '\n  ],\n  "info" : {\n    "author" : "xcode",\n    "version" : 1\n  }\n}\n'
} > "$APPICONSET/Contents.json"

# Not `plutil -lint`: it infers the format from the .json extension, tries to
# read it as an OpenStep plist, and fails on valid JSON — non-zero here killed
# the whole script under `set -e` after the catalogue had already been written,
# so the files looked right while CI went red.
json_pp < "$APPICONSET/Contents.json" >/dev/null

echo "Wrote Resources/AppIcon.icns and $CATALOG"
