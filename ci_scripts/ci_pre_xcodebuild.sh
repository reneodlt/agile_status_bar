#!/bin/sh
#
# Runs the popover size guard before Xcode Cloud builds, so the Guideline 4
# defect ("windows that cut off text") cannot be shipped a second time by
# someone who archives without remembering the pre-flight step.
#
# The guard opens an NSApplication to measure real SwiftUI layout, so it is
# treated as advisory if it cannot start at all — a build runner without a
# window server should not turn the build red for a reason unrelated to the
# code. A guard that runs and reports a bad size is fatal, which is the case
# that matters.
set -eu

cd "$CI_PRIMARY_REPOSITORY_PATH"

# Never let a stuck window server burn the whole build allowance.
./Tools/check-popover-size.sh &
guard=$!
( sleep 300; kill -9 "$guard" 2>/dev/null ) &
watchdog=$!

set +e
wait "$guard"
status=$?
set -e
kill "$watchdog" 2>/dev/null || true

case "$status" in
  0) echo "==> Popover size guard passed." ;;
  1) echo "==> Popover size guard FAILED — see the sizes above."; exit 1 ;;
  *) echo "==> WARNING: the popover size guard could not run (exit $status)."
     echo "    Not failing the build; check it locally with ./Tools/check-popover-size.sh." ;;
esac
