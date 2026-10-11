#!/usr/bin/env bash
# Usage: scripts/check-strings.sh [--final]
# Localization gate (docs/07-LOCALIZATION.md section 9): all fourteen localizations present, plurals,
# placeholders, derived localizations current, no hard-coded text in Screens/. Part of test.sh fast.
set -euo pipefail
exec python3 "$(cd "$(dirname "$0")" && pwd)/check-strings.py" "$@"
