//
//  BookingConfirmationText.swift
//  BelloHub
//

import Foundation

/// Builds the text a professional can send to her client right after booking an appointment from New appointment (3.1).
/// The text uses her "Confirm appointment" quick reply (`BuiltInQuickReply.confirm`), so she keeps full control of the
/// wording, and fills it with the client's name, the service, the day and time, her address and her booking link. Pure,
/// and never any clinical data (docs/06-PRIVACY-SECURITY.md section 8).
enum BookingConfirmationText {
    struct Input: Sendable {
        var client: Client
        var serviceName: String
        var startsAt: Date
        var link: String?
        var location: BusinessLocation?
        var businessName: String?
        var confirmReply: QuickReply?
        var localization: AppLocalization
        var formatters: Formatters
    }

    /// The values that fill the quick reply words for the just-booked visit.
    static func values(
        client: Client, serviceName: String, startsAt: Date, link: String?, location: BusinessLocation?,
        businessName: String? = nil
    ) -> QuickReplyValues {
        QuickReplyValues(
            name: client.firstName, service: serviceName, startsAt: startsAt, link: link,
            address: BusinessLocationFormat.messageBlock(location), business: businessName
        )
    }

    /// The finished confirmation text for a just-booked visit, in the business language. Uses her "Confirm appointment"
    /// quick reply when she has one, or the built-in wording.
    static func text(for input: Input) -> String {
        let template = input.confirmReply?.text ?? BuiltInQuickReply.confirm.text(in: input.localization)
        let vals = values(
            client: input.client, serviceName: input.serviceName, startsAt: input.startsAt, link: input.link,
            location: input.location, businessName: input.businessName
        )
        return QuickReplyRenderer.render(
            template, values: vals, formatters: input.formatters, isolates: input.localization.isRightToLeft
        )
    }
}
