//
//  BelloHubApp.swift
//  BelloHub
//

import SwiftUI

@main
struct BelloHubApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        FontRegistry.registerAll()
        FirebaseBootstrap.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
