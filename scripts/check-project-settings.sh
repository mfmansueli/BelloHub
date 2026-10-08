#!/usr/bin/env bash
# Fails if project.pbxproj holds any build setting. They belong in Config/*.xcconfig.
set -euo pipefail

pbxproj="$(cd "$(dirname "$0")/.." && pwd)/BelloHub.xcodeproj/project.pbxproj"

offenders="$(awk '
    /buildSettings = \{/ { inside = 1; next }
    inside && /^[[:space:]]*\};/ { inside = 0; next }
    inside { print "  line " NR ": " $0 }
' "$pbxproj")"

if [[ -n "$offenders" ]]; then
    echo "error: build settings found in project.pbxproj. Move them to Config/*.xcconfig:" >&2
    echo "$offenders" >&2
    exit 1
fi
echo "project.pbxproj has no inline build settings"
