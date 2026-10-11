#!/usr/bin/env bash
# Usage: scripts/check-health-forms.sh
# Checks the fourteen health form catalogs (docs/05-DATA-MODEL.md) and fails on any gap.
set -euo pipefail
exec python3 "$(cd "$(dirname "$0")" && pwd)/check-health-forms.py" "$@"
