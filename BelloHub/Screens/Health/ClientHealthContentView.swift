//
//  ClientHealthContentView.swift
//  BelloHub
//

import SwiftUI

/// The body of 4.5, a folder (D60): the health forms and the consents she filled in and signed with the client in
/// person, the answers recorded in the app before D60 (read-only, only when there are some) and the patch test log,
/// with the loading and error states and the two sheets. Everything on it is private to the professional.
struct ClientHealthContentView: View {
    @State private var viewModel: ClientHealthViewModel

    init(
        clientID: UUID, repository: (any HealthRepository)?, records: (any TreatmentRepository)?,
        profile: ProfileService, photos: any PhotoProcessing, locale: Locale
    ) {
        _viewModel = State(initialValue: ClientHealthViewModel(
            clientID: clientID, repository: repository, records: records, profile: profile, photos: photos,
            locale: locale
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
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
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
            formsSection
            if let form = viewModel.latestForm { answersSection(form) }
            consentSection
            PatchTestCard(
                patchTests: viewModel.patchTests, formatters: viewModel.formatters, onRecord: viewModel.startPatchTest
            )
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

    /// Her own health questionnaires, signed with the client in person: a photo or file of each, the date, and when
    /// to ask again. The app asks no health question itself (D60).
    private var formsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ConsentsCard(
                folder: .healthForms, consents: viewModel.healthForms, formatters: viewModel.formatters,
                onOpen: viewModel.open, onAdd: viewModel.startHealthForm
            )
            if viewModel.reviewStatus != nil {
                HealthReviewLine(
                    months: viewModel.reviewMonths, status: viewModel.reviewStatus, formatters: viewModel.formatters
                )
            }
        }
    }

    /// Answers recorded in the app before D60, or sent from the booking page: kept and readable, never asked again.
    private func answersSection(_ form: HealthForm) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "health.section.answers")
            HealthHistoryCard(viewModel: viewModel, form: form)
        }
    }

    private var consentSection: some View {
        ConsentsCard(
            consents: viewModel.otherConsents, formatters: viewModel.formatters, onOpen: viewModel.open,
            onAdd: { viewModel.startConsent() }
        )
    }
}
