//
//  UITestAppleOverlay.swift
//  BelloHub
//

#if DEBUG
import SwiftUI

/// In a UI-test launch the system Apple sheet cannot be driven, so a transparent button over the real native button
/// runs `action` instead (sign the dev Apple user in, or re-authorize before deleting the account). The real button
/// stays drawn underneath, so the audits still measure its layout. DEBUG only.
struct UITestAppleOverlay: ViewModifier {
    let identifier: String
    let action: () -> Void

    func body(content: Content) -> some View {
        if LaunchOptions.current.isUITesting {
            content
                .accessibilityHidden(true)
                .overlay {
                    Button(action: action) { Color.clear }
                        .accessibilityLabel(Text(verbatim: "Continue with Apple"))
                        .accessibilityIdentifier(identifier)
                }
        } else {
            content
        }
    }
}
#endif
