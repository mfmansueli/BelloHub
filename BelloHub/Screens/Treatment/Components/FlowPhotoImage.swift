//
//  FlowPhotoImage.swift
//  BelloHub
//

import SwiftUI
import UIKit

/// A photo from bytes in memory, filling its frame. A decoding failure shows a plain placeholder instead of nothing.
struct FlowPhotoImage: View {
    let data: Data

    var body: some View {
        if let image = UIImage(data: data) {
            Image(uiImage: image).resizable().scaledToFill()
        } else {
            Palette.sunken
        }
    }
}
