//
//  ConsentsCard.swift
//  BelloHub
//

import SwiftUI

/// The consent records of one client (D55), the most recent first, and the action that adds one. The header shows
/// how many there are. Each row opens the record for editing.
struct ConsentsCard: View {
    let consents: [ConsentRecord]
    let formatters: Formatters
    let onOpen: (ConsentRecord) -> Void
    let onAdd: () -> Void
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ListCard(dividerInset: Spacing.md) {
                if consents.isEmpty {
                    Text("health.consent.empty")
                        .font(Typography.meta)
                        .foregroundStyle(Palette.ink2)
                        .padding(Spacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("health.consent.empty")
                } else {
                    ForEach(consents) { consent in
                        ConsentRecordRow(
                            record: consent, formatters: formatters,
                            identifier: "health.consent.\(consent.id.uuidString)"
                        ) {
                            onOpen(consent)
                        }
                    }
                }
                addButton
            }
            Text("health.consent.footnote")
                .font(Typography.footnote)
                .foregroundStyle(Palette.ink2)
                .padding(.top, Spacing.sm)
                .accessibilityIdentifier("health.consent.footnote")
        }
    }

    // MARK: - Parts

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("health.section.consent")
                .font(Typography.section)
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: Spacing.row)
            if !consents.isEmpty {
                Text(LocalizedStringResource(
                    "health.consent.count", defaultValue: "\(consents.count) records"
                ).localized(in: locale))
                    .font(Typography.footnote)
                    .foregroundStyle(Palette.ink2)
            }
        }
        .padding(.top, Spacing.section)
        .padding(.bottom, Spacing.row)
    }

    private var addButton: some View {
        Button(action: onAdd) {
            HStack(spacing: Spacing.sm) {
                Image(icon: .plus).font(.system(size: 15, weight: .semibold)).accessibilityHidden(true)
                Text("health.consent.add").font(Typography.bodyStrong)
                Spacer(minLength: 0)
            }
            .foregroundStyle(Palette.roseText)
            .padding(.horizontal, Spacing.md)
            .frame(maxWidth: .infinity, minHeight: Spacing.touchTarget, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("health.addConsentButton")
    }
}
