#!/usr/bin/env bash
# Usage: scripts/test-web.sh [quick|full]   (default: full)
#   quick = install if needed, lint, typecheck, i18n, contrast, privacy, unit tests, build with the size budget
#   full  = quick, then the Playwright suite (Chromium, WebKit and the throttled low-end project)
#
# The client web app (web/) has its own toolchain (npm); this wrapper gives it the rules of the other scripts:
# only failures and a result line are printed, the full log goes to build/logs/, one Playwright run at a time per
# checkout (it owns a port and a browser pool). E2E_PORT picks the mock server's port when 4010 is busy.
source "$(dirname "$0")/lib.sh"

case "${1:-full}" in
    quick) mode="quick" ;;
    full) mode="full" ;;
    *)
        echo "usage: scripts/test-web.sh [quick|full]" >&2
        exit 2
        ;;
esac

WEB="$ROOT/web"
WEB_LOCK_DIR="$ROOT/build/.playwright.lock"
LOG="$LOG_DIR/test-web-$mode-$(date +%Y%m%d-%H%M%S).log"
: > "$LOG"
echo "Full log: ${LOG#"$ROOT"/}"

if ! command -v node > /dev/null 2>&1; then
    echo "error: node >= 22.18 is required (web/package.json engines)" >&2
    exit 1
fi

# Prints the failing lines of a step's output, never the whole thing (a passing Playwright line starts with a tick).
failures() {
    grep -E '^\s*✘|^\s+[0-9]+\) \[|error|Error|FAIL|✖|[1-9][0-9]* problems?|not ok|over budget|failed' "$1" \
        | grep -vE '^\s*✓|0 problems|0 errors|no problems|errors="0"|Error Context:|test-results/' | head -40 || true
}

# step <name> <command...>: runs in web/, appends everything to the log, prints only failures.
step() {
    local name="$1"
    shift
    local out
    out="$(mktemp "${TMPDIR:-/tmp}/test-web.XXXXXX")"
    printf '\n===== %s =====\n' "$name" >> "$LOG"
    if (cd "$WEB" && "$@") > "$out" 2>&1; then
        cat "$out" >> "$LOG"
        rm -f "$out"
        return 0
    fi
    cat "$out" >> "$LOG"
    echo "** $name FAILED **"
    failures "$out"
    rm -f "$out"
    return 1
}

# Playwright owns a port and a browser pool: one run per checkout (the lock dies with the process).
acquire_playwright_lock() {
    mkdir -p "$ROOT/build"
    if ! mkdir "$WEB_LOCK_DIR" 2>/dev/null; then
        local pid
        pid="$(cat "$WEB_LOCK_DIR/pid" 2>/dev/null || true)"
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            echo "error: another Playwright run is active in this checkout (pid $pid)" >&2
            exit 1
        fi
        rm -rf "$WEB_LOCK_DIR"
        mkdir "$WEB_LOCK_DIR"
    fi
    echo $$ > "$WEB_LOCK_DIR/pid"
    trap 'rm -rf "$WEB_LOCK_DIR"' EXIT
}

status=0

# Install only when something is missing: npm ci is slow and the lockfile is the truth.
if [[ ! -d "$WEB/node_modules" ]]; then
    step "npm ci" npm ci || exit 1
fi
# A no-op when the browsers are already in the Playwright cache.
if [[ "$mode" == "full" ]]; then
    step "playwright browsers" npx playwright install chromium webkit || exit 1
fi
# The cross-implementation vectors are committed; the Python venv is only for regenerating them.
if [[ ! -d "$WEB/.venv" ]] && command -v python3 > /dev/null 2>&1; then
    (cd "$WEB" && python3 -m venv .venv && .venv/bin/pip install -q -r test/vectors/generate/requirements.txt) >> "$LOG" 2>&1 || echo "note: the Python venv for the vectors could not be created (optional; see web/test/vectors/generate/README.md)"
fi

step "lint" npm run lint || status=1
step "typecheck" npm run typecheck || status=1
step "i18n" npm run i18n || status=1
step "contrast" npm run contrast || status=1
step "privacy" npm run privacy || status=1
step "unit tests" npm test || status=1
step "build and size budget" npm run build || status=1

if [[ "$mode" == "full" && "$status" == 0 ]]; then
    acquire_playwright_lock
    # The e2e build is separate from the production one (its own API config); the mock serves it.
    step "e2e build" npm run build:e2e || status=1
    if [[ "$status" == 0 ]]; then
        if ! step "playwright" npx playwright test; then
            status=1
            # The failing tests, one per line, from the log of this step.
            grep -E '^\s+[0-9]+\) \[' "$LOG" | tail -40 || true
        fi
    fi
    # Lighthouse CI on the same build (performance >= 0.9 mobile, accessibility >= 0.95; web/lighthouserc.json). Without a
    # Chrome it prints the command for the owner and passes; LIGHTHOUSE=0 skips it on a slow machine.
    if [[ "$status" == 0 && "${LIGHTHOUSE:-1}" != 0 ]]; then
        step "lighthouse" npm run lighthouse || status=1
    fi
fi

# The measured numbers, so a passing run still says how far it is from the budgets (docs/10 section 1, S9 exit).
grep -E '^(ok|FAIL) +initial JavaScript|^lighthouse /' "$LOG" | sed 's/^/  /' || true

if [[ "$status" == 0 ]]; then
    echo "** WEB TESTS SUCCEEDED ($mode) **"
else
    echo "** WEB TESTS FAILED ($mode) **"
fi
exit "$status"
