//
//  WelcomeView.swift
//  BelloHub
//

import SwiftUI

/// 1.1 Onb-1-Welcome. Sign in with Apple is the main action (D44) and creates or opens the workspace alike; the phone
/// number is the alternative where the build can send a code (`SessionService.supportsPhoneSignIn`).
struct WelcomeView: View {
    let onUsePhone: () -> Void
    private let offersPhone: Bool

    @State private var appleSignIn: AppleSignInViewModel

    init(session: SessionService, onSignedIn: @escaping @MainActor () async -> Void, onUsePhone: @escaping () -> Void) {
        self.onUsePhone = onUsePhone
        offersPhone = session.supportsPhoneSignIn
        _appleSignIn = State(initialValue: AppleSignInViewModel(session: session, onSignedIn: onSignedIn))
    }

    var body: some View {
        ScrollView {
            StaggeredStack(spacing: Spacing.lg) {
                WelcomePreviewCards()
                pill
                BrandLockup()
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("onb.welcome.tagline")
                        .font(Typography.screenTitle)
                        .foregroundStyle(Palette.ink)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("welcome.tagline")
                    Text("onb.welcome.subtitle")
                        .font(Typography.body)
                        .foregroundStyle(Palette.ink2)
                }
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.xl)
        }
        .background(Palette.bg)
        .safeAreaInset(edge: .bottom) { actions }
    }

    private var pill: some View {
        HStack(spacing: Spacing.sm) {
            Circle().fill(Palette.rose).frame(width: 8, height: 8)
            Text("onb.welcome.pill").font(Typography.metaStrong).foregroundStyle(HeroPalette.ink)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.row)
        .background(HeroPalette.gradientEnd, in: Capsule())
    }

    private var actions: some View {
        VStack(spacing: Spacing.sm) {
            AppleSignInSection(viewModel: appleSignIn, identifier: "signIn.appleButton")
            if offersPhone {
                Button(action: onUsePhone) { Text("onb.apple.usePhone") }
                    .buttonStyle(.belloSecondary)
                    .accessibilityIdentifier("welcome.phoneButton")
            }
        }
        .padding(.horizontal, Spacing.gutter)
        .padding(.vertical, Spacing.md)
        .background(Palette.bg)
        .motionBar()
    }
}

#Preview {
    WelcomeView(session: SessionService(), onSignedIn: {}, onUsePhone: {})
}
