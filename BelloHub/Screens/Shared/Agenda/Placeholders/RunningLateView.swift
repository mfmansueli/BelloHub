//
//  RunningLateView.swift
//  BelloHub
//

import SwiftUI

/// PLACEHOLDER for 2.12 RunningLate. An S6 slice replaces it with the real screen (same name
/// and `init`, in its feature folder) and deletes this file. Not meant to ship.
struct RunningLateView: View {
    let appointmentID: UUID
    var body: some View {
        Text(verbatim: "RunningLateView")
            .accessibilityIdentifier("runningLate.placeholder")
    }
}
