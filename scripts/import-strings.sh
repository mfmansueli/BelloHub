#!/usr/bin/env bash
# Usage: scripts/import-strings.sh <localization> <file.csv> [--reviewed] [--web]
#        scripts/import-strings.sh --self-test
# Reads a reviewer's corrections (columns key, en, <localization>, comment, state) back into the batches
# (Config/Locale/strings, Config/Locale/infoplist) or, with --web, into web/src/i18n/<id>.json. Then run
# scripts/merge-strings.py. --reviewed (a human who read the language) records the strings as approved, and
# merge-strings keeps them `translated` while their text is unchanged. Derived localizations cannot be
# imported: edit the parent or Config/Locale/overrides/<id>.json instead. Round trip: docs/review/README.md.
set -euo pipefail
exec python3 "$(cd "$(dirname "$0")" && pwd)/import-strings.py" "$@"
