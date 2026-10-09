//
//  WeekdayRow.swift
//  BelloHub
//

import SwiftUI

/// One weekday of the working hours: its name with the hours (or "Closed") that open the day's sheet, and a switch that
/// opens or closes the day. Two controls in one row, so each has its own label and identifier; a row-wide tap would
/// have to choose between them.
struct WeekdayRow: View {
    let weekday: Int
    let name: String
    /// The hours as text, or nil when the day is closed.
    let hours: String?
    @Binding var isOpen: Bool
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: Spacing.row) {
            Button(action: onEdit) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(verbatim: name).font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                    if let hours {
                        Text(verbatim: hours).font(Typography.meta).foregroundStyle(Palette.ink2)
                    } else {
                        Text("availability.day.closed").font(Typography.meta).foregroundStyle(Palette.ink2)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(hours == nil)
            .accessibilityHint(hours == nil ? Text(verbatim: "") : Text("availability.day.hint"))
            .accessibilityIdentifier("availability.day.\(weekday)")

            Toggle(isOn: $isOpen) { Text(verbatim: name) }
                .labelsHidden()
                .tint(Palette.sage)
                .accessibilityLabel(Text(verbatim: name))
                .accessibilityIdentifier("availability.dayToggle.\(weekday)")
        }
    }
}
