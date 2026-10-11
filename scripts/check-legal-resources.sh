#!/usr/bin/env bash
# Usage: scripts/check-legal-resources.sh
# Fails when a bundled legal text (BelloHub/Resources/Legal/) is missing, differs from legal/, or has no source.
# Run by scripts/test.sh next to the other gates. Fix with scripts/sync-legal-resources.sh.
set -euo pipefail
exec python3 "$(cd "$(dirname "$0")" && pwd)/sync-legal-resources.py" --check
