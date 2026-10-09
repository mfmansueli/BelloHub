//
//  RecordPhotoImage.swift
//  BelloHub
//

import SwiftUI

/// One photo of a client, loaded when it appears (the vault decrypts it on demand) and drawn to fill its frame.
/// While it loads, or when it cannot be read, a quiet placeholder stays in its place.
struct RecordPhotoImage: View {
    let photo: Photo
    var useThumbnail = true
    let load: (Photo) async -> PhotoData?

    @State private var data: Data?

    var body: some View {
        Group {
            if let data {
                FlowPhotoImage(data: data)
            } else {
                ZStack {
                    Palette.sunken
                    Image(icon: .image).font(.system(size: 22)).foregroundStyle(Palette.ink2)
                }
            }
        }
        .task(id: photo.id) {
            let loaded = await load(photo)
            data = useThumbnail ? loaded?.thumbnail : loaded?.image
        }
        .accessibilityHidden(true)
    }
}
