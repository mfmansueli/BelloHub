//
//  PhotosStepView.swift
//  BelloHub
//

import PhotosUI
import SwiftUI

/// 5.7 Tx-6-Photos: before and after for this visit, side by side, with the ones added so far below. A photo comes from
/// the camera (5.8) or from the library through the system picker (no library permission, and nothing is written back
/// to it). Photos are private to her unless the client signed the photo consent.
struct PhotosStepView: View {
    @Bindable var viewModel: TreatmentFlowViewModel

    @State private var picked: PhotosPickerItem?
    @Environment(\.locale) private var locale

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("treatmentFlow.photos.title").font(Typography.title).foregroundStyle(Palette.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text(verbatim: viewModel.visitSubtitle).font(Typography.meta).foregroundStyle(Palette.ink2)
                }
                consent
                pair
                if let failure = viewModel.failure { TreatmentFailureNotice(failure: failure) }
                timeline
                FooterNote(text: "treatmentFlow.photos.private", icon: .shield)
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.vertical, Spacing.md)
        }
        .background(Palette.bg)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            FlowBottomBar {
                Button { viewModel.path.append(.camera(nextKind)) } label: {
                    Label { Text("treatmentFlow.photos.take") } icon: { Image(icon: .camera) }
                }
                .buttonStyle(.belloPrimary)
                .accessibilityIdentifier("treatmentFlow.photos.takeButton")
                PhotosPicker(selection: $picked, matching: .images) { Text("treatmentFlow.photos.library") }
                    .buttonStyle(.belloSecondary)
                    .accessibilityIdentifier("treatmentFlow.photos.libraryButton")
                Button { viewModel.path.removeAll { $0 == .photos } } label: { Text("treatmentFlow.photos.continue") }
                    .buttonStyle(.belloTertiary)
                    .accessibilityIdentifier("treatmentFlow.photos.continueButton")
            }
        }
        .onChange(of: picked) { _, item in
            guard let item else { return }
            Task { await load(item) }
        }
        .accessibilityIdentifier("treatmentFlow.photos")
    }

    // MARK: - Parts

    /// Before comes first, then after: the camera opens for whichever of the two is still missing.
    private var nextKind: PhotoKind {
        let pair = viewModel.pair
        if pair.before == nil { return .before }
        if pair.after == nil { return .after }
        return .progress
    }

    private var consent: some View {
        InlineNotice(
            style: .info,
            title: viewModel.hasPhotoConsent ? "treatmentFlow.photos.consent.signed" : "treatmentFlow.photos.consent.none",
            message: viewModel.hasPhotoConsent ? nil : "treatmentFlow.photos.consent.noneMessage"
        )
        .accessibilityIdentifier("treatmentFlow.photos.consent")
    }

    private var pair: some View {
        HStack(spacing: Spacing.sm) {
            slot(viewModel.pair.before, title: "treatmentFlow.photos.before", id: "before")
            slot(viewModel.pair.after, title: "treatmentFlow.photos.after", id: "after")
        }
    }

    private func slot(_ photo: FlowPhoto?, title: LocalizedStringKey, id: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title).font(Typography.metaStrong).foregroundStyle(Palette.ink2)
            ZStack {
                Palette.sunken
                if let photo {
                    FlowPhotoImage(data: photo.data.thumbnail)
                } else {
                    Image(icon: .image).foregroundStyle(Palette.ink2).accessibilityHidden(true)
                }
            }
            .aspectRatio(3 / 4, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(photo == nil ? "treatmentFlow.photos.slot.empty" : "treatmentFlow.photos.slot.filled"))
        .accessibilityIdentifier("treatmentFlow.photos.slot.\(id)")
    }

    @ViewBuilder
    private var timeline: some View {
        if viewModel.isProcessingPhoto {
            HStack(spacing: Spacing.row) {
                ProgressView().accessibilityHidden(true)
                Text("treatmentFlow.photos.processing").font(Typography.body).foregroundStyle(Palette.ink2)
            }
            .accessibilityElement(children: .combine)
        }
        if !viewModel.photos.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                ForEach(viewModel.photos) { photo in row(photo) }
            }
        }
    }

    private func row(_ photo: FlowPhoto) -> some View {
        HStack(spacing: Spacing.row) {
            FlowPhotoImage(data: photo.data.thumbnail)
                .frame(width: 56, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(photo.photo.kind.title).font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                Text(photo.photo.visibility.title).font(Typography.meta).foregroundStyle(Palette.ink2)
            }
            Spacer(minLength: 0)
            Menu {
                Picker(selection: kindBinding(photo), label: Text("treatmentFlow.photos.kind")) {
                    ForEach(PhotoKind.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                Picker(selection: visibilityBinding(photo), label: Text("treatmentFlow.photos.visibility")) {
                    ForEach(viewModel.allowedVisibilities, id: \.self) { Text($0.title).tag($0) }
                }
                Button(role: .destructive) { Task { await viewModel.deletePhoto(photo.id) } } label: {
                    Text("treatmentFlow.photos.delete")
                }
            } label: {
                Image(icon: .sliders).frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel(Text("treatmentFlow.photos.options"))
            .accessibilityIdentifier("treatmentFlow.photos.options.\(photo.id.uuidString)")
        }
        .padding(Spacing.sm)
        .belloCard()
        .accessibilityIdentifier("treatmentFlow.photos.row.\(photo.id.uuidString)")
    }

    // MARK: - Actions

    private func kindBinding(_ photo: FlowPhoto) -> Binding<PhotoKind> {
        Binding(get: { photo.photo.kind }, set: { new in Task { await viewModel.setKind(new, for: photo.id) } })
    }

    private func visibilityBinding(_ photo: FlowPhoto) -> Binding<PhotoVisibility> {
        Binding(
            get: { photo.photo.visibility },
            set: { new in Task { await viewModel.setVisibility(new, for: photo.id) } }
        )
    }

    private func load(_ item: PhotosPickerItem) async {
        defer { picked = nil }
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            viewModel.failure = .photo
            return
        }
        await viewModel.addPhoto(data, kind: nextKind)
    }
}
