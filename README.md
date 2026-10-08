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

## Crashlytics

Reports are sent from Release builds only. Debug builds stay silent so simulator crashes and test runs
never reach the dashboard. Symbols are uploaded by the "Upload Crashlytics dSYMs" build phase, and only
when you archive.

To verify it end to end once (Crashlytics must be enabled in the Firebase console first):

1. In Xcode, Edit Scheme > Run > Info, uncheck **Debug executable**. The debugger swallows crashes, so
   Crashlytics never sees them while it is attached.
2. In Run > Arguments, add `-crashlyticsEnableInDebug` and `-crashlyticsTestCrash`, then run. The app crashes
   right after launch.
3. Remove `-crashlyticsTestCrash`, keep `-crashlyticsEnableInDebug`, and run again. The saved report is sent
   at startup and shows up in the Firebase console after a few minutes.
4. Remove both arguments and check **Debug executable** again.

Launching from the home screen sends nothing in a Debug build, because the arguments are what turn collection on.
