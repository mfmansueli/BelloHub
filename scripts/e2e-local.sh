#!/usr/bin/env bash
# Usage: scripts/e2e-local.sh
#
# The S8 exit criterion (docs/03-BUILD-PLAN.md): the client web app against the REAL functions, end to end, with no mock.
#   1. builds firebase/functions and the web app in its `e2e-local` mode (same-origin /api, production phone verifier)
#   2. starts the Hosting, Functions, Firestore, Auth and Storage emulators on ports of their own (firebase.e2e.json is
#      generated from firebase.json for this run: the Hosting block, its /api rewrites and its headers are the real ones)
#   3. seeds Maria through the owner API (firebase/functions/scripts/seed.ts: page, hours, health form, one device)
#   4. runs the Playwright story in web/test/e2e-local: book (email code 123456), move, sealed intake, cancel, outbox
#
# Like the other wrappers it prints only failures and a result line; the full log goes to build/logs/. Everything runs on
# the local emulators with the demo project id `demo-bellohub`, which can never reach the cloud. Ports: E2E_LOCAL_PORT_BASE
# (default 25000) picks the block; when any port of the block is busy (another agent's emulators) the next block is tried.
source "$(dirname "$0")/lib.sh"

FIREBASE_DIR="$ROOT/firebase"
FUNCTIONS_DIR="$FIREBASE_DIR/functions"
WEB="$ROOT/web"
PROJECT="demo-bellohub"
STAMP="$(date +%Y%m%d-%H%M%S)"
LOG="$LOG_DIR/e2e-local-$STAMP.log"
E2E_CONFIG="$FIREBASE_DIR/firebase.e2e.json"
INNER="$ROOT/build/e2e-local-inner-$STAMP.sh"
: > "$LOG"
echo "Full log: ${LOG#"$ROOT"/}"

if [[ "$PROJECT" != demo-* ]]; then
    echo "error: the emulator project id must start with demo- so it can never reach the cloud" >&2
    exit 1
fi
for tool in node npm java firebase; do
    command -v "$tool" > /dev/null || {
        echo "error: $tool is not installed (see firebase/README.md, Requirements)" >&2
        exit 1
    }
done

cleanup() {
    rm -f "$E2E_CONFIG" "$INNER"
}
trap cleanup EXIT

# step <name> <command...>: appends everything to the log, prints only the failing lines.
step() {
    local name="$1"
    shift
    local out
    out="$(mktemp "${TMPDIR:-/tmp}/e2e-local.XXXXXX")"
    printf '\n===== %s =====\n' "$name" >> "$LOG"
    if "$@" > "$out" 2>&1; then
        cat "$out" >> "$LOG"
        rm -f "$out"
        return 0
    fi
    cat "$out" >> "$LOG"
    echo "** $name FAILED **"
    grep -E '^\s*✘|^\s+[0-9]+\) \[|Error|error|FAIL|failed|timed out' "$out" | grep -vE '^\s*✓|0 errors|Error Context:|test-results/' | head -40 || true
    rm -f "$out"
    return 1
}

in_dir() {
    local dir="$1"
    shift
    (cd "$dir" && "$@")
}

# MARK: - Ports

port_free() {
    ! lsof -nP -iTCP:"$1" -sTCP:LISTEN > /dev/null 2>&1
}

# A block of eight ports from a base: hosting, functions, firestore, auth, storage, pubsub, hub, logging. The defaults
# never collide with firebase.json (5001, 8080, 9099, 9199), firebase.test.json (15001, 18080, ...) or the web mock (4010).
pick_ports() {
    local base="${E2E_LOCAL_PORT_BASE:-25000}" attempt
    for attempt in 0 1 2 3 4; do
        local candidate=$((base + attempt * 1000))
        PORT_HOSTING=$((candidate + 80))
        PORT_FUNCTIONS=$((candidate + 1))
        PORT_FIRESTORE=$((candidate + 2))
        PORT_AUTH=$((candidate + 3))
        PORT_STORAGE=$((candidate + 4))
        PORT_PUBSUB=$((candidate + 5))
        PORT_HUB=$((candidate + 6))
        PORT_LOGGING=$((candidate + 7))
        local busy=0 port
        for port in "$PORT_HOSTING" "$PORT_FUNCTIONS" "$PORT_FIRESTORE" "$PORT_AUTH" "$PORT_STORAGE" "$PORT_PUBSUB" "$PORT_HUB" "$PORT_LOGGING"; do
            port_free "$port" || busy=1
        done
        if [[ "$busy" == 0 ]]; then
            return 0
        fi
        echo "note: ports around $candidate are busy (another emulator run?); trying the next block"
    done
    echo "error: no free port block found; set E2E_LOCAL_PORT_BASE" >&2
    exit 1
}
pick_ports

# MARK: - Build

# The emulators and the functions read secrets from this file; these are fakes used only here (never a real value).
if [[ ! -f "$FUNCTIONS_DIR/.secret.local" ]]; then
    printf 'PHONE_HASH_PEPPER=local-test-pepper-not-a-secret\n' > "$FUNCTIONS_DIR/.secret.local"
fi
if ! grep -q '^EMAIL_API_KEY=' "$FUNCTIONS_DIR/.secret.local"; then
    printf 'EMAIL_API_KEY=unset\n' >> "$FUNCTIONS_DIR/.secret.local"
fi
# Same for the Sign in with Apple key (D44): never read while APPLE_SIGNIN_KEY_ID is empty.
if ! grep -q '^APPLE_SIGNIN_PRIVATE_KEY=' "$FUNCTIONS_DIR/.secret.local"; then
    printf 'APPLE_SIGNIN_PRIVATE_KEY=unset\n' >> "$FUNCTIONS_DIR/.secret.local"
fi

if [[ ! -d "$FUNCTIONS_DIR/node_modules" || "$FUNCTIONS_DIR/package-lock.json" -nt "$FUNCTIONS_DIR/node_modules/.package-lock.json" ]]; then
    step "npm ci (functions)" in_dir "$FUNCTIONS_DIR" npm ci --no-audit --no-fund || exit 1
fi
if [[ ! -d "$WEB/node_modules" ]]; then
    step "npm ci (web)" in_dir "$WEB" npm ci || exit 1
fi
step "playwright browsers" in_dir "$WEB" npx playwright install chromium || exit 1
step "build functions" in_dir "$FUNCTIONS_DIR" npm run build --silent || exit 1
step "build web (e2e-local)" in_dir "$WEB" npm run build:e2e-local || exit 1

# firebase.e2e.json = firebase.json with this run's ports, the e2e web build as the Hosting root and no emulator UI.
# Paths inside are relative to firebase/, so the file must live there; it is git-ignored and removed on exit.
E2E_CONFIG="$E2E_CONFIG" PORT_HOSTING="$PORT_HOSTING" PORT_FUNCTIONS="$PORT_FUNCTIONS" PORT_FIRESTORE="$PORT_FIRESTORE" \
PORT_AUTH="$PORT_AUTH" PORT_STORAGE="$PORT_STORAGE" PORT_PUBSUB="$PORT_PUBSUB" PORT_HUB="$PORT_HUB" PORT_LOGGING="$PORT_LOGGING" \
node -e '
const fs = require("fs");
const config = JSON.parse(fs.readFileSync(process.env.E2E_CONFIG.replace(/firebase\.e2e\.json$/, "firebase.json"), "utf8"));
const port = (name) => Number(process.env[name]);
config.hosting.public = "../web/dist-e2e-local";
delete config.hosting.predeploy;
for (const target of config.functions) delete target.predeploy;
config.emulators = {
  hub: { port: port("PORT_HUB") },
  logging: { port: port("PORT_LOGGING") },
  hosting: { port: port("PORT_HOSTING") },
  functions: { port: port("PORT_FUNCTIONS") },
  firestore: { port: port("PORT_FIRESTORE") },
  auth: { port: port("PORT_AUTH") },
  storage: { port: port("PORT_STORAGE") },
  pubsub: { port: port("PORT_PUBSUB") },
  ui: { enabled: false },
  singleProjectMode: true
};
fs.writeFileSync(process.env.E2E_CONFIG, JSON.stringify(config, null, 2) + "\n");
'

# MARK: - Run

# What runs inside `emulators:exec` (which sets FIRESTORE_EMULATOR_HOST and friends): the seed, then the story.
cat > "$INNER" <<EOF
set -euo pipefail
cd "$FUNCTIONS_DIR"
FUNCTIONS_BASE="http://127.0.0.1:$PORT_FUNCTIONS/$PROJECT/europe-west1" \\
FIREBASE_AUTH_EMULATOR_HOST="127.0.0.1:$PORT_AUTH" \\
SEED_DEVICE_TOKEN="e2e-local-iphone-fcm-token-not-real" \\
npx tsx scripts/seed.ts
cd "$WEB"
E2E_LOCAL_BASE="http://127.0.0.1:$PORT_HOSTING" \\
E2E_FIRESTORE_HOST="127.0.0.1:$PORT_FIRESTORE" \\
npx playwright test -c playwright.e2e-local.config.ts
EOF

status=0
if ! step "emulators + seed + story (hosting $PORT_HOSTING, functions $PORT_FUNCTIONS)" in_dir "$FIREBASE_DIR" \
    firebase emulators:exec --config firebase.e2e.json --project "$PROJECT" --only hosting,functions,firestore,auth,storage "bash $INNER"; then
    status=1
    grep -E '^\s+[0-9]+\) \[' "$LOG" | tail -20 || true
fi

if [[ "$status" == 0 ]]; then
    summary="$(grep -E '^\s+[0-9]+ passed' "$LOG" | tail -1 | tr -s ' ' || true)"
    echo "** E2E LOCAL SUCCEEDED **${summary:+ ($summary)}"
else
    echo "** E2E LOCAL FAILED **"
fi
exit "$status"
