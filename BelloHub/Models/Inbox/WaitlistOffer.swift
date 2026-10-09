//
//  WaitlistOffer.swift
//  BelloHub
//

import Foundation

/// A time she offers to somebody on the waitlist (`offerWaitlistSlot`, API.md 6.3): the server holds it for a while
/// for whoever opens the link first.
struct WaitlistOffer: Hashable, Codable, Sendable {
    let waitlistId: String
    let serviceId: String
    let startsAt: Date
    /// 15 to 1440; the server's default is 180.
    let holdMinutes: Int?

    init(waitlistId: String, serviceId: String, startsAt: Date, holdMinutes: Int? = nil) {
        self.waitlistId = waitlistId
        self.serviceId = serviceId
        self.startsAt = startsAt
        self.holdMinutes = holdMinutes
    }
}
