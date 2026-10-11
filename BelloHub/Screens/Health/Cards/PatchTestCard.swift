//
//  PatchTestCard.swift
//  BelloHub
//

import SwiftUI

/// The patch test log of one client: the tests, newest first, and the action that records a new one. The header shows
/// how many records there are.
struct PatchTestCard: View {
    let patchTests: [PatchTest]
    let formatters: Formatters
    let onRecord: () -> Void
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ListCard(dividerInset: Spacing.md) {
                if patchTests.isEmpty {
                    Text("health.patch.empty")
                        .font(Typography.meta)
                        .foregroundStyle(Palette.ink2)
                        .padding(Spacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("health.patch.empty")
                } else {
                    ForEach(patchTests) { patchTest in
                        PatchTestRow(
                            patchTest: patchTest, formatters: formatters,
                            identifier: "health.patchTest.\(patchTest.id.uuidString)"
                        )
                    }
                }
                recordButton
            }
        }
    }

    // MARK: - Parts

    /// The section title with the number of records on its trailing side. The count is a plural, so each language
    /// writes it its own way ("1 record", "2 records").
    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("health.section.patchTests")
                .font(Typography.section)
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: Spacing.row)
            if !patchTests.isEmpty {
                Text(LocalizedStringResource(
                    "health.patch.count", defaultValue: "\(patchTests.count) records"
                ).localized(in: locale))
                    .font(Typography.footnote)
                    .foregroundStyle(Palette.ink2)
            }
        }
        .padding(.top, Spacing.section)
        .padding(.bottom, Spacing.row)
    }

    private var recordButton: some View {
        Button(action: onRecord) {
            HStack(spacing: Spacing.sm) {
                Image(icon: .plus).font(.system(size: 15, weight: .semibold)).accessibilityHidden(true)
                Text("health.patch.record").font(Typography.bodyStrong)
                Spacer(minLength: 0)
            }
            .foregroundStyle(Palette.roseText)
            .padding(.horizontal, Spacing.md)
            .frame(maxWidth: .infinity, minHeight: Spacing.touchTarget, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("health.recordPatchTestButton")
    }
}
