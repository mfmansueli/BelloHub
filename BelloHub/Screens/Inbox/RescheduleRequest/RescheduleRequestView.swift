//
//  RescheduleRequestView.swift
//  BelloHub
//

import SwiftUI

/// 2.11 RescheduleRequest, pushed with `AgendaRoute.rescheduleRequest` (from Alerts). It reads the Services from the
/// environment and hands them to `RescheduleRequestContentView`, which owns the ViewModel.
struct RescheduleRequestView: View {
    let requestID: String
    @Environment(BookingSyncService.self) private var sync
    @Environment(ProfileService.self) private var profile

    var body: some View {
        RescheduleRequestContentView(
            viewModel: RescheduleRequestViewModel(requestID: requestID, sync: sync),
            settings: CalendarSettings(profile: profile.profile)
        )
    }
}
