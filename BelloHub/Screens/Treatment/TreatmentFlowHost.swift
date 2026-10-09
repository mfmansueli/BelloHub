//
//  TreatmentFlowHost.swift
//  BelloHub
//

import SwiftUI

/// The flow's navigation stack. It owns the ViewModel (`@State`), puts it in the environment of the steps, maps every
/// `TreatmentFlowStep` to its screen, and closes the flow: asking first when she would lose what she typed.
struct TreatmentFlowHost: View {
    @State private var viewModel: TreatmentFlowViewModel
    @State private var confirmsDiscard = false
    @State private var agendaSheet: AgendaSheet?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    init(viewModel: TreatmentFlowViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack(path: $viewModel.path) {
            RegisterStepView(viewModel: viewModel, onCancel: cancel)
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
        .onChange(of: locale) { _, new in viewModel.locale = new }
        .onDisappear { viewModel.tearDown() }
        .agendaSheet(item: $agendaSheet)
        .confirmationDialog(
            Text("treatmentFlow.discard.title"), isPresented: $confirmsDiscard, titleVisibility: .visible
        ) {
            Button(role: .destructive) { close() } label: { Text("treatmentFlow.discard.confirm") }
                .accessibilityIdentifier("treatmentFlow.discardButton")
            Button(role: .cancel) {} label: { Text("treatmentFlow.discard.keep") }
                .accessibilityIdentifier("treatmentFlow.keepButton")
        } message: {
            Text("treatmentFlow.discard.message")
        }
    }

    // MARK: - Destinations

    @ViewBuilder
    private func destination(for step: TreatmentFlowStep) -> some View {
        switch step {
        case .listening: ListeningStepView(viewModel: viewModel)
        case .organizing: OrganizingStepView(viewModel: viewModel)
        case .review: ReviewStepView(viewModel: viewModel, onCancel: cancel)
        case .form: FormStepView(viewModel: viewModel)
        case .saved: SavedStepView(viewModel: viewModel, onDone: close)
        case .photos: PhotosStepView(viewModel: viewModel)
        case .camera(let kind): CameraStepView(viewModel: viewModel, kind: kind)
        case .nextSession:
            NextSessionStepView(viewModel: viewModel, onBook: { agendaSheet = $0 })
        case .history: RecordHistoryView(clientID: viewModel.clientID)
        }
    }

    // MARK: - Closing

    /// Asks before throwing away what she typed or said; closes at once when there is nothing to lose.
    private func cancel() {
        if viewModel.hasUnsavedWork { confirmsDiscard = true } else { close() }
    }

    private func close() {
        viewModel.tearDown()
        dismiss()
    }
}
