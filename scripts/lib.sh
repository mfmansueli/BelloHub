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
run_xcodebuild() {
    local name="$1"
    shift
    acquire_lock
    LAST_LOG="$LOG_DIR/$name-$(date +%Y%m%d-%H%M%S).log"
    echo "Full log: ${LAST_LOG#"$ROOT"/}"

    local status
    set +e
    xcodebuild "$@" \
        -project "$ROOT/BelloHub.xcodeproj" \
        -derivedDataPath "$DERIVED_DATA" 2>&1 \
        | tee "$LAST_LOG" \
        | { grep -E '(error|warning):|\*\* [A-Z ]+ \*\*|Test Case .* failed|✘' | grep -v "$TOOL_NOISE" || true; }
    status="${PIPESTATUS[0]}"
    set -e
    return "$status"
}

# real_warnings <log>: the warnings in a full log, minus the known tool noise.
real_warnings() {
    grep -E 'warning:' "$1" | grep -v "$TOOL_NOISE" || true
}
