//
//  PhotoProcessing+Environment.swift
//  BelloHub
//

import SwiftUI

extension EnvironmentValues {
    /// How photos are prepared before the vault seals them. A test injects a fake; the owner swaps the default later.
    @Entry var photoProcessing: any PhotoProcessing = ImageIOPhotoProcessing()
}
