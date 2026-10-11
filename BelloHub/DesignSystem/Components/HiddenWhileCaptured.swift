//
//  HiddenWhileCaptured.swift
//  BelloHub
//

import SwiftUI

/// Hides a secret (the recovery words) while the screen is recorded, mirrored or shared, and says why in its place.
/// A screenshot cannot be refused with a public API, so the words also stay masked until Face ID and the app-switcher
/// snapshot is covered by `PrivacyCover`; this closes the recording and AirPlay path (docs/06 section 4.2).
struct HiddenWhileCaptured: ViewModifier {
    let message: LocalizedStringKey
    @State private var isCaptured = false

    func body(content: Content) -> some View {
        content
            .opacity(isCaptured ? 0 : 1)
            .accessibilityHidden(isCaptured)
            .overlay {
                if isCaptured {
                    Text(message)
                        .font(Typography.footnote).foregroundStyle(Palette.ink2)
                        .multilineTextAlignment(.center)
                        .padding(Spacing.md)
                        .accessibilityIdentifier("captureShield.message")
                }
            }
            .background { SceneCaptureObserver(isCaptured: $isCaptured).frame(width: 0, height: 0) }
    }
}

extension View {
    /// Hides this view while the screen is being recorded or shared; `message` takes its place.
    func hiddenWhileCaptured(_ message: LocalizedStringKey = "captureShield.message") -> some View {
        modifier(HiddenWhileCaptured(message: message))
    }
}
