#!/usr/bin/env bash
# Usage: scripts/test.sh [fast|smoke|full]   (default: full)
#   fast  = unit tests only        (test plan Fast)
#   smoke = one UI test per flow   (test plan UISmoke)
#   full  = everything             (test plan Full)
source "$(dirname "$0")/lib.sh"

case "${1:-full}" in
    fast) plan="Fast" ;;
    smoke) plan="UISmoke" ;;
    full) plan="Full" ;;
    *)
        echo "usage: scripts/test.sh [fast|smoke|full]" >&2
        exit 2
        ;;
esac

# Assigned on its own line so a missing simulator stops the script (set -e ignores $(...) in arguments).
destination="$(simulator_destination)"

run_xcodebuild "test-$plan" test \
    -scheme BelloHub \
    -testPlan "$plan" \
    -destination "$destination"
