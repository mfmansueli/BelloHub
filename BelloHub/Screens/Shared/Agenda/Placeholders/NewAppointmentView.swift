//
//  NewAppointmentView.swift
//  BelloHub
//

import SwiftUI

/// PLACEHOLDER for 3.1 NewAppointment. An S6 slice replaces it with the real screen (same name
/// and `init`, in its feature folder) and deletes this file. Not meant to ship.
struct NewAppointmentView: View {
    let clientID: UUID?
    let startsAt: Date?
    var body: some View {
        Text(verbatim: "NewAppointmentView")
            .accessibilityIdentifier("newAppointment.placeholder")
    }
}
