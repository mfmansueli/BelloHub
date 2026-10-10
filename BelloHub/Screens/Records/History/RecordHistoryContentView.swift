//
//  RecordHistoryContentView.swift
//  BelloHub
//

import SwiftUI

/// The body of 4.7: the client's records newest first, each with its edit trail and the one way to change it; her
/// incidents; and her photos. A locked record is never edited, only corrected, and every correction is logged.
struct RecordHistoryContentView: View {
    @State private var viewModel: RecordHistoryViewModel
    @State private var openPhoto: Photo?
    @Environment(\.locale) private var locale

    init(clientID: UUID, vault: VaultService, profile: ProfileService) {
        _viewModel = State(initialValue: RecordHistoryViewModel(clientID: clientID, vault: vault, profile: profile))
    }

    var body: some View {
        content
            .background(Palette.bg)
            .navigationTitle(Text("recordHistory.title"))
            .navigationSubtitle(Text(verbatim: viewModel.client?.name ?? ""))
            .navigationBarTitleDisplayMode(.inline)
            .task { await viewModel.loadAsync() }
            .sheet(item: $viewModel.draft) { _ in RecordCorrectionSheet(viewModel: viewModel) }
            .sheet(item: $openPhoto) { PhotoDetailSheet(photoID: $0.id, viewModel: viewModel) }
    }

    // MARK: - States

    @ViewBuilder
    private var content: some View {
        if viewModel.client != nil {
            overview
        } else if viewModel.isMissing {
            EmptyState(
                icon: .user, title: Text("recordHistory.missing.title"), message: Text("recordHistory.missing.message")
            )
            .accessibilityIdentifier("recordHistory.missing")
            .frame(maxHeight: .infinity)
        } else if let message = viewModel.errorMessage {
            EmptyState(
                icon: .alert, title: Text("recordHistory.error.title"), message: Text(message),
                actionTitle: "recordHistory.error.retry", action: viewModel.load
            )
            .accessibilityIdentifier("recordHistory.error")
            .frame(maxHeight: .infinity)
        } else {
            VStack(spacing: Spacing.md) {
                Skeleton(height: 90, cornerRadius: Radius.card)
                Skeleton(height: 220, cornerRadius: Radius.card)
                Spacer(minLength: 0)
            }
            .padding(Spacing.gutter)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("recordHistory.loading"))
            .accessibilityIdentifier("recordHistory.loading")
        }
    }

    // MARK: - Overview

    private var overview: some View {
        let formatters = viewModel.business.formatters(displayLocale: locale)
        let name = viewModel.professionalName
        return ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                if viewModel.items.contains(where: \.isLocked) {
                    InlineNotice(
                        style: .info, title: "recordHistory.locked.title", message: "recordHistory.locked.message"
                    )
                    .accessibilityIdentifier("recordHistory.lockNotice")
                }
                if let message = viewModel.actionErrorMessage, viewModel.draft == nil, openPhoto == nil {
                    ErrorNotice(
                        message: message, actionTitle: "recordHistory.error.dismiss",
                        action: viewModel.dismissActionError
                    )
                    .accessibilityIdentifier("recordHistory.actionError")
                }
                records(formatters: formatters, professionalName: name)
                if !viewModel.incidents.isEmpty { incidents(formatters: formatters) }
                RecordPhotosSection(
                    pairs: viewModel.pairs, timeline: viewModel.timeline, formatters: formatters,
                    load: viewModel.imageData, onOpen: { openPhoto = $0 }
                )
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.vertical, Spacing.md)
        }
        .refreshable { await viewModel.loadAsync() }
        .accessibilityIdentifier("recordHistory.overview")
    }

    @ViewBuilder
    private func records(formatters: Formatters, professionalName: String) -> some View {
        if viewModel.items.isEmpty {
            EmptyState(
                icon: .document, title: Text("recordHistory.empty.title"), message: Text("recordHistory.empty.message")
            )
            .accessibilityIdentifier("recordHistory.empty")
        } else {
            VStack(alignment: .leading, spacing: Spacing.md) {
                ForEach(viewModel.items) { item in
                    RecordHistoryCard(
                        item: item, formatters: formatters, professionalName: professionalName,
                        onChange: { viewModel.beginCorrection(for: item.id) }
                    )
                }
            }
        }
    }

    private func incidents(formatters: Formatters) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("recordHistory.incidents.title").font(Typography.section).foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            ListCard(dividerInset: Spacing.md) {
                ForEach(viewModel.incidents) { incident in
                    IncidentRow(incident: incident, formatters: formatters)
                }
            }
        }
        .accessibilityIdentifier("recordHistory.incidents")
    }
}
