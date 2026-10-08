//
//  ImportClientsView.swift
//  BelloHub
//

import SwiftUI

/// PLACEHOLDER for 4.6 Import clients, which the import slice provides with this exact signature (it brings its own
/// `NavigationStack`, because it is presented as a sheet). The coordinator deletes this file when that slice is
/// integrated; nothing here is meant to ship.
struct ImportClientsView: View {
    var onViewClients: () -> Void = {}

    var body: some View {
        NavigationStack {
            Button { onViewClients() } label: { Text(verbatim: "View clients") }
                .accessibilityIdentifier("importClients.placeholder")
        }
    }
}

#Preview {
    ImportClientsView()
}
