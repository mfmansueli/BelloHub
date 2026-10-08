//
//  ImportSkippedRow.swift
//  BelloHub
//

import SwiftUI

/// A row or contact that cannot be imported, with the reason, so she can fix the file and try again. Not selectable.
struct ImportSkippedRow: View {
    let entry: ImportEntry
    @Environment(\.locale) private var locale

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.row) {
            Image(icon: .alert)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.coralText)
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                title
                if let issue = entry.issue {
                    Text(issue.message.localized(in: locale)).font(Typography.footnote)
                        .foregroundStyle(Palette.coralText)
                }
            }
            .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .padding(.vertical, Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("importClients.skipped.\(entry.id)")
    }

    /// The name when the source had one; otherwise the row number as the spreadsheet shows it.
    @ViewBuilder
    private var title: some View {
        if !entry.displayName.isEmpty {
            Text(verbatim: BidiIsolate.wrap(entry.displayName)).font(Typography.calloutStrong)
                .foregroundStyle(Palette.ink)
        } else if let row = entry.rowNumber {
            Text(LocalizedStringResource("import.skipped.row", defaultValue: "Row \(row)").localized(in: locale))
                .font(Typography.calloutStrong).foregroundStyle(Palette.ink)
        } else {
            Text("import.skipped.unnamed").font(Typography.calloutStrong).foregroundStyle(Palette.ink)
        }
    }
}
