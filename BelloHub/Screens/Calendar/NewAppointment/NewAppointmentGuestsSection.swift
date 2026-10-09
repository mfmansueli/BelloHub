//
//  NewAppointmentGuestsSection.swift
//  BelloHub
//

import SwiftUI

/// The guests of a visit: each is booked right after the client, with the same service (D19), so each adds the
/// service's time. A name is optional (D48: names are asked in person).
struct NewAppointmentGuestsSection: View {
    let names: [String]
    let canAdd: Bool
    let onAdd: () -> Void
    let onRename: (String, Int) -> Void
    let onRemove: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ForEach(names.indices, id: \.self) { index in row(index) }
            if canAdd {
                Button(action: onAdd) { AddRowLabel(title: "newAppointment.guests.add") }
                    .accessibilityIdentifier("newAppointment.guests.addButton")
            }
            FooterNote(text: "newAppointment.guests.note", icon: .info)
        }
    }

    private func row(_ index: Int) -> some View {
        HStack(spacing: Spacing.sm) {
            TextField(
                text: Binding(
                    get: { names.indices.contains(index) ? names[index] : "" },
                    set: { onRename($0, index) }
                )
            ) { Text("newAppointment.guests.name") }
                .font(Typography.body).foregroundStyle(Palette.ink)
                .padding(.horizontal, Spacing.md)
                .frame(minHeight: 52)
                .background(Palette.sunken, in: RoundedRectangle(cornerRadius: Radius.input, style: .continuous))
                .accessibilityIdentifier("newAppointment.guests.nameField.\(index)")
            Button { onRemove(index) } label: {
                Image(icon: .close)
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.ink)
                    .frame(width: Spacing.touchTarget, height: Spacing.touchTarget)
            }
            .accessibilityLabel(Text("newAppointment.guests.remove"))
            .accessibilityIdentifier("newAppointment.guests.removeButton.\(index)")
        }
    }
}
