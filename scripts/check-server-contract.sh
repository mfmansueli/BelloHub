#!/usr/bin/env bash
# Usage: scripts/check-server-contract.sh
# Fails when the test bundle's copies of the backend's schemas and the shared mailbox vectors drifted from their sources.
set -euo pipefail
exec "$(cd "$(dirname "$0")" && pwd)/sync-server-contract.sh" --check
