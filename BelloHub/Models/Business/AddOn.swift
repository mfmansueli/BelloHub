//
//  AddOn.swift
//  BelloHub
//

import Foundation

/// An extra a client can tick when booking. It adds time to the visit. Its price is information only, shown by the
/// same visibility rule as the service's (D4).
struct AddOn: Identifiable, Hashable, Codable, Sendable, Positioned {
    let id: UUID
    var name: String
    var minutes: Int
    var priceAmount: Decimal?
    var isOffered: Bool
    var position: Int
}
