//
//  CrashCollectionPolicy.swift
//  BelloHub
//

/// When crash reports are sent. Debug builds stay silent so simulator crashes and test runs never
/// pollute the Crashlytics dashboard. Pure on purpose: both inputs are parameters, so it is testable.
enum CrashCollectionPolicy {
    /// Turns collection on in a Debug build, to verify Crashlytics end to end.
    static let enableInDebugArgument = "-crashlyticsEnableInDebug"
    /// Debug-only: crashes the app right after launch. Combine with `enableInDebugArgument`.
    static let testCrashArgument = "-crashlyticsTestCrash"

    static func isCollectionEnabled(isDebugBuild: Bool, arguments: [String]) -> Bool {
        !isDebugBuild || arguments.contains(enableInDebugArgument)
    }
}
