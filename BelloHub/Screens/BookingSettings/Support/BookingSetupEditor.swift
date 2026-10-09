//
//  BookingSetupEditor.swift
//  BelloHub
//

import Foundation
import Observation

/// The write path the booking screens share (booking page, cancel policy, no-show policy, share link): it shows a
/// change at once, saves it through `BookingSetupService`, and goes back to what is stored if the write fails. One
/// owner of that sequence, so the four screens cannot disagree about it.
@MainActor
@Observable
final class BookingSetupEditor {
    /// What the screens show. A copy of the service's setup that a change updates at once, so a switch does not snap
    /// back while the write runs.
    private(set) var setup: BookingSetup
    /// A change could not be saved; the screen shows it and the setup is back to what is stored.
    private(set) var saveErrorMessage: String?

    private let service: BookingSetupService

    init(service: BookingSetupService) {
        self.service = service
        setup = service.setup
    }

    /// Takes the stored setup again: when a screen appears (another screen may have changed it) and after a failed
    /// write.
    func adoptStored() {
        setup = service.setup
    }

    /// Applies `change` to the setup, shows it, and saves it. Returns whether it was saved.
    @discardableResult
    func apply(_ change: (inout BookingSetup) -> Void) async -> Bool {
        var updated = setup
        change(&updated)
        guard updated != setup else { return true }
        setup = updated
        saveErrorMessage = nil
        do {
            try await service.saveSetup(updated)
            return true
        } catch {
            adoptStored()
            saveErrorMessage = String(
                localized: "bookingSetup.error.save",
                defaultValue: "We could not save this change. Check that your iPhone has space and try again."
            )
            return false
        }
    }

    func dismissSaveError() {
        saveErrorMessage = nil
    }
}
