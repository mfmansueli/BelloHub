#!/usr/bin/env bash
# Usage: scripts/fetch-fonts.sh
# Downloads the official Fraunces and DM Sans variable fonts (SIL Open Font License) from the
# Google Fonts repository into the app and, once web/ exists, into the web app. Idempotent: files
# that are already present and valid are kept. Arabic and Devanagari use system fonts (no download).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE="https://raw.githubusercontent.com/google/fonts/main/ofl"
APP_DIR="$ROOT/BelloHub/DesignSystem/Fonts"
WEB_DIR="$ROOT/web/public/fonts"

# name | url path (percent-encoded) | local file name
FONTS=(
    "Fraunces|fraunces/Fraunces%5BSOFT%2CWONK%2Copsz%2Cwght%5D.ttf|Fraunces-VF.ttf"
    "DM Sans|dmsans/DMSans%5Bopsz%2Cwght%5D.ttf|DMSans-VF.ttf"
)
LICENSES=(
    "fraunces/OFL.txt|Fraunces-OFL.txt"
    "dmsans/OFL.txt|DMSans-OFL.txt"
)

mkdir -p "$APP_DIR"

fetch() {
    local url="$1" out="$2"
    if [[ -s "$out" ]]; then
        return
    fi
    echo "Downloading ${out#"$ROOT"/}"
    curl --fail --silent --show-error --location --max-time 120 "$url" --output "$out.part"
    mv "$out.part" "$out"
}

for entry in "${FONTS[@]}"; do
    IFS='|' read -r name path file <<<"$entry"
    fetch "$BASE/$path" "$APP_DIR/$file"
    # A TrueType file starts with 0x00010000; anything else is an error page saved by mistake.
    if [[ "$(head -c 4 "$APP_DIR/$file" | xxd -p)" != "00010000" ]]; then
        echo "error: $name is not a TrueType file; delete $APP_DIR/$file and retry" >&2
        exit 1
    fi
done

for entry in "${LICENSES[@]}"; do
    IFS='|' read -r path file <<<"$entry"
    fetch "$BASE/$path" "$APP_DIR/$file"
    grep -q "SIL OPEN FONT LICENSE" "$APP_DIR/$file" || {
        echo "error: $file is not the SIL OFL text" >&2
        exit 1
    }
done

if [[ -d "$ROOT/web" ]]; then
    mkdir -p "$WEB_DIR"
    for file in Fraunces-VF.ttf DMSans-VF.ttf Fraunces-OFL.txt DMSans-OFL.txt; do
        cp -n "$APP_DIR/$file" "$WEB_DIR/$file"
    done
fi

echo "Fonts ready in ${APP_DIR#"$ROOT"/}"
