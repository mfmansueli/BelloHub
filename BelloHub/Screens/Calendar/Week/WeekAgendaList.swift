//
//  WeekAgendaList.swift
//  BelloHub
//

import SwiftUI

/// The week as a list of days with their visits. It replaces the grid at accessibility text sizes, where seven
/// columns cannot hold readable text: the same visits, at the size the person chose, with 44 pt rows.
struct WeekAgendaList: View {
    let days: [Date]
    let visits: (Date) -> [Appointment]
    let clientName: (Appointment) -> String
    let now: Date
    let formatters: Formatters
    let onSelectDay: (Date) -> Void
    let onAdd: (Date) -> Void

    private var text: CalendarVisitText { CalendarVisitText(formatters: formatters) }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: Spacing.md) {
            ForEach(days, id: \.self) { day in section(day) }
        }
        .padding(.horizontal, Spacing.gutter)
    }

    private func section(_ day: Date) -> some View {
        let dayVisits = visits(day)
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            Button { onSelectDay(day) } label: {
                Text(verbatim: formatters.weekdayDayMonth(day))
                    .font(Typography.section).foregroundStyle(Palette.ink)
                    .frame(maxWidth: .infinity, minHeight: Spacing.touchTarget, alignment: .leading)
            }
            .accessibilityAddTraits(.isHeader)
            .accessibilityHint(Text("calendar.week.dayHint"))
            .accessibilityIdentifier("calendar.agenda.day.\(formatters.calendar.component(.day, from: day))")
            if dayVisits.isEmpty {
                Text("calendar.agenda.noVisits").font(Typography.meta).foregroundStyle(Palette.ink2)
            }
            ForEach(dayVisits) { visit in
                let style = CalendarVisitStyle.style(for: visit.status)
                NavigationLink(value: AgendaRoute.appointment(id: visit.id)) {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(verbatim: text.span(visit)).font(Typography.footnoteStrong)
                        Text(verbatim: clientName(visit)).font(Typography.bodyStrong)
                        Text(verbatim: visit.serviceName).font(Typography.meta)
                    }
                    .foregroundStyle(style.foreground)
                    .padding(Spacing.md)
                    .frame(maxWidth: .infinity, minHeight: Spacing.touchTarget, alignment: .leading)
                    .background(
                        style.background, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(verbatim: text.accessibilityLabel(for: visit, clientName: clientName(visit))))
                .accessibilityIdentifier("calendar.visit.\(visit.id.uuidString)")
            }
            Button { onAdd(day) } label: { AddRowLabel(title: "calendar.agenda.add") }
                .accessibilityIdentifier("calendar.agenda.add.\(formatters.calendar.component(.day, from: day))")
        }
    }
}
