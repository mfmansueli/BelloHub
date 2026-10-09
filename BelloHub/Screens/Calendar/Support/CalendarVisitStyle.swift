//
//  CalendarVisitStyle.swift
//  BelloHub
//

import SwiftUI

/// The colors of a visit block, by status: confirmed in sage, booked and waiting in rose, finished in neutral and a
/// missed one in coral. Every pair is a `Palette` text token on its own wash, measured by the contrast tests.
enum CalendarVisitStyle {
    static func style(for status: AppointmentStatus) -> StatusStyle {
        switch status {
        case .confirmed: StatusPalette.confirmed
        case .booked: StatusPalette.nextUp
        case .completed: StatusPalette.completed
        case .noShow: StatusPalette.attention
        case .cancelled: StatusPalette.completed
        }
    }

    /// The bar on the leading edge of a block, in the status' dot color.
    static func accent(for status: AppointmentStatus) -> Color {
        style(for: status).dot
    }
}
