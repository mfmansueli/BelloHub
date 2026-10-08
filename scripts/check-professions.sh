#!/usr/bin/env bash
# Usage: scripts/check-professions.sh
# Checks the fourteen profession catalogs (docs/07-LOCALIZATION.md section 5) and fails on any gap.
set -euo pipefail
exec python3 "$(cd "$(dirname "$0")" && pwd)/check-professions.py" "$@"
