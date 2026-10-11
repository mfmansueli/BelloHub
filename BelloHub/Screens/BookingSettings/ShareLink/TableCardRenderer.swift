//
//  TableCardRenderer.swift
//  BelloHub
//

import SwiftUI

/// Turns the table card into a picture she can share. `ImageRenderer` draws the SwiftUI view at print resolution;
/// nothing is written to disk here, the share sheet takes the image from memory.
@MainActor
enum TableCardRenderer {
    static func image(for card: TableCardView) -> Image? {
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        return renderer.uiImage.map(Image.init(uiImage:))
    }
}
