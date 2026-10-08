//
//  LockedView.swift
//  BelloHub
//

import SwiftUI

/// 1.11 Locked. Shown when the app opens cold or after the grace period: no client information is on screen. It
/// asks for Face ID by itself once, and again from the button. The passcode is the system's own fallback.
struct LockedView: View {
    @Environment(AppLockService.self) private var lock
    @Environment(\.scenePhase) private var scenePhase
    @State private var didAutoPrompt = false

    var body: some View {
        // A scroll view with a minimum height of the screen: the spacers still push the button to the bottom, and
        // at the largest text sizes everything stays reachable instead of running off the screen.
        GeometryReader { proxy in
            ScrollView {
                content.frame(minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background { GlowBackdrop() }
        .task(id: scenePhase) {
            // One automatic prompt per appearance, only while the app is in front: the system sheet cannot show
            // over an app that is going to the background.
            guard scenePhase == .active, !didAutoPrompt else { return }
            didAutoPrompt = true
            await lock.unlock()
        }
    }

    private var content: some View {
        VStack(spacing: Spacing.lg) {
            Spacer(minLength: Spacing.xl)
            BrandMark(size: 64)
            VStack(spacing: Spacing.sm) {
                Text("locked.title").font(Typography.title).foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("locked.title")
                Text("locked.subtitle").font(Typography.meta).foregroundStyle(Palette.ink2)
                    .multilineTextAlignment(.center)
            }
            biometryTile
            if let failure = lock.failure { failureNotice(failure) }
            Spacer(minLength: Spacing.xl)
            actions
        }
        .padding(.horizontal, Spacing.gutter)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Parts

    private var biometryTile: some View {
        Image(systemName: tileSymbol)
            .font(.system(size: 44, weight: .light))
            .foregroundStyle(Palette.ink)
            .frame(width: 96, height: 96)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.hero, style: .continuous))
            .belloElevation(.e1, cornerRadius: Radius.hero)
            .accessibilityHidden(true)
    }

    private var tileSymbol: String {
        switch lock.biometryKind {
        case .faceID: "faceid"
        case .touchID: "touchid"
        case .opticID: "opticid"
        case .passcodeOnly: "lock"
        }
    }

    private var actions: some View {
        VStack(spacing: Spacing.sm) {
            Button { Task { await lock.unlock() } } label: {
                HStack(spacing: Spacing.sm) {
                    if lock.biometryKind != .passcodeOnly {
                        Image(systemName: tileSymbol).accessibilityHidden(true)
                    }
                    Text(unlockTitle)
                }
            }
            .buttonStyle(.belloPrimary)
            .disabled(lock.isAuthenticating)
            .accessibilityIdentifier("locked.unlockButton")
            if lock.biometryKind != .passcodeOnly {
                Button { Task { await lock.unlock() } } label: { Text("locked.usePasscode") }
                    .buttonStyle(.belloTertiary)
                    .accessibilityIdentifier("locked.passcodeButton")
            }
        }
        .padding(.bottom, Spacing.md)
    }

    private var unlockTitle: LocalizedStringKey {
        switch lock.biometryKind {
        case .faceID: "locked.unlock.faceID"
        case .touchID: "locked.unlock.touchID"
        case .opticID: "locked.unlock.opticID"
        case .passcodeOnly: "locked.unlock.passcode"
        }
    }

    private func failureNotice(_ failure: UnlockFailure) -> some View {
        InlineNotice(
            style: failure == .keyMissing ? .warning : .info,
            title: failure == .keyMissing ? "locked.error.keyMissing.title" : "locked.error.notRecognized.title",
            message: failure == .keyMissing ? "locked.error.keyMissing.message" : "locked.error.notRecognized.message"
        )
        .accessibilityIdentifier("locked.error")
    }
}

#Preview {
    let keys = KeyManager()
    LockedView().environment(AppLockService(keyManager: keys))
}
