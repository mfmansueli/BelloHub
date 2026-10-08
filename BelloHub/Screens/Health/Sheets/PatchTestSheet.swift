//
//  PatchTestSheet.swift
//  BelloHub
//

import SwiftUI

/// The sheet that records a patch test: the product, where it was tried, when, how long the skin was watched and what
/// happened. Sealed in the vault when she saves.
struct PatchTestSheet: View {
    @Bindable var viewModel: PatchTestViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(
                title: "health.patch.record", subtitle: "health.private", closeLabel: "common.close",
                closeIdentifier: "patch.closeButton", onClose: { dismiss() }
            )
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    BelloTextField(
                        title: "patch.product", text: $viewModel.draft.product, prompt: "patch.product.prompt",
                        isSensitive: true, identifier: "patch.productField"
                    )
                    BelloTextField(
                        title: "patch.area", text: $viewModel.draft.area, prompt: "patch.area.prompt",
                        isSensitive: true, identifier: "patch.areaField"
                    )
                    DatePicker(selection: $viewModel.draft.testedAt, displayedComponents: .date) {
                        Text("patch.date").font(Typography.metaStrong).foregroundStyle(Palette.ink2)
                    }
                    .tint(Palette.roseText)
                    .frame(minHeight: Spacing.touchTarget)
                    .accessibilityIdentifier("patch.datePicker")
                    hoursChips
                    resultChips
                    BelloNoteField(
                        title: Text("patch.notes"), text: $viewModel.draft.notes, prompt: "healthForm.optional",
                        isSensitive: true, identifier: "patch.notesField"
                    )
                }
                .padding(.horizontal, Spacing.gutter)
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.lg)
            }
            .scrollDismissesKeyboard(.interactively)
            // A sibling of the scroll view, so the scroll view ends where the bar begins.
            saveBar
        }
        .background(Palette.bg)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onChange(of: viewModel.didSave) { _, didSave in
            if didSave { dismiss() }
        }
    }

    // MARK: - Parts

    private var hoursChips: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("patch.hours").font(Typography.metaStrong).foregroundStyle(Palette.ink2)
            FlowLayout(spacing: Spacing.sm, lineSpacing: Spacing.sm) {
                ForEach(PatchTest.observationOptions, id: \.self) { hours in
                    Button { viewModel.draft.observedHours = hours } label: {
                        Text(verbatim: duration(hours))
                    }
                    .buttonStyle(.belloChip(selected: viewModel.draft.observedHours == hours))
                    .accessibilityAddTraits(viewModel.draft.observedHours == hours ? .isSelected : [])
                    .accessibilityIdentifier("patch.hours.\(hours)")
                }
            }
        }
    }

    private var resultChips: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("patch.result").font(Typography.metaStrong).foregroundStyle(Palette.ink2)
            FlowLayout(spacing: Spacing.sm, lineSpacing: Spacing.sm, wrapsLongChildren: true) {
                resultChip("health.patch.result.none", result: .noReaction)
                resultChip("health.patch.result.mild", result: .mildReaction)
                resultChip("health.patch.result.reaction", result: .reaction)
            }
        }
    }

    private func resultChip(_ title: LocalizedStringKey, result: PatchTestResult) -> some View {
        Button { viewModel.draft.result = result } label: { Text(title) }
            .buttonStyle(.belloChip(selected: viewModel.draft.result == result))
            .accessibilityAddTraits(viewModel.draft.result == result ? .isSelected : [])
            .accessibilityIdentifier("patch.result.\(result.rawValue)")
    }

    /// "24 hr": the hours the skin was watched, in the reader's language.
    private func duration(_ hours: Int) -> String {
        Formatters(locale: locale, timeZone: .current, currencyCode: "USD").duration(minutes: hours * 60)
    }

    private var saveBar: some View {
        VStack(spacing: Spacing.sm) {
            if let message = viewModel.errorMessage {
                Text(verbatim: message)
                    .font(Typography.footnote)
                    .foregroundStyle(Palette.coralText)
                    .accessibilityAddTraits(.updatesFrequently)
                    .accessibilityIdentifier("patch.error")
            }
            Button { viewModel.save() } label: {
                if viewModel.isSaving { ProgressView() } else { Text("patch.save") }
            }
            .buttonStyle(.belloPrimary)
            .disabled(!viewModel.canSave)
            .accessibilityIdentifier("patch.saveButton")
        }
        .padding(.horizontal, Spacing.gutter)
        .padding(.vertical, Spacing.md)
        .background(Palette.bg)
    }
}
