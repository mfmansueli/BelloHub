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

# The cheap gates (strings, privacy, legal drafts, the server contract, profession and health form catalogs) run
# before the simulator does (docs/13-TESTING-QUALITY.md).
if [[ "$plan" != "UISmoke" ]]; then
    "$ROOT/scripts/check-strings.sh" > /dev/null
    "$ROOT/scripts/check-privacy.sh" > /dev/null
    "$ROOT/scripts/check-legal-status.sh" > /dev/null
    "$ROOT/scripts/check-server-contract.sh" > /dev/null
    "$ROOT/scripts/check-professions.sh" > /dev/null
    "$ROOT/scripts/check-health-forms.sh" > /dev/null
fi

# The server suites (firebase/functions) need Java and the Firebase emulators and take minutes, so they never run by
# default and the iOS plans stay fast. Opt in with RUN_FIREBASE=1, or run scripts/test-firebase.sh directly.
if [[ "${RUN_FIREBASE:-0}" == "1" ]]; then
    "$ROOT/scripts/test-firebase.sh" all
fi

# Assigned on its own line so a missing simulator stops the script (set -e ignores $(...) in arguments).
destination="$(simulator_destination)"

# ONLY_TESTING=BelloHubUITests/OnboardingAuditUITests runs one suite (or one test) of the plan, to iterate on a failure.
only_testing=()
if [[ -n "${ONLY_TESTING:-}" ]]; then only_testing=(-only-testing:"$ONLY_TESTING"); fi

run_xcodebuild "test-$plan" test \
    -scheme BelloHub \
    -testPlan "$plan" \
    -destination "$destination" \
    ${only_testing[@]+"${only_testing[@]}"}
