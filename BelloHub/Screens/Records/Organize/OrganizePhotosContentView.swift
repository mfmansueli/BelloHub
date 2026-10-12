//
//  OrganizePhotosContentView.swift
//  BelloHub
//

import SwiftUI

/// The body of "Organize photos": one row per photo (thumbnail, kind and day) with "Place in a visit".
struct OrganizePhotosContentView: View {
    @State private var viewModel: OrganizePhotosViewModel
    @Environment(ProfileService.self) private var profile
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    init(clientID: UUID, vault: VaultService) {
        _viewModel = State(initialValue: OrganizePhotosViewModel(clientID: clientID, vault: vault))
    }

    var body: some View {
        NavigationStack {
            content
                .background(Palette.bg)
                .navigationTitle(Text("organizePhotos.title"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button { dismiss() } label: { Text("common.done") }
                            .accessibilityIdentifier("organizePhotos.done")
                    }
                }
                .task { await viewModel.loadAsync() }
        }
        .presentationBackground(Palette.bg)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("organizePhotos.loading")
        } else if viewModel.photos.isEmpty {
            EmptyState(icon: .checkCircle, title: "organizePhotos.done.title", message: "organizePhotos.done.message")
                .accessibilityIdentifier("organizePhotos.empty")
                .frame(maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("organizePhotos.intro")
                        .font(Typography.meta)
                        .foregroundStyle(Palette.ink2)
                    if let message = viewModel.errorMessage {
                        ErrorNotice(message: message, actionTitle: "recordHistory.error.dismiss",
                                    action: { Task { await viewModel.loadAsync() } })
                    }
                    ListCard(dividerInset: 88) {
                        ForEach(viewModel.photos) { photo in row(photo) }
                    }
                }
                .padding(.horizontal, Spacing.gutter)
                .padding(.vertical, Spacing.md)
            }
        }
    }

    private func row(_ photo: Photo) -> some View {
        HStack(spacing: Spacing.row) {
            RecordThumbnail(photo: photo, size: 64, load: viewModel.thumbnail(for:))
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(photo.kind.title).font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                Text(verbatim: formatters.shortDate(photo.takenAt)).font(Typography.meta).foregroundStyle(Palette.ink2)
            }
            Spacer(minLength: Spacing.sm)
            Menu {
                ForEach(viewModel.visits) { visit in
                    Button { viewModel.link(photo, to: visit) } label: { Text(verbatim: title(of: visit)) }
                }
            } label: {
                Text("organizePhotos.place")
                    .font(Typography.metaStrong)
                    .foregroundStyle(Palette.roseText)
                    .frame(minHeight: Spacing.touchTarget)
            }
            .disabled(viewModel.visits.isEmpty || viewModel.isWorking)
            .accessibilityIdentifier("organizePhotos.place.\(photo.id.uuidString)")
        }
        .padding(Spacing.md)
        .accessibilityElement(children: .contain)
    }

    private func title(of visit: VisitSummary) -> String {
        let day = VisitDateLabel.text(visit.visitDate, formatters: formatters, now: Date(), locale: locale)
        return "\(day) · \(visit.record.serviceName)"
    }

    private var formatters: Formatters {
        let timeZone = profile.profile.flatMap { TimeZone(identifier: $0.timeZoneID) } ?? .current
        return Formatters(locale: locale, timeZone: timeZone, currencyCode: profile.profile?.currencyCode ?? "USD")
    }
}
