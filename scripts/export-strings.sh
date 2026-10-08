#!/usr/bin/env bash
# Usage: scripts/export-strings.sh [<localization>|all]   (default: all)
# Writes build/strings-<id>.csv for human reviewers: key, en, <localization>, comment, state.
# Reviewers edit the file; scripts/import-strings.sh reads the corrections back (task H10).
set -euo pipefail
exec python3 "$(cd "$(dirname "$0")" && pwd)/export-strings.py" "${1:-all}"
