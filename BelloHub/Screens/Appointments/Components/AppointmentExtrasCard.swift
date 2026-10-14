//
//  AppointmentExtrasCard.swift
//  BelloHub
//

import SwiftUI

/// The rest of what the visit holds: the add-ons, the guests and her private note (encrypted at rest). Nothing shows
/// when the visit has none of them.
struct AppointmentExtrasCard: View {
    let appointment: Appointment
    let formatters: Formatters

    private var hasContent: Bool {
        !appointment.addOns.isEmpty || appointment.numberOfGuests > 0 || !(appointment.privateNote ?? "").isEmpty
    }

    var body: some View {
        if hasContent {
            VStack(alignment: .leading, spacing: Spacing.md) {
                if !appointment.addOns.isEmpty {
                    infoLine("appointment.addOns", value: appointment.addOns.map(\.name), identifier: "addOns")
                }
                if appointment.numberOfGuests > 0 {
                    guestLine
                }
                if let note = appointment.privateNote, !note.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Label { Text("appointment.note.title") } icon: { Image(icon: .lock) }
                            .font(Typography.metaStrong)
                            .foregroundStyle(Palette.ink2)
                        Text(verbatim: note)
                            .font(Typography.body)
                            .foregroundStyle(Palette.ink)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("appointment.privateNote")
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .belloCard(cornerRadius: Radius.tile)
        }
    }

    private var guestLine: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("appointment.guests").font(Typography.metaStrong).foregroundStyle(Palette.ink2)
            if appointment.guests.isEmpty || appointment.numberOfGuests != appointment.guests.count {
                Text(verbatim: formatters.number(appointment.numberOfGuests))
                    .font(Typography.body).foregroundStyle(Palette.ink)
            } else {
                Text(verbatim: formatters.list(appointment.guests))
                    .font(Typography.body).foregroundStyle(Palette.ink)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("appointment.guests")
    }

    private func infoLine(_ title: LocalizedStringKey, value: [String], identifier: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(title).font(Typography.metaStrong).foregroundStyle(Palette.ink2)
            Text(verbatim: formatters.list(value)).font(Typography.body).foregroundStyle(Palette.ink)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("appointment.\(identifier)")
    }
}
