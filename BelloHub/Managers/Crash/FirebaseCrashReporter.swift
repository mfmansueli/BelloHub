//
//  FirebaseCrashReporter.swift
//  BelloHub
//

import FirebaseCrashlytics

/// Crashlytics behind `CrashReporter`. Collection is switched on or off once at launch by
/// `FirebaseBootstrap`; this type only forwards calls.
struct FirebaseCrashReporter: CrashReporter {
    func record(_ error: any Error) {
        Crashlytics.crashlytics().record(error: error)
    }

    func log(_ message: String) {
        Crashlytics.crashlytics().log(message)
    }

    func setUserID(_ userID: String?) {
        Crashlytics.crashlytics().setUserID(userID)
    }
}
