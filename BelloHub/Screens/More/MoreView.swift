//
//  MoreView.swift
//  BelloHub
//

import SwiftUI

/// 2.5 More. Her profile card and the account actions that exist so far. Business, client and account settings join it
/// as their screens are built (services and booking page in S5, account and privacy in S10).
struct MoreView: View {
    let onSignOut: () -> Void

    @Environment(ProfileService.self) private var profile
    @Environment(AppLockService.self) private var lock
    @Environment(\.locale) private var locale
    @State private var confirmsSignOut = false

    var body: some View {
        ScrollView {
            StaggeredStack(spacing: Spacing.lg) {
                profileCard
                VStack(alignment: .leading, spacing: 0) {
                    SectionHeader(title: "more.section.account")
                    ListCard(dividerInset: 72) {
                        row(icon: .lock, title: "more.lockNow", identifier: "more.lockNowButton") { lock.lockNow() }
                        row(icon: .logout, title: "more.signOut", identifier: "more.signOutButton") {
                            confirmsSignOut = true
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.xl)
        }
        .background(Palette.bg)
        .navigationTitle(Text("main.tab.more"))
        .confirmationDialog(
            Text("more.signOut.confirmTitle"), isPresented: $confirmsSignOut, titleVisibility: .visible
        ) {
            Button(role: .destructive, action: onSignOut) { Text("more.signOut.confirm") }
                .accessibilityIdentifier("more.signOutConfirmButton")
            Button(role: .cancel) {} label: { Text("common.cancel") }
        } message: {
            Text("more.signOut.confirmMessage")
        }
    }

    // MARK: - Parts

    private var profileCard: some View {
        HeroCard {
            HStack(spacing: Spacing.md) {
                Avatar(name: name, id: profile.profile?.id.uuidString ?? name, size: 64)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(verbatim: name).font(Typography.subtitle).foregroundStyle(HeroPalette.ink)
                    if !subtitle.isEmpty {
                        Text(verbatim: subtitle).font(Typography.meta).foregroundStyle(HeroPalette.ink2)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("more.profileCard")
    }

    private func row(
        icon: Icon, title: LocalizedStringKey, identifier: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.row) {
                Image(icon: icon)
                    .foregroundStyle(Palette.roseDeepText)
                    .frame(width: 44, height: 44)
                    .background(
                        Palette.roseWash, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                    )
                    .accessibilityHidden(true)
                Text(title).font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .frame(minHeight: 64)
            .contentShape(Rectangle())
        }
        .accessibilityIdentifier(identifier)
    }

    private var name: String {
        profile.profile?.publicName ?? ""
    }

    /// "Esthetician · Brazil": her first profession and her region, in the language of the app.
    private var subtitle: String {
        guard let current = profile.profile else { return "" }
        let region = locale.localizedString(forRegionCode: current.regionCode)
        let localization = AppLocalization(rawValue: current.appLocaleID) ?? .en
        let profession = (try? ProfessionCatalog.loadBundled(localization: localization))
            .flatMap { catalog in current.professions.first.flatMap { catalog.entry(for: $0)?.name } }
        return [profession, region].compactMap { $0 }.joined(separator: " · ")
    }
}
