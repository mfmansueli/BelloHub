//
//  PhotoDetailSheet.swift
//  BelloHub
//

import SwiftUI

/// One photo, large, with the choice of who can see it. A photo is private by default; sharing it needs the client's
/// signed photo consent (D2), so without one only "Only me" is offered and the sheet says why.
struct PhotoDetailSheet: View {
    let photoID: UUID
    let viewModel: RecordHistoryViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    var body: some View {
        NavigationStack {
            Group {
                if let photo = viewModel.photos.first(where: { $0.id == photoID }) {
                    content(photo)
                } else {
                    EmptyState(
                        icon: .image, title: Text("recordHistory.photo.missing.title"),
                        message: Text("recordHistory.photo.missing.message")
                    )
                }
            }
            .background(Palette.bg)
            .navigationTitle(Text("recordHistory.photo.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text("common.close") }
                        .accessibilityIdentifier("recordHistory.photo.closeButton")
                }
            }
        }
        .presentationDetents([.large])
        .presentationBackground(Palette.bg)
    }

    private func content(_ photo: Photo) -> some View {
        let formatters = viewModel.business.formatters(displayLocale: locale)
        return ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Color.clear
                    .aspectRatio(3 / 4, contentMode: .fit)
                    .overlay { RecordPhotoImage(photo: photo, useThumbnail: false, load: viewModel.imageData) }
                    .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(photoLabel(photo)))
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(photo.kind.title).font(Typography.section).foregroundStyle(Palette.ink)
                    Text(verbatim: formatters.dateTime(photo.takenAt)).font(Typography.meta)
                        .foregroundStyle(Palette.ink2)
                }
                if let message = viewModel.actionErrorMessage {
                    ErrorNotice(
                        message: message, actionTitle: "recordHistory.error.dismiss",
                        action: viewModel.dismissActionError
                    )
                }
                visibility(photo)
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.vertical, Spacing.md)
        }
        .accessibilityIdentifier("recordHistory.photo.detail")
    }

    private func photoLabel(_ photo: Photo) -> LocalizedStringResource {
        let kind = photo.kind.title.resolved(in: locale)
        return LocalizedStringResource("recordHistory.photo.label", defaultValue: "\(kind) photo").localized(in: locale)
    }

    private func visibility(_ photo: Photo) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Picker(selection: Binding(
                get: { photo.visibility }, set: { viewModel.setVisibility($0, of: photo) }
            )) {
                ForEach(viewModel.visibilityOptions(for: photo), id: \.self) { option in
                    Text(option.title).tag(option)
                }
            } label: {
                Text("recordHistory.photo.visibility")
            }
            .pickerStyle(.menu)
            .tint(Palette.roseText)
            .frame(minHeight: Spacing.touchTarget)
            .disabled(viewModel.isWorking)
            .accessibilityIdentifier("recordHistory.photo.visibility")
            if !viewModel.hasPhotoConsent {
                InlineNotice(style: .info, title: "recordHistory.photo.noConsent")
                    .accessibilityIdentifier("recordHistory.photo.noConsent")
            }
        }
    }
}
