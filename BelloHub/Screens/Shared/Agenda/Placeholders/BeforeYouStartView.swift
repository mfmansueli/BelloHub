//
//  BeforeYouStartView.swift
//  BelloHub
//

import SwiftUI

/// PLACEHOLDER for 3.3 BeforeYouStart. An S6 slice replaces it with the real screen (same name
/// and `init`, in its feature folder) and deletes this file. Not meant to ship.
struct BeforeYouStartView: View {
    let appointmentID: UUID
    var body: some View {
        Text(verbatim: "BeforeYouStartView")
            .accessibilityIdentifier("beforeYouStart.placeholder")
    }
}
