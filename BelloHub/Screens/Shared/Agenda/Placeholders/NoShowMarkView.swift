//
//  NoShowMarkView.swift
//  BelloHub
//

import SwiftUI

/// PLACEHOLDER for 3.7 NoShowMark. An S6 slice replaces it with the real screen (same name
/// and `init`, in its feature folder) and deletes this file. Not meant to ship.
struct NoShowMarkView: View {
    let appointmentID: UUID
    var body: some View {
        Text(verbatim: "NoShowMarkView")
            .accessibilityIdentifier("noShowMark.placeholder")
    }
}
