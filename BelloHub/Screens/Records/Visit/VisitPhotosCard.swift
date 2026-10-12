//
//  VisitPhotosCard.swift
//  BelloHub
//

import SwiftUI

/// The photos of this visit, each named by its kind, with "Add photo" and, when there is a "before" and an "after",
/// a one-tap comparison. Photos are private unless she shared one.
struct VisitPhotosCard: View {
    let photos: [Photo]
    let formatters: Formatters
    let loadThumbnail: (Photo) async -> Data?
    let onAdd: () -> Void
    let onCompare: (Photo, Photo) -> Void

    private let columns = [GridItem(.adaptive(minimum: 88, maximum: 140), spacing: Spacing.sm)]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("visitDetail.photos")
                .font(Typography.section)
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            if photos.isEmpty {
                Text("visitDetail.photos.empty")
                    .font(Typography.meta)
                    .foregroundStyle(Palette.ink2)
            } else {
                LazyVGrid(columns: columns, alignment: .leading, spacing: Spacing.sm) {
                    ForEach(photos) { photo in tile(photo) }
                }
            }
            FittingRow {
                Button(action: onAdd) {
                    Label { Text("visitDetail.photos.add") } icon: { Image(icon: .camera) }
                }
                .buttonStyle(.belloChip(selected: false))
                .accessibilityIdentifier("visitDetail.addPhoto")
                if let pair = PhotoComparisonRules.pairs(photos).first {
                    Button { onCompare(pair.before, pair.after) } label: {
                        Label { Text("visitDetail.photos.compare") } icon: { Image(icon: .compare) }
                    }
                    .buttonStyle(.belloChip(selected: false))
                    .accessibilityIdentifier("visitDetail.comparePhotos")
                }
            }
            FooterNote(text: "recordHistory.photos.private", icon: .lock)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .belloCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("visitDetail.photosCard")
    }

    private func tile(_ photo: Photo) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay { RecordThumbnail(photo: photo, size: nil, load: loadThumbnail) }
                .clipShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
            Text(photo.kind.title)
                .font(Typography.footnoteStrong)
                .foregroundStyle(Palette.ink)
            Text(photo.visibility.title)
                .font(Typography.footnote)
                .foregroundStyle(Palette.ink2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("visitDetail.photo.\(photo.id.uuidString)")
    }
}
