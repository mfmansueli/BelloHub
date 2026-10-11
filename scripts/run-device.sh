#!/usr/bin/env bash
# Usage: scripts/run-device.sh [device name or UDID]   (default: the first paired iPhone that is available)
# Builds the Debug app for a real iPhone, installs it and launches it. The phone must be unlocked.
# Debug builds sign in with the development provider: any phone number, code 123456 (docs/PROGRESS.md).
source "$(dirname "$0")/lib.sh"

wanted="${1:-}"
device_json="$(mktemp)"
trap 'rm -f "$device_json"' EXIT
xcrun devicectl list devices --json-output "$device_json" > /dev/null 2>&1

read -r udid name < <(WANTED="$wanted" python3 -I - "$device_json" <<'PY'
import json, os, sys
wanted = os.environ.get("WANTED", "").lower()
devices = json.load(open(sys.argv[1]))["result"]["devices"]
for d in devices:
    props, hw = d["deviceProperties"], d["hardwareProperties"]
    if hw.get("reality") != "physical" or hw.get("platform") != "iOS":
        continue
    if d["connectionProperties"].get("pairingState") != "paired":
        continue
    udid, name = hw["udid"], props["name"]
    if not wanted or wanted in (udid.lower(), name.lower()):
        print(udid, name.replace(" ", "_"))
        break
PY
)
if [[ -z "${udid:-}" ]]; then
    echo "error: no paired iPhone found${wanted:+ matching '$wanted'}. Connect it and unlock it." >&2
    exit 1
fi
echo "Device: ${name//_/ } ($udid)"

run_xcodebuild "device-Debug" build \
    -scheme BelloHub \
    -configuration Debug \
    -destination "platform=iOS,id=$udid" \
    -allowProvisioningUpdates

app="$DERIVED_DATA/Build/Products/Debug-iphoneos/BelloHub.app"
[[ -d "$app" ]] || { echo "error: $app was not built" >&2; exit 1; }
xcrun devicectl device install app --device "$udid" "$app"
xcrun devicectl device process launch --device "$udid" --terminate-existing com.bellohub
