#!/usr/bin/env bash
# Usage: scripts/build.sh [Debug|Release]
# Builds the app for the simulator. Prints only errors, warnings and the result.
source "$(dirname "$0")/lib.sh"

configuration="${1:-Debug}"
# Assigned on its own line so a missing simulator stops the script (set -e ignores $(...) in arguments).
destination="$(simulator_destination)"

run_xcodebuild "build-$configuration" build \
    -scheme BelloHub \
    -configuration "$configuration" \
    -destination "$destination"
