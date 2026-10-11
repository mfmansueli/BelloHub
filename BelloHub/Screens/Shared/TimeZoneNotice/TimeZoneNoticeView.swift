//
//  TimeZoneNoticeView.swift
//  BelloHub
//

import SwiftUI

/// The time-zone notice of a screen (tz-mismatch-notice): a card on Home, a quieter row at the top of Calendar. It
/// reads the Services from the environment and hands them to `TimeZoneNoticeContent`, which owns the ViewModel (a View
/// cannot read the environment in its `init`). Shows nothing when the zones agree, when she kept this pair, or in a
/// preview that does not inject `TimeZoneNoticeService`.
struct TimeZoneNoticeView: View {
    let placement: TimeZoneNoticeContent.Placement
    /// The screen's formatters (interface language), for the zone names and the difference.
    let formatters: Formatters
    let now: Date

    @Environment(TimeZoneNoticeService.self) private var notice: TimeZoneNoticeService?
    @Environment(ProfileService.self) private var profile
    @Environment(BookingSetupService.self) private var bookingSetup

    var body: some View {
        if let notice {
            TimeZoneNoticeContent(
                viewModel: TimeZoneNoticeViewModel(notice: notice, profile: profile, bookingSetup: bookingSetup),
                placement: placement, formatters: formatters, now: now
            )
        }
    }
}
