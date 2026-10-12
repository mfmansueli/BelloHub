//
//  SettingsSubtitles.swift
//  BelloHub
//

import SwiftUI

/// The live lines under the rows that open her settings ("Taking bookings", "Tue to Sat · 09:00 – 19:00", "Your plan
/// is on", "Esthetician · Brazil"). More and the quick access sheet on Home both read them here, so the two always say
/// the same thing.
@MainActor
struct SettingsSubtitles {
    let profile: ProfileService
    let bookingSetup: BookingSetupService
    let publishing: PublishingService
    let subscription: SubscriptionService?
    let locale: Locale

    /// "Bello Hub Pro" or "No plan yet"; nothing until the store answered.
    var plan: Text? {
        guard let state = subscription?.state else { return nil }
        switch state {
        case .unknown: return nil
        case .none: return Text("more.row.plan.none")
        case .active, .inGracePeriod: return Text("more.row.plan.active")
        }
    }

    /// "Not online yet" until her page is published, then "Taking bookings", "Paused" or "Paused until Oct 20"; nothing
    /// until the settings are read.
    func bookingPage(now: Date = Date()) -> Text? {
        guard bookingSetup.hasLoaded else { return nil }
        let zone = timeZone
        let formatters = Formatters(locale: locale, timeZone: zone, currencyCode: "EUR")
        let summary = BookingSetupSummary.page(
            bookingSetup.setup.page, now: now, timeZone: zone, formatters: formatters
        )
        return Text(PublishStatusText.rowSubtitle(publishing.state, pageSummary: summary).localized(in: locale))
    }

    /// "Tue to Sat · 09:00 – 19:00"; nothing until the settings are read.
    var availability: Text? {
        guard bookingSetup.hasLoaded else { return nil }
        let formatters = Formatters(locale: locale, timeZone: bookingSetup.availability.timeZone, currencyCode: "EUR")
        let firstWeekday = profile.profile?.weekConfig.firstWeekday ?? Calendar.current.firstWeekday
        return Text(verbatim: AvailabilityText(formatters: formatters, firstWeekday: firstWeekday)
            .weekSummary(of: bookingSetup.availability))
    }

    /// Her public name, as on her booking page.
    var name: String {
        profile.profile?.publicName ?? ""
    }

    /// "Esthetician · Brazil": her first profession and her region, in the language of the app.
    var headline: String {
        guard let current = profile.profile else { return "" }
        let region = locale.localizedString(forRegionCode: current.regionCode)
        // The profession's name is interface text: the interface language, not the business one.
        let localization = AppLocalization(resolving: locale)
        let profession = (try? ProfessionCatalog.loadBundled(localization: localization))
            .flatMap { catalog in current.professions.first.flatMap { catalog.entry(for: $0)?.name } }
        return [profession, region].compactMap { $0 }.joined(separator: " · ")
    }

    private var timeZone: TimeZone {
        profile.profile.flatMap { TimeZone(identifier: $0.timeZoneID) } ?? .current
    }
}
