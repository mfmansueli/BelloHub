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

# The fourteen localizations (docs/07-LOCALIZATION.md section 1) must all be known regions, or Xcode
# drops the language from the app even though the String Catalog carries it.
expected="en Base pt-BR pt-PT es-MX es-419 es en-GB it fr de tr id hi ar"
actual="$(awk '
    /knownRegions = \(/ { inside = 1; next }
    inside && /^[[:space:]]*\);/ { inside = 0; next }
    inside { gsub(/[",[:space:]]/, ""); print }
' "$pbxproj" | sort | xargs)"
if [[ "$actual" != "$(echo "$expected" | xargs -n1 | sort | xargs)" ]]; then
    echo "error: knownRegions in project.pbxproj is [$actual], expected the fourteen localizations plus Base" >&2
    exit 1
fi
echo "knownRegions lists the fourteen localizations"

# The Info.plist fragment must list the same localizations and keep the silent-push background mode.
plist="$(cd "$(dirname "$0")/.." && pwd)/Config/App-Info.plist"
listed="$(plutil -extract CFBundleLocalizations json -o - "$plist" | tr -d '[]"' | tr ',' '\n' | sort | xargs)"
wanted="$(echo "pt-BR pt-PT es-MX es-419 es en-GB en it fr de tr id hi ar" | xargs -n1 | sort | xargs)"
if [[ "$listed" != "$wanted" ]]; then
    echo "error: CFBundleLocalizations in Config/App-Info.plist is [$listed], expected [$wanted]" >&2
    exit 1
fi
if ! plutil -extract UIBackgroundModes json -o - "$plist" | grep -q remote-notification; then
    echo "error: Config/App-Info.plist lost the remote-notification background mode" >&2
    exit 1
fi
echo "Info.plist fragment lists the fourteen localizations and remote-notification"
