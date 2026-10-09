//
//  HomeViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// State and actions of Home (2.1). The data is `AgendaDigestService`'s (one observation shared with Alerts, Follow-ups
/// and Win back); this class starts it, reads her hours, and turns the raw data into the day's digest at the moment
/// the screen asks, so "in 1 h 20 min" stays true as the minutes pass.
@MainActor
@Observable
final class HomeViewModel {
    let settings: CalendarSettings
    private let source: AgendaDigestSource
    private let bookingSetup: BookingSetupService

    init(
        settings: CalendarSettings, digest: AgendaDigestService, bookingSetup: BookingSetupService,
        prefs: any NotificationPrefsStoring = DefaultsNotificationPrefsStore()
    ) {
        self.settings = settings
        self.bookingSetup = bookingSetup
        source = AgendaDigestSource(service: digest, bookingSetup: bookingSetup, settings: settings, prefs: prefs)
    }

    // MARK: - Reading

    func digest(now: Date) -> AgendaDigest {
        source.digest(now: now)
    }

    /// Loading until the visits arrived once, an error when the vault is not available, otherwise content (an empty day
    /// is a state of the content, because the follow-ups below may still have something to say).
    var phase: ScreenPhase {
        source.phase(isEmpty: false)
    }

    // MARK: - Actions

    /// Starts the observation and reads her hours (for the open slots of the week).
    func start() {
        source.service.startListening()
        Task { await loadHours() }
    }

    func retry() {
        Task { await refreshAsync() }
    }

    func refreshAsync() async {
        await source.service.refresh()
        await loadHours()
    }

    // MARK: - Private

    private func loadHours() async {
        try? await bookingSetup.load(timeZoneID: settings.timeZoneID)
    }
}
