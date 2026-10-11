#!/usr/bin/env bash
# Builds the web app and deploys it to Firebase Hosting of the dev project (bello-hub, D43).
# Why a script: `hosting.public` in firebase/firebase.json is ../web/dist, which the emulator accepts but a real deploy
# refuses ("outside of project directory"), so the build is copied into firebase/.hosting-public and a derived config
# points there. Only Hosting is touched. Usage: scripts/deploy-hosting-dev.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/web"
npm ci --no-audit --no-fund
npm run build
cd "$ROOT/firebase"
rm -rf .hosting-public
cp -R ../web/dist .hosting-public
python3 - <<'PY'
import json
config = json.load(open("firebase.json"))
config["hosting"]["public"] = ".hosting-public"
config["hosting"].pop("predeploy", None)
json.dump(config, open("firebase.hosting-deploy.json", "w"), indent=2)
PY
trap 'rm -f firebase.hosting-deploy.json' EXIT
firebase deploy --config firebase.hosting-deploy.json --project dev --only hosting
