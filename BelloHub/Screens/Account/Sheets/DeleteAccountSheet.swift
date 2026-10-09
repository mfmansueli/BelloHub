//
//  DeleteAccountSheet.swift
//  BelloHub
//

import SwiftUI

/// The delete-account flow (7.1): first the offer to export, then the explicit confirmation, then the result. The
/// vault is cleared only after the second, destructive tap (`AccountDeletionFlow`).
struct DeleteAccountSheet: View {
    @Bindable var viewModel: AccountViewModel

    @Environment(\.dismiss) private var dismiss
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
                if case .done = viewModel.deletion {} else {
                    ToolbarItem(placement: .cancellationAction) {
                        Button { viewModel.send(.cancelled) } label: { Text("account.delete.keep") }
                            .accessibilityIdentifier("deleteAccount.keepButton")
                    }
                }
            }
            .sheet(isPresented: $showsExport, onDismiss: { viewModel.send(.exportFinished) }) {
                NavigationStack { ExportAllView() }
            }
        }
        .presentationBackground(Palette.bg)
        .interactiveDismissDisabled(viewModel.isDeleting)
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
