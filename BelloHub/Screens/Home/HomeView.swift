//
//  HomeView.swift
//  BelloHub
//

import SwiftUI

/// 2.1 Home. The day's list, the follow-ups and the shortcuts arrive in S6; until then it greets her and says the day
/// is clear. Presentation-only, so it keeps no ViewModel.
struct HomeView: View {
    @Environment(ProfileService.self) private var profile
    @Environment(\.locale) private var locale

    var body: some View {
        ScrollView {
            StaggeredStack(spacing: Spacing.lg) {
                greeting
                    .font(Typography.screenTitle)
                    .foregroundStyle(Palette.ink)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("home.greeting")
                EmptyState(icon: .calendar, title: "home.empty.title", message: "home.empty.message")
                    .accessibilityIdentifier("home.empty")
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.md)
        }
        .background(Palette.bg)
        .navigationTitle(Text("home.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var greeting: Text {
        let name = profile.profile?.firstName ?? ""
        let timeZone = profile.profile.flatMap { TimeZone(identifier: $0.timeZoneID) } ?? .current
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        switch DayGreeting.at(Date(), calendar: calendar) {
        case .morning:
            return Text(LocalizedStringResource("home.greeting.morning", defaultValue: "Good morning, \(name)")
                .localized(in: locale))
        case .afternoon:
            return Text(LocalizedStringResource("home.greeting.afternoon", defaultValue: "Good afternoon, \(name)")
                .localized(in: locale))
        case .evening:
            return Text(LocalizedStringResource("home.greeting.evening", defaultValue: "Good evening, \(name)")
                .localized(in: locale))
        }
    }
}

#Preview {
    NavigationStack { HomeView() }
        .environment(ProfileService(vault: VaultService(repository: nil)))
}
