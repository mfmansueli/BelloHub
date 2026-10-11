//
//  TimeZoneNoticeText.swift
//  BelloHub
//

import Foundation

/// The sentences of the time-zone notice, with both zones named in the reader's language (`Formatters.zoneName`). One
/// owner, so the card on Home, the row on Calendar and the VoiceOver label say the same thing.
struct TimeZoneNoticeText {
    let mismatch: TimeZoneMismatch
    let formatters: Formatters
    let now: Date

    var phoneZone: String { name(mismatch.pair.phoneZoneID) }
    var businessZone: String { name(mismatch.pair.businessZoneID) }

    /// "Your iPhone is on Rome time, but your business uses São Paulo time."
    var headline: LocalizedStringResource {
        LocalizedStringResource(
            "timeZoneNotice.headline",
            defaultValue: "Your iPhone is on \(phoneZone) time, but your business uses \(businessZone) time."
        )
    }

    /// "Your iPhone is 5 h ahead of your business."
    var difference: LocalizedStringResource {
        let amount = formatters.duration(minutes: mismatch.differenceMinutes)
        return mismatch.isPhoneAhead
            ? LocalizedStringResource(
                "timeZoneNotice.ahead", defaultValue: "Your iPhone is \(amount) ahead of your business."
            )
            : LocalizedStringResource(
                "timeZoneNotice.behind", defaultValue: "Your iPhone is \(amount) behind your business."
            )
    }

    /// The quieter line at the top of Calendar: "Times are in São Paulo time. Your iPhone is on Rome time."
    var row: LocalizedStringResource {
        LocalizedStringResource(
            "timeZoneNotice.row",
            defaultValue: "Times are in \(businessZone) time. Your iPhone is on \(phoneZone) time."
        )
    }

    private func name(_ id: String) -> String {
        TimeZone(identifier: id).map { formatters.zoneName($0, at: now) } ?? id
    }
}
