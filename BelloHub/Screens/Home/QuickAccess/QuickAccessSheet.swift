//
//  QuickAccessSheet.swift
//  BelloHub
//

import SwiftUI

/// Opens from her avatar on Home: her profile, her booking link ready to copy or share, and the settings that keep the
/// business running (booking page, services, hours, products, record fields, plan, notifications, language), then
/// Lock now and All settings. A row closes the sheet and opens the same screen as in More, on the More tab: one screen
/// per setting, so nothing here can drift from More.
struct QuickAccessSheet: View {
    @State private var viewModel = QuickAccessViewModel()

    @Environment(ProfileService.self) private var profile
    @Environment(BookingSetupService.self) private var bookingSetup
    @Environment(PublishingService.self) private var publishing
    @Environment(SubscriptionService.self) private var subscription: SubscriptionService?
    @Environment(AppLockService.self) private var lock
    @Environment(MainNavigation.self) private var navigation: MainNavigation?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    private var subtitles: SettingsSubtitles {
        SettingsSubtitles(
            profile: profile, bookingSetup: bookingSetup, publishing: publishing, subscription: subscription,
            locale: locale
        )
    }

    /// Her booking link; nil until she chose an address.
    private var link: BookingLink? {
        bookingSetup.setup.slug.map { BookingLink(slug: $0, baseURL: BookingLink.defaultBaseURL) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SheetHeader(
                    title: "quickAccess.title", closeLabel: "common.close",
                    closeIdentifier: "home.quickAccess.closeButton", onClose: { dismiss() }
                )
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    profileCard
                    linkCard
                    section("more.section.business", items: QuickAccessItem.business)
                    section("more.section.preferences", items: QuickAccessItem.preferences)
                    footer
                }
                .padding(.horizontal, Spacing.gutter)
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.xl)
            }
        }
        .background(Palette.bg)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        // Her link and hours; a failed read leaves the card inviting her to choose an address and the rows bare.
        .task { try? await bookingSetup.load(timeZoneID: profile.profile?.timeZoneID ?? TimeZone.current.identifier) }
    }

    // MARK: - Parts

    private var profileCard: some View {
        Button { open([.account]) } label: {
            HStack(spacing: Spacing.md) {
                Avatar(name: subtitles.name, id: profile.profile?.id.uuidString ?? subtitles.name, size: 64)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(verbatim: subtitles.name).font(Typography.subtitle).foregroundStyle(Palette.ink)
                    if !subtitles.headline.isEmpty {
                        Text(verbatim: subtitles.headline).font(Typography.meta).foregroundStyle(Palette.ink2)
                    }
                    Text("more.profileCard.open").font(Typography.metaStrong).foregroundStyle(Palette.roseText)
                }
                Spacer(minLength: 0)
                Image(icon: .forward)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.ink2)
                    .accessibilityHidden(true)
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .belloCard()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.quickAccess.profile")
    }

    /// The same card as on the booking page settings: the link, what it does right now, Copy and Share.
    private var linkCard: some View {
        BookingLinkCard(
            link: link, shareMessage: shareMessage, isCopied: viewModel.copiedLink, state: publishing.state,
            onCopy: { if let link { viewModel.copy(link) } }, onGoOnline: publishing.goOnline
        ) {
            Button { open(QuickAccessItem.bookingPage.path) } label: { Text("bookingSettings.link.noAddress") }
        }
    }

    private func section(_ title: LocalizedStringKey, items: [QuickAccessItem]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: title)
            ListCard(dividerInset: 72) {
                ForEach(items) { item in
                    Button { open(item.path) } label: {
                        MoreRow(
                            icon: icon(of: item), tint: tint(of: item), title: Text(title(of: item)),
                            subtitle: subtitle(of: item), showsChevron: true
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(item.identifier)
                }
            }
        }
    }

    private var footer: some View {
        ListCard(dividerInset: 72) {
            Button {
                dismiss()
                lock.lockNow()
            } label: {
                MoreRow(icon: .lock, tint: .neutral, title: Text("more.lockNow"))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.quickAccess.lockNow")
            Button { open([]) } label: {
                MoreRow(icon: .sliders, tint: .neutral, title: Text("quickAccess.allSettings"), showsChevron: true)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.quickAccess.allSettings")
        }
    }

    // MARK: - Rows

    private func icon(of item: QuickAccessItem) -> Icon {
        switch item {
        case .bookingPage: .globe
        case .services: .scissors
        case .availability: .clock
        case .products: .box
        case .recordFields: .sliders
        case .plan: .star
        case .notifications: .bell
        case .languageRegion: .globe
        }
    }

    private func tint(of item: QuickAccessItem) -> MoreRow.Tint {
        switch item {
        case .services, .plan: .rose
        case .bookingPage, .availability, .recordFields, .languageRegion: .sage
        case .products, .notifications: .peach
        }
    }

    private func title(of item: QuickAccessItem) -> LocalizedStringKey {
        switch item {
        case .bookingPage: "more.row.bookingPage"
        case .services: "more.row.services"
        case .availability: "more.row.availability"
        case .products: "more.row.products"
        case .recordFields: "more.row.recordFields"
        case .plan: "more.row.plan"
        case .notifications: "more.row.notifications"
        case .languageRegion: "account.row.languageRegion"
        }
    }

    private func subtitle(of item: QuickAccessItem) -> Text? {
        switch item {
        case .bookingPage: subtitles.bookingPage()
        case .availability: subtitles.availability
        case .plan: subtitles.plan
        default: nil
        }
    }

    /// "Book with Maria", in the language of her messages, as the booking page settings share it.
    private var shareMessage: String {
        let localization = profile.profile.flatMap { AppLocalization(rawValue: $0.appLocaleID) } ?? .en
        let name = profile.profile?.displayName ?? ""
        return ShareTexts(
            localization: localization, professionalName: name.split(separator: " ").first.map(String.init) ?? name,
            displayLink: link?.display ?? ""
        ).shareMessage
    }

    // MARK: - Navigation

    /// Closes the sheet and opens `path` on the More tab; an empty path opens More itself.
    private func open(_ path: [MoreRoute]) {
        dismiss()
        guard let navigation else { return }
        navigation.morePath = path
        navigation.selection = .more
    }
}

#if DEBUG
#Preview {
    let vault = VaultService(repository: nil)
    Color.clear.sheet(isPresented: .constant(true)) { QuickAccessSheet() }
        .environment(ProfileService(vault: vault))
        .environment(BookingSetupService(vault: vault))
        .environment(PublishingService.preview)
        .environment(SubscriptionService.preview())
        .environment(AppLockService(keyManager: KeyManager()))
        .environment(MainNavigation())
}
#endif
