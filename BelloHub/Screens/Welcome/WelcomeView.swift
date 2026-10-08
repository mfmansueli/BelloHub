//
//  WelcomeView.swift
//  BelloHub
//

import SwiftUI

/// 1.1 Onb-1-Welcome. "Get started" opens a new workspace; "Sign in" is for someone who already has one.
struct WelcomeView: View {
    let onGetStarted: () -> Void
    let onSignIn: () -> Void

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
        .background(Color(hex: 0x242321), in: Capsule())
    }

    private var actions: some View {
        VStack(spacing: Spacing.sm) {
            Button(action: onGetStarted) { Text("onb.welcome.getStarted") }
                .buttonStyle(.belloPrimary)
                .accessibilityIdentifier("welcome.getStartedButton")
            FlowLayout(spacing: Spacing.xs, lineSpacing: 0, isCentered: true) {
                prompt
                signInLink
            }
        }
        .padding(.horizontal, Spacing.gutter)
        .padding(.vertical, Spacing.md)
        .background(Palette.bg)
        .motionBar()
    }

    private var prompt: some View {
        Text("onb.welcome.haveAccount").font(Typography.meta).foregroundStyle(Palette.ink2)
    }

    private var signInLink: some View {
        Button(action: onSignIn) {
            Text("onb.welcome.signIn").font(Typography.metaStrong).foregroundStyle(Palette.roseText)
                .frame(minHeight: Spacing.touchTarget)
        }
        .accessibilityIdentifier("welcome.signInButton")
    }
}

#Preview {
    WelcomeView(onGetStarted: {}, onSignIn: {})
}
