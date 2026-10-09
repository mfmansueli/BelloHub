//
//  AgendaBusinessContext.swift
//  BelloHub
//

import Foundation

/// What the visit screens need to know about her business to show and write times: its time zone, currency and the
/// language of the messages. Screens read dates in the language of the app (`displayLocale`) and the business time
/// zone; messages to clients are written in the **business** language (docs/07-LOCALIZATION.md section 6).
struct AgendaBusinessContext: Equatable, Sendable {
    let localization: AppLocalization
    let timeZone: TimeZone
    let currencyCode: String
    let professionalFirstName: String
    /// How people in her region usually write to each other (WhatsApp, or the Messages app).
    let preferredChannel: MessagingChannel

    init(profile: ProfessionalProfile?) {
        localization = profile.flatMap { AppLocalization(rawValue: $0.appLocaleID) } ?? .en
        timeZone = profile.flatMap { TimeZone(identifier: $0.timeZoneID) } ?? .current
        currencyCode = profile?.currencyCode ?? "USD"
        professionalFirstName = profile?.firstName ?? ""
        preferredChannel = (try? RegionCatalog.loadBundled())?.preset(for: profile?.regionCode)?.messagingChannel
            ?? .whatsapp
    }

    /// For text she reads on screen, in the language of the app.
    func formatters(displayLocale: Locale) -> Formatters {
        Formatters(locale: displayLocale, timeZone: timeZone, currencyCode: currencyCode)
    }

    /// For text a client reads, in the business language.
    var messageFormatters: Formatters {
        Formatters(locale: localization.locale, timeZone: timeZone, currencyCode: currencyCode)
    }

    var calendar: Calendar {
        messageFormatters.calendar
    }
}
