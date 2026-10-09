//
//  IncidentView.swift
//  BelloHub
//

import SwiftUI

/// PLACEHOLDER for 4.9 Incident. An S7 slice replaces it with the real screen (same name
/// and `init`, in its feature folder) and deletes this file. Not meant to ship.
struct IncidentView: View {
    let clientID: UUID
    let appointmentID: UUID?
    var body: some View {
        Text(verbatim: "IncidentView")
            .accessibilityIdentifier("incident.placeholder")
    }
}
