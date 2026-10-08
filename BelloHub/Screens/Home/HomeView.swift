//
//  HomeView.swift
//  BelloHub
//

import SwiftUI

/// Presentation-only for now, so it keeps no ViewModel. One arrives with the first state or IO.
struct HomeView: View {
    var body: some View {
        Text("home.greeting")
            .font(Typography.title)
            .foregroundStyle(Palette.ink)
            .padding(Spacing.md)
            .accessibilityIdentifier("home.greeting")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.bg)
            .navigationTitle("home.title")
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
}
