//
//  DeleteAccountSheet.swift
//  BelloHub
//

import AuthenticationServices
import SwiftUI

/// The delete-account flow (7.1): first the offer to export, then the explicit confirmation, then the result. The
/// vault is cleared only after the second, destructive tap (`AccountDeletionFlow`). For an Apple account that tap
/// is the native Apple button: the fresh authorization it returns is what lets the server revoke the token (D44).
struct DeleteAccountSheet: View {
    @Bindable var viewModel: AccountViewModel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var showsExport = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    switch viewModel.deletion {
                    case .idle, .offeringExport: offer
                    case .confirming, .deleting: confirmation
                    case .done(let outcome): done(outcome)
                    }
                }
                .padding(Spacing.gutter)
            }
            .background(Palette.bg)
            .navigationTitle(Text("account.delete.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isDone {
                    ToolbarItem(placement: .cancellationAction) {
                        Button { viewModel.send(.cancelled) } label: { Text("account.delete.keep") }
                            .accessibilityIdentifier("deleteAccount.keepButton")
                    }
                }
            }
            .sheet(
                isPresented: $showsExport, onDismiss: { viewModel.send(.exportFinished) },
                content: { NavigationStack { ExportAllView() } }
            )
        }
        .presentationBackground(Palette.bg)
        .interactiveDismissDisabled(viewModel.isDeleting)
    }

    private var isDone: Bool {
        if case .done = viewModel.deletion { return true }
        return false
    }

    // MARK: - Steps

    private var offer: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("account.delete.offer.message").font(Typography.body).foregroundStyle(Palette.ink)
            InlineNotice(style: .warning, title: "account.delete.offer.warning")
            Button { showsExport = true } label: { Text("account.delete.exportFirst") }
                .buttonStyle(.belloSecondary)
                .accessibilityIdentifier("deleteAccount.exportButton")
            Button { viewModel.send(.proceeded) } label: { Text("account.delete.continue") }
                .buttonStyle(.belloDestructive)
                .accessibilityIdentifier("deleteAccount.continueButton")
        }
    }

    private var confirmation: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("account.delete.confirm.title").font(Typography.title).foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("deleteAccount.confirmTitle")
            Text("account.delete.confirm.message").font(Typography.body).foregroundStyle(Palette.ink)
            if let message = viewModel.deletionErrorMessage {
                ErrorNotice(message: message).accessibilityIdentifier("deleteAccount.error")
            }
            if viewModel.requiresAppleReauthorization {
                appleConfirmation
            } else {
                Button { Task { await viewModel.deleteAccountAsync() } } label: {
                    if viewModel.isDeleting {
                        ProgressView().tint(Palette.coralText)
                    } else {
                        Text("account.delete.confirm.action")
                    }
                }
                .buttonStyle(.belloDestructive)
                .disabled(viewModel.isDeleting)
                .accessibilityIdentifier("deleteAccount.confirmButton")
            }
        }
    }

    /// The system draws the button (label, logo, localization, right-to-left); black on light and white on dark
    /// keep it above 4.5:1, as on Welcome. Deleting starts the moment Apple answers: the code is single-use.
    private var appleConfirmation: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("account.delete.apple.message").font(Typography.body).foregroundStyle(Palette.ink2)
                .accessibilityIdentifier("deleteAccount.appleMessage")
            if viewModel.isDeleting {
                ProgressView().tint(Palette.coralText)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .accessibilityLabel(Text("account.delete.apple.deleting"))
                    .accessibilityIdentifier("deleteAccount.appleProgress")
            } else {
                SignInWithAppleButton(
                    .continue, onRequest: viewModel.prepareAppleReauthorization,
                    onCompletion: viewModel.completeAppleReauthorization
                )
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 56)
                .accessibilityIdentifier("deleteAccount.appleButton")
                #if DEBUG
                .modifier(UITestAppleOverlay(
                    identifier: "deleteAccount.appleButton", action: viewModel.deleteWithDevStub
                ))
                #endif
            }
            if let message = viewModel.appleErrorMessage {
                Text(message)
                    .font(Typography.footnote)
                    .foregroundStyle(Palette.coralText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.updatesFrequently)
                    .accessibilityIdentifier("deleteAccount.appleButton.error")
            }
        }
    }

    private func done(_ outcome: AccountDeletionOutcome) -> some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            SuccessSeal(size: 64)
            Text("account.delete.done.title").font(Typography.title).foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("deleteAccount.doneTitle")
            Text(doneMessage(outcome)).font(Typography.body).foregroundStyle(Palette.ink2)
            Button {
                dismiss()
                viewModel.leaveAfterDeletion()
            } label: { Text("account.delete.done.action") }
                .buttonStyle(.belloPrimary)
                .accessibilityIdentifier("deleteAccount.doneButton")
        }
    }

    private func doneMessage(_ outcome: AccountDeletionOutcome) -> LocalizedStringKey {
        switch outcome {
        case .deleted: "account.delete.done.server"
        case .deletedWithoutAppleRevocation: "account.delete.done.appleRevocation"
        case .deviceOnly: "account.delete.done.deviceOnly"
        }
    }
}
