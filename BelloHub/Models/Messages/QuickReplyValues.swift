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
    /// The full address of the link the message carries (`ClientLinkText.text`): her client's own link to change or
    /// cancel (`https://bellohub.app/m/…`) or her booking page (`https://bellohub.app/maria`). Never the short form.
    var link: String?
    /// `BusinessLocationFormat.messageBlock`: a few lines ending with a map link; nil or empty when she has no address,
    /// and then `{address}` disappears instead of staying as written.
    var address: String?
    /// The business name (or professional display name) for the farewell sign-off.
    var business: String?

    init(
        name: String? = nil, service: String? = nil, startsAt: Date? = nil, link: String? = nil,
        address: String? = nil, business: String? = nil
    ) {
        self.name = name
        self.service = service
        self.startsAt = startsAt
        self.link = link
        self.address = address
        self.business = business
    }
}
