//
//  VisitBlock.swift
//  BelloHub
//

import SwiftUI

/// A visit drawn on the timeline: its time, the client and the service, on the wash of its status with a bar on the
/// leading edge. One button, one VoiceOver element that reads client, service, day, time and status. The same block
/// serves the day view (full text) and the week grid (the client's name only, because a column is narrow).
struct VisitBlock: View {
    enum Density {
        case full
        /// The week grid: a column about 48 pt wide, so only the first name and no 44 pt minimum.
        case compact
    }

    let appointment: Appointment
    let clientName: String
    let density: Density
    let text: CalendarVisitText
    let onReschedule: () -> Void
    let onCancel: () -> Void

    var body: some View {
        let style = CalendarVisitStyle.style(for: appointment.status)
        NavigationLink(value: AgendaRoute.appointment(id: appointment.id)) {
            HStack(spacing: 0) {
                Rectangle().fill(CalendarVisitStyle.accent(for: appointment.status))
                    .frame(width: density == .full ? 4 : 3)
                    .accessibilityHidden(true)
                content(style)
                    .padding(.horizontal, density == .full ? Spacing.row : Spacing.xs)
                    .padding(.vertical, density == .full ? Spacing.sm : Spacing.xxs)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(style.background)
            .clipShape(RoundedRectangle(
                cornerRadius: density == .full ? Radius.control : Radius.block, style: .continuous
            ))
            .contentShape(Rectangle())
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

    @ViewBuilder
    private func content(_ style: StatusStyle) -> some View {
        switch density {
        case .full:
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(verbatim: text.span(appointment))
                    .font(Typography.footnoteStrong).foregroundStyle(style.foreground)
                Text(verbatim: clientName).font(Typography.bodyStrong).foregroundStyle(style.foreground)
                Text(verbatim: appointment.serviceName).font(Typography.meta).foregroundStyle(style.foreground)
            }
            .lineLimit(1)
        case .compact:
            Text(verbatim: clientName.split(separator: " ").first.map(String.init) ?? clientName)
                .font(Typography.caption).foregroundStyle(style.foreground)
                .lineLimit(2).minimumScaleFactor(0.6)
        }
    }
}
