//
//  ReadyStepView.swift
//  BelloHub
//

import SwiftUI

/// 1.10 Onb-7-Ready. The workspace is set up. Shows what it will hold, where her booking link will be, and a button
/// that saves everything and opens the app. The import shortcut and the live link arrive with the screens they open
/// (clients in S4, the booking link in S8).
struct ReadyStepView: View {
    @Bindable var viewModel: OnboardingViewModel
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        OnboardingStepLayout(
            title: Text("onb.ready.title"), subtitle: subtitle, continueTitle: "onb.ready.go",
            isWorking: viewModel.isSaving, identifier: "ready", onContinue: viewModel.finish
        ) {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                SuccessSeal(size: 64)
                tiles
                linkCard
                if let message = viewModel.errorMessage {
                    InlineNotice(style: .warning, title: LocalizedStringKey(message))
                        .accessibilityIdentifier("onboarding.ready.error")
                }
            }
        }
    }

    private var subtitle: Text {
        let draft = viewModel.draft
        let professions = OnboardingSuggestions.pluralNames(
            for: draft.professions, in: viewModel.catalog,
            formatter: Formatters(locale: locale, timeZone: .current, currencyCode: draft.currencyCode)
        )
        let name = OnboardingRules.cleaned(draft.displayName).split(separator: " ").first.map(String.init) ?? ""
        return Text(LocalizedStringResource(
            "onb.ready.subtitle",
            defaultValue: "\(name), your workspace is set up for \(professions). It will fill up as clients book."
        ).localized(in: locale))
    }

    /// Side by side at normal sizes, stacked once the text is large enough that three tiles would not fit.
    @ViewBuilder
    private var tiles: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: Spacing.row) { tileSet }
        } else {
            HStack(spacing: Spacing.row) { tileSet }.fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var tileSet: some View {
        InsightTile(icon: .calendar, value: "0", label: "onb.ready.appointments", tone: .sage)
        InsightTile(
            icon: .clients, value: "0", label: LocalizedStringKey(viewModel.draft.clientTerm.titlePlural(in: locale)),
            tone: .rose
        )
        InsightTile(icon: .repeatArrows, value: "0", label: "onb.ready.followUps", tone: .peach)
    }

    private var linkCard: some View {
        HStack(spacing: Spacing.row) {
            Image(icon: .link)
                .foregroundStyle(Palette.roseDeepText)
                .frame(width: 44, height: 44)
                .background(Palette.roseWash, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("onb.ready.link").font(Typography.footnote).foregroundStyle(Palette.ink2)
                Text("onb.ready.link.pending").font(Typography.bodyStrong).foregroundStyle(Palette.ink)
            }
            Spacer(minLength: 0)
        }
        .padding(Spacing.md)
        .belloCard()
        .accessibilityElement(children: .combine)
    }
}
