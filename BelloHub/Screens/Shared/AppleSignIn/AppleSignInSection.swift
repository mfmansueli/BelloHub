//
//  AppleSignInSection.swift
//  BelloHub
//

import AuthenticationServices
import SwiftUI

/// The native Sign in with Apple button plus the honest message under it when sign-in failed. The system draws the
/// button (label, logo, localization, right-to-left); black on light and white on dark keep it above 4.5:1 and
/// match Apple's guidelines.
struct AppleSignInSection: View {
    let viewModel: AppleSignInViewModel
    let identifier: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: Spacing.sm) {
            button
            if let error = viewModel.error {
                Text(message(for: error))
                    .font(Typography.footnote)
                    .foregroundStyle(Palette.coralText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.updatesFrequently)
                    .accessibilityIdentifier("\(identifier).error")
            }
        }
    }

    private var button: some View {
        SignInWithAppleButton(.continue, onRequest: viewModel.prepare, onCompletion: viewModel.complete)
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 56)
            .disabled(viewModel.isWorking)
            .accessibilityIdentifier(identifier)
            #if DEBUG
            .modifier(UITestAppleOverlay(viewModel: viewModel, identifier: identifier))
            #endif
    }

    private func message(for error: AuthError) -> LocalizedStringKey {
        switch error {
        case .network: "onb.signIn.error.network"
        case .unavailable: "onb.signIn.error.unavailable"
        case .tooManyAttempts: "onb.signIn.error.tooMany"
        default: "onb.apple.error.failed"
        }
    }
}

#if DEBUG
/// In a UI-test launch the system sheet cannot be driven, so a transparent button over the real one signs the dev
/// Apple user in. The real button stays drawn, so the audits still measure its layout.
private struct UITestAppleOverlay: ViewModifier {
    let viewModel: AppleSignInViewModel
    let identifier: String

    func body(content: Content) -> some View {
        if LaunchOptions.current.isUITesting {
            content
                .accessibilityHidden(true)
                .overlay {
                    Button(action: viewModel.signInWithDevStub) { Color.clear }
                        .accessibilityLabel(Text(verbatim: "Continue with Apple"))
                        .accessibilityIdentifier(identifier)
                }
        } else {
            content
        }
    }
}
#endif
