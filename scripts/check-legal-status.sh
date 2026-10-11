#!/usr/bin/env bash
# Usage: scripts/check-legal-status.sh [--write]
# Prints the status of every legal draft (docs/16-MARKETS.md section 2; owner decision D40) and fails if a document or
# a localization is missing or a text makes a forbidden claim. --write refreshes legal/STATUS.md.
set -euo pipefail
exec python3 "$(cd "$(dirname "$0")" && pwd)/check-legal-status.py" "$@"
