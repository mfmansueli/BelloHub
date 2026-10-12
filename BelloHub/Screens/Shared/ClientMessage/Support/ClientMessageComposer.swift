//
//  ClientMessageComposer.swift
//  BelloHub
//

import Foundation

/// Builds the text of a follow-up, win-back or birthday message, in the business language. Follow-ups and win-back use
/// **her own** "Come back soon" quick reply (she may have rewritten it), falling back to the built-in wording. The only
/// values a message can carry are the client's first name, a service name and her booking link, so it can never hold
/// clinical data (docs/06-PRIVACY-SECURITY.md section 8). Pure.
enum ClientMessageComposer {
    /// The wording with its `{name}`-style words still in it.
    static func template(for kind: ClientMessageRequest.Kind, comeBack: QuickReply?, localization: AppLocalization)
        -> String {
        switch kind {
        case .followUp, .winBack:
            return comeBack?.text ?? BuiltInQuickReply.comeBack.text(in: localization)
        case .birthday:
            return LocalizedStringResource(
                "clientMessage.birthday",
                defaultValue: """
                Happy birthday, {name}! Wishing you a lovely day. Whenever you want a little care, I am here.
                """
            ).resolved(in: localization.locale)
        case .general:
            return LocalizedStringResource("clientMessage.general", defaultValue: "Hi {name}! ")
                .resolved(in: localization.locale)
        }
    }

    /// What fills the words: the client's first name, the service (the follow-up's own, or the one of her last visit)
    /// and her booking link when she has one.
    static func values(
        for kind: ClientMessageRequest.Kind, client: Client, lastServiceName: String?, link: String?,
        location: BusinessLocation? = nil
    ) -> QuickReplyValues {
        let service: String? = if case .followUp(let name) = kind { name } else { lastServiceName }
        return QuickReplyValues(
            name: client.firstName, service: service, startsAt: nil, link: link,
            address: BusinessLocationFormat.messageBlock(location)
        )
    }

    /// The finished text for one client.
    static func text(
        for kind: ClientMessageRequest.Kind, comeBack: QuickReply?, values: QuickReplyValues,
        localization: AppLocalization, formatters: Formatters
    ) -> String {
        QuickReplyRenderer.render(
            template(for: kind, comeBack: comeBack, localization: localization), values: values,
            formatters: formatters, isolates: localization.isRightToLeft
        )
    }

    /// The service of her last completed visit, for a win-back message ("It has been a while since your Glow Facial").
    static func lastServiceName(in appointments: [Appointment]) -> String? {
        appointments.filter { $0.status == .completed }.max { $0.startsAt < $1.startsAt }?.serviceName
    }
}
