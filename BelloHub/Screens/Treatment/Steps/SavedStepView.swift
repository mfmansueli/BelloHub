//
//  SavedStepView.swift
//  BelloHub
//

import SwiftUI

/// 5.6 Tx-5-Saved: the record is in the vault, step 1 of the visit's closing (routine-a item 7). A summary of this
/// session (the first rows, the rest behind "Show all details"), the way to the full record, the 24-hour lock in plain
/// words, and "Continue" into the optional photos, aftercare and next visit. "Finish later" closes the flow and leaves
/// the visit in the follow-up queue; once every step is settled the button reads "Done".
struct SavedStepView: View {
    @Bindable var viewModel: TreatmentFlowViewModel
    let onDone: () -> Void

    @State private var showsAll = false
    @Environment(\.locale) private var locale

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                ClosingProgress(step: .saved)
                header
                summary
                historyLink
                InlineNotice(
                    style: .info, title: "treatmentFlow.saved.lock.title", message: "treatmentFlow.saved.lock.message"
                )
                    .accessibilityIdentifier("treatmentFlow.saved.lock")
                photosRow
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.vertical, Spacing.md)
        }
        .background(Palette.bg)
        .navigationBarBackButtonHidden()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    viewModel.finishLater()
                    onDone()
                } label: {
                    Text(hasOpenSteps ? "treatmentFlow.closing.later" : "treatmentFlow.saved.done")
                }
                .accessibilityIdentifier("treatmentFlow.saved.doneButton")
            }
        }
        .accessibilityIdentifier("treatmentFlow.saved")
        .safeAreaInset(edge: .bottom) {
            if hasOpenSteps {
                FlowBottomBar {
                    Button(action: viewModel.continueClosing) { Text("treatmentFlow.closing.continue") }
                        .buttonStyle(.belloPrimary)
                        .accessibilityIdentifier("treatmentFlow.saved.continueButton")
                    Text("treatmentFlow.closing.optional")
                        .font(Typography.footnote).foregroundStyle(Palette.ink2)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }

    /// Photos, aftercare or the next visit is still open.
    private var hasOpenSteps: Bool {
        !(viewModel.closing?.isComplete ?? true)
    }

    // MARK: - Parts

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label { Text("treatmentFlow.saved.badge") } icon: { Image(icon: .check) }
                .font(Typography.footnoteStrong)
                .foregroundStyle(Palette.sageText)
                .padding(.horizontal, Spacing.row)
                .frame(minHeight: 28)
                .background(Palette.sageWash, in: Capsule())
            Text(verbatim: viewModel.serviceName).font(Typography.title).foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            Text(verbatim: viewModel.visitSubtitle).font(Typography.meta).foregroundStyle(Palette.ink2)
        }
    }

    private var rows: [SavedSummary.Row] {
        guard let record = viewModel.savedRecord else { return [] }
        return SavedSummary.rows(for: record, names: names)
    }

    private var shownRows: [SavedSummary.Row] {
        showsAll ? rows : Array(rows.prefix(SavedSummary.previewCount))
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("treatmentFlow.saved.session").font(Typography.metaStrong).foregroundStyle(Palette.roseText)
                .padding(Spacing.md)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("treatmentFlow.saved.summary")
            if rows.isEmpty {
                Text("treatmentFlow.saved.empty").font(Typography.body).foregroundStyle(Palette.ink2)
                    .padding([.horizontal, .bottom], Spacing.md)
            }
            ForEach(shownRows) { row in
                Divider().overlay(Palette.hairline)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(verbatim: row.name).font(Typography.meta).foregroundStyle(Palette.ink2)
                    Text(verbatim: row.value).font(Typography.body).foregroundStyle(Palette.ink)
                }
                .padding(Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("treatmentFlow.saved.row.\(row.id)")
            }
            if rows.count > SavedSummary.previewCount {
                Divider().overlay(Palette.hairline)
                Button { showsAll.toggle() } label: {
                    Text(showsAll ? "treatmentFlow.saved.showLess" : "treatmentFlow.saved.showAll")
                        .font(Typography.bodyStrong)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .accessibilityIdentifier("treatmentFlow.saved.toggleButton")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .belloCard()
    }

    private var historyLink: some View {
        Button { viewModel.path.append(.history) } label: {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("treatmentFlow.saved.fullRecord").font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                    Text("treatmentFlow.saved.fullRecord.detail").font(Typography.meta).foregroundStyle(Palette.ink2)
                }
                Spacer(minLength: 0)
                Image(icon: .forward).foregroundStyle(Palette.ink2).flipsForRightToLeftLayoutDirection(true)
                    .accessibilityHidden(true)
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .belloCard()
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("treatmentFlow.saved.historyButton")
    }

    private var photosRow: some View {
        HStack {
            Text("treatmentFlow.saved.photos").font(Typography.body).foregroundStyle(Palette.ink)
            Spacer(minLength: 0)
            Text(viewModel.photos.isEmpty
                 ? LocalizedStringKey("treatmentFlow.saved.photos.none")
                 : LocalizedStringKey("treatmentFlow.saved.photos.added"))
                .font(Typography.body).foregroundStyle(Palette.ink2)
        }
        .padding(Spacing.md)
        .belloCard()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("treatmentFlow.saved.photosStatus")
    }

    private var names: SavedSummary.Names {
        SavedSummary.Names(
            notes: text("treatmentFlow.field.notes", "Observations"),
            technique: text("treatmentFlow.saved.technique", "Technique"),
            products: text("treatmentFlow.saved.products", "Products"),
            result: text("treatmentFlow.saved.result", "Result"),
            aftercare: text("treatmentFlow.saved.aftercare", "Aftercare"),
            yes: text("treatmentFlow.yes", "Yes"), no: text("treatmentFlow.no", "No")
        )
    }

    private func text(_ key: StaticString, _ fallback: String.LocalizationValue) -> String {
        LocalizedStringResource(key, defaultValue: fallback).resolved(in: locale)
    }
}
