//
//  ImportResultView.swift
//  BelloHub
//

import SwiftUI

/// The last step: how many were imported, how many were skipped and why, and what the free registrations left out with
/// the way to the paywall (D42). "View clients" opens the list. The "Send my booking link" invitation of the prototype
/// waits for the booking link (S8) and WhatsApp (S6), so it is not here.
struct ImportResultView: View {
    let viewModel: ImportClientsViewModel
    let term: ClientTerm
    let onViewClients: () -> Void
    @Environment(\.locale) private var locale

    private var result: ClientImportResult { viewModel.result ?? ClientImportResult() }

    var body: some View {
        ScrollView {
            StaggeredStack(spacing: Spacing.lg) {
                hero
                if result.duplicates > 0 || result.malformed > 0 { details }
                if result.blocked > 0 { paywallOffer }
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.lg)
        }
        .background(Palette.bg)
        .safeAreaInset(edge: .bottom) { actionBar }
    }

    // MARK: - Sections

    private var hero: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            if result.registered > 0 {
                SuccessSeal(size: 64)
            } else {
                Image(icon: .info)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(Palette.ink2)
                    .frame(width: 64, height: 64)
                    .background(Palette.sunken, in: Circle())
                    .accessibilityHidden(true)
            }
            title
                .font(Typography.screenTitle)
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("importClients.result.title")
            if result.registered > 0 {
                Text(LocalizedStringResource(
                    "import.result.subtitle",
                    defaultValue: "Your \(term.pluralText(in: locale)) list is up to date. Add tags and notes."
                ).localized(in: locale))
                    .font(Typography.body).foregroundStyle(Palette.ink2)
            }
        }
    }

    private var title: Text {
        if result.registered > 0 {
            Text(LocalizedStringResource(
                "import.result.title", defaultValue: "\(result.registered) new registrations"
            ).localized(in: locale))
        } else {
            Text("import.result.titleNone")
        }
    }

    /// The rows that were left out and why, one line each.
    private var details: some View {
        ListCard(dividerInset: 56) {
            if result.duplicates > 0 {
                detailRow(
                    icon: .repeatArrows,
                    text: LocalizedStringResource(
                        "import.result.duplicates", defaultValue: "\(result.duplicates) already in your list"
                    ),
                    detail: "import.result.duplicates.detail", identifier: "importClients.result.duplicates"
                )
            }
            if result.malformed > 0 {
                detailRow(
                    icon: .alert,
                    text: LocalizedStringResource(
                        "import.result.malformed", defaultValue: "\(result.malformed) entries skipped"
                    ),
                    detail: "import.result.malformed.detail", identifier: "importClients.result.malformed"
                )
            }
        }
    }

    private func detailRow(
        icon: Icon, text: LocalizedStringResource, detail: LocalizedStringKey, identifier: String
    ) -> some View {
        HStack(alignment: .top, spacing: Spacing.row) {
            Image(icon: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.ink2)
                .frame(width: 32, height: 32)
                .background(Palette.sunken, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(text.localized(in: locale)).font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                Text(detail).font(Typography.meta).foregroundStyle(Palette.ink2)
            }
            .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }

    /// What the free registrations did not cover, and the way to the plan that adds the rest.
    private var paywallOffer: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(LocalizedStringResource(
                    "import.result.blocked", defaultValue: "\(result.blocked) more need a plan"
                ).localized(in: locale))
                    .font(Typography.bodyStrong).foregroundStyle(Palette.sageText)
                Text("import.result.blocked.detail").font(Typography.meta).foregroundStyle(Palette.sageText)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("importClients.result.blocked")
            Button { viewModel.showPaywall() } label: { Text("import.result.seePlans") }
                .buttonStyle(.belloSecondary)
                .accessibilityIdentifier("importClients.result.seePlansButton")
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.sageWash, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
    }

    private var actionBar: some View {
        Button(action: onViewClients) {
            Text(LocalizedStringResource(
                "import.result.viewClients", defaultValue: "View \(term.pluralText(in: locale))"
            ).localized(in: locale))
        }
        .buttonStyle(.belloPrimary)
        .padding(.horizontal, Spacing.gutter)
        .padding(.vertical, Spacing.md)
        .background(Palette.bg)
        .accessibilityIdentifier("importClients.result.viewClientsButton")
        .motionBar()
    }
}
