//
//  RootView.swift
//  BelloHub
//

import SwiftUI

/// State gate for the whole app: onboarding → login → setup → app.
/// Only the last state exists so far. Each earlier step arrives with its feature, driven by an
/// `@AppStorage` flag, and the app-session Services are created here as `@State`.
struct RootView: View {
    var body: some View {
        MainView()
            .disablesAnimationsForUITests()
    }
}

#Preview {
    RootView()
}
