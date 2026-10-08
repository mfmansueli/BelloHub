//
//  BelloHubApp.swift
//  BelloHub
//

import SwiftUI

@main
struct BelloHubApp: App {
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
