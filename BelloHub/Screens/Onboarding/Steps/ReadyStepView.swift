//
//  ReadyStepView.swift
//  BelloHub
//

import SwiftUI

/// 1.10 Onb-7-Ready. The workspace is set up. Shows what it will hold, where her booking link will be, a shortcut to
/// import her clients, and a button that saves everything and opens the app. The live booking link arrives with the
/// server (S8).
struct ReadyStepView: View {
    @Bindable var viewModel: OnboardingViewModel
    @Environment(ClientRegistrationService.self) private var registration
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var isImportPresented = false

    var body: some View {
        OnboardingStepLayout(
            title: Text("onb.ready.title"), subtitle: subtitle, continueTitle: "onb.ready.go",
            isWorking: viewModel.isSaving, identifier: "ready", onContinue: viewModel.finish
        ) {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                SuccessSeal(size: 64)
                tiles
                linkCard
                importCard
                if let message = viewModel.errorMessage {
                    InlineNotice(style: .warning, title: LocalizedStringKey(message))
                        .accessibilityIdentifier("onboarding.ready.error")
                }
            }
        }
        // The profile is not saved yet, so the import is told the region and the term she has just chosen.
        .sheet(isPresented: $isImportPresented) {
            ImportClientsView(
                businessRegionCode: viewModel.draft.regionCode, clientTerm: viewModel.draft.clientTerm
            )
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
            icon: .clients, value: "\(registration.usage.used)",
            label: LocalizedStringKey(viewModel.draft.clientTerm.titlePlural(in: locale)), tone: .rose
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

    /// The shortcut to the import (4.6): clients she already has come in from her contacts or a spreadsheet.
    private var importCard: some View {
        Button { isImportPresented = true } label: {
            HStack(spacing: Spacing.row) {
                Image(icon: .userPlus)
                    .foregroundStyle(Palette.neutralText)
                    .frame(width: 44, height: 44)
                    .background(
                        Palette.neutralWash, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                    )
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(LocalizedStringResource(
                        "import.title", defaultValue: "Import \(viewModel.draft.clientTerm.pluralText(in: locale))"
                    ).localized(in: locale))
                        .font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                    Text("import.entry.subtitle").font(Typography.footnote).foregroundStyle(Palette.ink2)
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Image(icon: .forward)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.ink3)
                    .flipsForRightToLeftLayoutDirection(true)
                    .accessibilityHidden(true)
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .belloCard()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("onboarding.ready.importButton")
    }
}
