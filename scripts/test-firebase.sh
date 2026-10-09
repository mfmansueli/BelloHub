#!/usr/bin/env bash
# Usage: scripts/test-firebase.sh [all|static|unit|emulator|transport]   (default: all)
#   static    = ESLint (zero warnings), type check, build, npm audit
#   unit      = pure rules, templates, contracts (no emulator)
#   emulator  = Firestore rules + every use case against the Firestore, Auth and Storage emulators
#   transport = the deployed entry points through the Functions emulator (callable protocol, triggers)
#
# Everything runs on the LOCAL emulators with the demo project id `demo-bellohub`: a `demo-` id never reaches the
# cloud, so no data, rule or function is ever deployed or written anywhere real (docs/11-BACKEND-FIREBASE.md section 10).
# Like the other wrappers it prints only failures and the result; the full logs go to build/logs/.
# Needs: Node 20+ (functions declare 22), Java 17+ (the Firestore emulator) and firebase-tools.
source "$(dirname "$0")/lib.sh"

FIREBASE_DIR="$ROOT/firebase"
FUNCTIONS_DIR="$FIREBASE_DIR/functions"
PROJECT="demo-bellohub"
CONFIG="firebase.test.json"
STAMP="$(date +%Y%m%d-%H%M%S)"
mode="${1:-all}"

case "$mode" in
    all | static | unit | emulator | transport) ;;
    *)
        echo "usage: scripts/test-firebase.sh [all|static|unit|emulator|transport]" >&2
        exit 2
        ;;
esac

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

# The emulators and the tests read project secrets from the environment; these are fakes used only here. The email key
# is a placeholder: with EMAIL_FROM unset the provider stays disabled and the key is never read.
if [[ ! -f "$FUNCTIONS_DIR/.secret.local" ]]; then
    printf 'PHONE_HASH_PEPPER=local-test-pepper-not-a-secret\n' > "$FUNCTIONS_DIR/.secret.local"
fi
if ! grep -q '^EMAIL_API_KEY=' "$FUNCTIONS_DIR/.secret.local"; then
    printf 'EMAIL_API_KEY=unset\n' >> "$FUNCTIONS_DIR/.secret.local"
fi

if [[ ! -d "$FUNCTIONS_DIR/node_modules" || "$FUNCTIONS_DIR/package-lock.json" -nt "$FUNCTIONS_DIR/node_modules/.package-lock.json" ]]; then
    echo "Installing firebase/functions dependencies"
    (cd "$FUNCTIONS_DIR" && npm ci --no-audit --no-fund > "$LOG_DIR/firebase-install-$STAMP.log" 2>&1) || {
        tail -20 "$LOG_DIR/firebase-install-$STAMP.log" >&2
        exit 1
    }
fi

# run <name> <command...>: runs in firebase/functions or firebase/ as the command needs, logs everything, and prints
# the failing lines or the vitest summary.
run() {
    local name="$1"
    shift
    local log="$LOG_DIR/firebase-$name-$STAMP.log"
    if "$@" > "$log" 2>&1; then
        local summary
        summary="$(grep -E '^ +Tests +[0-9]+' "$log" | tr -s ' ' | paste -sd ';' - || true)"
        echo "ok   $name${summary:+ ($summary)}   [${log#"$ROOT"/}]"
    else
        echo "FAIL $name   [${log#"$ROOT"/}]" >&2
        grep -E 'FAIL|AssertionError|Error:|error TS|✖|×|problem' "$log" | grep -v 'Script "' | head -40 >&2 || tail -30 "$log" >&2
        exit 1
    fi
}

in_functions() {
    (cd "$FUNCTIONS_DIR" && "$@")
}

in_firebase() {
    (cd "$FIREBASE_DIR" && "$@")
}

# The audit needs the package registry; a network failure is reported, a vulnerability fails the run.
audit() {
    local out
    if out="$(cd "$FUNCTIONS_DIR" && npm audit --audit-level=high 2>&1)"; then
        echo "$out"
        return 0
    fi
    if echo "$out" | grep -qiE 'ENOTFOUND|ECONNREFUSED|EAI_AGAIN|network'; then
        echo "warning: npm audit could not reach the registry; skipped"
        return 0
    fi
    echo "$out"
    return 1
}

emulator_run() {
    local only="$1" script="$2"
    in_firebase firebase emulators:exec --config "$CONFIG" --project "$PROJECT" --only "$only" "$script"
}

if [[ "$mode" == all || "$mode" == static ]]; then
    run lint in_functions npm run lint --silent
    run typecheck in_functions npm run typecheck --silent
    run build in_functions npm run build --silent
    run audit audit
fi
if [[ "$mode" == all || "$mode" == unit ]]; then
    run unit in_functions npm run test:unit --silent
fi
if [[ "$mode" == all || "$mode" == emulator ]]; then
    run rules-and-use-cases emulator_run "firestore,auth,storage" "npm --prefix functions run test:rules --silent && npm --prefix functions run test:integration --silent"
fi
if [[ "$mode" == all || "$mode" == transport ]]; then
    # The Functions emulator runs the compiled code in lib/, so build it first (a no-op after "static").
    run build-for-emulator in_functions npm run build --silent
    run transport emulator_run "functions,firestore,auth,storage" "npm --prefix functions run test:transport --silent"
fi
echo "Firebase checks passed"
