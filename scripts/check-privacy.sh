#!/usr/bin/env bash
# Privacy gate (docs/06-PRIVACY-SECURITY.md section 11 item 8, docs/13-TESTING-QUALITY.md section 4).
# Fails when the architecture boundaries are crossed. Run by check-warnings.sh and in CI.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/BelloHub"
failed=0

# fail <message> <matches>: prints the offenders and marks the run as failed.
fail() {
    echo "error: $1" >&2
    echo "$2" | sed 's/^/  /' >&2
    failed=1
}

# 1. Firebase modules only inside the booking, session and bootstrap managers (ASSUMPTION-4).
hits="$(grep -rEn '^[[:space:]]*(@_exported[[:space:]]+)?import[[:space:]]+Firebase' "$APP" --include='*.swift' \
    | grep -vE "$APP/Managers/(Booking|Session|Firebase)/" || true)"
[[ -z "$hits" ]] || fail "Firebase imported outside Managers/Booking, Managers/Session and Managers/Firebase" "$hits"

# 2. SwiftData and CloudKit only inside Managers/Persistence.
hits="$(grep -rEn '^[[:space:]]*import[[:space:]]+(SwiftData|CloudKit|CoreData)' "$APP" --include='*.swift' \
    | grep -v "$APP/Managers/Persistence/" || true)"
[[ -z "$hits" ]] || fail "SwiftData, CloudKit or CoreData imported outside Managers/Persistence" "$hits"

# 3. No print or NSLog outside DEBUG-only files. A file counts as DEBUG-only when it declares #if DEBUG.
hits=""
while IFS= read -r file; do
    grep -q '#if DEBUG' "$file" && continue
    found="$(grep -En '(^|[^A-Za-z_.])(print|NSLog)\(' "$file" || true)"
    [[ -z "$found" ]] || hits+="$file:"$'\n'"$found"$'\n'
done < <(grep -rlE '(print|NSLog)\(' "$APP" --include='*.swift' || true)
[[ -z "$hits" ]] || fail "print( or NSLog( outside a #if DEBUG file" "$hits"

# 4. No analytics or crash-reporting SDK: no client text may leave the phone through telemetry.
hits="$(grep -rEn '^[[:space:]]*import[[:space:]]+(FirebaseAnalytics|FirebaseCrashlytics|FirebasePerformance|Sentry|Mixpanel|Amplitude|AppsFlyer)' \
    "$APP" --include='*.swift' || true)"
[[ -z "$hits" ]] || fail "analytics or crash SDK imported" "$hits"

# 4b. Photos never reach the camera roll: no photo-library write API in the app (comments may name it).
hits="$(grep -rEn 'PHPhotoLibrary|UIImageWriteToSavedPhotosAlbum|PHAssetChangeRequest' "$APP" --include='*.swift' \
    | grep -vE '^[^:]+:[0-9]+:[[:space:]]*(//|\*|/\*)' || true)"
[[ -z "$hits" ]] || fail "photo library write API used (photos stay in the vault, never the camera roll)" "$hits"

# 5. Web: no browser storage in the pages that can hold a health answer (when web/ exists).
if [[ -d "$ROOT/web/src/routes" ]]; then
    hits="$(grep -rEn 'localStorage|sessionStorage|document\.cookie' \
        "$ROOT/web/src/routes/form" "$ROOT/web/src/routes/checkin" "$ROOT/web/src/routes/data" 2>/dev/null \
        | grep -vE '^[^:]+:[0-9]+:[[:space:]]*(//|\*|/\*)' || true)"
    [[ -z "$hits" ]] || fail "browser storage used in a sealed-form route" "$hits"
fi

# 6. Functions: no console.log of request bodies (when firebase/functions exists).
if [[ -d "$ROOT/firebase/functions/src" ]]; then
    hits="$(grep -rEn 'console\.(log|info|debug)\([^)]*(req\.body|request\.data|\.body)' "$ROOT/firebase/functions/src" || true)"
    [[ -z "$hits" ]] || fail "request body logged in a function" "$hits"
fi

# 7. Privacy manifest (docs/store/app-privacy.md): it exists, it says no tracking, and every required-reason API
#    category the app's code uses is declared in it. A new use means a new NSPrivacyAccessedAPITypes entry, not a
#    silent submission rejection.
MANIFEST="$APP/SupportFiles/PrivacyInfo.xcprivacy"
if [[ ! -f "$MANIFEST" ]]; then
    fail "privacy manifest missing" "$MANIFEST"
else
    grep -A1 '<key>NSPrivacyTracking</key>' "$MANIFEST" | grep -q '<false/>' \
        || fail "privacy manifest must declare NSPrivacyTracking false" "$MANIFEST"
    # category|pattern of the APIs Apple lists for it (code only; comments may name them)
    while IFS='|' read -r category pattern; do
        hits="$(grep -rEn "$pattern" "$APP" --include='*.swift' | grep -vE '^[^:]+:[0-9]+:[[:space:]]*(//|\*|/\*)' || true)"
        if [[ -n "$hits" ]] && ! grep -q "$category" "$MANIFEST"; then
            fail "required-reason API used but $category is not in PrivacyInfo.xcprivacy" "$hits"
        fi
    done <<'EOF'
NSPrivacyAccessedAPICategoryUserDefaults|UserDefaults|@AppStorage
NSPrivacyAccessedAPICategoryFileTimestamp|creationDate|modificationDate|ModificationDate|attributesOfItem|getattrlist|fstat\(|lstat\(|[^a-z]stat\(
NSPrivacyAccessedAPICategoryDiskSpace|volumeAvailableCapacity|volumeTotalCapacity|systemFreeSize|systemSize|statfs|statvfs
NSPrivacyAccessedAPICategorySystemBootTime|systemUptime|mach_absolute_time
NSPrivacyAccessedAPICategoryActiveKeyboards|activeInputModes
EOF
fi

if [[ "$failed" == 0 ]]; then
    echo "Privacy checks passed"
fi
exit "$failed"
