//
//  TreatmentFlowHost.swift
//  BelloHub
//

import SwiftUI

/// The flow's navigation stack. It owns the ViewModel (`@State`), maps every `TreatmentFlowStep` to its screen, and
/// closes the flow. The visit form is the root. Closing never loses anything: the draft is saved first, and she can
/// keep it for later or delete it.
struct TreatmentFlowHost: View {
    @State private var viewModel: TreatmentFlowViewModel
    @State private var asksAboutDraft = false
    @State private var agendaSheet: AgendaSheet?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    init(viewModel: TreatmentFlowViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack(path: $viewModel.path) {
            VisitFormStepView(viewModel: viewModel, onCancel: cancel)
                .navigationDestination(for: TreatmentFlowStep.self) { step in
                    destination(for: step)
                }
        }
        .tint(Palette.accent)
        .background(Palette.bg)
        .task {
            viewModel.locale = locale
            await viewModel.load()
        }
        .onChange(of: locale) { _, new in viewModel.useLocale(new) }
        .onDisappear { viewModel.tearDown() }
        .agendaSheet(item: $agendaSheet)
        .confirmationDialog(
            Text("visitForm.leave.title"), isPresented: $asksAboutDraft, titleVisibility: .visible
        ) {
            Button { close() } label: { Text("visitForm.leave.keep") }
                .accessibilityIdentifier("treatmentFlow.keepButton")
            Button(role: .destructive) { discard() } label: { Text("visitForm.leave.delete") }
                .accessibilityIdentifier("treatmentFlow.discardButton")
            Button(role: .cancel) {} label: { Text("visitForm.leave.stay") }
                .accessibilityIdentifier("treatmentFlow.stayButton")
        } message: {
            Text("visitForm.leave.message")
        }
    }

    // MARK: - Destinations

    @ViewBuilder
    private func destination(for step: TreatmentFlowStep) -> some View {
        switch step {
        case .listening: ListeningStepView(viewModel: viewModel)
        case .organizing: OrganizingStepView(viewModel: viewModel)
        case .review:
            // Her words are kept as notes before leaving, so cancelling the review never loses the dictation.
            ReviewStepView(viewModel: viewModel, onCancel: {
                viewModel.applyTranscriptAsNotes()
                cancel()
            })
        case .saved: SavedStepView(viewModel: viewModel, onBook: { agendaSheet = $0 }, onDone: close)
        case .camera(let kind): CameraStepView(viewModel: viewModel, kind: kind)
        case .record: VisitDetailView(recordID: viewModel.recordID)
        }
    }

    // MARK: - Closing

    /// A draft with something in it is saved, then she chooses to keep it for later or delete it; an empty form or a
    /// finalized record closes at once.
    private func cancel() {
        Task {
            await viewModel.autosaveNow()
            if viewModel.savedRecord?.isDraft == true {
                asksAboutDraft = true
            } else {
                close()
            }
        }
    }

    private func discard() {
        Task {
            if await viewModel.discardDraft() { close() }
        }
    }

    private func close() {
        viewModel.markClosingDone()
        viewModel.tearDown()
        dismiss()
    }
}
