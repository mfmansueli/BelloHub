//
//  DayAgendaList.swift
//  BelloHub
//

import SwiftUI

/// The day as a list in time order: the visits, her breaks and the time she blocked. It replaces the timeline at
/// accessibility text sizes, where two visits side by side or an hour of 60 minutes cannot hold readable text.
struct DayAgendaList: View {
    let layout: CalendarDayLayout
    let appointments: [Appointment]
    let blocks: [TimeBlock]
    let clientName: (Appointment) -> String
    let formatters: Formatters
    let onAdd: () -> Void
    let onReschedule: (UUID) -> Void
    let onCancel: (UUID) -> Void
    let onRemoveBlock: (UUID) -> Void

    /// What the list shows, merged and sorted by start.
    private enum Item: Identifiable {
        case visit(Appointment)
        case band(CalendarDayLayout.Band)

        var id: String {
            switch self {
            case .visit(let appointment): appointment.id.uuidString
            case .band(let band): band.id
            }
        }

        var start: Date {
            switch self {
            case .visit(let appointment): appointment.startsAt
            case .band(let band): band.interval.start
            }
        }
    }

    private var text: CalendarVisitText { CalendarVisitText(formatters: formatters) }

    private var items: [Item] {
        (appointments.map(Item.visit) + layout.bands.map(Item.band)).sorted { $0.start < $1.start }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ForEach(items) { item in
                switch item {
                case .visit(let appointment):
                    VisitListRow(
                        appointment: appointment, clientName: clientName(appointment), text: text,
                        onReschedule: { onReschedule(appointment.id) }, onCancel: { onCancel(appointment.id) }
                    )
                    .motionRow()
                case .band(let band):
                    bandRow(band).motionRow()
                }
            }
            Button(action: onAdd) { AddRowLabel(title: "calendar.agenda.add") }
                .accessibilityIdentifier("calendar.agenda.add")
        }
        .motionRows(ids: items.map(\.id), context: layout.day)
        .padding(.horizontal, Spacing.gutter)
    }

    @ViewBuilder
    private func bandRow(_ band: CalendarDayLayout.Band) -> some View {
        let span = (band.interval.start..<band.interval.end).formatted(
            Date.IntervalFormatStyle(locale: formatters.locale, calendar: formatters.calendar,
                                     timeZone: formatters.timeZone).hour().minute()
        )
        switch band.kind {
        case .breakTime(let label):
            row(Text(verbatim: "\(label) · \(span)"), fill: Palette.sunken, foreground: Palette.ink2)
        case .blocked(let id):
            let reason = blocks.first { $0.id == id }?.reason
            let base = String(localized: LocalizedStringResource(
                "calendar.band.blocked", defaultValue: "Blocked · \(span)", locale: formatters.locale
            ))
            Button { onRemoveBlock(id) } label: {
                row(Text(verbatim: reason.map { "\(base) · \($0)" } ?? base),
                    fill: Palette.neutralWash, foreground: Palette.neutralText)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("calendar.block.\(id.uuidString)")
        }
    }

    private func row(_ label: Text, fill: Color, foreground: Color) -> some View {
        label.font(Typography.meta).foregroundStyle(foreground)
            .multilineTextAlignment(.leading)
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, minHeight: Spacing.touchTarget, alignment: .leading)
            .background(fill, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
    }
}
