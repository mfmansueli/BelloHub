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
