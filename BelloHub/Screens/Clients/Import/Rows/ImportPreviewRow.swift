//
//  ImportPreviewRow.swift
//  BelloHub
//

import SwiftUI

/// A row of the file as it will be imported with the current column choices: the name and the phone, or why the row
/// cannot be imported. Shown under the column menus so she sees at once whether the choices are right.
struct ImportPreviewRow: View {
    let entry: ImportEntry
    let phoneText: String?
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(verbatim: entry.displayName.isEmpty ? "–" : BidiIsolate.wrap(entry.displayName))
                .font(Typography.calloutStrong)
                .foregroundStyle(Palette.ink)
            if let issue = entry.issue {
                Text(issue.message.localized(in: locale)).font(Typography.footnote).foregroundStyle(Palette.coralText)
            } else if let phoneText {
                Text(verbatim: phoneText).font(Typography.footnote).foregroundStyle(Palette.ink2)
            } else {
                Text("import.noPhone").font(Typography.footnote).foregroundStyle(Palette.ink2)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.row)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
