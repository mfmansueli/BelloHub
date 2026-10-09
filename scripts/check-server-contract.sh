#!/usr/bin/env bash
# Usage: scripts/check-server-contract.sh
# Fails when the test bundle's copy of the backend's schemas drifted from firebase/functions/contracts/schemas.json.
set -euo pipefail
exec "$(cd "$(dirname "$0")" && pwd)/sync-server-contract.sh" --check
