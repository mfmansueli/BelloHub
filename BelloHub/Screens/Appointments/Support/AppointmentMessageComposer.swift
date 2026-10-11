//
//  AppointmentMessageComposer.swift
//  BelloHub
//

import Foundation

/// Builds the text of a message to a client, in the business language, from the wording of its kind and the visit's
/// own day, time and service. **Never any clinical data** (docs/06-PRIVACY-SECURITY.md section 8): the only values it
/// can fill are the client's first name, the service name, the day and time, the link and her own address.
enum AppointmentMessageComposer {
    /// The wording with its `{name}`-style words still in it, in the business language.
    static func template(
        for kind: AppointmentMessageKind, localization: AppLocalization, formatters: Formatters
    ) -> String {
        let locale = localization.locale
        switch kind {
        case .cancelled:
            return LocalizedStringResource(
                "appointment.message.cancelled",
                defaultValue: """
                Hi {name}, I am sorry, I need to cancel your {service} on {date} at {time}. \
                Let me know which new time suits you.
                """
            ).resolved(in: locale)
        case .noShow:
            return LocalizedStringResource(
                "appointment.message.noShow",
                defaultValue: """
                Hi {name}, we missed you today. If you can't make it, a quick message helps me offer your time \
                to someone else. See you soon!
                """
            ).resolved(in: locale)
        case .runningLate(let minutes):
            let delay = isolated(formatters.minutes(minutes), localization)
            return LocalizedStringResource(
                "appointment.message.runningLate",
                defaultValue: "Hi {name}, I am running about \(delay) behind. Thank you for your patience!"
            ).resolved(in: locale)
        case .quickReply(let reply):
            return reply.text
        }
    }

    /// The finished text for one client.
    static func text(
        for kind: AppointmentMessageKind, values: QuickReplyValues, localization: AppLocalization,
        formatters: Formatters
    ) -> String {
        QuickReplyRenderer.render(
            template(for: kind, localization: localization, formatters: formatters), values: values,
            formatters: formatters, isolates: localization.isRightToLeft
        )
    }

    /// What fills the words of the message for this visit: the client's first name, the service, the day and time,
    /// the link (her client's own or her booking page) and where she works. Nothing else, so no message can carry
    /// clinical data.
    static func values(
        client: Client, appointment: Appointment, link: String?, location: BusinessLocation? = nil
    ) -> QuickReplyValues {
        let first = client.name.split(separator: " ").first.map(String.init) ?? client.name
        return QuickReplyValues(
            name: first, service: appointment.serviceName, startsAt: appointment.startsAt, link: link,
            address: BusinessLocationFormat.messageBlock(location)
        )
    }

    private static func isolated(_ value: String, _ localization: AppLocalization) -> String {
        localization.isRightToLeft ? BidiIsolate.wrap(value) : value
    }
}
