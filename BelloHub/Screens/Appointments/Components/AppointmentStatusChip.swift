//
//  AppointmentStatusChip.swift
//  BelloHub
//

import SwiftUI

/// The status of a visit as a chip. The chip's text says the status, so color is never the only signal.
struct AppointmentStatusChip: View {
    let status: AppointmentStatus

    var body: some View {
        StatusChip(label: label, style: style)
            .accessibilityIdentifier("appointment.statusChip")
    }

    private var label: LocalizedStringKey {
        switch status {
        case .booked: "appointment.status.booked"
        case .confirmed: "appointment.status.confirmed"
        case .completed: "appointment.status.completed"
        case .cancelled: "appointment.status.cancelled"
        case .noShow: "appointment.status.noShow"
        }
    }

    private var style: StatusStyle {
        switch status {
        case .booked: StatusPalette.pending
        case .confirmed: StatusPalette.confirmed
        case .completed: StatusPalette.completed
        case .cancelled, .noShow: StatusPalette.attention
        }
    }
}
