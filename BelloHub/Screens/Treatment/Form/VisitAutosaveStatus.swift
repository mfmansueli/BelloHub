//
//  VisitAutosaveStatus.swift
//  BelloHub
//

import SwiftUI

/// The small line that says where the draft stands: saving, saved at a time, or not saved with a retry. It never
/// asks for attention while things work; a failure is said plainly, with what she wrote still on screen.
struct VisitAutosaveStatus: View {
    let state: AutosaveState
    let isFinalized: Bool
    let formatters: Formatters
    let onRetry: () -> Void
    @Environment(\.locale) private var locale

    var body: some View {
        HStack(spacing: Spacing.xs) {
            switch state {
            case .idle:
                Image(icon: .lock).accessibilityHidden(true)
                Text("visitForm.autosave.idle")
            case .saving:
                ProgressView().controlSize(.mini).accessibilityHidden(true)
                Text("visitForm.autosave.saving")
            case .saved(let date):
                Image(icon: .check).accessibilityHidden(true)
                Text(savedText(date))
            case .failed:
                Image(icon: .alert).accessibilityHidden(true)
                Text("visitForm.autosave.failed")
                Button(action: onRetry) {
                    Text("treatmentFlow.retry").font(Typography.footnoteStrong).underline()
                        .frame(minHeight: Spacing.touchTarget)
                }
                .accessibilityIdentifier("visitForm.autosave.retry")
            }
        }
        .font(Typography.footnote)
        .foregroundStyle(state == .failed ? Palette.coralText : Palette.ink2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("visitForm.autosave")
    }

    private func savedText(_ date: Date) -> String {
        let time = formatters.time(date)
        return isFinalized
            ? LocalizedStringResource("visitForm.autosave.savedRecord", defaultValue: "Record saved at \(time)")
                .resolved(in: locale)
            : LocalizedStringResource("visitForm.autosave.savedDraft", defaultValue: "Draft saved at \(time)")
                .resolved(in: locale)
    }
}
