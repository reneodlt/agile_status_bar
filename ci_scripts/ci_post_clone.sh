#!/bin/sh
#
# Xcode Cloud runs this after cloning, before it resolves dependencies and
# builds. Everything the Xcode build needs but the repo deliberately does not
# carry gets made here.
#
# Three things are gitignored on purpose — the .xcodeproj, Resources/AppIcon.icns
# and Resources/Assets.xcassets — because they are build artefacts generated from
# project.yml and Tools/make-icon.swift. That is fine on a laptop, where you run
# the tools before archiving, and fatal on a fresh clone, where nothing has run
# them. Without the asset catalog the upload is rejected for a missing 512pt@2x
# icon; without the project there is nothing to build at all.
set -eu

cd "$CI_PRIMARY_REPOSITORY_PATH"
echo "==> Working in $(pwd)"

echo "==> Installing XcodeGen"
brew install xcodegen

echo "==> Generating the icon (.icns + Assets.xcassets)"
./Tools/make-icon.sh

# project.yml ships DEVELOPMENT_TEAM empty so the repo carries no identity.
# The archive needs one, so the workflow supplies it as an environment
# variable and it is written in here rather than committed.
if [ -n "${DEVELOPMENT_TEAM:-}" ]; then
  echo "==> Setting DEVELOPMENT_TEAM from the workflow environment"
  /usr/bin/sed -i '' "s/DEVELOPMENT_TEAM: \"\"/DEVELOPMENT_TEAM: \"$DEVELOPMENT_TEAM\"/" project.yml
  grep -n 'DEVELOPMENT_TEAM:' project.yml
else
  echo "==> WARNING: DEVELOPMENT_TEAM is not set in this workflow's environment."
  echo "    An archive action will fail with \"requires a development team\"."
  echo "    Add it under Environment in the Xcode Cloud workflow settings."
fi

echo "==> Generating OctoStatusBar.xcodeproj"
xcodegen generate

echo "==> Done. Shared schemes:"
ls -1 OctoStatusBar.xcodeproj/xcshareddata/xcschemes/
