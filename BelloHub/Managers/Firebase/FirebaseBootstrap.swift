//
//  FirebaseBootstrap.swift
//  BelloHub
//

import FirebaseCore
import FirebaseCrashlytics
import Foundation

/// The one place that starts the Firebase SDK, so the app entry point imports no SDK.
/// Pure infrastructure with no state, which is why it is a static entry point and not an
/// injected Service. The only other files that import Firebase are `FirebaseCrashReporter` and,
/// once it exists, `SessionService`.
enum FirebaseBootstrap {
    @MainActor
    static func configure() {
        guard FirebaseApp.app() == nil else { return }
        FirebaseApp.configure()

        let arguments = ProcessInfo.processInfo.arguments
        #if DEBUG
        let isDebugBuild = true
        #else
        let isDebugBuild = false
        #endif
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(
            CrashCollectionPolicy.isCollectionEnabled(isDebugBuild: isDebugBuild, arguments: arguments)
        )

        #if DEBUG
        if arguments.contains(CrashCollectionPolicy.testCrashArgument) {
            fatalError("Crashlytics test crash requested with \(CrashCollectionPolicy.testCrashArgument)")
        }
        #endif
    }
}
