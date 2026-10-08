//
//  MainView.swift
//  BelloHub
//

import SwiftUI

/// System `TabView`; every tab owns its `NavigationStack`.
/// The signed-in user's Services are created here as `@State` and injected with `.environment(...)`.
struct MainView: View {
    var body: some View {
        TabView {
            Tab("main.tab.home", systemImage: "house") {
                NavigationStack {
                    HomeView()
                }
            }
            .accessibilityIdentifier("main.tab.home")
        }
        .tint(Palette.accent)
    }
}

#Preview {
    MainView()
}
