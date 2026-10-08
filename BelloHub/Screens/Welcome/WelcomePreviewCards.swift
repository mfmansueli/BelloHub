//
//  WelcomePreviewCards.swift
//  BelloHub
//

import SwiftUI

/// Two sample cards that show what the app remembers for her: the day's list and one client's note. Decorative:
/// the names and times are made up, so VoiceOver skips them and reads the tagline below instead.
struct WelcomePreviewCards: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            todayCard
            clientCard.padding(.leading, Spacing.xl)
        }
        .accessibilityHidden(true)
    }

    private var todayCard: some View {
        VStack(alignment: .leading, spacing: Spacing.row) {
            Text("onb.welcome.today").font(Typography.metaStrong).foregroundStyle(Palette.ink2)
            row(name: "Julia Mendes", service: "onb.welcome.sample.service1", time: "09:00")
            row(name: "Camila Rocha", service: "onb.welcome.sample.service2", time: "11:30")
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .belloCard()
    }

    private func row(name: String, service: LocalizedStringKey, time: String) -> some View {
        HStack(spacing: Spacing.row) {
            Avatar(name: name, id: name, size: 40)
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: name).font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                Text(service).font(Typography.footnote).foregroundStyle(Palette.ink2)
            }
            Spacer(minLength: 0)
            Text(verbatim: time).font(Typography.bodyStrong).foregroundStyle(Palette.ink)
        }
    }

    private var clientCard: some View {
        VStack(alignment: .leading, spacing: Spacing.row) {
            HStack(spacing: Spacing.row) {
                Avatar(name: "Ana Costa", id: "Ana Costa", size: 44)
                VStack(alignment: .leading, spacing: 0) {
                    Text(verbatim: "Ana Costa").font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                    Text("onb.welcome.sample.lastVisit").font(Typography.footnote).foregroundStyle(Palette.ink2)
                }
            }
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("onb.welcome.sample.important").font(Typography.metaStrong).foregroundStyle(Palette.roseDeepText)
                Text("onb.welcome.sample.note").font(Typography.meta).foregroundStyle(Palette.ink)
            }
            .padding(Spacing.row)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.roseWash, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
        }
        .padding(Spacing.md)
        .belloCard()
    }
}

#Preview {
    WelcomePreviewCards().padding().background(Palette.bg)
}
