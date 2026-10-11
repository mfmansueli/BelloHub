//
//  TimeZoneMismatch.swift
//  BelloHub
//

import Foundation

/// The iPhone's clock and the business clock disagree right now (tz-mismatch-notice). Pure: zone ids and `now` in,
/// an answer out.
///
/// Why the offset at `now` and not the identifier: the calendar, the booking page and every time she reads follow the
/// business zone, and what she would notice is a *different hour*. Two ids with the same offset at this moment
/// (Europe/Rome and Europe/Paris, America/Sao_Paulo and America/Argentina/Buenos_Aires, an alias such as Asia/Calcutta
/// and Asia/Kolkata) show every visit at the same time, so telling her would be noise; she could not see any
/// difference. Zones whose daylight-saving rules differ (Rome and Lagos agree in winter, not in summer) are only
/// reported while they actually differ, which is exactly when a visit would read differently.
struct TimeZoneMismatch: Equatable, Sendable {
    /// The two zones she was told about. "Keep it" remembers this pair, so she is not asked again until one of the two
    /// changes (she travels on, or changes the business zone).
    struct Pair: Codable, Hashable, Sendable {
        let businessZoneID: String
        let phoneZoneID: String
    }

    let pair: Pair
    /// Minutes the iPhone is ahead of the business (negative when it is behind). Never zero.
    let phoneAheadMinutes: Int

    var isPhoneAhead: Bool { phoneAheadMinutes > 0 }

    /// The size of the difference, always positive ("5 h 30 min" whichever way it goes).
    var differenceMinutes: Int { abs(phoneAheadMinutes) }

    /// The mismatch between the business zone and the iPhone's at `now`, or nil when they show the same hour (or a zone
    /// id is not one Foundation knows: nothing is said about a zone the app could not name).
    static func check(businessZoneID: String, phoneZoneID: String, now: Date) -> TimeZoneMismatch? {
        guard businessZoneID != phoneZoneID,
              let business = TimeZone(identifier: businessZoneID),
              let phone = TimeZone(identifier: phoneZoneID) else { return nil }
        let seconds = phone.secondsFromGMT(for: now) - business.secondsFromGMT(for: now)
        guard seconds != 0 else { return nil }
        return TimeZoneMismatch(
            pair: Pair(businessZoneID: businessZoneID, phoneZoneID: phoneZoneID), phoneAheadMinutes: seconds / 60
        )
    }

    /// The notice to show: the mismatch at `now`, unless she already kept this very pair.
    static func notice(businessZoneID: String, phoneZoneID: String, kept: Pair?, now: Date) -> TimeZoneMismatch? {
        guard let mismatch = check(businessZoneID: businessZoneID, phoneZoneID: phoneZoneID, now: now),
              mismatch.pair != kept else { return nil }
        return mismatch
    }

    /// Whether the iPhone's zone belongs to another region preset than her business region, so the notice adds that
    /// the region and the currency do not follow the zone. A zone no preset lists says nothing: the app cannot tell
    /// which country it is.
    static func isInAnotherRegion(phoneZoneID: String, businessRegionCode: String, regions: RegionCatalog) -> Bool {
        guard let preset = regions.preset(containingTimeZone: phoneZoneID) else { return false }
        return preset.code != businessRegionCode.uppercased()
    }
}
