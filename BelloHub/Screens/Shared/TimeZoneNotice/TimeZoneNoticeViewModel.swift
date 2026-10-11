//
//  TimeZoneNoticeViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// State and actions of the time-zone notice on Home and Calendar (tz-mismatch-notice). The rule is
/// `TimeZoneMismatch`'s; this class reads the zones from the Services, and changes the business zone only when she
/// taps "Use my iPhone's time zone".
@MainActor
@Observable
final class TimeZoneNoticeViewModel {
    private(set) var isSaving = false
    private(set) var errorMessage: String?

    private let notice: TimeZoneNoticeService
    private let profile: ProfileService
    private let bookingSetup: BookingSetupService

    init(notice: TimeZoneNoticeService, profile: ProfileService, bookingSetup: BookingSetupService) {
        self.notice = notice
        self.profile = profile
        self.bookingSetup = bookingSetup
    }

    // MARK: - Reading

    /// The notice to show at `now`, or nil: no profile yet (she is still setting up), the zones show the same hour, or
    /// she kept this pair.
    func mismatch(now: Date) -> TimeZoneMismatch? {
        guard notice.isEnabled, let stored = profile.profile else { return nil }
        return TimeZoneMismatch.notice(
            businessZoneID: stored.timeZoneID, phoneZoneID: notice.phoneZoneID, kept: notice.kept, now: now
        )
    }

    /// Whether to add that the region and the currency stay as they are (the iPhone is in another preset's country).
    func showsRegionNote(for mismatch: TimeZoneMismatch) -> Bool {
        guard let stored = profile.profile else { return false }
        return TimeZoneMismatch.isInAnotherRegion(
            phoneZoneID: mismatch.pair.phoneZoneID, businessRegionCode: stored.regionCode, regions: notice.regions
        )
    }

    // MARK: - Actions

    /// "Keep it": hides the notice until one of the two zones changes.
    func keep(_ mismatch: TimeZoneMismatch) {
        errorMessage = nil
        notice.keep(mismatch.pair)
    }

    func usePhoneZone(_ mismatch: TimeZoneMismatch) {
        Task { await usePhoneZoneAsync(mismatch) }
    }

    /// Makes the iPhone's zone the business zone. Her hours are wall-clock hours ("09:00 to 18:00") and her days off
    /// are dates: they keep that meaning in the new zone, which is what she means when she works where she is. The
    /// profile write is a vault change, so a page that is online publishes again by itself (`PublishingService`), with
    /// the new zone on both the profile and the availability payloads.
    func usePhoneZoneAsync(_ mismatch: TimeZoneMismatch) async {
        guard !isSaving, var updated = profile.profile, updated.timeZoneID == mismatch.pair.businessZoneID,
              let zone = TimeZone(identifier: mismatch.pair.phoneZoneID) else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        updated.timeZoneID = zone.identifier
        do {
            try await profile.saveProfile(updated)
        } catch {
            errorMessage = String(interface: LocalizedStringResource(
                "timeZoneNotice.error", defaultValue: "We could not change the time zone. Try again."
            ))
            return
        }
        await alignStoredHours(with: zone)
    }

    // MARK: - Private

    /// Stores her hours with the new zone, so the zone saved with them matches the business again. Best effort: every
    /// reader already reads them in the business zone (`AvailabilitySettings.inTimeZone`), and the page publishes her
    /// days off from the zone they were saved in, so a failure here changes nothing she sees.
    private func alignStoredHours(with zone: TimeZone) async {
        if !bookingSetup.hasLoaded { try? await bookingSetup.load(timeZoneID: zone.identifier) }
        guard bookingSetup.hasLoaded, !bookingSetup.isStarterAvailability,
              bookingSetup.availability.timeZoneID != zone.identifier else { return }
        try? await bookingSetup.saveAvailability(bookingSetup.availability.inTimeZone(zone))
    }
}
