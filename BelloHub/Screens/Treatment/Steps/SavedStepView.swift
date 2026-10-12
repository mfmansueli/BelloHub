//
//  SavedStepView.swift
//  BelloHub
//

import SwiftUI

/// The compact confirmation after "Finalize record": a small seal, the visit in one line, and three ways on. Open the
/// record, book the return, or finish. The 24-hour window is said in one sentence.
struct SavedStepView: View {
    @Bindable var viewModel: TreatmentFlowViewModel
    let onBook: (AgendaSheet) -> Void
    let onDone: () -> Void

    @Environment(\.calendar) private var calendar

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                // The visit is saved: the one confirmation the clinical steps allow (docs/09-MOTION.md section 3.6).
                // It is small, takes no touch and never delays the buttons below.
                SuccessSeal(size: 56)
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("visitForm.saved.title").font(Typography.title).foregroundStyle(Palette.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text(verbatim: viewModel.visitSubtitle).font(Typography.meta).foregroundStyle(Palette.ink2)
                    if let summary = summary {
                        Text(verbatim: summary).font(Typography.body).foregroundStyle(Palette.ink)
                            .lineLimit(3)
                            .accessibilityIdentifier("treatmentFlow.saved.summary")
                    }
                }
                Text("visitForm.saved.lock").font(Typography.footnote).foregroundStyle(Palette.ink2)
                    .accessibilityIdentifier("treatmentFlow.saved.lock")
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.vertical, Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Palette.bg)
        .navigationBarBackButtonHidden()
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("treatmentFlow.saved")
        .safeAreaInset(edge: .bottom) {
            FlowBottomBar {
                Button(action: onDone) { Text("treatmentFlow.saved.done") }
                    .buttonStyle(.belloPrimary)
                    .accessibilityIdentifier("treatmentFlow.saved.doneButton")
                Button { viewModel.path.append(.record) } label: { Text("visitForm.saved.open") }
                    .buttonStyle(.belloSecondary)
                    .accessibilityIdentifier("treatmentFlow.saved.historyButton")
                Button {
                    onBook(.newAppointment(clientID: viewModel.clientID,
                                           startsAt: viewModel.suggestedDate(calendar: calendar)))
                } label: { Text("visitForm.saved.book") }
                    .buttonStyle(.belloTertiary)
                    .accessibilityIdentifier("treatmentFlow.next.bookButton")
            }
        }
    }

    private var summary: String? {
        viewModel.savedRecord.flatMap { VisitSummaryText.make($0, list: viewModel.formatters.list) }
    }
}
