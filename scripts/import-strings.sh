#!/usr/bin/env bash
# Usage: scripts/import-strings.sh <localization> <file.csv> [--reviewed]
# Reads a reviewer's corrections (columns key, en, <localization>, comment, state) back into the catalog.
# Values that changed are stored as `translated` only with --reviewed, which a human passes after reading
# the language; otherwise they stay `needs_review`. Derived localizations cannot be imported: edit the
# parent or Config/Locale/overrides/<id>.json instead.
set -euo pipefail
exec python3 "$(cd "$(dirname "$0")" && pwd)/import-strings.py" "$@"
