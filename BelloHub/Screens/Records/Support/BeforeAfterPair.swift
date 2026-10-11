//
//  BeforeAfterPair.swift
//  BelloHub
//

import Foundation

/// A "before" and an "after" photo of the same visit, shown side by side or under the slider.
struct BeforeAfterPair: Identifiable, Equatable, Sendable {
    let before: Photo
    let after: Photo

    var id: UUID { after.id }
}
