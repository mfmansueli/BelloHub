//
//  QuickReplyValues.swift
//  BelloHub
//

import Foundation

/// What fills the words of a quick reply for one client. A value that is nil leaves its word in the message as written,
/// so she sees the gap when she reads the message before sending it (she always does, D14).
struct QuickReplyValues: Equatable, Sendable {
    var name: String?
    var service: String?
    /// The start of the visit: `{date}` and `{time}` both come from it, in the business time zone.
    var startsAt: Date?
    /// The booking link as people read it (`bellohub.app/maria`), or her client's personal link.
    var link: String?

    init(name: String? = nil, service: String? = nil, startsAt: Date? = nil, link: String? = nil) {
        self.name = name
        self.service = service
        self.startsAt = startsAt
        self.link = link
    }
}
