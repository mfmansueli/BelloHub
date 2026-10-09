#!/usr/bin/env bash
# Usage: scripts/sync-server-contract.sh [--check]
# Copies the backend's published schemas (firebase/functions/contracts/schemas.json) into the test bundle
# (BelloHubTests/Resources/ServerContract/), where the request-shape tests read them. --check fails on drift.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="$ROOT/firebase/functions/contracts/schemas.json"
COPY="$ROOT/BelloHubTests/Resources/ServerContract/schemas.json"
if [[ "${1:-}" == "--check" ]]; then
    if ! cmp -s "$SOURCE" "$COPY"; then
        echo "error: $COPY differs from $SOURCE. Run scripts/sync-server-contract.sh and commit." >&2
        exit 1
    fi
    echo "server contract copy matches firebase/functions/contracts/schemas.json"
    exit 0
fi
mkdir -p "$(dirname "$COPY")"
cp "$SOURCE" "$COPY"
echo "copied the server contract into the test bundle"
