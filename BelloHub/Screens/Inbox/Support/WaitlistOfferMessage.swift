//
//  WaitlistOfferMessage.swift
//  BelloHub
//

import Foundation

/// The message that takes a waitlist offer to the person (2.9, docs/10-WEB-BOOKING.md section 3): the time that opened,
/// until when it is held for them, and the one-time link that books it, in the business language. Before this the app
/// made the offer on the server and dropped the link, so nobody ever received it. The link follows `ClientLinkText`
/// (full address, own line). Booking facts only, never anything clinical. Pure.
enum WaitlistOfferMessage {
    struct Input: Equatable, Sendable {
        let personName: String
        let serviceName: String
        let startsAt: Date
        /// When the server lets the hold go.
        let heldUntil: Date
        /// `https://…/<slug>/time?offer=<key>`.
        let link: URL
    }

    static func text(_ input: Input, localization: AppLocalization, formatters: Formatters) -> String {
        let rtl = localization.isRightToLeft
        let first = input.personName.split(separator: " ").first.map(String.init) ?? input.personName
        let name = rtl ? BidiIsolate.wrap(first) : first
        let service = rtl ? BidiIsolate.wrap(input.serviceName) : input.serviceName
        let date = formatters.weekdayDayMonth(input.startsAt)
        let time = formatters.time(input.startsAt)
        // Day and time, like the {deadline} of every message template (docs/strings/message-templates.json).
        let deadline = "\(formatters.weekdayDayMonth(input.heldUntil)), \(formatters.time(input.heldUntil))"
        let sentence = LocalizedStringResource(
            "waitlist.offerMessage",
            defaultValue: """
            Hi \(name)! A time just opened for \(service) on \(rtl ? BidiIsolate.wrap(date) : date) at \
            \(rtl ? BidiIsolate.wrapLeftToRight(time) : time). It is yours if you confirm by \
            \(rtl ? BidiIsolate.wrap(deadline) : deadline):
            """
        ).resolved(in: localization.locale)
        return ClientLinkText.appendOnOwnLine(ClientLinkText.text(input.link), to: sentence)
    }
}
