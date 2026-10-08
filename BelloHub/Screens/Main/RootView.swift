//
//  RootView.swift
//  BelloHub
//

import SwiftUI

/// State gate for the whole app: onboarding → login → setup → locked → app.
/// Only the last state exists so far. Each earlier step arrives with its feature, driven by an
/// `@AppStorage` flag, and the app-session Services are created here as `@State`.
struct RootView: View {
    var body: some View {
        content
            .belloLocaleTypography()
            .disablesAnimationsForUITests()
    }

    @ViewBuilder
    private var content: some View {
        #if DEBUG
        if LaunchOptions.current.showsDesignCatalog {
            DesignCatalogView(options: LaunchOptions.current)
        } else {
            MainView()
        }
        #else
        MainView()
        #endif
    }
}

#Preview {
    RootView()
}
