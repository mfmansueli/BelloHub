//
//  MoreView.swift
//  BelloHub
//

import SwiftUI

/// 2.5 More. Her profile card, then her business (services, products, booking page, availability, credentials,
/// team), the tags, record fields and forms of her clients, her messages and the account actions. The preferences
/// sections join it as their screens are built (privacy, plan and help in S10). Rows that open a screen are
/// `NavigationLink`s on the typed `MoreRoute`; the stack and its destinations belong to `MoreTab`.
struct MoreView: View {
    let onSignOut: () -> Void

    @Environment(ProfileService.self) private var profile
    @Environment(AppLockService.self) private var lock
    @Environment(BookingSetupService.self) private var bookingSetup
    @Environment(PublishingService.self) private var publishing
    @Environment(\.locale) private var locale
    @State private var confirmsSignOut = false

    var body: some View {
        ScrollView {
            StaggeredStack(spacing: Spacing.lg) {
                profileCard
                businessSection
                clientsSection
                messagesSection
                accountSection
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.xl)
        }
        .background(Palette.bg)
        .navigationTitle(Text("main.tab.more"))
        // Her booking page and hours show under their rows; a failed read leaves the rows without a subtitle.
        .task { try? await bookingSetup.load(timeZoneID: profile.profile?.timeZoneID ?? TimeZone.current.identifier) }
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

    /// Services, products, the booking page, availability, credentials and team, above the clients as in the
    /// prototype.
    private var businessSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(Text("more.section.business"))
            ListCard(dividerInset: 72) {
                link(.services, identifier: "more.servicesRow") {
                    MoreRow(icon: .scissors, tint: .rose, title: Text("more.row.services"), showsChevron: true)
                }
                link(.products, identifier: "more.productsRow") {
                    MoreRow(icon: .box, tint: .peach, title: Text("more.row.products"), showsChevron: true)
                }
                link(.bookingPage, identifier: "more.bookingPageRow") {
                    MoreRow(
                        icon: .globe, tint: .sage, title: Text("more.row.bookingPage"),
                        subtitle: bookingPageSubtitle, showsChevron: true
                    )
                }
                link(.availability, identifier: "more.availabilityRow") {
                    MoreRow(
                        icon: .clock, tint: .sage, title: Text("more.row.availability"),
                        subtitle: availabilitySubtitle, showsChevron: true
                    )
                }
                link(.credentials, identifier: "more.credentialsRow") {
                    MoreRow(icon: .star, tint: .rose, title: Text("more.row.credentials"), showsChevron: true)
                }
                link(.team, identifier: "more.teamRow") {
                    MoreRow(icon: .clients, tint: .peach, title: Text("more.row.team"), showsChevron: true)
                }
            }
        }
    }

    /// The messages she sends clients: quick replies now, templates and channels later.
    private var messagesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(Text("more.section.messages"))
            ListCard(dividerInset: 72) {
                link(.quickReplies, identifier: "more.quickRepliesRow") {
                    MoreRow(icon: .chat, tint: .sage, title: Text("more.row.quickReplies"), showsChevron: true)
                }
            }
        }
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

    /// "Not online yet" until her page is published, then "Taking bookings", "Paused" or "Paused until Oct 20"; nothing
    /// until the settings are read.
    private var bookingPageSubtitle: Text? {
        guard bookingSetup.hasLoaded else { return nil }
        let zone = timeZone
        let formatters = Formatters(locale: locale, timeZone: zone, currencyCode: "EUR")
        let summary = BookingSetupSummary.page(
            bookingSetup.setup.page, now: Date(), timeZone: zone, formatters: formatters
        )
        return Text(PublishStatusText.rowSubtitle(publishing.state, pageSummary: summary).localized(in: locale))
    }

    /// "Tue to Sat · 09:00 – 19:00"; nothing until the settings are read.
    private var availabilitySubtitle: Text? {
        guard bookingSetup.hasLoaded else { return nil }
        let formatters = Formatters(locale: locale, timeZone: bookingSetup.availability.timeZone, currencyCode: "EUR")
        let firstWeekday = profile.profile.map { WeekConfig.defaults(forRegion: $0.regionCode).firstWeekday }
            ?? Calendar.current.firstWeekday
        return Text(verbatim: AvailabilityText(formatters: formatters, firstWeekday: firstWeekday)
            .weekSummary(of: bookingSetup.availability))
    }

    private var timeZone: TimeZone {
        profile.profile.flatMap { TimeZone(identifier: $0.timeZoneID) } ?? .current
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
        .environment(BookingSetupService(vault: VaultService(repository: nil)))
        .environment(PublishingService.preview)
}
