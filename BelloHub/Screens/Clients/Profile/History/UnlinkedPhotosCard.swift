//
//  UnlinkedPhotosCard.swift
//  BelloHub
//

import SwiftUI

/// Photos that belong to no visit (saved before the record, or kept after a record was removed). They are never
/// attached to a visit by date: she chooses where each one goes.
struct UnlinkedPhotosCard: View {
    let photos: [Photo]
    let loadThumbnail: (Photo) async -> Data?
    let onOrganize: () -> Void
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(LocalizedStringResource(
                "clientRecord.unlinked.title", defaultValue: "\(photos.count) photos without a visit"
            ).localized(in: locale))
                .font(Typography.bodyStrong)
                .foregroundStyle(Palette.ink)
            Text("clientRecord.unlinked.message")
                .font(Typography.meta)
                .foregroundStyle(Palette.ink2)
            VisitPhotoStrip(photos: photos, load: loadThumbnail)
            Button(action: onOrganize) {
                Label { Text("clientRecord.unlinked.organize") } icon: { Image(icon: .photoStack) }
            }
            .buttonStyle(.belloSecondary)
            .accessibilityIdentifier("clientRecord.unlinked.organize")
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .belloCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("clientRecord.unlinked")
    }
}
