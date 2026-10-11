//
//  SchedulingWarningsView.swift
//  BelloHub
//

import SwiftUI

/// The warnings of a time, one notice each. They inform; nothing here blocks the booking.
struct SchedulingWarningsView: View {
    let entries: [SchedulingWarningText.Entry]
    let idPrefix: String

    @Environment(\.locale) private var locale

    var body: some View {
        VStack(spacing: Spacing.sm) {
            ForEach(entries) { entry in
                InlineNotice(
                    style: style(entry.tone), title: Text(entry.title.localized(in: locale)),
                    message: entry.message.map { Text($0.localized(in: locale)) }
                )
                .accessibilityIdentifier("\(idPrefix).warning.\(entry.key)")
            }
        }
    }

    private func style(_ tone: SchedulingWarningText.Tone) -> InlineNotice.Style {
        switch tone {
        case .safety: .safety
        case .warning: .warning
        case .info: .info
        }
    }
}
