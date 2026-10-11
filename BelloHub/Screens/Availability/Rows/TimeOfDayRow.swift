//
//  TimeOfDayRow.swift
//  BelloHub
//

import SwiftUI

/// A label and a native time picker that edits minutes after midnight in the business time zone. The system picker is
/// kept (it brings the wheel, VoiceOver adjustable values and the locale's clock); only its binding converts, so the
/// time she sees is the time clients see, whatever zone the phone is in.
struct TimeOfDayRow: View {
    let title: LocalizedStringKey
    @Binding var minutes: Int
    let formatters: Formatters
    var identifier: String?

    var body: some View {
        DatePicker(
            selection: Binding(
                get: { formatters.timeOfDay(minutes: minutes) },
                set: { minutes = formatters.minutesOfDay($0) }
            ),
            displayedComponents: .hourAndMinute
        ) {
            Text(title).font(Typography.body).foregroundStyle(Palette.ink)
        }
        .environment(\.timeZone, formatters.timeZone)
        .environment(\.calendar, formatters.calendar)
        .frame(minHeight: Spacing.touchTarget)
        .accessibilityIdentifier(identifier ?? "")
    }
}
