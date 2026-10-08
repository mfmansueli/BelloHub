//
//  BelloHubApp.swift
//  BelloHub
//

import SwiftUI

@main
struct BelloHubApp: App {
    init() {
        FirebaseBootstrap.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
