//
//  VisitListRow.swift
//  BelloHub
//

import SwiftUI

/// An appointment as a row of a list: its time, the client and the service on the wash of its status. Used where the
/// timeline cannot hold readable text (the day and the week at accessibility text sizes). One link, one VoiceOver
/// element, with the same menu as a block on the timeline.
struct VisitListRow: View {
    let appointment: Appointment
    let clientName: String
    let text: CalendarVisitText
    let onReschedule: () -> Void
    let onCancel: () -> Void

    var body: some View {
        let style = CalendarVisitStyle.style(for: appointment.status)
        NavigationLink(value: AgendaRoute.appointment(id: appointment.id)) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(verbatim: text.span(appointment)).font(Typography.footnoteStrong)
                Text(verbatim: clientName).font(Typography.bodyStrong)
                Text(verbatim: appointment.serviceName).font(Typography.meta)
            }
            .foregroundStyle(style.foreground)
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, minHeight: Spacing.touchTarget, alignment: .leading)
            .background(style.background, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: text.accessibilityLabel(for: appointment, clientName: clientName)))
        .accessibilityIdentifier("calendar.visit.\(appointment.id.uuidString)")
        .contextMenu {
            Button(action: onReschedule) { Text("calendar.visit.reschedule") }
                .accessibilityIdentifier("calendar.visit.menu.reschedule")
            Button(role: .destructive, action: onCancel) { Text("calendar.visit.cancel") }
        }
    }
}
