//
//  HomeVisitRow.swift
//  BelloHub
//

import SwiftUI

/// One visit of "The rest of today": avatar, client and service on the leading side, the time and the status chip on
/// the trailing side. The whole row opens the visit; at accessibility sizes the trailing column goes below.
struct HomeVisitRow: View {
    let visit: AgendaDigest.Visit
    let formatters: Formatters
    @Environment(\.dynamicTypeSize) private var typeSize

    private var appointment: Appointment { visit.appointment }

    var body: some View {
        NavigationLink(value: AgendaRoute.appointment(id: appointment.id)) {
            layout {
                HStack(spacing: Spacing.row) {
                    Avatar(name: visit.clientName, id: appointment.clientID.uuidString, size: 52)
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(verbatim: visit.clientName)
                            .font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                        Text(verbatim: appointment.serviceName)
                            .font(Typography.meta).foregroundStyle(Palette.ink2)
                    }
                    Spacer(minLength: Spacing.sm)
                }
                VStack(alignment: typeSize.isAccessibilitySize ? .leading : .trailing, spacing: Spacing.xs) {
                    Text(verbatim: formatters.time(appointment.startsAt))
                        .font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                    AppointmentStatusChip(status: appointment.status)
                }
            }
            .padding(Spacing.md)
            .frame(minHeight: 72)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.visit.\(appointment.id.uuidString)")
    }

    private var layout: AnyLayout {
        typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.sm))
            : AnyLayout(HStackLayout(alignment: .center, spacing: Spacing.sm))
    }
}
