//
//  Tag.swift
//  BelloHub
//

import Foundation

/// A private label on a client (VIP, sensitive skin, bridal). Clients never see tags.
struct Tag: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var name: String
    /// A semantic color token (`rose`, `sage`, `peach`, `sand`), never a hex value.
    var colorToken: String
    var position: Int
}
