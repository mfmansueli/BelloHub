//
//  ClientHealthView.swift
//  BelloHub
//

import SwiftUI

/// PLACEHOLDER for 4.5 Health and consent, which the health-forms slice provides with this exact signature. The
/// coordinator deletes this file when that slice is integrated; nothing here is meant to ship.
struct ClientHealthView: View {
    let clientID: UUID

    var body: some View {
        Text(verbatim: "ClientHealthView \(clientID.uuidString)")
            .accessibilityIdentifier("clientHealth.placeholder")
    }
}

#Preview {
    NavigationStack { ClientHealthView(clientID: UUID()) }
}
