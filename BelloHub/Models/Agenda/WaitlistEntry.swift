//
//  WaitlistEntry.swift
//  BelloHub
//

import Foundation

/// Someone who asked to be told when a time opens up. Operational data: it may also exist on the server.
struct WaitlistEntry: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var clientID: UUID?
    var nameIfNoClient: String
    var phoneE164: String
    var serviceID: UUID?
    /// First and last day she can come, as instants at the start of those days in the business time zone.
    var dayFrom: Date
    var dayTo: Date
    var status: WaitlistStatus
    var createdAt: Date
    var offeredAt: Date?
}
