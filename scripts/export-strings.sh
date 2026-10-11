#!/usr/bin/env bash
# Usage: scripts/export-strings.sh [<localization>|all]   (default: all)
# Writes build/strings-<id>.csv (app) and build/web-strings-<id>.csv (booking pages) for human reviewers:
# key, en, <localization>, comment, state. Reviewers edit the files; scripts/import-strings.sh reads the
# corrections back (task H10; the round trip is in docs/review/README.md).
set -euo pipefail
exec python3 "$(cd "$(dirname "$0")" && pwd)/export-strings.py" "${1:-all}"
