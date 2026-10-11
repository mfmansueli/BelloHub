#!/usr/bin/env bash
# Usage: scripts/check-localization-sources.sh [--self-test]
# Fails on Swift patterns that leave the app in the wrong language (routine-a item 1). Part of test.sh fast.
set -euo pipefail
exec python3 "$(cd "$(dirname "$0")" && pwd)/check-localization-sources.py" "$@"
