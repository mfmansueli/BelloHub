//
//  CrashReporter.swift
//  BelloHub
//

/// What the app needs from crash reporting. Services take this protocol through `init` with
/// `FirebaseCrashReporter` as the default; Views and ViewModels never see the SDK.
protocol CrashReporter: Sendable {
    /// Records a handled error that did not crash the app.
    func record(_ error: any Error)
    /// Adds a breadcrumb that is attached to the next crash or recorded error.
    func log(_ message: String)
    /// Ties reports to a signed-in user. Pass `nil` on sign-out.
    func setUserID(_ userID: String?)
}
