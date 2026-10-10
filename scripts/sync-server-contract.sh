#!/usr/bin/env bash
# Usage: scripts/sync-server-contract.sh [--check]
# Copies what the app's tests check against into the test bundle (BelloHubTests/Resources/ServerContract/):
# the backend's published schemas (firebase/functions/contracts/schemas.json) for the request-shape tests, and the
# sealed-mailbox vectors the web and the backend share (web/test/vectors/inbox-v1.json) for the HPKE suite test, and
# what the page's own code sealed (web/test/vectors/js-sealed.json) for the opener and payload readers.
# --check fails on drift.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/BelloHubTests/Resources/ServerContract"
PAIRS=(
    "$ROOT/firebase/functions/contracts/schemas.json:$DEST/schemas.json"
    "$ROOT/web/test/vectors/inbox-v1.json:$DEST/inbox-v1.json"
    "$ROOT/web/test/vectors/js-sealed.json:$DEST/js-sealed.json"
)
if [[ "${1:-}" == "--check" ]]; then
    for pair in "${PAIRS[@]}"; do
        source="${pair%%:*}"; copy="${pair##*:}"
        if ! cmp -s "$source" "$copy"; then
            echo "error: $copy differs from $source. Run scripts/sync-server-contract.sh and commit." >&2
            exit 1
        fi
    done
    echo "server contract and mailbox vectors in the test bundle match their sources"
    exit 0
fi
mkdir -p "$DEST"
for pair in "${PAIRS[@]}"; do cp "${pair%%:*}" "${pair##*:}"; done
echo "copied the server contract and the mailbox vectors into the test bundle"
