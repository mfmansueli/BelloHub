//
//  MoreView.swift
//  BelloHub
//

import SwiftUI

/// 2.5 More. Her profile card, then the settings that exist so far: the tags, record fields and forms of her clients,
/// and the account actions. The business, messages and preferences sections join it as their screens are built
/// (services, booking page and availability in S5; privacy, plan and help in S10). Rows that open a screen are
/// `NavigationLink`s on the typed `MoreRoute`; the stack and its destinations belong to `MoreTab`.
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
                // The Business section (services, products, booking page, availability, credentials, team) goes
                // here in S5, above Clients, as in the prototype.
                clientsSection
                accountSection
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

    // MARK: - Sections

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

    /// Titled with the word she uses for the people she serves, as the tab is. The "Import clients" row joins it
    /// with the import screen (4.6).
    private var clientsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(Text(verbatim: profile.clientTerm.titlePlural(in: locale)))
            ListCard(dividerInset: 72) {
                link(.recordTemplate, identifier: "more.recordFieldsRow") {
                    MoreRow(
                        icon: .sliders, tint: .sage, title: Text("more.row.recordFields"),
                        subtitle: recordFieldsSubtitle, showsChevron: true
                    )
                }
                link(.formTemplates, identifier: "more.formsRow") {
                    MoreRow(
                        icon: .document, tint: .peach, title: Text("more.row.forms"),
                        subtitle: Text("more.row.forms.subtitle"), showsChevron: true
                    )
                }
                link(.tags, identifier: "more.tagsRow") {
                    MoreRow(
                        icon: .tag, tint: .rose, title: Text("more.row.tags"), subtitle: tagsSubtitle,
                        showsChevron: true
                    )
                }
            }
        }
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(Text("more.section.account"))
            ListCard(dividerInset: 72) {
                Button { lock.lockNow() } label: {
                    MoreRow(icon: .lock, tint: .neutral, title: Text("more.lockNow"))
                }
                .accessibilityIdentifier("more.lockNowButton")
                Button { confirmsSignOut = true } label: {
                    MoreRow(icon: .logout, tint: .neutral, title: Text("more.signOut"))
                }
                .accessibilityIdentifier("more.signOutButton")
            }
        }
    }

    // MARK: - Parts

    /// The same look as `SectionHeader`, for a title that is already a `Text` (the client term is not a catalog key).
    private func sectionHeader(_ title: Text) -> some View {
        title
            .font(Typography.section)
            .foregroundStyle(Palette.ink)
            .accessibilityAddTraits(.isHeader)
            .padding(.top, Spacing.xs)
            .padding(.bottom, Spacing.row)
    }

    private func link<Label: View>(
        _ route: MoreRoute, identifier: String, @ViewBuilder label: () -> Label
    ) -> some View {
        NavigationLink(value: route, label: label)
            .buttonStyle(.plain)
            .accessibilityIdentifier(identifier)
    }

    private var summary: MoreSummary {
        MoreSummary(tags: profile.tags, template: profile.template, professions: profile.profile?.professions ?? [])
    }

    private var tagsSubtitle: Text {
        Text(LocalizedStringResource(
            "more.row.tags.count", defaultValue: "\(summary.tagCount) tags"
        ).localized(in: locale))
    }

    private var recordFieldsSubtitle: Text? {
        guard let on = summary.fieldsOn else { return nil }
        return Text(LocalizedStringResource(
            "more.row.recordFields.count", defaultValue: "\(on) fields on"
        ).localized(in: locale))
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

#Preview {
    NavigationStack { MoreView(onSignOut: {}) }
        .environment(ProfileService(vault: VaultService(repository: nil)))
        .environment(AppLockService(keyManager: KeyManager()))
}
