//
//  PlanLegalSection.swift
//  BelloHub
//

import SwiftUI

/// What App Review 3.1.2 asks next to an auto-renewing subscription, on the Plan screen and the paywall: that the plan
/// renews automatically at the price shown until she cancels, and links to the Terms of Use and the Privacy Policy
/// (the texts bundled with the app, in her language; the same pages as on the website).
struct PlanLegalSection: View {
    let errorMessage: String?
    let onOpen: (LegalNotice) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("plan.legal.renewal")
                .font(Typography.footnote)
                .foregroundStyle(Palette.ink2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("plan.legal.renewal")
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Spacing.md) { links }
                VStack(alignment: .leading, spacing: 0) { links }
            }
            if let errorMessage {
                Text(verbatim: errorMessage).font(Typography.footnote).foregroundStyle(Palette.coralText)
                    .accessibilityIdentifier("plan.legal.error")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var links: some View {
        link("plan.legal.terms", notice: .termsAndDPA, identifier: "plan.legal.termsButton")
        link("plan.legal.privacy", notice: .privacyPolicy, identifier: "plan.legal.privacyButton")
    }

    private func link(_ title: LocalizedStringKey, notice: LegalNotice, identifier: String) -> some View {
        Button { onOpen(notice) } label: {
            Text(title)
                .font(Typography.metaStrong)
                .foregroundStyle(Palette.roseText)
                .frame(minHeight: Spacing.touchTarget, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isLink)
        .accessibilityIdentifier(identifier)
    }
}

#if DEBUG
#Preview {
    PlanLegalSection(errorMessage: nil, onOpen: { _ in }).padding().background(Palette.bg)
}
#endif
