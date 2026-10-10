# BelloHub

iOS 26+ SwiftUI app. Architecture and working rules are in [CLAUDE.md](CLAUDE.md), the design in [DESIGN.md](DESIGN.md).

## Build and test

Always go through the wrappers in `scripts/`. They keep DerivedData in `build/`, run one `xcodebuild` at a time,
print only errors, warnings and failures, and save the full log to `build/logs/`.

```
scripts/build.sh [Debug|Release]      # build for the simulator
scripts/test.sh [fast|smoke|full]     # unit only | one UI test per flow | everything (default)
scripts/check-warnings.sh             # clean builds for simulator, device and Release; fails on any warning
scripts/check-project-settings.sh     # fails if build settings leak into project.pbxproj
```

Needs SwiftLint (`brew install swiftlint`). Build settings live in `Config/*.xcconfig`.
Set `SIM_NAME` or `SIM_UDID` to pick another simulator (default: iPhone 17 on the oldest iOS 26+ runtime).
`ONLY_TESTING=BelloHubUITests/CalendarUITests scripts/test.sh full` runs one suite. Opt-in runs:
`TEST_RUNNER_BELLO_PERF=1 ONLY_TESTING=BelloHubUITests/PerformanceUITests scripts/test.sh full` (performance budgets)
and `TEST_RUNNER_BELLO_A11Y=1 TEST_RUNNER_AUDIT_LOCALES=en,pt-BR ONLY_TESTING=BelloHubUITests/AccessibilityAuditUITests
scripts/test.sh full` (the full accessibility audit; the Full plan runs it in `en`).

## Server, web and end to end

Needs Node 22+, Java 17+ and `firebase-tools`. Everything below runs on the local emulators with the demo project id
`demo-bellohub`, which can never reach the cloud.

```
scripts/test-firebase.sh [all|static|unit|emulator|transport]   # functions: lint, types, audit, unit, rules, use cases
scripts/test-web.sh [quick|full]      # web app: lint, types, i18n, contrast, unit, Playwright, Lighthouse, bundle
scripts/e2e-local.sh                  # the web app against the real functions on the emulators, end to end
scripts/run-device.sh                 # Debug build installed and launched on the test iPhone
```

Deploys go to the development project `bello-hub` only (D43): `scripts/deploy-hosting-dev.sh` for the web page and
`cd firebase && firebase deploy --project dev --only functions` for the functions. Never turn on App Check
enforcement from here (H5).

## Handoff

The product brief, decisions, build plan and progress live in [docs/README.md](docs/README.md); the running log is
`docs/PROGRESS.md`. Backend config (Firestore `eur3`, Functions `europe-west1`) is in `firebase/`.
