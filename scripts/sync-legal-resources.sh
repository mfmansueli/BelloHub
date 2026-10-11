#!/usr/bin/env bash
# Usage: scripts/sync-legal-resources.sh
# Copies the legal notices the app shows (terms, privacy policy) from legal/ into BelloHub/Resources/Legal/ (flat, byte for byte).
# Run it after a legal text changes, then commit both. scripts/check-legal-resources.sh fails if they drift apart.
set -euo pipefail
exec python3 "$(cd "$(dirname "$0")" && pwd)/sync-legal-resources.py" "$@"
