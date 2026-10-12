//
//  RecordThumbnail.swift
//  BelloHub
//

import SwiftUI

/// A photo's thumbnail, decrypted on demand through `load` (thumbnail only, never the full image). It shows a quiet
/// placeholder while loading and when the bytes cannot be read, so a damaged photo never breaks a card.
struct RecordThumbnail: View {
    let photo: Photo
    /// The side of the square, or nil to fill whatever frame the parent gives (a grid cell).
    var size: CGFloat? = 56
    let load: (Photo) async -> Data?

    @State private var data: Data?

    var body: some View {
        Group {
            if let data {
                DataImage(data: data)
            } else {
                ZStack {
                    Palette.sunken
                    Image(icon: .image).font(.system(size: (size ?? 60) / 3)).foregroundStyle(Palette.ink2)
                }
            }
        }
        .frame(width: size, height: size)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
        .task(id: photo.id) { data = await load(photo) }
        .accessibilityHidden(true)
    }
}
