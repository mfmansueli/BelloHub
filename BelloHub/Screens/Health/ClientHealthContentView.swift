//
//  ClientHealthContentView.swift
//  BelloHub
//

import SwiftUI

/// The body of 4.5: the answers of the latest health form, the consent records and the patch test log, with the
/// loading, empty and error states, and the three sheets. Everything on it is private to the professional.
struct ClientHealthContentView: View {
    @State private var viewModel: ClientHealthViewModel

    init(
        clientID: UUID, repository: (any HealthRepository)?, profile: ProfileService, photos: any PhotoProcessing,
        locale: Locale
    ) {
        _viewModel = State(initialValue: ClientHealthViewModel(
            clientID: clientID, repository: repository, profile: profile, photos: photos, locale: locale
        ))
    }

    var body: some View {
        @Bindable var model = viewModel
        ScrollView {
            StaggeredStack(spacing: Spacing.md) {
                FooterNote(text: "health.private")
                    .accessibilityIdentifier("health.private")
                content
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.xl)
        }
        .background(Palette.bg)
        .navigationTitle(Text("health.title"))
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .sheet(item: $model.fillSheet, onDismiss: viewModel.reload) { sheet in
            HealthFormSheet(viewModel: sheet)
        }
        .sheet(item: $model.patchSheet, onDismiss: viewModel.reload) { sheet in
            PatchTestSheet(viewModel: sheet)
        }
        .sheet(item: $model.consentSheet, onDismiss: viewModel.reload) { sheet in
            ConsentRecordSheet(viewModel: sheet)
        }
    }

    // MARK: - States

    @ViewBuilder
    private var content: some View {
        if !viewModel.hasLoaded {
            if viewModel.errorMessage != nil { errorState } else { loadingState }
        } else {
            if viewModel.errorMessage != nil { errorNotice }
            historySection
            consentSection
            PatchTestCard(
                patchTests: viewModel.patchTests, formatters: viewModel.formatters, onRecord: viewModel.startPatchTest
            )
            if viewModel.latestForm != nil { fillAgainButton }
        }
    }

    private var loadingState: some View {
        VStack(spacing: Spacing.sm) {
            Skeleton(height: 52)
            Skeleton(height: 52)
            Skeleton(height: 52)
        }
        .padding(.top, Spacing.section)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("health.title"))
        .accessibilityAddTraits(.updatesFrequently)
        .accessibilityIdentifier("health.loading")
    }

    private var errorState: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            InlineNotice(style: .warning, title: "health.error.load")
            retryButton
        }
        .padding(.top, Spacing.md)
    }

    /// A problem after the screen was already showing (a sheet could not open): the content stays.
    private var errorNotice: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            InlineNotice(style: .warning, title: "health.error.load")
            retryButton
        }
    }

    private var retryButton: some View {
        Button { viewModel.reload() } label: { Text("health.retry") }
            .buttonStyle(.belloSecondary)
            .accessibilityIdentifier("health.retryButton")
    }

    // MARK: - Sections

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "health.section.history")
            if let form = viewModel.latestForm {
                HealthHistoryCard(viewModel: viewModel, form: form)
            } else {
                emptyHistory
            }
        }
    }

    /// No form yet: explains why and offers the professional-filled path (the client's own form needs the booking
    /// link, which arrives with the server).
    private var emptyHistory: some View {
        VStack(spacing: Spacing.sm) {
            EmptyState(icon: .document, title: "health.empty.title", message: "health.empty.message")
            Button { viewModel.startFilling() } label: { Text("health.fill.first") }
                .buttonStyle(.belloPrimary)
                .accessibilityIdentifier("health.fillButton")
        }
    }

    private var consentSection: some View {
        ConsentsCard(
            consents: viewModel.consents, formatters: viewModel.formatters, onOpen: viewModel.open,
            onAdd: viewModel.startConsent
        )
    }

    private var fillAgainButton: some View {
        Button { viewModel.startFilling() } label: { Text("health.fill.again") }
            .buttonStyle(.belloSecondary)
            .padding(.top, Spacing.sm)
            .accessibilityIdentifier("health.fillButton")
    }
}
