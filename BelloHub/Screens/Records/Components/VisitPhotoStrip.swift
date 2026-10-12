//
//  VisitPhotoStrip.swift
//  BelloHub
//

import SwiftUI

/// The thumbnails of one visit in a row: the first few, then "+N" for the rest. Decorative on a card (the card's
/// label says how many photos there are).
struct VisitPhotoStrip: View {
    static let visibleCount = 4

    let photos: [Photo]
    var size: CGFloat = 56
    let load: (Photo) async -> Data?
    @Environment(\.locale) private var locale

    var body: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(photos.prefix(Self.visibleCount)) { photo in
                RecordThumbnail(photo: photo, size: size, load: load)
            }
            if photos.count > Self.visibleCount {
                Text(verbatim: "+\((photos.count - Self.visibleCount).formatted(.number.locale(locale)))")
                    .font(Typography.metaStrong)
                    .foregroundStyle(Palette.ink2)
                    .frame(width: size, height: size)
                    .background(Palette.sunken, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
            }
        }
        .accessibilityHidden(true)
    }
}
