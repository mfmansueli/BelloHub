//
//  StorageUnavailableView.swift
//  BelloHub
//

import SwiftUI

/// Shown instead of the app when the vault could not be opened on this phone. It never offers to wipe anything: her
/// records may be intact and only unreachable for now.
struct StorageUnavailableView: View {
    var body: some View {
        EmptyState(icon: .alert, title: "storage.unavailable.title", message: "storage.unavailable.message")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.bg)
            .accessibilityIdentifier("storage.unavailable")
    }
}

#Preview {
    StorageUnavailableView()
}
