#!/usr/bin/env bash
# Regenerates firebase/functions/test/fixtures/rules.fixture.json from the iOS rule types.
#
# The booking rules exist twice: in Swift (FreeSlotsCalculator, CancellationEvaluator, RegistrationQuota) and in
# TypeScript (functions/src/lib). This script compiles the REAL Swift sources with a small generator and writes the
# expected answers of many cases; the TypeScript unit tests read the same file, so a change on either side that is not
# mirrored on the other fails a test (docs/11-BACKEND-FIREBASE.md section 4).
#
# Needs Xcode's swiftc. Run it when one of the Swift rule files changes, and commit the JSON.
# Output goes to the repo only; nothing is compiled into the app.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
MODELS="$ROOT/BelloHub/Models"
OUT="$ROOT/firebase/functions/test/fixtures/rules.fixture.json"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/bellohub-rules-fixtures.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

swiftc -O -module-name RulesFixtures -o "$WORK/generate" \
    "$HERE/main.swift" \
    "$MODELS/Common/PersistedEnum.swift" \
    "$MODELS/Agenda/FreeSlotsCalculator.swift" \
    "$MODELS/Agenda/FreeSlotsCalculator+Day.swift" \
    "$MODELS/Agenda/FreeSlotsCalculator+Segments.swift" \
    "$MODELS/Agenda/FreeSlotsCalculator+Windows.swift" \
    "$MODELS/Agenda/FreeSlotsPlan.swift" \
    "$MODELS/Agenda/FreeSlotsRequest.swift" \
    "$MODELS/Agenda/TimedInterval.swift" \
    "$MODELS/Agenda/VisitTiming.swift" \
    "$MODELS/Business/AvailabilitySettings.swift" \
    "$MODELS/Business/AvailabilityRule.swift" \
    "$MODELS/Business/BreakRule.swift" \
    "$MODELS/Business/DayOff.swift" \
    "$MODELS/Business/DayOffKind.swift" \
    "$MODELS/Policy/CancellationEvaluator.swift" \
    "$MODELS/Policy/CancellationDecision.swift" \
    "$MODELS/Policy/CancellationPolicy.swift" \
    "$MODELS/Policy/AfterWindowCancel.swift" \
    "$MODELS/Policy/AfterWindowReschedule.swift" \
    "$MODELS/Plan/RegistrationQuota.swift" \
    "$MODELS/Plan/RegistrationDecision.swift"

"$WORK/generate" > "$OUT"
echo "wrote ${OUT#"$ROOT"/}"
