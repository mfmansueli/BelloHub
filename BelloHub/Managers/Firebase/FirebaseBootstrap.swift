//
//  FirebaseBootstrap.swift
//  BelloHub
//

import FirebaseCore

/// The one place that starts the Firebase SDK, so the app entry point imports no SDK.
/// Pure infrastructure with no state, which is why it is a static entry point and not an
/// injected Service. Only Firebase modules the product needs are linked (Core and Auth now; the
/// rest arrive in stage S8). There is no Analytics and no Crashlytics: no client text may leave
/// the phone through a telemetry SDK (docs/04-ARCHITECTURE.md section 8).
enum FirebaseBootstrap {
    @MainActor
    static func configure() {
        guard FirebaseApp.app() == nil else { return }
        FirebaseApp.configure()
    }
}
