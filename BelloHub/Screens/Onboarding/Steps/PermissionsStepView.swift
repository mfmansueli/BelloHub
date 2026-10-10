//
//  PermissionsStepView.swift
//  BelloHub
//

import SwiftUI

/// 1.9 Permissions. One page per system permission (microphone, notifications, camera, contacts), each explaining
/// why before the system dialog appears. "Not now" skips; nothing here is required.
struct PermissionsStepView: View {
    let onContinue: () -> Void

    @Environment(PermissionService.self) private var permissions
    @State private var index = 0
    @State private var isAsking = false

    private let kinds = PermissionKind.allCases

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                page
                    .id(index)
                    .transition(.opacity)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, Spacing.gutter)
                    .padding(.top, Spacing.xl)
            }
            actions
        }
        .animation(.easeOut(duration: 0.2), value: index)
    }

    private var isDone: Bool { index >= kinds.count }

    // MARK: - Pages

    @ViewBuilder
    private var page: some View {
        if isDone {
            VStack(spacing: Spacing.lg) {
                SuccessSeal(size: 72)
                Text("onb.permissions.done.title").font(Typography.screenTitle).foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center).accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("onboarding.permissions.title")
                Text("onb.permissions.done.text").font(Typography.body).foregroundStyle(Palette.ink2)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, Spacing.xl)
        } else {
            let kind = kinds[index]
            VStack(spacing: Spacing.lg) {
                Image(icon: icon(for: kind))
                    .font(.system(size: 34, weight: .regular))
                    .foregroundStyle(Palette.roseDeepText)
                    .frame(width: 80, height: 80)
                    .background(Palette.roseWash, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                    .accessibilityHidden(true)
                Text(title(for: kind)).font(Typography.screenTitle).foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center).accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("onboarding.permissions.title")
                Text(text(for: kind)).font(Typography.body).foregroundStyle(Palette.ink2)
                    .multilineTextAlignment(.center)
                dots
            }
            .padding(.top, Spacing.xl)
        }
    }

    private var dots: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(0..<kinds.count, id: \.self) { step in
                Capsule().fill(step == index ? Palette.action : Palette.hairline)
                    .frame(width: step == index ? 22 : 6, height: 6)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(
            LocalizedStringResource("common.stepProgress", defaultValue: "Step \(index + 1) of \(kinds.count)")
        ))
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: Spacing.sm) {
            if isDone {
                Button(action: onContinue) { Text("onb.continue") }
                    .buttonStyle(.belloPrimary)
                    .accessibilityIdentifier("onboarding.permissions.continueButton")
            } else {
                Button(action: allow) { Text(allowTitle(for: kinds[index])) }
                    .buttonStyle(.belloPrimary)
                    .disabled(isAsking)
                    .accessibilityIdentifier("onboarding.permissions.allowButton")
                Button(action: skip) { Text("onb.permissions.notNow") }
                    .buttonStyle(.belloTertiary)
                    .accessibilityIdentifier("onboarding.permissions.notNowButton")
            }
        }
        .padding(.horizontal, Spacing.gutter)
        .padding(.vertical, Spacing.md)
        .background(Palette.bg)
        .motionBar()
    }

    private func allow() {
        guard !isDone, !isAsking else { return }
        isAsking = true
        let kind = kinds[index]
        Task {
            await permissions.request(kind)
            isAsking = false
            index += 1
        }
    }

    private func skip() {
        index += 1
    }

    // MARK: - Words

    private func icon(for kind: PermissionKind) -> Icon {
        switch kind {
        case .microphone: .mic
        case .notifications: .bell
        case .camera: .camera
        case .contacts: .clients
        }
    }

    private func title(for kind: PermissionKind) -> LocalizedStringKey {
        switch kind {
        case .microphone: "onb.permissions.microphone.title"
        case .notifications: "onb.permissions.notifications.title"
        case .camera: "onb.permissions.camera.title"
        case .contacts: "onb.permissions.contacts.title"
        }
    }

    private func text(for kind: PermissionKind) -> LocalizedStringKey {
        switch kind {
        case .microphone: "onb.permissions.microphone.text"
        case .notifications: "onb.permissions.notifications.text"
        case .camera: "onb.permissions.camera.text"
        case .contacts: "onb.permissions.contacts.text"
        }
    }

    private func allowTitle(for kind: PermissionKind) -> LocalizedStringKey {
        switch kind {
        case .microphone: "onb.permissions.microphone.allow"
        case .notifications: "onb.permissions.notifications.allow"
        case .camera: "onb.permissions.camera.allow"
        case .contacts: "onb.permissions.contacts.allow"
        }
    }
}
