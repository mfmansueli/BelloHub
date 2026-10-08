#!/usr/bin/env bash
# Shared by the other scripts. Source it, don't run it.
#
# Rules it enforces (see CLAUDE.md, section 7):
#  - one DerivedData per checkout, inside the repo (build/DerivedData)
#  - one xcodebuild at a time per checkout
#  - only errors, warnings and failures are printed; the full log goes to build/logs/
#  - no simulator is ever created: an existing one is picked

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="$ROOT/build/DerivedData"
LOG_DIR="$ROOT/build/logs"
LOCK_DIR="$ROOT/build/.xcodebuild.lock"
LAST_LOG=""
LOCK_HELD=0

# Xcode's App Intents extractor prints "warning: Metadata extraction skipped" for every target of
# an app that doesn't use App Intents. It is log noise, not an Xcode issue, and no setting silences
# it (LM_FILTER_WARNINGS does not), so it is dropped here. Remove this once App Intents are adopted.
TOOL_NOISE='appintentsmetadataprocessor'

mkdir -p "$LOG_DIR"

# Prints the xcodebuild destination. Override with SIM_UDID, or SIM_NAME (default "iPhone 17").
# Among simulators with that name it picks the oldest runtime >= iOS 26, our minimum.
simulator_destination() {
    if [[ -n "${SIM_UDID:-}" ]]; then
        echo "platform=iOS Simulator,id=$SIM_UDID"
        return
    fi
    local udid
    export SIM_NAME="${SIM_NAME:-iPhone 17}"
    udid="$(xcrun simctl list devices available -j | python3 -c '
import json, os, sys
name = os.environ["SIM_NAME"]
found = []
for runtime, devices in json.load(sys.stdin)["devices"].items():
    if "iOS-" not in runtime:
        continue
    version = tuple(int(part) for part in runtime.split("iOS-")[1].split("-"))
    if version < (26, 0):
        continue
    found += [(version, d["udid"]) for d in devices if d["name"] == name]
if found:
    print(sorted(found)[0][1])
')"
    if [[ -z "$udid" ]]; then
        echo "error: no available '$SIM_NAME' simulator on iOS 26+. Set SIM_NAME or SIM_UDID." >&2
        exit 1
    fi
    echo "platform=iOS Simulator,id=$udid"
}

acquire_lock() {
    [[ "$LOCK_HELD" == 1 ]] && return
    mkdir -p "$ROOT/build"
    if ! mkdir "$LOCK_DIR" 2>/dev/null; then
        local pid
        pid="$(cat "$LOCK_DIR/pid" 2>/dev/null || true)"
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            echo "error: another xcodebuild is running in this checkout (pid $pid)" >&2
            exit 1
        fi
        rm -rf "$LOCK_DIR"
        mkdir "$LOCK_DIR"
    fi
    echo $$ > "$LOCK_DIR/pid"
    LOCK_HELD=1
    trap 'rm -rf "$LOCK_DIR"' EXIT
}

# run_xcodebuild <log-name> <xcodebuild arguments...>
# Sets LAST_LOG to the full log and returns xcodebuild's exit status.
#
# Xcode 27 sometimes keeps `xcodebuild test` alive for minutes after the tests have finished (nothing is
# running; the process sits idle). A watchdog stops it once the log shows the test run is complete and has not
# grown for 30 seconds, and takes the verdict from the log, so a finished run never blocks the next one.
# The filtered summary is printed when the run ends, not live.
run_xcodebuild() {
    local name="$1"
    shift
    acquire_lock
    LAST_LOG="$LOG_DIR/$name-$(date +%Y%m%d-%H%M%S).log"
    echo "Full log: ${LAST_LOG#"$ROOT"/}"
    : > "$LAST_LOG"

    xcodebuild "$@" \
        -project "$ROOT/BelloHub.xcodeproj" \
        -derivedDataPath "$DERIVED_DATA" > "$LAST_LOG" 2>&1 &
    local build_pid=$!

    local last_size=-1 idle_since=$SECONDS size hung=0
    while kill -0 "$build_pid" 2>/dev/null; do
        size="$(wc -c < "$LAST_LOG" | tr -d ' ')"
        if [[ "$size" != "$last_size" ]]; then
            last_size="$size"
            idle_since=$SECONDS
        elif (( SECONDS - idle_since >= 30 )) && test_run_finished "$LAST_LOG"; then
            hung=1
            kill "$build_pid" 2>/dev/null || true
            break
        fi
        sleep 1
    done

    local status=0
    wait "$build_pid" 2>/dev/null || status=$?
    if [[ "$hung" == 1 ]]; then
        if grep -qE '✘ Test run|Test Case .* failed|\*\* TEST FAILED \*\*' "$LAST_LOG"; then
            status=1
            echo "** TEST FAILED ** (xcodebuild did not exit after the run; stopped by the watchdog)"
        else
            status=0
            echo "** TEST SUCCEEDED ** (xcodebuild did not exit after the run; stopped by the watchdog)"
        fi
    fi
    # Only errors, warnings and results are printed; the full log stays in build/logs/.
    { grep -E '(error|warning):|\*\* [A-Z ]+ \*\*|Test Case .* failed|✘' "$LAST_LOG" | grep -v "$TOOL_NOISE" || true; }
    return "$status"
}

# test_run_finished <log>: true when Swift Testing or XCTest has printed its final summary.
test_run_finished() {
    grep -qE "^(✔|✘) Test run with [0-9]+ tests?|^Test Suite '(All|Selected) tests' (passed|failed)" "$1"
}

# real_warnings <log>: the warnings in a full log, minus the known tool noise.
real_warnings() {
    grep -E 'warning:' "$1" | grep -v "$TOOL_NOISE" || true
}
