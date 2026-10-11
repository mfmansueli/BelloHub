//
//  DraftService.swift
//  BelloHub
//

import Foundation

/// A service she typed herself in onboarding (`Onb-4-CustomService`) before it becomes a `Service`.
struct DraftService: Identifiable, Equatable, Codable, Sendable {
    let id: UUID
    var name: String
    var category: String
    var priceAmount: Decimal?
    var minutes: Int
    var followUpWeeks: Int?
    var remindsPhotos: Bool
    var sharesAftercare: Bool

    init(
        id: UUID = UUID(), name: String = "", category: String = "", priceAmount: Decimal? = nil, minutes: Int = 60,
        followUpWeeks: Int? = 4, remindsPhotos: Bool = true, sharesAftercare: Bool = true
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.priceAmount = priceAmount
        self.minutes = minutes
        self.followUpWeeks = followUpWeeks
        self.remindsPhotos = remindsPhotos
        self.sharesAftercare = sharesAftercare
    }
}
