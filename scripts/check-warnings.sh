#!/usr/bin/env bash
# Run before declaring a feature done. Clean builds for simulator, device and Release,
# failing on any warning. Zero warnings is the rule, even for ones you didn't cause.
source "$(dirname "$0")/lib.sh"

"$ROOT/scripts/check-project-settings.sh"

failed=0

# check <label> <log-name> <xcodebuild arguments...>
check() {
    local label="$1" name="$2"
    shift 2
    echo "== $label"
    if ! run_xcodebuild "$name" clean build -scheme BelloHub "$@"; then
        echo "error: $label did not build" >&2
        failed=1
        return
    fi
    if [[ -n "$(real_warnings "$LAST_LOG")" ]]; then
        echo "error: $label has warnings (see above)" >&2
        failed=1
    fi
}

simulator="$(simulator_destination)"
check "Simulator, Debug" check-sim-debug -configuration Debug -destination "$simulator"
check "Device, Debug" check-device-debug -configuration Debug -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO
check "Simulator, Release" check-sim-release -configuration Release -destination "$simulator"

if [[ "$failed" == 0 ]]; then
    echo "Zero warnings on simulator, device and Release."
fi
exit "$failed"
