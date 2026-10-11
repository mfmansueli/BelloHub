//
//  LocalePreview.swift
//  BelloHub
//

import Foundation

/// The "What this sets" rows and the message previews of Language and region (7.2), computed from a draft so the
/// screen updates as she taps: currency, date, time, week start, phone, messaging channel and privacy law, plus two
/// quick replies and the cancellation lines rendered in the chosen language. Pure, with fixed `now` and samples.
struct LocalePreview: Equatable, Sendable {
    struct Row: Equatable, Identifiable, Sendable {
        let key: String
        let value: String
        var id: String { key }
    }

    let rows: [Row]
    /// Two quick replies (confirm, running late) filled with a sample client, in the business language.
    let messages: [String]
    /// The client-facing cancellation rules in the business language.
    let policyLines: [String]

    static func make(
        draft: LanguageRegionDraft, preset: RegionPreset?, professionalName: String, timeZone: TimeZone, now: Date,
        policy: (cancellation: CancellationPolicy, noShow: NoShowPolicy)? = nil
    ) -> LocalePreview {
        let week = LanguageRegionRules.effectiveWeekConfig(draft)
        let locale = draft.localization.locale
        let formatters = Formatters(
            locale: locale, timeZone: timeZone, currencyCode: draft.currencyCode, firstWeekday: week.firstWeekday
        )
        var rows = [
            Row(key: "languageRegion.sets.currency", value: formatters.money(Decimal(string: "1234.5") ?? 0)),
            Row(key: "languageRegion.sets.date", value: formatters.weekdayDayMonth(now)),
            Row(key: "languageRegion.sets.time", value: formatters.time(now, use24Hour: week.use24Hour)),
            Row(key: "languageRegion.sets.weekStart", value: weekdayName(week.firstWeekday, locale: locale))
        ]
        if let preset {
            let sample = "+\(preset.callingCode)" + String(repeating: "5", count: preset.nationalLengths.first ?? 9)
            let catalog = RegionCatalog(presets: [preset])
            let phone = PhoneFormatter(catalog: catalog).international(sample)
            rows.append(Row(key: "languageRegion.sets.phone", value: phone))
            let channel = channelName(preset.messagingChannel, locale: locale)
            rows.append(Row(key: "languageRegion.sets.channel", value: channel))
            rows.append(Row(key: "languageRegion.sets.privacyLaw", value: preset.privacyFrameworkId.uppercased()))
        }
        let values = QuickReplyValues(
            name: "Ana", service: sampleService(in: draft.localization), startsAt: now.addingTimeInterval(86_400),
            link: BookingLink(slug: BookingSlug.make(from: professionalName) ?? "maria").messageText
        )
        let messages = [BuiltInQuickReply.confirm, .late].map {
            QuickReplyRenderer.render(
                $0.text(in: draft.localization), values: values, formatters: formatters,
                isolates: draft.localization.isRightToLeft
            )
        }
        let policyLines = policy.map {
            PolicyRuleText(localization: draft.localization, professionalName: professionalName)
                .lines(cancellation: $0.cancellation, noShow: $0.noShow)
        } ?? []
        return LocalePreview(rows: rows, messages: messages, policyLines: policyLines)
    }

    static func weekdayName(_ weekday: Int, locale: Locale) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        let names = calendar.standaloneWeekdaySymbols
        return names.indices.contains(weekday - 1) ? names[weekday - 1] : ""
    }

    static func channelName(_ channel: MessagingChannel, locale: Locale) -> String {
        switch channel {
        case .whatsapp: "WhatsApp"
        case .messages: LocalizedStringResource("languageRegion.channel.messages").resolved(in: locale)
        }
    }

    private static func sampleService(in localization: AppLocalization) -> String {
        LocalizedStringResource("languageRegion.sample.service").resolved(in: localization.locale)
    }
}
