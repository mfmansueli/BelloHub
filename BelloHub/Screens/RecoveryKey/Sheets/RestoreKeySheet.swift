//
//  RestoreKeySheet.swift
//  BelloHub
//

import SwiftUI

/// "Enter your 12 words": the restore flow the Locked screen offers when this iPhone has no key. One text area, the
/// count of words typed, the parse error by position, and Restore.
struct RestoreKeySheet: View {
    @State private var viewModel: RestoreKeyViewModel
    let onRestored: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    init(service: RecoveryKeyService, onRestored: @escaping () -> Void) {
        _viewModel = State(initialValue: RestoreKeyViewModel(service: service))
        self.onRestored = onRestored
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    Text("restoreKey.subtitle").font(Typography.body).foregroundStyle(Palette.ink2)
                    editor
                    if let issue = viewModel.issue {
                        ErrorNotice(message: issueText(issue)).accessibilityIdentifier("restoreKey.error")
                    }
                    Button(action: viewModel.restore) { Text("restoreKey.action") }
                        .buttonStyle(.belloPrimary)
                        .disabled(!viewModel.canRestore)
                        .accessibilityIdentifier("restoreKey.restoreButton")
                    FooterNote(text: "restoreKey.footer", icon: .lock)
                }
                .padding(Spacing.gutter)
            }
            .background(Palette.bg)
            .navigationTitle(Text("restoreKey.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text("common.cancel") }
                        .accessibilityIdentifier("restoreKey.cancelButton")
                }
            }
            .onChange(of: viewModel.restored) { _, restored in
                if restored { onRestored() }
            }
        }
        .presentationBackground(Palette.bg)
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            TextEditor(text: $viewModel.text)
                .font(Typography.body)
                .foregroundStyle(Palette.ink)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 120)
                .padding(Spacing.sm)
                .background(Palette.sunken, in: RoundedRectangle(cornerRadius: Radius.input, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.input, style: .continuous).stroke(Palette.fieldBorder)
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .privacySensitive()
                .environment(\.layoutDirection, .leftToRight)
                .accessibilityLabel(Text("restoreKey.field"))
                .accessibilityIdentifier("restoreKey.wordsField")
            Text(LocalizedStringResource(
                "restoreKey.count", defaultValue: "\(viewModel.typedCount) of \(RecoveryPhrase.wordCount) words"
            ).localized(in: locale))
                .font(Typography.footnote).foregroundStyle(Palette.ink2)
                .accessibilityIdentifier("restoreKey.count")
        }
    }

    private func issueText(_ issue: RestoreKeyViewModel.Issue) -> String {
        switch issue {
        case .wordCount(let count):
            return String(localized: LocalizedStringResource(
                "restoreKey.error.wordCount", defaultValue: "A key has 12 words; you typed \(count)."
            ).localized(in: locale))
        case .unknownWord(let position):
            return String(localized: LocalizedStringResource(
                "restoreKey.error.unknownWord", defaultValue: "Word \(position) is not on the list. Check its spelling."
            ).localized(in: locale))
        case .checksum:
            return String(localized: "restoreKey.error.checksum")
        case .failed:
            return String(localized: "restoreKey.error.failed")
        }
    }
}
