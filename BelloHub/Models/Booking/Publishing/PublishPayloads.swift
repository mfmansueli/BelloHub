//
//  PublishPayloads.swift
//  BelloHub
//

import Foundation

/// Builds the two requests that put her booking page online, from what is in the vault (docs/10-WEB-BOOKING.md, API.md
/// section 6.2). Pure: `now` is a parameter, so the same inputs always give the same requests, which is how the
/// publisher
/// knows a change would publish nothing new. This type is the one owner of what leaves the phone about her page.
///
/// What it never includes: a client, a note, a reason for a block, a private note, or an appointment that came from the
/// link (the server already holds those, and counting them twice would double-block a time).
enum PublishPayloads {
    static let nameLimit = 80
    static let busyLimit = 600
    static let localeLimit = 6
    static let rulesLimit = 2000

    // MARK: - Readiness

    /// What stops the page from going online at all, or nil when it can.
    static func blocker(_ inputs: PublishInputs) -> PublishFailure? {
        if inputs.setup.slug == nil { return .needsAddress }
        if offeredServices(inputs.services).isEmpty { return .needsService }
        return nil
    }

    // MARK: - Profile

    static func profile(_ inputs: PublishInputs, now: Date) -> PublishProfileRequest {
        let profile = inputs.profile
        let business = AppLocalization(rawValue: profile.appLocaleID) ?? .en
        let locales = bookingLocales(profile)
        let page = inputs.setup.page
        let timeZone = TimeZone(identifier: profile.timeZoneID) ?? .current
        let pause = BookingPause.state(of: page, now: now, timeZone: timeZone)
        let booking = bookingSwitches(page: page, pause: pause, inputs: inputs)

        var rules: [String: String] = [:]
        for locale in locales {
            let text = PolicyRuleText(localization: locale, professionalName: profile.firstName)
                .lines(cancellation: inputs.setup.cancellation, noShow: inputs.setup.noShow)
                .joined(separator: "\n")
            rules[locale.rawValue] = String(text.prefix(rulesLimit))
        }

        let formatters = Formatters(locale: business.locale, timeZone: timeZone, currencyCode: profile.currencyCode)
        return PublishProfileRequest(profile: .init(
            displayName: clip(profile.displayName),
            businessName: profile.businessName.isEmpty ? nil : clip(profile.businessName),
            regionCode: profile.regionCode,
            timeZoneID: profile.timeZoneID,
            currencyCode: profile.currencyCode,
            locales: locales.map(\.rawValue),
            credentials: credentials(inputs.credentials, business: business),
            services: offeredServices(inputs.services).map(service),
            addOns: addOns(inputs.addOns, formatters: formatters),
            booking: booking,
            policy: policy(inputs.setup.cancellation),
            rulesText: rules,
            inboxKey: inputs.inboxKey,
            intake: inputs.healthForm.flatMap { intake($0, locales: locales) }
        ))
    }

    /// The business language first, then the others she offers, each once, at most six, only ones the product speaks.
    static func bookingLocales(_ profile: ProfessionalProfile) -> [AppLocalization] {
        let business = AppLocalization(rawValue: profile.appLocaleID) ?? .en
        var result = [business]
        for id in profile.bookingLocaleIDs {
            guard let locale = AppLocalization(rawValue: id), !result.contains(locale) else { continue }
            result.append(locale)
        }
        return Array(result.prefix(localeLimit))
    }

    /// Active services, in her order. A service whose price she hides is still offered, only without a price.
    static func offeredServices(_ services: [Service]) -> [Service] {
        services.filter(\.isActive).sorted { ($0.position, $0.name) < ($1.position, $1.name) }
    }

    // MARK: - Availability

    static func availability(_ inputs: PublishInputs, now: Date) -> PublishAvailabilityRequest {
        let settings = inputs.availability
        let timeZone = settings.timeZone
        let noShow = inputs.setup.noShow
        return PublishAvailabilityRequest(
            timeZoneID: inputs.profile.timeZoneID,
            weekly: weekly(settings),
            breaks: breaks(settings),
            daysOff: daysOff(settings, now: now, timeZone: timeZone),
            bufferMinutes: min(max(settings.bufferMinutes, 0), 120),
            minNoticeHours: min(max(settings.minNoticeHours, 0), 336),
            maxDaysAhead: min(max(settings.maxDaysAhead, 1), 365),
            slotStepMinutes: AvailabilitySettings.slotStepOptions.contains(settings.effectiveSlotStep)
                ? settings.effectiveSlotStep : FreeSlotsRequest.defaultStepMinutes,
            compactDay: settings.keepsDayCompact,
            busy: busy(inputs, now: now),
            noShow: .init(
                isOn: noShow.isOn, limit: min(max(noShow.limit, 1), 5), action: noShow.action.rawValue,
                lateCancelCounts: noShow.lateCancelCounts,
                countingMonths: NoShowPolicy.countingMonthOptions.contains(noShow.countingMonths)
                    ? noShow.countingMonths : 12
            )
        )
    }

    /// Her own agenda minus link bookings: manual visits that still hold a time, and her time blocks, from `now` on.
    /// Visits made from the link carry a `bookingID` and the server already knows them (API.md 6.2).
    static func busy(_ inputs: PublishInputs, now: Date) -> [PublishAvailabilityRequest.Busy] {
        let timings = Dictionary(inputs.services.map { ($0.id, $0.visitTiming) }) { first, _ in first }
        let visits = inputs.appointments
            .filter { $0.origin == .manual && $0.bookingID == nil && $0.status.holdsTime && $0.endsAt > now }
            .map {
                PublishAvailabilityRequest.Busy(kind: "appointment", startsAt: $0.startsAt, endsAt: $0.endsAt,
                                                timing: $0.serviceID.flatMap { timings[$0] } ?? .noExtraTime)
            }
        let blocks = inputs.blocks
            .filter { $0.endsAt > now && $0.endsAt > $0.startsAt }
            .map { PublishAvailabilityRequest.Busy(kind: "block", startsAt: $0.startsAt, endsAt: $0.endsAt) }
        let all = (visits + blocks).filter { $0.endsAt > $0.startsAt }
            .sorted { ($0.startsAt, $0.endsAt, $0.kind) < ($1.startsAt, $1.endsAt, $1.kind) }
        return Array(all.prefix(busyLimit))
    }

    /// `YYYY-MM-DD` of the day `date` falls on in `timeZone`, with plain digits in every language.
    static func localDate(_ date: Date, timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 1970, parts.month ?? 1, parts.day ?? 1)
    }

    // MARK: - Parts

    private static func bookingSwitches(
        page: BookingPageSettings, pause: BookingPageState, inputs: PublishInputs
    ) -> PublishProfileRequest.Booking {
        var until: Date?
        var accepting = true
        if case .paused(let returnDay) = pause {
            accepting = false
            until = returnDay
        }
        return .init(
            acceptingBookings: accepting, pausedUntil: until, requiresApproval: page.confirmNewClients,
            maxGuests: min(max(page.maxGuests, 0), 2), maxDaysAhead: min(max(inputs.availability.maxDaysAhead, 1), 365)
        )
    }

    private static func policy(_ policy: CancellationPolicy) -> PublishProfileRequest.Policy {
        .init(
            freeWindowHours: CancellationPolicy.freeWindowOptions.contains(policy.freeWindowHours)
                ? policy.freeWindowHours : CancellationPolicy.standard.freeWindowHours,
            clientCanReschedule: policy.clientCanReschedule,
            maxReschedules: policy.maxReschedules.map { min(max($0, 0), 20) },
            afterWindowCancel: policy.afterWindowCancel.rawValue,
            afterWindowReschedule: policy.afterWindowReschedule.rawValue,
            askConfirmation: policy.askConfirmation,
            graceMinutes: min(max(policy.graceMinutes, 5), 20)
        )
    }

    private static func service(_ service: Service) -> PublishProfileRequest.Service {
        let minutes = min(max(service.durationMinutes, 5), 720)
        let timing = PublishTimingFields(service.visitTiming, visibleMinutes: minutes)
        return .init(
            id: service.id.uuidString.lowercased(),
            name: clip(service.name),
            category: service.category.isEmpty ? nil : clip(service.category),
            durationMinutes: minutes,
            price: price(service),
            prepMinutes: timing.prepMinutes,
            cleanupMinutes: timing.cleanupMinutes,
            processingStartMinutes: timing.processingStartMinutes,
            processingMinutes: timing.processingMinutes
        )
    }

    private static func price(_ service: Service) -> PublishProfileRequest.Price? {
        switch service.priceDisplay {
        case .hide: nil
        case .onRequest: .init(display: "onRequest", amount: nil)
        case .show: service.priceAmount.map { .init(display: "show", amount: rounded($0)) }
        case .startingFrom: service.priceAmount.map { .init(display: "startingFrom", amount: rounded($0)) }
        }
    }

    private static func addOns(_ addOns: [AddOn], formatters: Formatters) -> [PublishProfileRequest.AddOn] {
        addOns.filter(\.isOffered).sorted { ($0.position, $0.name) < ($1.position, $1.name) }.prefix(30).map { addOn in
            .init(
                id: addOn.id.uuidString.lowercased(), name: clip(addOn.name), minutes: min(max(addOn.minutes, 1), 240),
                priceText: addOn.priceAmount.map { String(formatters.money(rounded($0)).prefix(160)) }
            )
        }
    }

    private static func credentials(
        _ credentials: [Credential], business: AppLocalization
    ) -> [PublishProfileRequest.Credential] {
        credentials.filter(\.showOnBookingPage).sorted { ($0.position, $0.title) < ($1.position, $1.title) }
            .prefix(20).compactMap { credential in
                let number = credential.registrationNumber?.trimmingCharacters(in: .whitespaces)
                switch credential.kind {
                case .registration:
                    guard let number, !number.isEmpty else { return nil }
                    let title = LocalizedStringResource(
                        "credentials.registration.title", defaultValue: "Professional registration"
                    ).resolved(in: business.locale)
                    return .init(title: title, institution: nil, year: nil, registrationNumber: clip(number, to: 40))
                case .training:
                    guard !credential.title.isEmpty else { return nil }
                    return .init(
                        title: clip(credential.title, to: 120),
                        institution: credential.institution.isEmpty ? nil : clip(credential.institution, to: 120),
                        year: credential.year.flatMap { (1950...2100).contains($0) ? $0 : nil },
                        registrationNumber: nil
                    )
                }
            }
    }

    private static func weekly(_ settings: AvailabilitySettings) -> [PublishAvailabilityRequest.Weekly] {
        settings.weekly
            .filter { (1...7).contains($0.weekday) && $0.startMinutes >= 0 && $0.endMinutes <= 1440
                && $0.endMinutes > $0.startMinutes }
            .sorted { ($0.weekday, $0.startMinutes) < ($1.weekday, $1.startMinutes) }
            .prefix(56).map { .init(weekday: $0.weekday, startMinutes: $0.startMinutes, endMinutes: $0.endMinutes) }
    }

    private static func breaks(_ settings: AvailabilitySettings) -> [PublishAvailabilityRequest.Break] {
        settings.breaks
            .filter { $0.startMinutes >= 0 && $0.endMinutes <= 1440 && $0.endMinutes > $0.startMinutes
                && ($0.weekday.map { (1...7).contains($0) } ?? true) }
            .sorted { ($0.weekday ?? 0, $0.startMinutes) < ($1.weekday ?? 0, $1.startMinutes) }
            .prefix(28).map { .init(weekday: $0.weekday, startMinutes: $0.startMinutes, endMinutes: $0.endMinutes) }
    }

    /// Days off that have not ended yet, as local dates; a range ending before today tells the server nothing.
    private static func daysOff(
        _ settings: AvailabilitySettings, now: Date, timeZone: TimeZone
    ) -> [PublishAvailabilityRequest.DayOff] {
        let today = localDate(now, timeZone: timeZone)
        return settings.daysOff
            .map { range in
                PublishAvailabilityRequest.DayOff(
                    startDate: localDate(range.startDate, timeZone: timeZone),
                    endDate: localDate(range.endDate, timeZone: timeZone)
                )
            }
            .filter { $0.endDate >= today && $0.endDate >= $0.startDate }
            .sorted { ($0.startDate, $0.endDate) < ($1.startDate, $1.endDate) }
            .prefix(100).map { $0 }
    }

    private static func clip(_ text: String, to limit: Int = nameLimit) -> String {
        String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(limit))
    }

    private static func rounded(_ amount: Decimal) -> Decimal {
        var source = amount
        var result = Decimal()
        NSDecimalRound(&result, &source, 2, .plain)
        return result
    }
}
