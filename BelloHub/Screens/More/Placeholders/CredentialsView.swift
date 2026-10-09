//
//  CredentialsView.swift
//  BelloHub
//

import SwiftUI

/// PLACEHOLDER for 6.10 Credentials. An S5 slice replaces it with the real screen (same name and `init()`, in its
/// feature folder) and deletes this file. Nothing here is meant to ship.
struct CredentialsView: View {
    var body: some View {
        Text(verbatim: "CredentialsView")
            .accessibilityIdentifier("credentials.placeholder")
    }
}

#Preview {
    NavigationStack { CredentialsView() }
}
