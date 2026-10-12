//
//  PlanContentView.swift
//  BelloHub
//

import SwiftUI

/// The one plan (D33): a hero with her status, the monthly and yearly choice (the yearly highlighted with its
/// saving), what is included, the purchase button, restore and manage, then what App Review 3.1.2 asks next to a
/// subscription: that it renews automatically until cancelled, and the Terms and the Privacy Policy. Prices are the
/// store's `displayPrice`, never typed here. In paywall form the headline explains the limit and reminds her that
/// nothing is lost.
struct PlanContentView: View {
    @State private var viewModel: PlanViewModel

    @Environment(\.locale) private var locale

    init(subscription: SubscriptionService, mode: PlanViewModel.Mode) {
        _viewModel = State(initialValue: PlanViewModel(subscription: subscription, mode: mode))
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                intro
                notices
                hero
                if !viewModel.state.hasActivePlan { choice }
                features
                actions
                FooterNote(text: "plan.footer", icon: .info)
                PlanLegalSection(
                    errorMessage: viewModel.legalErrorMessage, onOpen: viewModel.open
                )
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.xl)
        }
        .background(Palette.bg)
        .navigationTitle(Text("plan.title"))
        // The paywall is a sheet: an inline bar, and the headline that explains the limit sits in the content.
        .navigationBarTitleDisplayMode(viewModel.mode == .paywall ? .inline : .large)
        .task { await viewModel.load() }
        .sheet(isPresented: Binding(
            get: { viewModel.openedNotice != nil }, set: { if !$0 { viewModel.closeLegalNotice() } }
        )) {
            if let notice = viewModel.openedNotice { LegalNoticeSheet(text: notice) }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var intro: some View {
        if viewModel.mode == .paywall {
            Text("paywall.title").font(Typography.title).foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("paywall.title")
            Text("paywall.message").font(Typography.body).foregroundStyle(Palette.ink2)
                .accessibilityIdentifier("paywall.message")
            InlineNotice(style: .info, title: "paywall.reassurance")
                .accessibilityIdentifier("paywall.reassurance")
        } else {
            Text("plan.subtitle").font(Typography.body).foregroundStyle(Palette.ink2)
        }
    }

    @ViewBuilder
    private var notices: some View {
        if let message = viewModel.offersErrorMessage {
            ErrorNotice(message: message, actionTitle: "plan.retry", action: viewModel.retry)
                .accessibilityIdentifier("plan.error")
        }
        if let notice = viewModel.notice {
            InlineNotice(style: notice == .failed ? .warning : .info, title: noticeTitle(notice))
                .accessibilityIdentifier("plan.notice")
        }
    }

    private var hero: some View {
        HeroCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(spacing: Spacing.xs) {
                    Image(icon: .star).accessibilityHidden(true)
                    Text(verbatim: PlanProducts.groupName).font(Typography.metaStrong)
                }
                .foregroundStyle(HeroPalette.ink2)
                Text(heroTitle).font(Typography.title).foregroundStyle(HeroPalette.ink)
                Text(heroSubtitle).font(Typography.meta).foregroundStyle(HeroPalette.ink2)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("plan.status")
    }

    /// Monthly and yearly as choice cards; the yearly one carries the saving computed from the store's prices.
    private var choice: some View {
        SettingsSection(title: "plan.section.choose", subtitle: "plan.sameFeatures") {
            if viewModel.isLoadingOffers && viewModel.offers.isEmpty {
                VStack(spacing: Spacing.row) {
                    Skeleton(height: 64)
                    Skeleton(height: 64)
                }
                .accessibilityIdentifier("plan.loading")
            } else {
                VStack(spacing: Spacing.row) {
                    ForEach(PlanPeriod.allCases) { period in
                        if let offer = viewModel.offers.first(where: { $0.period == period }) {
                            ChoiceCard(
                                title: cardTitle(offer), subtitle: cardSubtitle(offer),
                                emphasizesSubtitle: period == viewModel.presentation.highlighted,
                                isSelected: viewModel.choice == period,
                                identifier: "plan.choice.\(period.rawValue)"
                            ) { viewModel.choose(period) }
                        }
                    }
                }
            }
        }
    }

    private var features: some View {
        SettingsSection(title: "plan.section.included") {
            ListCard(dividerInset: Spacing.md) {
                ForEach(PlanPresentation.features, id: \.self) { key in
                    HStack(spacing: Spacing.row) {
                        Image(icon: .check).foregroundStyle(Palette.sageText).accessibilityHidden(true)
                        Text(LocalizedStringKey(key)).font(Typography.body).foregroundStyle(Palette.ink)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .frame(minHeight: 52)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private var actions: some View {
        VStack(spacing: Spacing.sm) {
            if viewModel.state.hasActivePlan {
                Button(action: viewModel.manage) { Text("plan.manage") }
                    .buttonStyle(.belloPrimary)
                    .accessibilityIdentifier("plan.manageButton")
            } else {
                Button(action: viewModel.buy) {
                    if viewModel.isBusy {
                        ProgressView().tint(Palette.onAction)
                    } else {
                        Text(buyTitle).motionNumber(buyTitle)
                    }
                }
                .buttonStyle(.belloPrimary)
                .disabled(!viewModel.canBuy)
                .accessibilityIdentifier("plan.buyButton")
            }
            Button(action: viewModel.restore) { Text("plan.restore") }
                .buttonStyle(.belloSecondary)
                .disabled(viewModel.isBusy)
                .accessibilityIdentifier("plan.restoreButton")
        }
    }

    // MARK: - Texts

    private var heroTitle: LocalizedStringKey {
        switch viewModel.state {
        case .unknown: "plan.status.checking"
        case .none: "plan.status.none"
        case .active: "plan.status.active"
        case .inGracePeriod: "plan.status.grace"
        }
    }

    private var heroSubtitle: String {
        switch viewModel.state {
        case .unknown: return String(interface: LocalizedStringResource("plan.status.checking.subtitle"))
        case .none: return String(interface: LocalizedStringResource("plan.status.none.subtitle"))
        case .active(let period, let expiresAt, let willRenew):
            let formatters = Formatters(locale: locale, timeZone: .current, currencyCode: "EUR")
            let periodName = String(localized: period.label.localized(in: locale))
            guard let expiresAt else { return periodName }
            let day = formatters.shortDate(expiresAt)
            return willRenew
                ? String(localized: LocalizedStringResource(
                    "plan.status.renews", defaultValue: "\(periodName) · renews on \(day)"
                ).localized(in: locale))
                : String(localized: LocalizedStringResource(
                    "plan.status.endsOn", defaultValue: "\(periodName) · ends on \(day)"
                ).localized(in: locale))
        case .inGracePeriod: return String(interface: LocalizedStringResource("plan.status.grace.subtitle"))
        }
    }

    private func cardTitle(_ offer: PlanOffer) -> String {
        let period = String(localized: offer.period.label.localized(in: locale))
        let per = String(localized: offer.period.perPeriod.localized(in: locale))
        return "\(period) · \(offer.displayPrice) \(per)"
    }

    private func cardSubtitle(_ offer: PlanOffer) -> String? {
        guard offer.period == .yearly, let percent = viewModel.presentation.savingsPercent else { return nil }
        return String(localized: LocalizedStringResource("plan.saving", defaultValue: "Save \(percent)%")
            .localized(in: locale))
    }

    private var buyTitle: String {
        guard let offer = viewModel.chosenOffer else { return String(interface: LocalizedStringResource(
            "plan.buy.choose"
        )) }
        let period = String(localized: offer.period.label.localized(in: locale))
        return String(localized: LocalizedStringResource(
            "plan.buy", defaultValue: "Continue with \(period)"
        ).localized(in: locale))
    }

    private func noticeTitle(_ notice: PlanViewModel.Notice) -> LocalizedStringKey {
        switch notice {
        case .purchased: "plan.notice.purchased"
        case .restored: "plan.notice.restored"
        case .nothingToRestore: "plan.notice.nothingToRestore"
        case .pending: "plan.notice.pending"
        case .failed: "plan.notice.failed"
        }
    }
}
