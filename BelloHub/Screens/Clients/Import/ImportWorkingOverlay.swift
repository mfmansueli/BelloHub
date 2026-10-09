//
//  ImportWorkingOverlay.swift
//  BelloHub
//

import SwiftUI

/// A spinner over the screen while a file is read or the import is saved. Touches are blocked: nothing can be started
/// twice.
struct ImportWorkingOverlay: View {
    var body: some View {
        ZStack {
            Palette.bg.opacity(0.6).ignoresSafeArea()
            ProgressView()
                .controlSize(.large)
                .padding(Spacing.lg)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                .accessibilityLabel(Text("import.working"))
                .accessibilityIdentifier("importClients.working")
        }
        .transition(.opacity)
    }
}
