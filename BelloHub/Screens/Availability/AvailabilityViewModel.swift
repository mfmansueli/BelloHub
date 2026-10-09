//
//  AvailabilityViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// State and actions of the Availability screen (6.5): her weekly hours, breaks, the time between clients and days off.
/// Reads and writes go through `BookingSetupService`. Every change is saved as she makes it ("changes apply right
/// away"); the rules behind each change are `AvailabilityEditor`'s, so this class only sequences them.
@MainActor
@Observable
final class AvailabilityViewModel {
    /// What the screen shows. A copy of the service's settings that a change updates at once, so a switch does not snap
    /// back while the write runs; a failed write puts the service's copy back.
    private(set) var settings: AvailabilitySettings
    private(set) var isStarter: Bool
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    /// Her hours could not be read; the screen shows this with a retry.
    private(set) var errorMessage: String?
    /// A change could not be saved; the screen shows it above the list and the list stays as it was.
    private(set) var saveErrorMessage: String?

    let timeZoneID: String
    private let service: BookingSetupService
    private let now: @Sendable () -> Date
    /// The stretches a day had before she switched it off, so switching it back on restores them.
    private var remembered: [AvailabilityRule] = []

    init(service: BookingSetupService, timeZoneID: String, now: @escaping @Sendable () -> Date = { Date() }) {
        self.service = service
        self.timeZoneID = timeZoneID
        self.now = now
        settings = service.availability
        isStarter = service.isStarterAvailability
    }

    // MARK: - Reading

    /// Whether to draw placeholder rows: the first read is running and nothing is known yet.
    var showsSkeleton: Bool { isLoading && !hasLoaded }

    var upcomingDaysOff: [DayOff] { AvailabilityEditor.upcomingDaysOff(settings, now: now()) }

    var sortedBreaks: [(index: Int, rule: BreakRule)] { AvailabilityEditor.sortedBreaks(settings) }

    var canAddBreak: Bool { settings.breaks.count < AvailabilityEditor.maxBreaks }

    // MARK: - Loading

    /// Entry point for appearing and retrying; `loadAsync()` is what tests await.
    func load() {
        Task { await loadAsync() }
    }

    func loadAsync() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
            hasLoaded = true
        }
        do {
            try await service.load(timeZoneID: timeZoneID)
            adoptService()
        } catch {
            errorMessage = String(
                localized: "availability.error.load",
                defaultValue: "We could not read your availability. Check that your iPhone is unlocked and try again."
            )
        }
    }

    func dismissSaveError() {
        saveErrorMessage = nil
    }

    // MARK: - Editing

    func setDay(_ weekday: Int, open: Bool) async {
        if !open { remembered += AvailabilityEditor.stretches(for: weekday, in: settings) }
        await commit(AvailabilityEditor.setting(weekday, open: open, in: settings, restoring: remembered))
    }

    /// Saves the stretches of one day. Returns nil when saved, or why it was not.
    func saveStretches(of weekday: Int, _ drafts: [StretchDraft]) async -> AvailabilityIssue? {
        switch AvailabilityEditor.replacingStretches(of: weekday, with: drafts, in: settings) {
        case .failure(let issue): return issue
        case .success(let updated):
            await commit(updated)
            return nil
        }
    }

    /// Saves a break (a new one when `index` is nil). Returns nil when saved, or why it was not.
    func saveBreak(_ rule: BreakRule, at index: Int?, fallbackLabel: String) async -> AvailabilityIssue? {
        switch AvailabilityEditor.savingBreak(rule, at: index, fallbackLabel: fallbackLabel, in: settings) {
        case .failure(let issue): return issue
        case .success(let updated):
            await commit(updated)
            return nil
        }
    }

    func deleteBreak(at index: Int) async {
        await commit(AvailabilityEditor.removingBreak(at: index, from: settings))
    }

    func saveDayOff(_ dayOff: DayOff) async -> AvailabilityIssue? {
        switch AvailabilityEditor.savingDayOff(dayOff, now: now(), in: settings) {
        case .failure(let issue): return issue
        case .success(let updated):
            await commit(updated)
            return nil
        }
    }

    func deleteDayOff(id: UUID) async {
        await commit(AvailabilityEditor.removingDayOff(id: id, from: settings))
    }

    func setBuffer(_ minutes: Int) async {
        var updated = settings
        updated.bufferMinutes = minutes
        await commit(updated)
    }

    // MARK: - Private

    /// Shows `updated` at once, writes it, and goes back to what is stored if the write fails.
    private func commit(_ updated: AvailabilitySettings) async {
        guard updated != settings else { return }
        settings = updated
        isStarter = false
        saveErrorMessage = nil
        do {
            try await service.saveAvailability(updated)
        } catch {
            adoptService()
            saveErrorMessage = String(
                localized: "bookingSetup.error.save",
                defaultValue: "We could not save this change. Check that your iPhone has space and try again."
            )
        }
    }

    private func adoptService() {
        settings = service.availability
        isStarter = service.isStarterAvailability
    }
}
