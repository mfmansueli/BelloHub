//
//  ImportClientsFlowView.swift
//  BelloHub
//

import SwiftUI

/// The frame of the import: a navigation bar (Cancel on the first step, Back on the next two, nothing on the result),
/// the step in view, and everything the steps present: the system file importer, the contact picker and the paywall.
struct ImportClientsFlowView: View {
    @Bindable var viewModel: ImportClientsViewModel
    let term: ClientTerm
    let onViewClients: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.motionPolicy) private var policy

    var body: some View {
        NavigationStack {
            stepView
                .id(viewModel.step)
                .transition(.opacity)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { leadingButton }
        }
        .tint(Palette.accent)
        .animation(policy.allowsFade ? Motion.ease(Motion.Duration.fade) : nil, value: viewModel.step)
        .overlay { if viewModel.isWorking { ImportWorkingOverlay() } }
        .interactiveDismissDisabled(viewModel.isWorking)
        .fileImporter(
            isPresented: $viewModel.isFileImporterPresented, allowedContentTypes: viewModel.files.allowedContentTypes
        ) { outcome in
            viewModel.fileImporterFinished(outcome.map { [$0] })
        }
        .contactPicker(for: viewModel.contacts)
        .sheet(isPresented: $viewModel.isPaywallPresented, onDismiss: viewModel.paywallClosed) { PaywallSheet() }
        .task { await viewModel.start() }
    }

    // MARK: - Steps

    @ViewBuilder
    private var stepView: some View {
        switch viewModel.step {
        case .sources: ImportSourcesView(viewModel: viewModel, term: term)
        case .mapping: ImportMappingView(viewModel: viewModel)
        case .choose: ImportChooseView(viewModel: viewModel, term: term)
        case .result: ImportResultView(viewModel: viewModel, term: term, onViewClients: viewClients)
        }
    }

    private var title: Text {
        Text(LocalizedStringResource(
            "import.title", defaultValue: "Import \(term.pluralText(in: locale))"
        ).localized(in: locale))
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var leadingButton: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            switch viewModel.step {
            case .sources:
                Button { dismiss() } label: { Text("common.cancel") }
                    .accessibilityIdentifier("importClients.cancelButton")
            case .mapping, .choose:
                Button { viewModel.back() } label: { Text("common.back") }
                    .accessibilityIdentifier("importClients.backButton")
            case .result:
                EmptyView()
            }
        }
    }

    private func viewClients() {
        onViewClients()
        dismiss()
    }
}
