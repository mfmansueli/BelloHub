//
//  VisitPhotosSection.swift
//  BelloHub
//

import PhotosUI
import SwiftUI

/// Photos of this visit, at any moment of the form: take one with the app's own camera (before, after or progress,
/// with the previous photo as a framing reference when there is one) or import one through the system picker (no
/// library permission). Each photo can change kind and who sees it; private by default.
struct VisitPhotosSection: View {
    @Bindable var viewModel: TreatmentFlowViewModel

    @State private var picked: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("visitForm.photos").font(Typography.section).foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            if !viewModel.photos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.sm) {
                        ForEach(viewModel.photos) { photo in tile(photo) }
                    }
                }
            }
            if viewModel.isProcessingPhoto {
                HStack(spacing: Spacing.row) {
                    ProgressView().accessibilityHidden(true)
                    Text("treatmentFlow.photos.processing").font(Typography.meta).foregroundStyle(Palette.ink2)
                }
                .accessibilityElement(children: .combine)
            }
            HStack(spacing: Spacing.sm) {
                Menu {
                    ForEach(PhotoKind.allCases, id: \.self) { kind in
                        Button { viewModel.path.append(.camera(kind)) } label: { Text(kind.title) }
                            .accessibilityIdentifier("visitForm.photos.take.\(kind.rawValue)")
                    }
                } label: {
                    Label { Text("treatmentFlow.photos.take") } icon: { Image(icon: .camera) }
                        .font(Typography.metaStrong)
                        .padding(.horizontal, Spacing.md)
                        .frame(minHeight: Spacing.touchTarget)
                        .overlay { Capsule().strokeBorder(Palette.fieldBorder, lineWidth: 1) }
                }
                .tint(Palette.ink)
                .accessibilityIdentifier("treatmentFlow.photos.takeButton")
                PhotosPicker(selection: $picked, matching: .images) {
                    Label { Text("treatmentFlow.photos.library") } icon: { Image(icon: .image) }
                }
                .buttonStyle(.belloChip(selected: false))
                .accessibilityIdentifier("treatmentFlow.photos.libraryButton")
            }
            Text(viewModel.hasPhotoConsent ? "treatmentFlow.photos.consent.signed" : "visitForm.photos.private")
                .font(Typography.footnote)
                .foregroundStyle(Palette.ink2)
                .accessibilityIdentifier("treatmentFlow.photos.consent")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("treatmentFlow.photos")
        .onChange(of: picked) { _, item in
            guard let item else { return }
            Task { await load(item) }
        }
    }

    private func tile(_ photo: FlowPhoto) -> some View {
        Menu {
            Picker(selection: kindBinding(photo), label: Text("treatmentFlow.photos.kind")) {
                ForEach(PhotoKind.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            Picker(selection: visibilityBinding(photo), label: Text("treatmentFlow.photos.visibility")) {
                ForEach(viewModel.allowedVisibilities, id: \.self) { Text($0.title).tag($0) }
            }
            if !viewModel.isLocked {
                Button(role: .destructive) { Task { await viewModel.deletePhoto(photo.id) } } label: {
                    Text("treatmentFlow.photos.delete")
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                DataImage(data: photo.data.thumbnail)
                    .frame(width: 84, height: 108)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
                Text(photo.photo.kind.title).font(Typography.footnoteStrong).foregroundStyle(Palette.ink)
            }
        }
        .accessibilityLabel(Text(photo.photo.kind.title))
        .accessibilityHint(Text("treatmentFlow.photos.options"))
        .accessibilityIdentifier("treatmentFlow.photos.row.\(photo.id.uuidString)")
    }

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
        await viewModel.addPhoto(data, kind: viewModel.nextPhotoKind)
    }
}
